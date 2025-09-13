module MyModule::RockPaperScissors {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    
    /// Game choices: 1 = Rock, 2 = Paper, 3 = Scissors
    const ROCK: u8 = 1;
    const PAPER: u8 = 2;
    const SCISSORS: u8 = 3;
    
    /// Game struct with escrowed funds
    struct Game has store, key {
        player2: address,
        player1_choice: u8,
        player1_bet: coin::Coin<AptosCoin>,
        bet_amount: u64,
        active: bool,
    }
    
    /// Create game - Player 1 deposits bet and makes choice
    public fun create_game(player1: &signer, player2: address, choice: u8, bet: u64) {
        assert!(choice >= 1 && choice <= 3, 1);
        
        let player1_bet = coin::withdraw<AptosCoin>(player1, bet);
        
        let game = Game {
            player2,
            player1_choice: choice,
            player1_bet,
            bet_amount: bet,
            active: true,
        };
        
        move_to(player1, game);
    }
    
    /// Player 2 plays - deposits bet and determines winner
    public fun play(player2: &signer, player1_addr: address, choice: u8) acquires Game {
        assert!(choice >= 1 && choice <= 3, 1);
        
        let game = borrow_global_mut<Game>(player1_addr);
        assert!(game.active, 2);
        assert!(signer::address_of(player2) == game.player2, 3);
        
        let player2_bet = coin::withdraw<AptosCoin>(player2, game.bet_amount);
        game.active = false;
        
        // Check for tie
        if (game.player1_choice == choice) {
            // Tie - return bets to original players
            coin::deposit<AptosCoin>(player1_addr, coin::extract_all<AptosCoin>(&mut game.player1_bet));
            coin::deposit<AptosCoin>(signer::address_of(player2), player2_bet);
            return
        };
        
        // Determine winner
        let player1_wins = (game.player1_choice == ROCK && choice == SCISSORS) ||
                          (game.player1_choice == PAPER && choice == ROCK) ||
                          (game.player1_choice == SCISSORS && choice == PAPER);
        
        if (player1_wins) {
            // Player 1 wins both bets
            coin::merge<AptosCoin>(&mut game.player1_bet, player2_bet);
            coin::deposit<AptosCoin>(player1_addr, coin::extract_all<AptosCoin>(&mut game.player1_bet));
        } else {
            // Player 2 wins both bets
            coin::merge<AptosCoin>(&mut game.player1_bet, player2_bet);
            coin::deposit<AptosCoin>(signer::address_of(player2), coin::extract_all<AptosCoin>(&mut game.player1_bet));
        };
    }
}