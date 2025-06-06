#https://ctftime.org/writeup/39192
module solve::solve {

    // [*] Import dependencies
    use challenge::Otter::{Self, OTTER};

    public fun solve(
        _board: &mut Otter::QuestBoard,
        _vault: &mut Otter::Vault<OTTER>,
        _player: &mut Otter::Player,
        _ctx: &mut TxContext
    ) {
        let mut ticket = Otter::enter_tavern(_player);
        Otter::buy_sword(_player, &mut ticket);
        Otter::checkout(ticket, _player, _ctx, _vault, _board);

        let mut i = 0;
        while (i < 25) {
            Otter::find_a_monster(_board, _player);
            i = i + 1;
        };

        Otter::bring_it_on(_board, _player, 0);
        Otter::return_home(_board, _player);
        Otter::get_the_reward(_vault, _board, _player, _ctx);

        let mut i = 0;
        while (i < 24) {
            let mut ticket = Otter::enter_tavern(_player);
            Otter::buy_shield(_player, &mut ticket);
            Otter::get_the_reward(_vault, _board, _player, _ctx);
            Otter::checkout(ticket, _player, _ctx, _vault, _board);
            i = i + 1;
        };

        let mut ticket = Otter::enter_tavern(_player);
        Otter::buy_flag(&mut ticket, _player);
        Otter::checkout(ticket, _player, _ctx, _vault, _board);
    }
}
