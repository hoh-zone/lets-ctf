
# JustCTF 2024 Writeup

## 题目
https://2024.justctf.team/challenges  
有三道sui move题目

- TOS
```
The Otter Scrolls
Points: 246
zwalaczkonia12
BLOCKCHAIN
Behold the ancient Spellbook, a tome of arcane wisdom where spells cast by mystical Otters weave the threads of fate. Embark on this enchanted journey where the secrets of the blockchain will be revealed. Brave adventurers, your quest awaits; may your courage be as boundless as the magic that guides you.

Challenge created by embe221ed & Darkstar49 from OtterSec

nc tos.nc.jctf.pro 31337
https://s3.cdn.justctf.team/a3cc5591-ad0a-47e5-bce0-78ff9bb7d2f3/tos_docker.tar.gz
```

- DB
```
Dark BrOTTERhood
Points: 275
CyKor
BLOCKCHAIN
In the shadowed corners of the Dark Brotterhood's secrets, lies a tavern where valiant Otters barter for swords and shields. Here, amidst whispers of hidden bounties, adventurers find the means to battle fearsome monsters for rich rewards. Join this clandestine fellowship, where the blockchain holds mysteries to uncover. Otters of Valor, your destiny calls; may your path be lined with both honor and gold.

Challenge created by embe221ed & Darkstar49 from OtterSec

nc db.nc.jctf.pro 31337
https://s3.cdn.justctf.team/42840bf9-5734-42c6-9463-2b61238148e8/db_docker.tar.gz
```


- WOO
```
World of Ottercraft
Points: 271
zwalaczkonia12
BLOCKCHAIN
Welcome to the World of Ottercraft, where otters rule the blockchain! In this challenge, you'll dive deep into the blockchain to grab the mythical Otter Stone! Beware of the powerful monsters that will try to block your path! Can you outsmart them and fish out the Otter Stone, or will you just end up swimming in circles?

Challenge created by embe221ed & Darkstar49 from OtterSec

nc woo.nc.jctf.pro 31337
https://s3.cdn.justctf.team/a951edfb-bd5f-40a0-b334-ad650d889ac3/woo_docker.tar.gz
```


## 部署题目

比赛结束后服务器已经关了，可以自己把比赛环境搭起来.   
实测至少需要买一台2核4G 、硬盘25G的vps

1.安装docker和compose

https://docs.docker.com/engine/install/debian/   
https://docs.docker.com/compose/install/linux/

2.拉取镜像   
https://hub.docker.com/r/embe221ed/otter_template/tags
sha256:1868755b24d06342766c54dd6e0516f41b62cec1e992a036f77a0b0401476a04   
下载需要大概16G磁盘空间
```
docker pull embe221ed/otter_template:latest
```

3.解开tos_docker.tar.gz并修改docker-compose.yml (非必须)

在本地测试时，我改了两个地方:  
- 添加flag
- 把服务端口改成了127.0.0.1:31337
```
services:
  tos:
    environment:
      FLAG: justCTF{Th4t_sp3ll_looks_d4ngerous...keep_y0ur_distance}
      PORT: 31337
    build:
      context: ./
      dockerfile: ./Dockerfile
    ports:
      - "127.0.0.1:31337:31337"
    restart: always
```
4.最后执行docker compose up 或者 docker compose up -d即可


## The Otter Scrolls
```
0 % sui --version
sui 1.27.0-homebrew

```
首先进入解题框架，把题目的地址(nc连接服务器获得)填入`dependency/Move.toml`

```
test@vps ~/justctf/tos/sources/framework-solve
0 % ls
Cargo.lock  Cargo.toml	dependency  solve  src

test@vps ~/justctf/tos/sources/framework-solve
0 % nc tos.movectf.com 31337

[SERVER] Challenge modules published at: 542fe29e11d10314d3330e060c64f8fb9cd341981279432b03b2bd51cf5d489b%                                                                          

test@vps ~/justctf/tos/sources/framework-solve
0 % cat dependency/Move.toml
[package]
name = "challenge"
version = "0.0.1"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "devnet-v1.27.0" }

[addresses]
admin = "0xfccc9a421bbb13c1a66a1aa98f0ad75029ede94857779c6915b44f94068b921e"
#challenge = "<ENTER ADDRESS OF THE PUBLISHED CHALLENGE MODULE HERE>"
challenge = "0x542fe29e11d10314d3330e060c64f8fb9cd341981279432b03b2bd51cf5d489b"
```
然后编写solve
```
test@vps ~/justctf/tos/sources/framework-solve
0 % ls solve
build  Move.lock  Move.toml  sources

test@vps ~/justctf/tos/sources/framework-solve
0 % cat solve/sources/solve.move
module solve::solve {

    // [*] Import dependencies
    use challenge::theotterscrolls;

    public fun solve(
        _spellbook: &mut theotterscrolls::Spellbook,
        _ctx: &mut TxContext
    ) {
        // Your code here...
        theotterscrolls::cast_spell(vector[1, 0, 3, 3, 3], _spellbook);
    }

}
```
TOS这道题目比较简单，相当于一道签到题   
按照指定顺序取出单词即可，解题代码只需要插入一行   
```
        theotterscrolls::cast_spell(vector[1, 0, 3, 3, 3], _spellbook);
```
然后执行build，把编译后的字节码发送到服务器就能得到flag了
```
test@vps ~/justctf/tos/sources/framework-solve
0 % cd solve

test@vps ~/justctf/tos/sources/framework-solve/solve
0 % sui move build
INCLUDING DEPENDENCY challenge
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING solve

test@vps ~/justctf/tos/sources/framework-solve/solve
0 % cat build/solve/bytecode_modules/solve.mv | nc 127.0.0.1 31337
[SERVER] Challenge modules published at: 542fe29e11d10314d3330e060c64f8fb9cd341981279432b03b2bd51cf5d489b[SERVER] Solution published at cf07b5b91e5ea4b1c17442a0e626cbb77b6a1d9a3427e568f403a2c3eff95566[SERVER] Congrats, flag: justCTF{Th4t_sp3ll_looks_d4ngerous...keep_y0ur_distance}%
```
# DB

酒馆里有个任务榜单，里面有不超过25个怪兽，击杀可以获取奖励   
获取奖励的函数存在逻辑漏洞,击杀榜单里第0个怪兽，可以领取所有怪兽的击杀奖金 

```
    #[allow(lint(self_transfer))]
    public fun get_the_reward(
        vault: &mut Vault<OTTER>,
        board: &mut QuestBoard,
        player: &mut Player,
        quest_id: u64,
        ctx: &mut TxContext,
    ) {
        let quest_to_claim = vector::borrow_mut(&mut board.quests, quest_id);
        assert!(quest_to_claim.fight_status == FINISHED, WRONG_STATE);


        let monster = vector::pop_back(&mut board.quests);


        let Monster {
            fight_status: _,
            reward: reward,
            power: _
        } = monster;


        let coins = coin::split(&mut vault.cash, (reward as u64), ctx); 
        coin::join(&mut player.coins, coins);
    }

```
# WOO

与上一道题目DB类似，问题还是出在获取奖励上    


```
    public fun get_the_reward(vault: &mut Vault<OTTER>, board: &mut QuestBoard, player: &mut Player, ctx: &mut TxContext) {
        assert!(player.status != RESTING && player.status != PREPARE_FOR_TROUBLE && player.status != ON_ADVENTURE, WRONG_PLAYER_STATE);


        let monster = vector::remove(&mut board.quests, player.quest_index);


        let Monster {
            reward: reward,
            power: _
        } = monster;


        let coins = coin::split(&mut vault.cash, reward, ctx); 
        let balance = coin::into_balance(coins);


        balance::join(&mut player.wallet, balance);


        player.status = RESTING;
    }
```

设置黑名单防止重复获取奖励，
```
        assert!(player.status != RESTING && player.status != PREPARE_FOR_TROUBLE && player.status != ON_ADVENTURE, WRONG_PLAYER_STATE);
```



但是忘记了考虑玩家处于购物状态的情况

```
    public fun enter_tavern(player: &mut Player): TawernTicket {
        assert!(player.status == RESTING, WRONG_PLAYER_STATE);

        player.status = SHOPPING;

        TawernTicket{ total: 0, flag_bought: false }
    }
```

玩家可以领取奖励后购物，再领奖，再购物......
