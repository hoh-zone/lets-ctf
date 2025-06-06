module solve::solve {

    // [*] Import dependencies
    use challenge::Otter::{Self, OTTER};
    use sui::random::Random;

    #[allow(lint(public_random))]
    public fun solve(
        _vault: &mut Otter::Vault<OTTER>,
        _questboard: &mut Otter::QuestBoard,
        _player: &mut Otter::Player,
        _r: &Random,
        _ctx: &mut TxContext,
    ) {
        // Your code here ...
    }

}
