## 引言

在Sui Move智能合约开发中，模块间的交互是构建复杂应用的基础。然而，这种交互也引入了新的安全风险。本章将深入探讨跨合约交互的安全问题，分析潜在风险，并提供实用的防御策略。

## 1. Sui中跨合约交互

### 1.1 跨合约交互的基本概念

跨合约交互是指一个智能合约模块调用或访问另一个模块的功能或资源。在Sui Move中，这种交互通过以下方式实现：

模块导入：使用use关键字导入其他模块的功能。

``` move
use game::inventory::{Self, Sword, Armor};
```

友元关系：通过friend关键字建立模块间的特权访问。

```move
friend game::adventure;
```

公共接口：通过public函数提供对外服务。

```move
public fun remove_sword(hero: &mut Hero): Sword {
    assert!(option::is_some(&hero.sword), ENO_SWORD);
    option::extract(&mut hero.sword)
}
```

对象传递：在模块间传递和操作对象。

```move
let sword = inventory::create_sword(ctx);
hero::equip_or_levelup_sword(hero, sword, ctx);
```

### 1.2 跨合约交互的应用场景

在Sui Move生态系统中，跨合约交互广泛应用于：</br>
组合式应用：将功能分解为多个专用模块，如游戏系统中的英雄、装备和冒险模块。</br>
标准库集成：与Sui标准库（如sui::object、sui::transfer）交互。</br>
协议互操作：DeFi协议间的流动性共享和资产交换。</br>
权限管理：通过专用模块实现访问控制和权限验证。

### 1.3 跨合约交互的特点

模块边界：Sui Move强制执行严格的模块边界，限制对内部状态的直接访问。</br>
能力约束：对象的传递和操作受能力系统（如key、store）约束。</br>
类型安全：编译时类型检查确保交互的类型兼容性。</br>
可见性控制：通过public、public(friend)和public(package)控制函数访问权限。

## 2. 跨模块交互的风险分析

### 2.1 信任边界问题

跨合约交互引入了信任边界，当一个模块调用另一个模块时，调用方需要信任被调用方的实现。这种信任可能导致以下风险：

接口滥用：攻击者可能以非预期方式调用公共接口。例如，在游戏系统中，如果create_sword函数没有适当的访问控制：

```move
// 风险：任何人都可以创建武器
public fun create_sword(_ctx: &mut TxContext): Sword {
    Sword {
        rarity: 1,
        strength: BASE_SWORD_STRENGTH,
    }
}
```

状态不一致：模块间状态同步失败可能导致系统不一致。例如，如果英雄打怪兽结束后没有更新英雄的一些属性值：

```move
// 英雄的HP在战斗过程中会在本地变量hero_hp中减少，但是这些变化并没有被写回到Hero对象中，
// 这导致战斗结束后英雄应该受到的伤害没有持久化到其状态中
fun fight_monster<T>(hero:  &Hero, monster: &Monster<T>):u64{
    let hero_strength = hero::strength(hero);
    let hero_defense = hero::defense(hero);
    let hero_hp = hero::hp(hero);
    let monster_hp = monster.hp;
    // attack the monster until its HP goes to zero
    let cnt = 0u64; // max fight times
    let rst = 0u64; // 0: tie, 1: hero win, 2: monster win;
    // 战斗逻辑...
    // 英雄和怪物互相攻击，hero_hp可能会减少
    // ...
    rst
}
```

### 2.2 权限控制缺陷

不当的权限控制是跨合约交互中的常见漏洞：

缺少访问控制：关键函数未实施适当的权限检查。

```move
// 铸造代币没有管理员检查
public entry fun mint_tokens(
    treasury_cap: &mut TreasuryCap<GAME_TOKEN>,
    amount: u64,
    recipient: address,
    _config: &GameConfig, // 仅用于读取配置，但没有检查调用者是否为管理员
    ctx: &mut TxContext
) {
    // 缺少管理员权限验证！
    // 应该有：assert!(tx_context::sender(ctx) == config.admin, 0);
    // 检查系统是否暂停
    assert!(!_config.paused, 1);
    // 检查铸币上限
    assert!(amount <= _config.daily_mint_limit, 2);
    // 铸造代币
    let minted_coins = coin::mint(treasury_cap, amount, ctx);
    // 转移给接收者
    transfer::public_transfer(minted_coins, recipient);
}
```

权限提升 ：通过中间模块绕过访问控制。例如，虽然模块A限制了函数访问，但模块B作为友元可以访问并暴露了该功能：

```move
// 模块A
module game::treasury{
    friend game::trusted_manager;

    // 从国库提取资金 - 受限函数，只允许友元模块调用
    public(friend) fun withdraw(
        treasury: &mut Treasury,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(treasury.balance >= amount, 0);
        treasury.balance = treasury.balance - amount;
        let coin = coin::mint_for_testing<SUI>(amount, ctx); 
        transfer::public_transfer(coin, recipient);
    }
}
```

```move
// 模块B
module game::trusted_manager {
    public fun withdraw_funds(
        treasury: &mut treasury::Treasury, 
        amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        // 风险：直接调用受限函数，没有进行任何权限验证
        // 应该在这里添加管理员检查，例如：
        // assert!(tx_context::sender(ctx) == ADMIN_ADDRESS, 0);
        treasury::withdraw(treasury, amount, recipient, ctx);
    }
}
```

验证绕过：接受外部验证结果而非直接验证。

```move
// 依赖外部验证
public fun process_withdrawal(
    treasury: &mut Treasury,
    request: WithdrawRequest,
    is_verified: bool, // 外部传入的验证结果
    ctx: &mut TxContext
) {
    // 风险：直接信任外部传入的验证结果
    if (is_verified) {
        // 如果验证通过，执行提款
        let amount = request.amount;
        let recipient = request.recipient;
        assert!(treasury.balance >= amount, 0);
        treasury.balance = treasury.balance - amount;
        let payment = coin::mint_for_testing<SUI>(amount, ctx);
        transfer::transfer(payment, recipient);
    }
}
```

### 2.3 对象安全问题

对象在模块间传递时面临特殊风险：

对象伪造：攻击者创建结构相似但非法的对象。

```move
// 使用无价值的FakeCoin也可以获取投票权
public entry fun register_voter<T>(vote_coin: coin::Coin<T>, ctx: &mut TxContext) {
    let amount = vote_coin.value();
    assert!(amount == 100,1);
    let sender = tx_context::sender(ctx);
    let token = VoteToken<T> {
        id: object::new(ctx),
        amount: 100,
    };
    public_transfer(token, sender);
    public_transfer(vote_coin, @0x0);
}
```

生命周期管理：对象创建和销毁的责任不明确。例如，谁负责销毁临时对象：

```move
// 这里我们通过获得的宝藏对象去获取一次拿flag的机会，那么如果我们没有正确销毁对象，
// 就会通过这一个宝藏对象无限get_flag
public entry fun get_flag(box: TreasuryBox, ctx: &mut TxContext) {
    // 应该添加这两行代码使一个宝藏对象只能获取一次flag的机会
    // let TreasuryBox { id } = box; 
    // object::delete(id);
    let d100 = random::rand_u64_range(0, 100, ctx);        
    if (d100 == 0) {
        event::emit(Flag { user: tx_context::sender(ctx), flag: true });
    }
}
```

## 3. 跨合约交互的实践

### 3.1 PTB交易

PTB（程序化事务块）是Sui区块链的一种高级功能，它允许在单一事务中组合多个操作。与传统区块链系统中每个事务只能执行单一操作的限制不同，PTB提供了更高的灵活性和效率。在PTB中，开发者可以将多个操作组合成一个事务，并按特定的逻辑执行，操作之间也可以互相依赖。

### 3.2 案例分析：利用PTB对象创建限制的随机数预测攻击

我们需要知道的一个知识点就是Sui PTB有一次最多创建2048个对象的限制。
```move
let current_timestamp = clock::timestamp_ms(clock);
let d100 = current_timestamp % 3;
if (d100 == 1) {
    let coin_1 = mint(treasury_cap,ctx);
    coin::join(coin,coin_1);
}else{
    let obj = NoUse {
        id: object::new(ctx),
        value: 100,
    };
    transfer::transfer(obj, tx_context::sender(ctx));
    let burned_coin = coin::split(coin, 5,ctx);
    burn(treasury_cap, burned_coin);
};
```
在这段代码里面赢了我们可以获取一些代币，输了则会扣除相应的代币，但是这里输的逻辑会比赢得逻辑多创建一个对象，那么我们如何做一直赢呢。这就是用到PTB一次最多创建2048个对象限制的概念。我们预先创建2047个对象，赢得时候会在mint的时候创建一个对象，而输的时候就会创建两个对象，超过2048这个阀值，这样就可以保证只有赢得逻辑才能成功上链。


## 4. 防御策略

### 4.1 严格的访问控制

最小权限原则：仅暴露必要的功能，使用 public(friend) 限制访问。

```move
public(friend) fun sensitive_operation() { ... }
```

显式验证：在关键操作前验证调用者身份或权限。

```move
// 验证是否有管理员权限
public entry fun admin_operation(admin: &AdminCap) {   
    assert!(admin.is_valid(), ERROR_INVALID_ADMIN);    
}
```

不可变引用：优先使用不可变引用（&T）而非可变引用（&mut T）。

```move
public fun read_only_operation(obj: &Object) { ... }
```

### 4.2 模块间协议

明确契约：定义清晰的模块间交互契约，包括前置条件和后置条件。

```move
public fun redeem(
    token: RedeemToken,
    pool: &mut TokenPool,
    ctx: &mut TxContext
) {
    // 前置条件：
    // token.amount > 0 - 代币金额必须大于0
    // pool 中必须有足够的SUI余额支付兑换
    let RedeemToken { id, amount } = token;
    assert!(amount > 0,error::invalid_argument(E_INSUFFICIENT_AMOUNT));
    let sui_amount = amount * pool.exchange_rate;
    assert!(balance::value(&pool.balance) >= sui_amount, error::resource_exhausted(0));
    object::delete(id);
    // 后置条件：
    // token完全消耗
    // 用户获得等值的SUI资产 - 按照汇率计算的SUI被转移给用户
    let sui_coin = coin::take(&mut pool.balance, sui_amount, ctx);
    transfer::public_transfer(sui_coin, tx_context::sender(ctx));
}
```

事件通知：使用事件记录关键操作，便于跟踪和审计。

```move
public fun important_operation() {    
    event::emit(OperationEvent { ... });
}
```

版本控制：实施版本控制机制，确保兼容性。

```move
// 强制要求版本兼容，否则中止执行
public fun require_version(
    version_obj: &ProtocolVersion,
    required_version: u64
) {
    assert!(
        version_obj.version >= required_version,
        error::invalid_state(E_VERSION_MISMATCH)
    );
}
```

## 结论

跨合约交互是构建复杂Sui Move应用的基础，但也引入了独特的安全挑战。通过理解潜在风险、实施严格的访问控制、安全地处理对象、建立清晰的模块间协议，开发者可以构建更安全的智能合约系统。
