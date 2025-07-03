
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
