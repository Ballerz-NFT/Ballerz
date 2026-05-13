import "FungibleToken"
import "DapperUtilityCoin"
import "TokenForwarding"

// Sets up a TokenForwarding.Forwarder for DapperUtilityCoin on the signer's
// account, publishing a public FungibleToken.Receiver capability at
// /public/dapperUtilityCoinReceiver. The Forwarder forwards every deposit to
// Dapper's main DUC vault on 0xead892083b3e2c6c, which is what Dapper's
// purchase transaction templates require — a direct DUC.Vault here trips the
// "DapperUtilityCoin leakage" post-condition.
//
// Note: actually receiving value from the forwarded DUC requires a separate
// merchant arrangement with Dapper to attribute incoming forwards to this
// wallet. Without that, sales succeed but the DUC accumulates at Dapper
// unattributed.
//
// Idempotent: safe to run more than once.

transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Tear down whatever's currently at the public receiver path
        signer.capabilities.unpublish(/public/dapperUtilityCoinReceiver)

        // Drop any prior direct DUC vault we may have placed here.
        // Refuse if it has a non-zero balance — we shouldn't destroy real funds.
        if let oldVault <- signer.storage.load<@DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault) {
            assert(oldVault.balance == 0.0, message: "existing /storage/dapperUtilityCoinVault has non-zero balance; withdraw before re-running")
            destroy oldVault
        }

        // Drop any prior forwarder so re-runs land clean
        if let oldFwd <- signer.storage.load<@TokenForwarding.Forwarder>(from: /storage/dapperUtilityCoinReceiver) {
            destroy oldFwd
        }

        // Create a forwarder targeting Dapper's main DUC receiver
        let dapperReceiver = getAccount(0xead892083b3e2c6c)
            .capabilities.get<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(dapperReceiver.check(), message: "Dapper main DUC receiver capability is not borrowable")

        let forwarder <- TokenForwarding.createNewForwarder(recipient: dapperReceiver)
        signer.storage.save(<-forwarder, to: /storage/dapperUtilityCoinReceiver)

        let cap = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/dapperUtilityCoinReceiver)
        signer.capabilities.publish(cap, at: /public/dapperUtilityCoinReceiver)
    }
}
