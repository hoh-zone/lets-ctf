#[test_only]
module task8::test {
    use sui::test_scenario;
    use sui::coin::{mint_for_testing, Self};
    use std::type_name::{Self, TypeName};
    use std::string::{Self, String};
    use std::string::utf8;
    use std::debug::print;

    use std::debug;
    
    use task8::token1::TOKEN1 as T_TOKEN1;
    use task8::token2::TOKEN2 as T_TOKEN2;
    use task8::token3::TOKEN3 as T_TOKEN3;
    use task8::token4::TOKEN4 as T_TOKEN4;
    use task8::pool::{
        init_for_testing, 
        Pools, AdminCap, 
        init_pools, 
        set_fee_manager, 
        create_pool, 
        PoolCap, 
        claim_fees,
        is_solved,
        swap_a_2_b,
        swap_b_2_a,
        get_token,
        get_pool,
    };


    public struct TOKEN1 has drop {}
    public struct TOKEN2 has drop {}
    public struct TOKEN3 has drop {}
    public struct TOKEN4 has drop {}

    #[test]
    fun solve() {
        let dev = @0x1;
        let mut scenario_val = test_scenario::begin(dev);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, dev);
        {
            init_for_testing(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, dev);
        {
            let mut pools = test_scenario::take_shared<Pools>(scenario);
            let mut cap = test_scenario::take_from_sender<AdminCap>(scenario);
            init_pools(
                &mut cap, &mut pools, 
                mint_for_testing<T_TOKEN1>(1000, test_scenario::ctx(scenario)),
                mint_for_testing<T_TOKEN2>(1000, test_scenario::ctx(scenario)),
                mint_for_testing<T_TOKEN3>(1000, test_scenario::ctx(scenario)),
                mint_for_testing<T_TOKEN4>(1000, test_scenario::ctx(scenario)),
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(pools);
            test_scenario::return_to_address(dev, cap);       
        };

        // ////////////// user 
        let user = @0x1235;
        test_scenario::next_tx(scenario, user);
        {
            let mut pools = test_scenario::take_shared<Pools>(scenario);
            
            let mut in = mint_for_testing<TOKEN2>(8000, test_scenario::ctx(scenario));
            let out = swap_b_2_a<T_TOKEN1, TOKEN2>(&mut pools, &mut in, test_scenario::ctx(scenario));

            transfer::public_transfer(out, user);
            transfer::public_transfer(in, user);
   
            let mut in = mint_for_testing<TOKEN1>(8000, test_scenario::ctx(scenario));
            let out = swap_a_2_b<TOKEN1, T_TOKEN2>(&mut pools, &mut in, test_scenario::ctx(scenario));
            transfer::public_transfer(out, user);
            transfer::public_transfer(in, user);

            set_fee_manager(&mut pools, user, test_scenario::ctx(scenario));
            let mut cap = create_pool<T_TOKEN1, T_TOKEN2>(&mut pools, 0, coin::zero<T_TOKEN1>(test_scenario::ctx(scenario)), coin::zero<T_TOKEN2>(test_scenario::ctx(scenario)), test_scenario::ctx(scenario));
            let (x, y) = claim_fees<T_TOKEN1, T_TOKEN2>(&mut pools, &mut cap, test_scenario::ctx(scenario));
            transfer::public_transfer(x, user);
            transfer::public_transfer(y, user);
            transfer::public_transfer(cap, user);

            test_scenario::return_shared(pools);
        };

        test_scenario::next_tx(scenario, user);
        {
            let mut pools = test_scenario::take_shared<Pools>(scenario);
            let mut in = mint_for_testing<TOKEN4>(8000, test_scenario::ctx(scenario));
            let out = swap_b_2_a<T_TOKEN3, TOKEN4>(&mut pools, &mut in, test_scenario::ctx(scenario));
            transfer::public_transfer(out, user);
            transfer::public_transfer(in, user);
   
            let mut in = mint_for_testing<TOKEN3>(8000, test_scenario::ctx(scenario));
            let out = swap_a_2_b<TOKEN3, T_TOKEN4>(&mut pools, &mut in, test_scenario::ctx(scenario));
            transfer::public_transfer(out, user);
            transfer::public_transfer(in, user);

            set_fee_manager(&mut pools, user, test_scenario::ctx(scenario));
            let mut cap = create_pool<T_TOKEN3, T_TOKEN4>(&mut pools, 0, coin::zero<T_TOKEN3>(test_scenario::ctx(scenario)), coin::zero<T_TOKEN4>(test_scenario::ctx(scenario)), test_scenario::ctx(scenario));
            let (x, y) = claim_fees<T_TOKEN3, T_TOKEN4>(&mut pools, &mut cap, test_scenario::ctx(scenario));
            transfer::public_transfer(x, user);
            transfer::public_transfer(y, user);
            transfer::public_transfer(cap, user);


            test_scenario::return_shared(pools);
        };

        let user = @0x1235;
        test_scenario::next_tx(scenario, user);
        {
            let mut pools = test_scenario::take_shared<Pools>(scenario);
            is_solved(&mut pools, test_scenario::ctx(scenario));
            test_scenario::return_shared(pools);
        };

        test_scenario::end(scenario_val);
    }


}