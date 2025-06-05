# 实践：分析利用资源管理漏洞

```
module chapter_4::vote {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer::{public_transfer, share_object, public_freeze_object};
    use sui::vec_map::{Self, VecMap};
    use sui::object_table::{Self, ObjectTable};
    use std::string::String;

    public struct VOTE has drop {}

    public struct Votecap has key {
        id: UID,
        cap: TreasuryCap<VOTE>,
    }

    public struct Mintlist has key {
        id: UID,
        mintlist: VecMap<address, u64>,
    }

    public struct VoteStore has key {
        id: UID,
        proposals: ObjectTable<String, Proposal>,
        voters: VecMap<address, bool>, 
    }

    public struct Proposal has key, store {
        id: UID,
        votes: u64,
    }

    const E_INVALID_AMOUNT: u64 = 1;
    const E_INVALID_PROPOSAL: u64 = 2;
    const E_ALREADY_MINTED: u64 = 3;

    fun init(witness: VOTE, ctx: &mut TxContext) {
        let name = std::string::utf8(b"letsctf");
        let (treasury_cap, meta) = coin::create_currency(
            witness,
            6,
            b"VOTE",
            b"VOTE",
            b"",
            option::none(),
            ctx
        );

        let vote_cap = Votecap { id: object::new(ctx), cap: treasury_cap };
        let mintlist = Mintlist { id: object::new(ctx), mintlist: vec_map::empty() };
        let mut store = VoteStore {
            id: object::new(ctx),
            proposals: object_table::new(ctx),
            voters: vec_map::empty(),
        };

        let proposal = Proposal {
            id: object::new(ctx),
            votes: 0,
        };

        object_table::add(&mut store.proposals, name, proposal);
        public_freeze_object(meta);
        share_object(vote_cap);
        share_object(mintlist);
        share_object(store);
    }

    public entry fun mint(
        vote_cap: &mut Votecap,
        mint_list: &mut Mintlist,
        ctx: &mut TxContext
    ) {
        let addr = tx_context::sender(ctx);
        assert!(!vec_map::contains(&mint_list.mintlist, &addr), E_ALREADY_MINTED);
        let coin = coin::mint(&mut vote_cap.cap, 100, ctx);
        vec_map::insert(&mut mint_list.mintlist, addr, 100);
        public_transfer(coin, addr);
    }

    public entry fun vote(
        store: &mut VoteStore,
        vote_coin: &Coin<VOTE>,
        proposal_name: String,
        ctx: &mut TxContext
    ) {
        assert!(vote_coin.value() > 0, E_INVALID_AMOUNT);
        assert!(object_table::contains(&store.proposals, proposal_name), E_INVALID_PROPOSAL);
        let sender = tx_context::sender(ctx);
        if (!vec_map::contains(&store.voters, &sender)) {
            vec_map::insert(&mut store.voters, sender, true);
        };
        let proposal = object_table::borrow_mut(&mut store.proposals, proposal_name);
        proposal.votes = proposal.votes + vote_coin.value();
    }
}
```

