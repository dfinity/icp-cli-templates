/// Minimal Bitcoin integration example for the Internet Computer.
///
/// Demonstrates reading Bitcoin balance via the Bitcoin canister API.

import Prim "mo:⛔";
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

  // Resolved once at init/upgrade (actor body has system capability).
  // Environment variables are set at deploy time, so this is safe.
  transient let network : Network = do {
    switch (Prim.envVar<system>("BITCOIN_NETWORK")) {
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

  transient let bitcoinCanisterId : Text = switch (network) {
    case (#mainnet) "ghsi2-tqaaa-aaaan-aaaca-cai";
    case _ "g4xu7-jiaaa-aaaan-aaaaq-cai";
  };

  transient let networkText : Text = switch (network) {
    case (#mainnet) "mainnet";
    case (#testnet) "testnet";
    case (#regtest) "regtest";
  };

  private func getBitcoinCanister() : BitcoinCanister {
    actor (bitcoinCanisterId) : BitcoinCanister;
  };

  // Minimum cycles required for bitcoin_get_balance
  // (100M for mainnet, 40M for testnet/regtest).
  // See https://docs.internetcomputer.org/references/bitcoin-how-it-works
  transient let getBalanceCost : Nat = switch (network) {
    case (#mainnet) 100_000_000;
    case _ 40_000_000;
  };

  /// Get the balance of a Bitcoin address in satoshis.
  public func get_balance(address : BitcoinAddress) : async Satoshi {
    await (with cycles = getBalanceCost) getBitcoinCanister().bitcoin_get_balance({
      address;
      network;
      min_confirmations = null;
    });
  };

  /// Get the canister's Bitcoin configuration.
  public query func get_config() : async BitcoinConfig {
    {
      network = networkText;
      bitcoin_canister_id = bitcoinCanisterId;
    };
  };
};
