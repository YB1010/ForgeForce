module forge_force_dev_v2::xoroshiro {
    use std::signer;
    use std::vector;
    use aptos_framework::account;

    const E_NOT_AUTHORIZED: u64 = 1;

    struct FriendList has key {
        friends: vector<address>
    }

    struct Xoroshiro has store, copy, drop {
        state: u128
    }

    public fun new(seed: u128): Xoroshiro {
        Xoroshiro {
            state: seed
        }
    }

    public fun next(self: &mut Xoroshiro): u64 acquires FriendList{
        assert!(is_friend(@forge_force_dev_v2), E_NOT_AUTHORIZED);
        roll_state(self);
        (self.state as u64)
    }

    public fun get_state(self: &Xoroshiro): u128 acquires FriendList{
        assert!(is_friend(@forge_force_dev_v2), E_NOT_AUTHORIZED);
        self.state
    }

    public fun set_state(self: &mut Xoroshiro, state: u128)acquires FriendList {
        assert!(is_friend(@forge_force_dev_v2), E_NOT_AUTHORIZED);
        self.state = state;
    }

    fun roll_state(self: &mut Xoroshiro) {
        let state = (self.state as u256);
        let x = state;
        let y = state >> 64;

        let t = x ^ y;
        state = ((x << 55) | (x >> 9)) + y + t;

        y = y ^ x;
        state = state + ((y << 14) | (y >> 50)) + x + t;
        
        state = state + t;
        state = state % ((1 << 128) - 1);
        self.state = (state as u128);
    }

    public entry fun set_friend(account: &signer, friend_address: address) acquires FriendList {
        let account_addr = signer::address_of(account);
        assert!(account_addr == @forge_force_dev_v2, E_NOT_AUTHORIZED);

        if (!exists<FriendList>(account_addr)) {
            move_to(account, FriendList { friends: vector::empty() });
        };

        let friend_list = borrow_global_mut<FriendList>(account_addr);
        if (!vector::contains(&friend_list.friends, &friend_address)) {
            vector::push_back(&mut friend_list.friends, friend_address);
        };
    }

    fun is_friend(module_addr: address): bool acquires FriendList {
        if (!exists<FriendList>(@forge_force_dev_v2)) {
            return false
        };
        let friend_list = borrow_global<FriendList>(@forge_force_dev_v2);
        vector::contains(&friend_list.friends, &module_addr)
    }

    fun init_module(account: &signer) {
        assert!(signer::address_of(account) == @forge_force_dev_v2, E_NOT_AUTHORIZED);
        move_to(account, FriendList { friends: vector::empty() });
    }
}