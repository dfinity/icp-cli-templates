/// Minimal Bitcoin integration example for the Internet Computer.
///
/// Demonstrates reading Bitcoin balance via the Bitcoin canister API.

import Runtime "mo:core/Runtime";
import Text "mo:core/Text";

persistent actor Backend {
  public type Satoshi = Nat64;
  public type BitcoinAddress = Text;

  public type Network = {
    #mainnet;
    #testnet;
    #regtest;
  };

  public type BitcoinConfig = {
    network : Text;
    bitcoin_canister_id : Text;
  };

  type BitcoinCanister = actor {
    bitcoin_get_balance : shared {
      address : BitcoinAddress;
      network : Network;
      min_confirmations : ?Nat32;
    } -> async Satoshi;
  };

  // The BITCOIN_NETWORK env var (and thus the targeted Bitcoin network)
  // can be changed at runtime without redeploying the canister.
  private func getNetwork<system>() : Network {
    switch (Runtime.envVar("BITCOIN_NETWORK")) {
      case (?value) {
        switch (Text.toLower(value)) {
          case ("mainnet") #mainnet;
          case ("testnet") #testnet;
          case _ #regtest;
        };
      };
      case null #regtest;
    };
  };

  private func getBitcoinCanisterId(network : Network) : Text {
    switch (network) {
      case (#mainnet) "ghsi2-tqaaa-aaaan-aaaca-cai";
      case _ "g4xu7-jiaaa-aaaan-aaaaq-cai";
    };
  };

  private func networkToText(network : Network) : Text {
    switch (network) {
      case (#mainnet) "mainnet";
      case (#testnet) "testnet";
      case (#regtest) "regtest";
    };
  };

  // Minimum cycles required for bitcoin_get_balance
  // (100M for mainnet, 40M for testnet/regtest).
  // See https://docs.internetcomputer.org/references/bitcoin-how-it-works
  private func getBalanceCost(network : Network) : Nat {
    switch (network) {
      case (#mainnet) 100_000_000;
      case _ 40_000_000;
    };
  };

  /// Get the balance of a Bitcoin address in satoshis.
  public func get_balance(address : BitcoinAddress) : async Satoshi {
    let network = getNetwork();
    await (with cycles = getBalanceCost(network)) (actor (getBitcoinCanisterId(network)) : BitcoinCanister).bitcoin_get_balance({
      address;
      network;
      min_confirmations = null;
    });
  };

  /// Get the canister's Bitcoin configuration.
  public query func get_config() : async BitcoinConfig {
    let network = getNetwork();
    {
      network = networkToText(network);
      bitcoin_canister_id = getBitcoinCanisterId(network);
    };
  };
};
