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
