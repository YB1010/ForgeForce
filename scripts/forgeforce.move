module forge_force::forge_force {
    use std::signer;
    use std::debug;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::resource_account;
    use aptos_framework::account;

    // Error codes
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_OUTSIDE_AGGRESSIVE: u64 = 2;
    const SCALE_FACTOR: u64 = 10000;

    struct ModuleData has key {
        signer_cap: account::SignerCapability
    }

    #[randomness]
    entry fun raffle_with_aggre(account: &signer, amount: u64 , aggressive :u64) acquires ModuleData {
        let account_addr = std::signer::address_of(account);
        let module_data = borrow_global<ModuleData>(@forge_force);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);

        // Transfer tokens from the caller to the contract
        //coin::transfer<AptosCoin>(account, @forge_force, amount); //caller will transfer apt into deployer address, instead of transfering the token into the resource account that created in Init module
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

        let return_multiplier = SCALE_FACTOR * 100 / (101 - aggressive);
        let return_amount = (amount * return_multiplier) / SCALE_FACTOR;
        // Check if the contract has enough balance
        assert!(
            coin::balance<AptosCoin>(@forge_force) >= return_amount,
            E_INSUFFICIENT_BALANCE
        );

        // Transfer the doubled amount back to the caller
        let rand_val = aptos_framework::randomness::u64_range(0,100);
        
        if(rand_val >= aggressive){
            
            coin::transfer<AptosCoin>(&module_signer, account_addr, return_amount);
        }

    }
    public entry fun fund_contract(funder: &signer, amount: u64) acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@forge_force);
        let module_signer = account::create_signer_with_capability(&module_data.signer_cap);
        coin::transfer<AptosCoin>(funder, signer::address_of(&module_signer), amount);
    }
    // Initialize the module (called when deploying the contract)
    fun init_module(account: &signer) {
        let (resource_signer, signer_cap) = account::create_resource_account(account, b"forge_force"); //this will create a new account address as resource account.
 

        // Register the contract to receive AptosCoin
        coin::register<AptosCoin>(&resource_signer);

        move_to(account, ModuleData { signer_cap });

    }


}
