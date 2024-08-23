module forge_force_dev_v4::forge_force_dev_v4 {
    use std::signer;
    use std::vector;
    use std::string;
    use std::option::{Self, Option};
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;
    use aptos_framework::block;
    use supra_addr::supra_vrf;
    use aptos_framework::create_signer::create_signer;
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
        resource_signer_address: address,


        random_number_events: event::EventHandle<RandomNumberEvent>, //has to be included/bound in the moduleData 
        monster: Monster,
        player_raffles: Table<address, PlayerRaffle>,
        server_random: u64,
        request_nonce: Option<u64>,
        random_number: Option<u64>,
        attack_outcome_events: event::EventHandle<AttackOutcomeEvent>
    }
    
    struct Monster has store, drop {
        hp: u64,
        max_hp: u64
    }

    struct PlayerRaffle has copy, store, drop {
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

    #[event]
    struct AttackOutcomeEvent has drop, store {
        player: address,
        outcome: bool, // true if player won, false if player lost
        amount: u64 // amount won or lost
    }
    #[view]
    public fun get_resource_signer_address(): address acquires ModuleData {
        borrow_global<ModuleData>(@forge_force_dev_v4).resource_signer_address
    }


    #[view]
    public fun get_module_signer_address(): address acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev_v4);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        signer::address_of(&module_signer)
    }
    #[view]
    public fun get_signer_capability_address_address(): address acquires ModuleData {
        account::get_signer_capability_address(&borrow_global<ModuleData>(@forge_force_dev_v4).signer_cap)
    }

    fun request_random_number(module_signer: &signer): u64 {
        let callback_module = string::utf8(b"forge_force_dev_v4");
        let callback_function = string::utf8(b"handle_random_number"); // function name
        let rng_count: u8 = 1; // how many random number you want to generate
        let client_seed: u64 = 0; // client seed using as seed to generate random. if you don't want to use then just assign 0
        let num_confirmations: u64 = 1; // how many confirmation required for random number
        

        supra_vrf::rng_request(module_signer, @forge_force_dev_v4, callback_module, callback_function, rng_count, client_seed, num_confirmations)
    }

    public entry fun forge_attack_with_aggressive(account: &signer, amount: u64, aggressive: u64) acquires ModuleData {
        let account_addr = signer::address_of(account);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v4);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);

        assert!(!table::contains(&module_data.player_raffles, account_addr), E_RAFFLE_ALREADY_SAMPLED);

        coin::transfer<AptosCoin>(account, signer::address_of(&module_signer), amount);

        assert!(aggressive < 100 && aggressive >= 0, E_OUTSIDE_AGGRESSIVE);

        let nonce = request_random_number(&module_signer);
        module_data.request_nonce = option::some(nonce);

        table::add(&mut module_data.player_raffles, account_addr, PlayerRaffle {
            amount,
            aggressive,
            random_number: 0, // Placeholder, will be updated in callback
            sampled: false
        });
    }

    public entry fun handle_random_number(
        nonce: u64,
        message: vector<u8>,
        signature: vector<u8>,
        caller_address: address,
        rng_count: u8,
        client_seed: u64
    ) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v4);
        let verified_num = supra_vrf::verify_callback(nonce, message, signature, caller_address, rng_count, client_seed);

        let random_number = *vector::borrow(&verified_num, 0);
        module_data.random_number = option::some(random_number);

        let block_height = block::get_current_block_height();
        let current_timestamp = timestamp::now_microseconds();

        let event = RandomNumberEvent { 
            random_number,
            block_height,
            timestamp: (current_timestamp as u64)
        };
        event::emit_event(&mut module_data.random_number_events, event);

        // Update the player raffle with the generated random number
        let player_raffles = &mut module_data.player_raffles;
        let raffle = table::borrow_mut(player_raffles, caller_address);
        raffle.random_number = random_number;
        raffle.sampled = true;

        // Settle the attack outcome for the specific player
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        let monster_defeated = settle_attack(caller_address, &mut *raffle, &mut module_data.monster, &module_data.signer_cap, &mut module_data.attack_outcome_events, &module_signer);
        // Remove the player's raffle entry
        table::remove(&mut module_data.player_raffles, caller_address);


        if (monster_defeated == true) {
            generate_new_monster(&module_signer);
        }


    }

    fun settle_attack(
        account_addr: address,
        raffle: &mut PlayerRaffle,
        monster: &mut Monster,
        signer_cap: &account::SignerCapability,
        attack_outcome_events: &mut event::EventHandle<AttackOutcomeEvent>,
        module_signer: &signer
    ): bool {
        let PlayerRaffle { amount, aggressive, random_number, sampled } = raffle;
        assert!(*sampled, E_RAFFLE_NOT_SAMPLED);

        let return_multiplier = SCALE_FACTOR * 100 / (100 - *aggressive);

        // return amount is the total potential return without bonus
        let return_amount = (*amount * return_multiplier) / SCALE_FACTOR;

        // damage amount is the amount that the monster will take
        let damage_amount = return_amount - *amount;

        if (monster.hp == 0) {
            // If monster HP is 0, return all stake back to the player
            coin::transfer<AptosCoin>(module_signer, account_addr, *amount);
            event::emit_event(attack_outcome_events, AttackOutcomeEvent {
                player: account_addr,
                outcome: false,
                amount: *amount
            });
            return false
        };

        if (*random_number >= *aggressive) {
            // Player wins, damage the monster. house cut will be applied to return amount.

            let bonus = monster.max_hp / 100 ; // 1% of max HP

            if (monster.hp >= damage_amount) {
                //Normal win scenario, all stake is effective
                let total = return_amount - (return_amount * HOUSE_CUT) / 100;
                monster.hp = monster.hp - damage_amount;
                if (monster.hp == 0) {
                    total = total + bonus;
                    event::emit_event(attack_outcome_events, AttackOutcomeEvent {
                        player: account_addr,
                        outcome: true,
                        amount: total
                    });
                    return true
                };
                coin::transfer<AptosCoin>(module_signer, account_addr, total);
                event::emit_event(attack_outcome_events, AttackOutcomeEvent {
                    player: account_addr,
                    outcome: true,
                    amount: total
                });
            } else {
                let used_stake = (monster.hp * SCALE_FACTOR) / return_multiplier;
                let unused_stake = *amount - used_stake;
                
                let used_return = (used_stake * return_multiplier) / SCALE_FACTOR;
                let house_cut_amount = (used_return * HOUSE_CUT) / 100;
                
                let over_kill_total = used_return - house_cut_amount + unused_stake + bonus;
                
                coin::transfer<AptosCoin>(module_signer, account_addr, over_kill_total);
                monster.hp = 0;
                event::emit_event(attack_outcome_events, AttackOutcomeEvent {
                    player: account_addr,
                    outcome: true,
                    amount: over_kill_total
                });
                return true
            };
        } else {
            // Player loses, coins stay with the resource account
            event::emit_event(attack_outcome_events, AttackOutcomeEvent {
                player: account_addr,
                outcome: false,
                amount: *amount
            });
        };
        false
    }

    fun generate_new_monster(module_signer: &signer) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v4);
        let balance = coin::balance<AptosCoin>(signer::address_of(module_signer));
        let new_hp = (balance * 90) / 100; // 90% of current balance
        module_data.monster = Monster { hp: new_hp, max_hp: new_hp };
    }

    public entry fun generate_monster(admin: &signer, hp: u64) acquires ModuleData {
        assert!(signer::address_of(admin) == @forge_force_dev_v4, E_UNAUTHORIZED);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v4);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(admin, signer::address_of(&module_signer), hp);
        module_data.monster = Monster { hp, max_hp: hp };
    }

    #[view]
    public fun get_monster_hp(): (u64, u64) acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev_v4);
        (module_data.monster.hp, module_data.monster.max_hp)
    }

    public entry fun update_server_random(admin: &signer, new_random: u64) acquires ModuleData {
        assert!(signer::address_of(admin) == @forge_force_dev_v4, E_UNAUTHORIZED);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v4);
        module_data.server_random = new_random;
    }

    public entry fun fund_contract(funder: &signer, amount: u64) acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev_v4);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(funder, signer::address_of(&module_signer), amount);
    }

    public entry fun withdraw_balance(admin: &signer, amount: u64) acquires ModuleData {
        assert!(signer::address_of(admin) == @forge_force_dev_v4, E_UNAUTHORIZED);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v4);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(&module_signer, signer::address_of(admin), amount);
    }

    fun init_module(account: &signer) {
        let (resource_signer, signer_cap) = account::create_resource_account(account, b"forge_force_dev_v4");
        let resource_signer_address = signer::address_of(&resource_signer);

        coin::register<AptosCoin>(&resource_signer);

        move_to(account, ModuleData { 
            signer_cap,
            resource_signer_address,
            random_number_events: account::new_event_handle<RandomNumberEvent>(&resource_signer),
            monster: Monster { hp: 0, max_hp: 0 },
            player_raffles: table::new(),
            server_random: 0, // Initial server random number
            request_nonce: option::none(),
            random_number: option::none(),
            attack_outcome_events: account::new_event_handle<AttackOutcomeEvent>(&resource_signer)
        });
    }
}