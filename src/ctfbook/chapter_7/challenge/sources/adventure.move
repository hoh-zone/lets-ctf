
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

    struct Obj has key{
        id: UID,
        value: u64,
    }

    public fun new_obj(count: u64,addr:address, ctx: &mut TxContext){
        let i = 0;
        while(i < count){
            let obj = Obj{
                id: object::new(ctx),
                value: 20,
            };
            transfer::transfer(obj,addr);
            i = i + 1;
        }
    }

}
