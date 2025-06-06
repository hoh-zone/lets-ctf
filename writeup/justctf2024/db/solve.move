#https://ctftime.org/writeup/39193
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
        let mut i = 0;
        while (i < 10) {
            Otter::buy_sword(_vault, _player, _ctx);

            let mut j = 0;
            while (j < 25) {
                Otter::find_a_monster(_questboard, _r, _ctx);
                j = j + 1;
            };

            Otter::fight_monster(_questboard, _player, 0);
            Otter::return_home(_questboard, 0);

            let mut j = 0;
            while (j < 25) {
                Otter::get_the_reward(_vault, _questboard, _player, 0, _ctx);
                j = j + 1;
            };

            i = i + 1;
        };

        let flag = Otter::buy_flag(_vault, _player, _ctx);
        Otter::prove(_questboard, flag);
    }

}
