//! Minimal Bitcoin integration example for the Internet Computer.
//!
//! Demonstrates reading Bitcoin balance via the Bitcoin canister API.

use candid::CandidType;
use ic_cdk::bitcoin_canister::{
    bitcoin_get_balance, get_bitcoin_canister_id, GetBalanceRequest, Network, Satoshi,
};

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

/// Get the canister's Bitcoin configuration.
#[ic_cdk::query]
fn get_config() -> BitcoinConfig {
    let network = get_network();
    BitcoinConfig {
        network: match network {
            Network::Mainnet => "mainnet",
            Network::Testnet => "testnet",
            Network::Regtest => "regtest",
        }
        .to_string(),
        bitcoin_canister_id: get_bitcoin_canister_id(&network).to_string(),
    }
}

#[derive(CandidType)]
struct BitcoinConfig {
    network: String,
    bitcoin_canister_id: String,
}
