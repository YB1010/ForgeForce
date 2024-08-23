module forge_force_dev_v4::forge_force_player_v4 {
    use std::signer;
    use forge_force_dev_v4::forge_force_dev_v4;

    public entry fun forge_attack(account: &signer, amount: u64, aggressive: u64) {
        forge_force_dev_v4::forge_attack_with_aggressive(account, amount, aggressive);
    }

}
