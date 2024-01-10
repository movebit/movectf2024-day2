#[lint_allow(coin_field, self_transfer)]
module zk::zk2 {
    use sui::groth16;
    use sui::event;
    use sui::tx_context;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::table::{Table, Self};
    use sui::hash::keccak256;

    use std::option;

    struct Flag has copy, drop {
        user: address
    }

    struct ZK2 has drop {}

    struct Protocol has key {
        id: UID,
        vault: Coin<ZK2>,
        cap: TreasuryCap<ZK2>,
        proof_talbe: Table<vector<u8>, bool>,
        balance: Table<address, u64>
    }
    
    fun init(witness: ZK2, ctx: &mut sui::tx_context::TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            3,
            b"zk2",
            b"zk2",
            b"zk2",
            option::none(),
            ctx,
        );

        transfer::share_object(Protocol {
            id: object::new(ctx),
            vault: coin::mint(&mut treasury_cap, 100_000, ctx),
            cap: treasury_cap,
            proof_talbe: table::new<vector<u8>, bool>(ctx),
            balance: table::new<address, u64>(ctx)
        });

        transfer::public_freeze_object(metadata);
    }

    public entry fun faucet(protocol: &mut Protocol, ctx: &mut tx_context::TxContext) {
        table::add(&mut protocol.balance, tx_context::sender(ctx), 60_000);
    }

    public entry fun verify_proof(public_inputs_bytes: vector<u8>, proof_points_bytes: vector<u8>) {
        let vk = x"546930fc4eb310adee09b7d2f7caaf8674980a7bc8eb6cb96a7a11cfbd1adb14f7e343bbd6bbb8b7296a00219ed6980a79cfe185b6b06749039bf0437553381a3f2d9c8565481c1be4212f723cd0d1832254d174338abaf941fdf69905719f13257170c23ec5bff18e4617513918be6635e60e7f6aeea03600a4936adf8ace12bf2f9f3c4d01d056b4ab97061040dc81389f335b844401ded1ca9d7e10e9742bb4f354e734b0f948214e23fc6a0de7440ce99d339e9c58aa4a72e30e714e50246b1f5ed80d89996c57d39907f3d27dbb2c86bd25ddb3ef7b36df198513fbac870200000000000000d04719dcf59f5387d2f51733a49c1c200395a9a8b1e35d8deb029af6d1a5892c18ff4a1891e92af042eded7aea48b61a7581baa05899413e445ea7158993e123";
        let pvk = groth16::prepare_verifying_key(&groth16::bn254(), &vk);
        let public_inputs = groth16::public_proof_inputs_from_bytes(public_inputs_bytes);
        let proof_points = groth16::proof_points_from_bytes(proof_points_bytes);
        assert!(groth16::verify_groth16_proof(&groth16::bn254(), &pvk, &public_inputs, &proof_points), 0);
    }

    public entry fun withdraw(amount: u64, public_inputs_bytes: vector<u8>, proof_points_bytes: vector<u8>, protocol: &mut Protocol, ctx: &mut tx_context::TxContext) {
        verify_proof(public_inputs_bytes, proof_points_bytes);
        assert!(*table::borrow(&protocol.balance, tx_context::sender(ctx)) >= amount, 0);
        table::add(&mut protocol.proof_talbe, keccak256(&proof_points_bytes), true);
        let coin = coin::split(&mut protocol.vault, amount, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));
    }

    public entry fun get_flag(protocol: &mut Protocol, ctx: &mut tx_context::TxContext) {
        assert!(coin::value<ZK2>(&protocol.vault) == 0, 0);
        event::emit(Flag { user: tx_context::sender(ctx) });
    }

    #[test_only]
    public fun init_test(ctx: &mut tx_context::TxContext) {
        init(ZK2{}, ctx);
    }
}