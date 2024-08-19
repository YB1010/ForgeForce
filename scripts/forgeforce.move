module forge_force_dev_v2::forge_force_dev_v2 {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;
    use aptos_framework::block;
    use forge_force_dev_v2::xoroshiro::{Self, Xoroshiro};

    // Error codes
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_OUTSIDE_AGGRESSIVE: u64 = 2;
    const E_RAFFLE_ALREADY_SAMPLED: u64 = 3;
    const E_RAFFLE_NOT_SAMPLED: u64 = 4;
    const E_UNAUTHORIZED: u64 = 5;

    //Constant
    const SCALE_FACTOR: u64 = 10000;
    const HOUSE_CUT:u64 = 3;

    struct ModuleData has key {
        signer_cap: account::SignerCapability,
        random_number_events: event::EventHandle<RandomNumberEvent>, //has to be included/bound in the moduleData 
        monster: Monster,
        player_raffles: Table<address, PlayerRaffle>,
        prng: Xoroshiro,
        server_random: u64
    }
    
    struct Monster has store, drop {
        hp: u64,
        max_hp: u64
    }

    struct PlayerRaffle has store, drop {
        amount: u64,
        aggressive: u64,
        random_number: u64,
        sampled: bool
    }

    #[event]
    struct RandomNumberEvent has drop, store {
        random_number:u64,
        block_height: u64,
        timestamp: u64
    }   


    public entry fun forge_attack_with_aggressive(account: &signer, amount: u64, aggressive: u64) acquires ModuleData {
        let account_addr = signer::address_of(account);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v2);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);

        assert!(!table::contains(&module_data.player_raffles, account_addr), E_RAFFLE_ALREADY_SAMPLED);

        coin::transfer<AptosCoin>(account, signer::address_of(&module_signer), amount);

        assert!(aggressive < 100 && aggressive >= 0, E_OUTSIDE_AGGRESSIVE);

        let block_height = block::get_current_block_height();
        let current_timestamp = timestamp::now_microseconds();
        let noise = (block_height as u128) ^ (current_timestamp as u128) ^ (module_data.server_random as u128);
        
        let current_state = xoroshiro::get_state(&module_data.prng);
        xoroshiro::set_state(&mut module_data.prng, current_state ^ noise);
        
        let rand_val = xoroshiro::next(&mut module_data.prng) % 100;
        
        let event = RandomNumberEvent { 
            random_number: rand_val,
            block_height,
            timestamp: (current_timestamp as u64)
        };
        event::emit_event(&mut module_data.random_number_events, event);

        table::add(&mut module_data.player_raffles, account_addr, PlayerRaffle {
            amount,
            aggressive,
            random_number: rand_val,
            sampled: true
        });
    }

    public entry fun attack_settle(account: &signer) acquires ModuleData {
        let account_addr = signer::address_of(account);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v2);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);

        assert!(table::contains(&module_data.player_raffles, account_addr), E_RAFFLE_NOT_SAMPLED);

        let PlayerRaffle { amount, aggressive, random_number, sampled } = table::remove(&mut module_data.player_raffles, account_addr);
        assert!(sampled, E_RAFFLE_NOT_SAMPLED);

        let return_multiplier = SCALE_FACTOR * 100 / (100 - aggressive);

        // return amount is the total potential return without bonus
        let return_amount = (amount * return_multiplier) / SCALE_FACTOR;

        // damage amount is the amount that the monster will take
        let damage_amount = return_amount - amount;

        if (module_data.monster.hp == 0) {
            // If monster HP is 0, return all stake back to the player
            coin::transfer<AptosCoin>(&module_signer, account_addr, amount);
            return
        };

        if (random_number >= aggressive) {
            // Player wins, damage the monster. house cut will be applied to return amount.
            let monster = &mut module_data.monster;
            let bonus = monster.max_hp / 100; // 1% of max HP

            if (monster.hp >= damage_amount) {
                //Normal win scenario, all stake is effective
                let total = return_amount - (return_amount * HOUSE_CUT) / 100;
                monster.hp = monster.hp - damage_amount;
                if (monster.hp == 0) {
                    total = total + bonus;
                    generate_new_monster(&module_signer);
                };
                coin::transfer<AptosCoin>(&module_signer, account_addr, total);
            } else {
                let used_stake = (monster.hp * SCALE_FACTOR) / return_multiplier;
                let unused_stake = amount - used_stake;
                
                let used_return = (used_stake * return_multiplier) / SCALE_FACTOR;
                let house_cut_amount = (used_return * HOUSE_CUT) / 100;
                
                let over_kill_total = used_return - house_cut_amount + unused_stake + bonus;
                
                coin::transfer<AptosCoin>(&module_signer, account_addr, over_kill_total);
                monster.hp = 0;
                generate_new_monster(&module_signer);
            }
        }
        // Player loses, coins stay with the resource account
        // todo emit event to inform the player that they lost
        
    }

    fun generate_new_monster(module_signer: &signer) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v2);
        let balance = coin::balance<AptosCoin>(signer::address_of(module_signer));
        let new_hp = (balance * 90) / 100; // 90% of current balance
        module_data.monster = Monster { hp: new_hp, max_hp: new_hp };
    }

    public entry fun generate_monster(admin: &signer, hp: u64) acquires ModuleData {
        assert!(signer::address_of(admin) == @forge_force_dev_v2, E_UNAUTHORIZED);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v2);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(admin, signer::address_of(&module_signer), hp);
        module_data.monster = Monster { hp, max_hp: hp };
    }

    #[view]
    public fun get_monster_hp(): (u64, u64) acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev_v2);
        (module_data.monster.hp, module_data.monster.max_hp)
    }

    public entry fun update_server_random(admin: &signer, new_random: u64) acquires ModuleData {
        assert!(signer::address_of(admin) == @forge_force_dev_v2, E_UNAUTHORIZED);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v2);
        module_data.server_random = new_random;
    }

    public entry fun fund_contract(funder: &signer, amount: u64) acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev_v2);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(funder, signer::address_of(&module_signer), amount);
    }

    fun init_module(account: &signer) {
        let (resource_signer, signer_cap) = account::create_resource_account(account, b"forge_force_dev_v2");
        coin::register<AptosCoin>(&resource_signer);

        move_to(account, ModuleData { 
            signer_cap,
            random_number_events: account::new_event_handle<RandomNumberEvent>(&resource_signer),
            monster: Monster { hp: 0, max_hp: 0 },
            player_raffles: table::new(),
            prng: xoroshiro::new(0x1234567890ABCDEF1234567890ABCDEF), // Initial seed for xoroshiro
            server_random: 0 // Initial server random number
        });

        // Set this module as a friend of the xoroshiro module
        xoroshiro::set_friend(account, @forge_force_dev_v2);
    }
}