# 阅读Move代码与常见问题
## 阅读 Move 代码与常见问题

欢迎来到 **Move CTF 挑战课程** 的第二节！在第一节中，你通过一个签到挑战初步体验了 Move 代码的分析和解题流程。现在，我们将迈出审计的第一步，深入学习如何阅读 Move 代码并识别常见问题。本节将通过详细的理论讲解和实践环节，帮助你掌握基础审计技能，为后续更复杂的漏洞分析打下坚实基础。

#### 1. 模块与函数
- **模块（Module）**：
  - Move 的代码组织单元，类似于传统语言中的合约或类。
  - 格式：`module <address>::<name>`，其中 `<address>` 是部署地址（如 `0x1`），`<name>` 是模块名。
  - 包含结构体、常量和函数，定义合约的逻辑。
  - 示例：
    ```
    module chapter_2_test::counter {

        public struct Counter has key {
            id: UID,
            count: u64,
        }

        fun init(ctx: &mut TxContext){
            transfer::share_object(Counter { id:object::new(ctx), count: 0 });
            
        }

        public entry fun increment(counter: &mut Counter) {
            counter.count = counter.count + 1;
        }
    }
    ```
- **函数类型**：
  - `public entry fun`：外部可调用的入口函数，通常是 CTF 题目中的交互点，接受 `&mut TxContext` 参数以获取交易上下文。
  - `public fun`：公开函数，可被其他模块调用，但不直接作为交易入口。
  - `fun`：私有函数，仅模块内部使用。
  - 示例：
    ```
    public entry fun set_value(value: u64, tx: &mut TxContext) { 
        /* 交易入口 */ 
    }
    fun internal_add(a: u64, b: u64): u64 { a + b } // 内部辅助函数
    ```
#### 2. 资源与所有权
- **资源（Resource）**：
  - Move 的核心特性，使用 `struct` 定义，带有能力（`has` 声明，如 `key`、`store`）。
  - 线性类型：资源不可复制（`copy`）或丢弃（`drop`），必须显式转移或销毁。
  - 示例：
    ```
    public struct Coin has key {
        id: UID,
        value: u64  
    }
    ```
- **所有权管理**：
  - 创建资源后，可通过 `transfer::transfer`（转移给地址）或 `transfer::share_object`（共享对象）等处理。
  - 示例：
    ```
    public entry fun create(ctx: &mut TxContext){
        let coin = Coin { id: object::new(ctx), value: 100 };
        transfer::transfer(coin, tx_context::sender(ctx));
    }
    ```
  - 未处理资源会导致编译错误，确保所有权清晰。
- **Sui 特有机制**：
  - **对象（Object）**：通过 `UID`（唯一标识符）管理，Sui 的基本数据单元。
  - **共享对象**：通过 `transfer::share_object` 创建，允许多人操作，常用于 CTF 的共享状态。

#### 3. 事件与输出
- **事件（Event）**：
  - 通过 `event::emit` 输出日志，用于记录状态变化或 CTF 中的 flag 输出。
  - 需定义事件结构体，具备 `copy` 和 `drop` 能力。
  - 示例：
    ```
    public struct FlagEvent has copy, drop {
        sender: address,
        flag: vector<u8>
    }

    public entry fun get_flag(ctx: &mut TxContext){
        event::emit(FlagEvent { sender: tx_context::sender(ctx), flag: b"CTF{example}" });
    }
    ```
  - CTF 中，事件常是获取 flag 的关键途径。

#### 4. 变量与类型
- **基本类型**：
  - `u8`、`u64`、`u128`：无符号整数。
  - `bool`：布尔值。
  - `address`：账户地址。
  - `vector<T>`：动态数组。
- **引用**：
  - `&T`：不可变引用，用于读取。
  - `&mut T`：可变引用，用于修改。
  - 示例：
    ```
    public entry fun increment(counter: &mut Counter) {
        counter.count = counter.count + 1;
    }
    ```

### 常见问题与漏洞类型

#### 1. 未验证的输入
- **影响**：
  - 若 `limit` 被设置为异常值（如 `2^64 - 1`），后续逻辑可能失效。
  - 在 CTF 中，可能通过异常输入绕过限制或提取 flag。

#### 2. 逻辑错误
- **问题**：条件判断、状态更新或流程控制错误，导致与设计意图不符的结果。
- **详细说明**：
  - Move 依赖开发者正确实现逻辑，无内置保护机制。
  - 常见于条件遗漏、顺序错误或判断反转。
- **示例**：
    ```
    public struct AccessControl has key {
        id: UID,
        is_allowed: bool,
        threshold: u64
    }

    public entry fun check_access(access: &mut AccessControl, score: u64) {
        if (score > 50) { // 应为 >= 50，但是设置为 >50
            access.is_allowed = true;
        }
    }
    ```
- 边界值 score = 50 被意外排除.

- **更复杂示例**：
    ```
    public entry fun update_state(state: &mut AccessControl, value: u64) {
      if (value < state.threshold) {
          state.is_allowed = false; // 可能应为 true
      }
    }
    ```
  - 若意图是“低于阈值激活”，条件与赋值不符。

- **影响**：
  - 可能允许未授权操作或阻止合法行为。

#### 3. 权限控制不足
- **问题**：函数未限制调用者身份，允许任何人执行敏感操作。
- **详细说明**：
  - Move 的 public entry fun 默认对所有地址开放，需手动验证 tx_context::sender.
  - Sui 的共享对象尤其需注意权限。
- **示例**：
    ```
    public entry fun reset_counter(counter: &mut Counter) { // 未验证调用者
      counter.count = 0; 
    }
    ```
  - 任何人都可重置计数器。
- **更实际示例**：
    ```
    public struct SuiPool has key {
        id: UID,
        suiBalance: Balance<0x2::sui::SUI>,
    }

    public entry fun withdraw_commision(
        suipool: &mut SuiPool,
        amount: u64,
        to: address,
        ctx: &mut TxContext,
    ) {
        assert!(suipool.suiBalance.value() > amount, 1);
        let coin_balance = suipool.suiBalance.split(amount);
        let coin = from_balance(coin_balance, ctx);
        public_transfer(coin, to);
    }
    ```
  - 非管理者可提取余额。
- **影响**：
  - 未授权用户可能破坏合约状态或窃取资源。

#### 4. 整数溢出/下溢
- **问题**：在 Sui 中，Move 的整数运算（如 u64 的加法、减法）默认启用溢出检查，溢出或下溢会导致交易失败.
- **示例**：
    ```
    module counter::counter{
        use sui::event;

        public struct Counter has key {
            id: UID,
            count: u64,
        }

        public struct CounterEmit has copy, drop{
            count: u64,
        }

        fun init(ctx: &mut TxContext){
            transfer::share_object(Counter { id:object::new(ctx), count: 0 });
        }

        public entry fun add(counter: &mut Counter,amount: u64){
            counter.count = counter.count + amount;
            event::emit(CounterEmit { count: counter.count })
        }

        public entry fun reduce(counter: &mut Counter,amount: u64){
            counter.count = counter.count - amount;
            event::emit(CounterEmit { count: counter.count })
        }
    }
    ```
- **影响**：
    - 若 counter + amount > 2^64 - 1 或 counter - amount < 0 会抛出 MovePrimitiveRuntimeError，交易失败，无法继续执行。

#### 5. 资源管理不当
- **问题**：资源未正确转移或销毁，导致编译错误。
- **示例**：
    ```
    public entry fun create_coin(ctx: &mut TxContext) {
      let coin = Coin { id: object::new(ctx), value: 100 };
    }
    ```
- **影响**：
    - 编译错误。