module forge_force_dev::forge_force_dev {
    use std::signer;
    use std::debug;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::resource_account;
    use aptos_framework::account;
    use aptos_framework::event;

    // Error codes
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_OUTSIDE_AGGRESSIVE: u64 = 2;

    //Constant
    const SCALE_FACTOR: u64 = 10000;
    const HOUSE_CUT:u64 = 2;

    struct ModuleData has key {
        signer_cap: account::SignerCapability,
        random_number_events: event::EventHandle<RandomNumberEvent> //has to be included/bound in the moduleData 

    }

//event struct
//but it is a global value? Is it will be created as a singleton object? 
//do we need to put such info onchain? 
    #[event]
    struct RandomNumberEvent has drop, store {
        random_number:u64
    }


    #[randomness]
    entry fun raffle_with_aggre(account: &signer, amount: u64 , aggressive :u64) acquires ModuleData {
        let account_addr = std::signer::address_of(account);
        let module_data = borrow_global_mut<ModuleData>(@forge_force_dev);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);

       
        //coin::transfer<AptosCoin>(account, @forge_force_dev, amount); //caller will transfer apt into deployer address, instead of transfering the token into the resource account that created in Init module
        coin::transfer<AptosCoin>(account, signer::address_of(&module_signer), amount); //this line will transfer the token into resource account        

        // Calculate the doubled amount
        assert!(
            aggressive <100,
            E_OUTSIDE_AGGRESSIVE
        );
        assert!(
            aggressive >=0,
            E_OUTSIDE_AGGRESSIVE
        );

        let return_multiplier = SCALE_FACTOR * 100 / (100 - aggressive);
        let return_amount = (amount * return_multiplier) / SCALE_FACTOR;
        // Check if the contract has enough balance
        assert!(
            coin::balance<AptosCoin>(signer::address_of(&module_signer)) >= return_amount,
            E_INSUFFICIENT_BALANCE
        );

        // generate random number
        let rand_val = aptos_framework::randomness::u64_range(0,100);
        let event = RandomNumberEvent{
            random_number: rand_val
        };

        //emit the event to output the random result
        //event::emit_event(&mut module_data.random_number_events, RandomNumberEvent { random_number: rand_val }); 
        aptos_framework::event::emit(event);

        if(rand_val >= aggressive){
            
            coin::transfer<AptosCoin>(&module_signer, account_addr, return_amount);
        }

    }
    public entry fun fund_contract(funder: &signer, amount: u64) acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force_dev);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(funder, signer::address_of(&module_signer), amount);
    }


    // Initialize the module (called when deploying the contract)
    fun init_module(account: &signer) {
        let (resource_signer, signer_cap) = account::create_resource_account(account, b"forge_force_dev"); //this will create a new account address as resource account.
 

        // Register the contract to receive AptosCoin
        coin::register<AptosCoin>(&resource_signer);

        move_to(account, ModuleData { 
            signer_cap,
            // initialize the moduleData
            random_number_events: account::new_event_handle<RandomNumberEvent>(&resource_signer)
         });

    }


}
