//! Bitcoin Integration Example
//!
//! This canister demonstrates Bitcoin integration on the Internet Computer:
//! - Derive a Bitcoin address controlled by the canister via threshold ECDSA
//! - Receive Bitcoin by mining to the canister's address (on regtest)
//! - Send Bitcoin to any address
//! - Query balances and UTXOs
//!
//! The Bitcoin network is configured via the BITCOIN_NETWORK environment variable.

use bitcoin::{
    absolute::LockTime,
    consensus::serialize,
    hashes::Hash,
    sighash::{EcdsaSighashType, SighashCache},
    transaction::Version,
    Address, Amount, CompressedPublicKey, Network as BtcNetwork, OutPoint, ScriptBuf, Sequence,
    Transaction, TxIn, TxOut, Txid, Witness,
};
use candid::CandidType;
use ic_cdk::bitcoin_canister::{
    bitcoin_get_balance, bitcoin_get_current_fee_percentiles, bitcoin_get_utxos,
    bitcoin_send_transaction, GetBalanceRequest, GetCurrentFeePercentilesRequest, GetUtxosRequest,
    GetUtxosResponse, MillisatoshiPerByte, Network, Satoshi, SendTransactionRequest, Utxo,
};
use ic_cdk::management_canister::{EcdsaCurve, EcdsaKeyId, EcdsaPublicKeyArgs, SignWithEcdsaArgs};
use serde::Deserialize;

const DUST_THRESHOLD: u64 = 1_000;

// ---------------------------------------------------------------------------
// Bitcoin network helpers
// ---------------------------------------------------------------------------

/// Get the IC Bitcoin network from the BITCOIN_NETWORK environment variable.
fn get_network() -> Network {
    let network_str = if ic_cdk::api::env_var_name_exists("BITCOIN_NETWORK") {
        ic_cdk::api::env_var_value("BITCOIN_NETWORK").to_lowercase()
    } else {
        "regtest".to_string()
    };

    match network_str.as_str() {
        "mainnet" => Network::Mainnet,
        "testnet" => Network::Testnet,
        _ => Network::Regtest,
    }
}

/// Map the IC network type to the rust-bitcoin network type.
fn to_btc_network(network: Network) -> BtcNetwork {
    match network {
        Network::Mainnet => BtcNetwork::Bitcoin,
        Network::Testnet => BtcNetwork::Testnet,
        Network::Regtest => BtcNetwork::Regtest,
    }
}

/// The ECDSA key name used by the IC subnet.
fn ecdsa_key_name() -> String {
    match get_network() {
        Network::Regtest | Network::Testnet => "test_key_1".to_string(),
        Network::Mainnet => "key_1".to_string(),
    }
}

fn ecdsa_key_id() -> EcdsaKeyId {
    EcdsaKeyId {
        curve: EcdsaCurve::Secp256k1,
        name: ecdsa_key_name(),
    }
}

/// A fixed derivation path for the canister's Bitcoin key.
fn derivation_path() -> Vec<Vec<u8>> {
    vec![b"btc".to_vec()]
}

// ---------------------------------------------------------------------------
// Address derivation
// ---------------------------------------------------------------------------

/// Fetch the canister's compressed ECDSA public key from the IC management canister.
async fn get_ecdsa_public_key() -> Vec<u8> {
    ic_cdk::management_canister::ecdsa_public_key(&EcdsaPublicKeyArgs {
        canister_id: None,
        derivation_path: derivation_path(),
        key_id: ecdsa_key_id(),
    })
    .await
    .expect("Failed to get ECDSA public key")
    .public_key
}

/// Derive the canister's P2WPKH Bitcoin address from its ECDSA public key.
async fn get_p2wpkh_address() -> Address {
    let public_key_bytes = get_ecdsa_public_key().await;
    let compressed_key = CompressedPublicKey::from_slice(&public_key_bytes)
        .expect("Invalid 33-byte compressed public key");
    Address::p2wpkh(&compressed_key, to_btc_network(get_network()))
}

// ---------------------------------------------------------------------------
// Transaction building
// ---------------------------------------------------------------------------

/// Select UTXOs greedily to cover `amount + fee`.
fn select_utxos(utxos: &[Utxo], amount: u64, fee: u64) -> Vec<Utxo> {
    let target = amount + fee;
    let mut selected = Vec::new();
    let mut total = 0u64;
    for utxo in utxos.iter().rev() {
        selected.push(utxo.clone());
        total += utxo.value;
        if total >= target {
            return selected;
        }
    }
    panic!(
        "Insufficient balance: have {} satoshi, need {} (amount {} + fee {})",
        total, target, amount, fee
    );
}

/// Build a transaction spending `utxos_to_spend` with one output to `dst_address`
/// and an optional change output back to `own_address`.
fn build_transaction(
    utxos_to_spend: &[Utxo],
    own_address: &Address,
    dst_address: &Address,
    amount: u64,
    fee: u64,
) -> Transaction {
    let inputs: Vec<TxIn> = utxos_to_spend
        .iter()
        .map(|utxo| TxIn {
            previous_output: OutPoint {
                txid: Txid::from_raw_hash(Hash::from_slice(&utxo.outpoint.txid).unwrap()),
                vout: utxo.outpoint.vout,
            },
            sequence: Sequence::MAX,
            script_sig: ScriptBuf::new(),
            witness: Witness::new(),
        })
        .collect();

    let mut outputs = vec![TxOut {
        value: Amount::from_sat(amount),
        script_pubkey: dst_address.script_pubkey(),
    }];

    let total_in: u64 = utxos_to_spend.iter().map(|u| u.value).sum();
    let change = total_in - amount - fee;
    if change >= DUST_THRESHOLD {
        outputs.push(TxOut {
            value: Amount::from_sat(change),
            script_pubkey: own_address.script_pubkey(),
        });
    }

    Transaction {
        version: Version::TWO,
        lock_time: LockTime::ZERO,
        input: inputs,
        output: outputs,
    }
}

/// Estimate the transaction fee using iterative sizing with mock signatures.
fn estimate_fee(
    utxos: &[Utxo],
    own_address: &Address,
    dst_address: &Address,
    amount: u64,
    fee_per_vbyte: u64,
) -> (Vec<Utxo>, Transaction, u64) {
    let mut fee = 0u64;
    loop {
        let selected = select_utxos(utxos, amount, fee);
        let tx = build_transaction(&selected, own_address, dst_address, amount, fee);

        // Create a mock-signed copy to measure the virtual size.
        let signed = mock_sign_transaction(tx.clone());
        let vsize = signed.vsize() as u64;
        let new_fee = (vsize * fee_per_vbyte) / 1000;

        if new_fee == fee {
            return (selected, tx, fee);
        }
        fee = new_fee;
    }
}

/// Fill in witness data with dummy signatures for size estimation.
fn mock_sign_transaction(mut tx: Transaction) -> Transaction {
    let mock_sig = [1u8; 64];
    let mock_pubkey = [2u8; 33];

    for input in tx.input.iter_mut() {
        let mut witness = Witness::new();
        // A DER-encoded ECDSA signature is at most 73 bytes + 1 sighash byte.
        // Using a compact 64-byte representation here slightly underestimates,
        // but the iterative loop will converge to the correct fee regardless.
        witness.push(mock_sig);
        witness.push(mock_pubkey);
        input.witness = witness;
    }

    tx
}

/// Sign each transaction input with the canister's threshold ECDSA key (P2WPKH).
async fn sign_transaction(
    mut tx: Transaction,
    utxos_to_spend: &[Utxo],
    own_address: &Address,
    public_key_bytes: &[u8],
) -> Transaction {
    let compressed_key =
        CompressedPublicKey::from_slice(public_key_bytes).expect("Invalid compressed public key");

    // Build the prevouts list (needed for SegWit sighash computation).
    let prevouts: Vec<TxOut> = utxos_to_spend
        .iter()
        .map(|utxo| TxOut {
            value: Amount::from_sat(utxo.value),
            script_pubkey: own_address.script_pubkey(),
        })
        .collect();

    for index in 0..tx.input.len() {
        let sighash = {
            let mut cache = SighashCache::new(&tx);
            cache
                .p2wpkh_signature_hash(
                    index,
                    &prevouts[index].script_pubkey,
                    prevouts[index].value,
                    EcdsaSighashType::All,
                )
                .expect("Failed to compute sighash")
        };

        let raw_signature = ic_cdk::management_canister::sign_with_ecdsa(&SignWithEcdsaArgs {
            message_hash: sighash.as_byte_array().to_vec(),
            derivation_path: derivation_path(),
            key_id: ecdsa_key_id(),
        })
        .await
        .expect("Failed to sign with ECDSA")
        .signature;

        let signature = bitcoin::secp256k1::ecdsa::Signature::from_compact(&raw_signature)
            .expect("Invalid ECDSA signature");
        let bitcoin_sig = bitcoin::ecdsa::Signature {
            signature,
            sighash_type: EcdsaSighashType::All,
        };

        let mut witness = Witness::new();
        witness.push(bitcoin_sig.to_vec());
        witness.push(compressed_key.to_bytes());
        tx.input[index].witness = witness;
    }

    tx
}

// ---------------------------------------------------------------------------
// Public canister API
// ---------------------------------------------------------------------------

/// Returns a Bitcoin address controlled by this canister via threshold ECDSA.
#[ic_cdk::update]
async fn get_canister_btc_address() -> String {
    get_p2wpkh_address().await.to_string()
}

/// Get the balance of a Bitcoin address in satoshis.
#[ic_cdk::update]
async fn get_balance(address: String) -> Satoshi {
    bitcoin_get_balance(&GetBalanceRequest {
        address,
        network: get_network(),
        min_confirmations: None,
    })
    .await
    .expect("Failed to get balance")
}

/// Get the UTXOs for a Bitcoin address.
#[ic_cdk::update]
async fn get_utxos(address: String) -> GetUtxosResponse {
    bitcoin_get_utxos(&GetUtxosRequest {
        address,
        network: get_network(),
        filter: None,
    })
    .await
    .expect("Failed to get UTXOs")
}

/// Get current Bitcoin fee percentiles (millisatoshi per vbyte).
#[ic_cdk::update]
async fn get_fee_percentiles() -> Vec<MillisatoshiPerByte> {
    bitcoin_get_current_fee_percentiles(&GetCurrentFeePercentilesRequest {
        network: get_network(),
    })
    .await
    .expect("Failed to get fee percentiles")
}

/// Transfer Bitcoin to a destination address.
///
/// Returns the transaction ID of the submitted transaction.
#[ic_cdk::update]
async fn transfer_btc(request: TransferRequest) -> String {
    let network = get_network();
    let btc_network = to_btc_network(network);

    // Parse and validate destination address.
    let dst_address: Address = request
        .destination
        .parse::<Address<_>>()
        .expect("Invalid destination address")
        .require_network(btc_network)
        .expect("Destination address does not match the configured Bitcoin network");

    // Get the canister's own address and public key.
    let public_key_bytes = get_ecdsa_public_key().await;
    let compressed_key =
        CompressedPublicKey::from_slice(&public_key_bytes).expect("Invalid compressed public key");
    let own_address = Address::p2wpkh(&compressed_key, btc_network);

    // Fetch UTXOs for the canister's address.
    let utxos_response = bitcoin_get_utxos(&GetUtxosRequest {
        address: own_address.to_string(),
        network,
        filter: None,
    })
    .await
    .expect("Failed to get UTXOs");

    // Determine fee rate (median of fee percentiles, fallback for regtest).
    let fee_percentiles =
        bitcoin_get_current_fee_percentiles(&GetCurrentFeePercentilesRequest { network })
            .await
            .expect("Failed to get fee percentiles");
    let fee_per_vbyte = if fee_percentiles.is_empty() {
        2000 // fallback: 2 sat/vbyte in millisatoshis
    } else {
        fee_percentiles[fee_percentiles.len() / 2]
    };

    // Build and sign the transaction.
    let (selected_utxos, unsigned_tx, _fee) = estimate_fee(
        &utxos_response.utxos,
        &own_address,
        &dst_address,
        request.amount_in_satoshi,
        fee_per_vbyte,
    );

    let signed_tx =
        sign_transaction(unsigned_tx, &selected_utxos, &own_address, &public_key_bytes).await;

    let txid = signed_tx.compute_txid().to_string();

    // Broadcast the transaction.
    bitcoin_send_transaction(&SendTransactionRequest {
        network,
        transaction: serialize(&signed_tx),
    })
    .await
    .expect("Failed to send transaction");

    txid
}

/// Get information about the Bitcoin canister configuration.
#[ic_cdk::query]
fn get_bitcoin_info() -> BitcoinInfo {
    BitcoinInfo {
        network: format!("{:?}", get_network()),
    }
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

#[derive(CandidType, Deserialize)]
struct TransferRequest {
    destination: String,
    amount_in_satoshi: u64,
}

#[derive(CandidType, Deserialize)]
struct BitcoinInfo {
    network: String,
}
