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
