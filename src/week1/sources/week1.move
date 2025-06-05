module week1::challenge {
    use std::bcs;
    use std::hash::sha3_256;
    use std::string::{Self, String};
    use sui::event;
    use sui::random::{Self, Random};
    use sui::transfer::share_object;

    const EINVALID_GUESS_HASH: u64 = 0;
    const EINVALID_HASH: u64 = 1;
    const EINVALID_MAGIC: u64 = 2;
    const EINVALID_SEED: u64 = 3;
    const EINVALID_SCORE: u64 = 4;


    public struct Challenge has key {
        id: UID,
        secret: String,
        current_score: u64,
        round_hash: vector<u8>,
        finish: u64,
    }

    public struct FlagEvent has copy, drop {
        sender: address,
        flag: String,
        github_id: String,
        success: bool,
        rank: u64,
    }

    fun init(ctx: &mut TxContext) {
        let secret = b"Letsmovectf_week1";
        let secret_hash = sha3_256(secret);
        let challenge = Challenge {
            id: object::new(ctx),
            secret: string::utf8(secret),
            current_score: 0,
            round_hash: secret_hash,
            finish: 0
        };
        share_object(challenge);
    }

    #[allow(lint(public_random))]
    public entry fun get_flag(
        score: u64,
        guess: vector<u8>,
        hash_input: vector<u8>,
        github_id: String,
        magic_number: u64,
        seed: u64,
        challenge: &mut Challenge,
        rand: &Random,
        ctx: &mut TxContext
    ) {
        let secret_hash = sha3_256(*string::as_bytes(&challenge.secret));
        let expected_score = (((*vector::borrow(&secret_hash, 0) as u64) << 24) |
                             ((*vector::borrow(&secret_hash, 1) as u64) << 16) |
                             ((*vector::borrow(&secret_hash, 2) as u64) << 8) |
                             (*vector::borrow(&secret_hash, 3) as u64));
        assert!(score == expected_score, EINVALID_SCORE);
        challenge.current_score = score;

        let mut guess_data = guess;
        vector::append(&mut guess_data, *string::as_bytes(&challenge.secret));
        let random = sha3_256(guess_data);
        let prefix_length = 2;
        assert!(compare_hash_prefix(&random, &challenge.round_hash, prefix_length), EINVALID_GUESS_HASH);

        let mut bcs_input = bcs::to_bytes(&challenge.secret);
        vector::append(&mut bcs_input, *string::as_bytes(&github_id));
        let expected_hash = sha3_256(bcs_input);
        assert!(hash_input == expected_hash, EINVALID_HASH);
        let expected_magic = challenge.current_score % 1000 + seed;
        assert!(magic_number == expected_magic, EINVALID_MAGIC);
        let secret_bytes = *string::as_bytes(&challenge.secret);
        let secret_len = vector::length(&secret_bytes);
        assert!(seed == secret_len * 2, EINVALID_SEED);

        challenge.secret = getRandomString(rand, ctx);
        challenge.round_hash = sha3_256(*string::as_bytes(&challenge.secret));
        challenge.current_score = 0;
        challenge.finish = challenge.finish + 1;

        event::emit(FlagEvent {
            sender: tx_context::sender(ctx),
            flag: string::utf8(b"CTF{Letsmovectf_week1}"),
            github_id,
            success: true,
            rank: challenge.finish
        });
    }

    fun getRandomString(rand: &Random, ctx: &mut TxContext): String {
        let mut gen = random::new_generator(rand, ctx);
        let mut str_len = random::generate_u8_in_range(&mut gen, 4, 32);
        let mut rand_vec: vector<u8> = b"";
        while (str_len != 0) {
            let rand_num = random::generate_u8_in_range(&mut gen, 34, 126);
            vector::push_back(&mut rand_vec, rand_num);
            str_len = str_len - 1;
        };
        string::utf8(rand_vec)
    }

    fun compare_hash_prefix(hash1: &vector<u8>, hash2: &vector<u8>, n: u64): bool {
        if (vector::length(hash1) < n || vector::length(hash2) < n) {
            return false
        };
        let mut i = 0;
        while (i < n) {
            if (*vector::borrow(hash1, i) != *vector::borrow(hash2, i)) {
                return false
            };
            i = i + 1;
        };
        true
    }
}