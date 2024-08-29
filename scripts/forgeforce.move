module forge_force_dev_v8::forge_force_dev_v8 {
    use std::signer;
    use std::vector;
    use std::string;
    use std::debug;
    use std::option::{Self, Option};
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account;
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;
    use aptos_framework::block;
    use aptos_framework::event;
    use aptos_framework::create_signer::create_signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::smart_vector::{Self, SmartVector};
    use aptos_std::simple_map::{Self, SimpleMap};

    // Error codes
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_OUTSIDE_AGGRESSIVE: u64 = 2;
    const E_RAFFLE_ALREADY_SAMPLED: u64 = 3;
    const E_RAFFLE_NOT_SAMPLED: u64 = 4;
    const E_UNAUTHORIZED: u64 = 5;

    //Constant
    const SCALE_FACTOR: u64 = 10000000;

    struct ModuleData has key {
        signer_cap: account::SignerCapability,
        resource_signer_address: address,
        monster: smart_table::SmartTable<u64, Monster>,
        player_raffles: smart_table::SmartTable<address, AttackHistory>,
        attack_outcome_events: event::EventHandle<AttackOutcomeEvent>
    }
    
    struct Monster has store, copy {
        hp: u64,
        max_hp: u64,
        defence: u64
    }

    struct PlayerRaffle has store, copy {
        raffle_id: u64,
        monster_id: u64,
        stake_amount: u64, // amount that the player staked
        effective_amount: u64, // amount that applied to the monster
        bonus: u64, // bonus amount given to the player if the monster is killed
        final_damage: u64, // damage done to the monster
        aggressive: u64,
        random_number: u64,
        sampled: bool
    }

    struct AttackHistory has store {
        attack_history: smart_vector::SmartVector<PlayerRaffle>
    }

    #[event]
    struct AttackOutcomeEvent has store, drop {
        raffle_id: u64,
        player: address,
        outcome: bool, // true if player won, false if player lost
        amount: u64, // amount won or lost
        damage: u64
    }
    #[view]
    public fun get_resource_signer_address(): address acquires ModuleData {
        borrow_global<ModuleData>(@forge_force_dev_v8).resource_signer_address
    }

    // TODO: BCS format for passing the history
    // #[view]
    // public fun get_History_By_address(account_addr: address): AttackHistory acquires ModuleData {
    //     smart_table::borrow_mut(&borrow_global<ModuleData>(@forge_force_dev_v8).player_raffles, account_addr)
    // }

    #[view]
    public fun get_module_signer_address(): address acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev_v8);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        signer::address_of(&module_signer)
    }
    #[view]
    public fun get_signer_capability_address_address(): address acquires ModuleData {
        account::get_signer_capability_address(&borrow_global<ModuleData>(@forge_force_dev_v8).signer_cap)
    }

    public entry fun forge_attack_with_aggressive(account: &signer, amount: u64, aggressive: u64) acquires ModuleData {
        let account_addr = signer::address_of(account);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v8);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        // TODO: adjust the entry require for the u
        // assert!(
        //     !smart_table::contains(&module_data.player_raffles, account_addr) ||
        //     (smart_table::contains(&module_data.player_raffles, account_addr) &&
        //      smart_vector::is_empty(&smart_table::borrow(&module_data.player_raffles, account_addr).attack_history)),
        //     E_RAFFLE_ALREADY_SAMPLED
        // );

        

        assert!(aggressive < 100 && aggressive >= 0, E_OUTSIDE_AGGRESSIVE);
 
        // Generate random number using new RNG method
        let random_number = 0; // Placeholder, replace with your new RNG method

        // Get or create the AttackHistory for the player
        if (!smart_table::contains(&mut module_data.player_raffles, account_addr)) {
            smart_table::add(&mut module_data.player_raffles, account_addr, AttackHistory { attack_history: smart_vector::empty() });
        };
        let attack_history = smart_table::borrow_mut(&mut module_data.player_raffles, account_addr);

        let raffle_id = smart_vector::length(&attack_history.attack_history) + 1;

        // Get the latest monster ID !!todo must generate monster first
        let monster_id = smart_table::length(&module_data.monster);

        let new_raffle = PlayerRaffle {
            raffle_id,
            monster_id,
            stake_amount: amount,
            effective_amount: 0, // Will be set in settle_attack
            bonus: 0, // Will be set in settle_attack
            final_damage: 0, // Will be set in settle_attack
            aggressive,
            random_number,
            sampled: false
        };

        smart_vector::push_back(&mut attack_history.attack_history, new_raffle);
        coin::transfer<AptosCoin>(account, signer::address_of(&module_signer), amount);
    }

    public entry fun settle_attack(admin: &signer, player: address, server_random: u64) acquires ModuleData {
        assert!(signer::address_of(admin) == @forge_force_dev_v8, E_UNAUTHORIZED);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v8);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        let player_raffle = &mut module_data.player_raffles;

        let attack_history = smart_table::borrow_mut(player_raffle, player);

        let last_index = smart_vector::length(&attack_history.attack_history) - 1;

        let last_raffle = smart_vector::borrow_mut(&mut attack_history.attack_history, last_index);

        assert!(!last_raffle.sampled, E_RAFFLE_ALREADY_SAMPLED);

        last_raffle.random_number = server_random;
        last_raffle.sampled = true;
        let monster = smart_table::borrow_mut(&mut module_data.monster, last_raffle.monster_id);

        if (monster.hp == 0) {
            // If monster HP is 0, return all stake back to the player
            coin::transfer<AptosCoin>(&module_signer, player, last_raffle.stake_amount);
            last_raffle.effective_amount = 0;
            last_raffle.final_damage = 0;
            last_raffle.bonus = 0;

            event::emit_event(&mut module_data.attack_outcome_events, AttackOutcomeEvent {
                raffle_id: last_raffle.raffle_id,
                player,
                outcome: false,
                amount: last_raffle.stake_amount,
                damage: 0
            });
            return;
        };

        if (last_raffle.random_number >= last_raffle.aggressive) {
            // Player wins, damage the monster. house cut will be applied to return amount.

            // Calculate the return multiplier
            let return_multiplier = (SCALE_FACTOR * 100 / (100 - last_raffle.aggressive)) - SCALE_FACTOR;

            // Calculate the effective amount
            let effective_amount = (last_raffle.stake_amount * return_multiplier) / SCALE_FACTOR;

            // Calculate the damage amount
            let damage_amount = (effective_amount * (100 * SCALE_FACTOR - monster.defence * SCALE_FACTOR)) / (100 * SCALE_FACTOR);
            
            let bonus = monster.max_hp / 100; // 1% of max HP

            let return_total = 0;  
            if (monster.hp >= damage_amount) {
                // Normal win scenario, all stake is effective
                
                monster.hp = if (monster.hp > damage_amount) { monster.hp - damage_amount } else { 0 };
    
                last_raffle.effective_amount = effective_amount;
                last_raffle.final_damage = damage_amount;

                if (monster.hp == 0) {
                    last_raffle.bonus = bonus;
                    return_total = damage_amount + bonus;
                } else {
                    last_raffle.bonus = 0; // No bonus if monster not killed
                    return_total = damage_amount;
                };

                return_total = return_total + last_raffle.stake_amount;


                coin::transfer<AptosCoin>(&module_signer, player, return_total);
                event::emit_event(&mut module_data.attack_outcome_events, AttackOutcomeEvent {
                    raffle_id: last_raffle.raffle_id,
                    player,
                    outcome: true,
                    amount: return_total,
                    damage: damage_amount
                });
            } else {
                // damage amount is greater than monster hp

                last_raffle.effective_amount = effective_amount;
                let over_kill_damage = monster.hp;
                last_raffle.final_damage = over_kill_damage;
                last_raffle.bonus = bonus;


                let over_kill_total = over_kill_damage + last_raffle.stake_amount + bonus;  
                coin::transfer<AptosCoin>(&module_signer, player, over_kill_total);
                event::emit_event(&mut module_data.attack_outcome_events, AttackOutcomeEvent {
                    raffle_id: last_raffle.raffle_id,
                    player,
                    outcome: true,
                    amount: over_kill_total,
                    damage: over_kill_damage
                });

                monster.hp = 0;
            };
        } else {
            // Player loses, coins stay with the resource account
            last_raffle.effective_amount = 0;
            last_raffle.final_damage = 0;
            last_raffle.bonus = 0;
            event::emit_event(&mut module_data.attack_outcome_events, AttackOutcomeEvent {
                raffle_id: last_raffle.raffle_id,
                player,
                outcome: false,
                amount: last_raffle.stake_amount,
                damage: 0
            });
        };
    }

    // fun generate_new_monster(module_signer: &signer) acquires ModuleData {
    //     let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v8);
    //     let balance = coin::balance<AptosCoin>(signer::address_of(module_signer));
    //     let new_hp = (balance * 90) / 100; // 90% of current balance
    //     module_data.monster = Monster { hp: new_hp, max_hp: new_hp };
    // }

    public entry fun generate_monster(admin: &signer, hp: u64 , defence: u64) acquires ModuleData {
        assert!(signer::address_of(admin) == @forge_force_dev_v8, E_UNAUTHORIZED);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v8);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(admin, signer::address_of(&module_signer), hp);
        let monster_id = smart_table::length(&module_data.monster) + 1;
        smart_table::add(&mut module_data.monster, monster_id, Monster { hp, max_hp: hp, defence });
    }

    #[view]
    public fun get_monster_list(): SimpleMap<u64, Monster>  acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev_v8);
        smart_table::to_simple_map(&module_data.monster)
    }
    #[view]
    public fun get_player_attack_history(player: address): vector<PlayerRaffle> acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev_v8);
        
        if (!smart_table::contains(&module_data.player_raffles, player)) {
            return vector::empty<PlayerRaffle>()
        };
        
        let attack_history = smart_table::borrow(&module_data.player_raffles, player);
        let history_vector = &attack_history.attack_history;
        
        let result = vector::empty<PlayerRaffle>();
        let i = 0;
        let len = smart_vector::length(history_vector);
        
        while (i < len) {
            let raffle = smart_vector::borrow(history_vector, i);
            vector::push_back(&mut result, *raffle);
            i = i + 1;
        };

        result
    }

    // public entry fun update_server_random(admin: &signer, new_random: u64) acquires ModuleData {
    //     assert!(signer::address_of(admin) == @forge_force_dev_v8, E_UNAUTHORIZED);
    //     let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v8);
    //     module_data.server_random = new_random;
    // }

    public entry fun fund_contract(funder: &signer, amount: u64) acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev_v8);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(funder, signer::address_of(&module_signer), amount);
    }

    public entry fun withdraw_balance(admin: &signer, amount: u64) acquires ModuleData {
        assert!(signer::address_of(admin) == @forge_force_dev_v8, E_UNAUTHORIZED);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev_v8);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(&module_signer, signer::address_of(admin), amount);
    }

    fun init_module(account: &signer) {
        let (resource_signer, signer_cap) = account::create_resource_account(account, b"forge_force_dev_v8");
        let resource_signer_address = signer::address_of(&resource_signer);

        coin::register<AptosCoin>(&resource_signer);

        move_to(account, ModuleData { 
            signer_cap,
            resource_signer_address,
            monster: smart_table::new(),
            player_raffles: smart_table::new(),
            attack_outcome_events: account::new_event_handle<AttackOutcomeEvent>(&resource_signer)
        });
    }

    #[view]
    public fun get_noise(): u64 {
        1
    }
}