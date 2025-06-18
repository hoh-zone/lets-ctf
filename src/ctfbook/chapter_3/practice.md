# 实践：利用泛型漏洞伪造投票凭证。

## 引言

以下是一个简单的投票系统的合约，每个地址可以领取100数量的coin然后进行投票，但是存在一些漏洞问题请尝试找出问题。

```
module votechain::vote {
    use sui::object_table::{Self, ObjectTable};
    use sui::coin::{Self,TreasuryCap};
    use sui::transfer::{public_transfer, share_object, public_freeze_object};
    use std::string::String;
    use sui::table::{Self, Table};

    public struct VOTE has drop {}

    public struct Votecap has key {
        id: UID,
        cap: TreasuryCap<VOTE>
    }

    public struct Mintlist has key {
        id: UID,
        mintlist: Table<address, u64>
    }

    public struct VoteToken<phantom T> has key, store {
        id: UID,
        amount: u64,
    }

    public struct VoteStore has key {
        id: UID,
        proposals: ObjectTable<String, Proposal>,
    }

    public struct Proposal has key, store {
        id: UID,
        votes: u64,
    }


    fun init(waitness: VOTE,ctx: &mut TxContext) {
        let name = std::string::utf8(b"letsctf");

        let mintlist = Mintlist { id: object::new(ctx) , mintlist: table::new(ctx) };
        let mut store = VoteStore {
            id: object::new(ctx),
            proposals: object_table::new(ctx),
        };

        let proposal = Proposal {
            id: object::new(ctx),
            votes: 0,
        };

        let (treasury_cap, meta) = coin::create_currency(waitness,6,b"VOTE", b"VOTE", b"", option::none(), ctx);
  
        let vote_cap = Votecap { id: object::new(ctx), cap: treasury_cap };

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
    ){
        let addr = ctx.sender();
        assert!(!table::contains(&mint_list.mintlist, addr), 1);
        let coin = coin::mint(&mut vote_cap.cap, 100, ctx);
        table::add(&mut mint_list.mintlist, addr, 100);
        public_transfer(coin, addr);
    }

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

    public entry fun vote<T>(token: &VoteToken<T>, store: &mut VoteStore, proposal_name: String) {
        assert!(token.amount > 0, 1);
        assert!(object_table::contains(&store.proposals, proposal_name), 2);

        let proposal = object_table::borrow_mut(&mut store.proposals, proposal_name);
        proposal.votes = proposal.votes + token.amount;
    }
}
```

