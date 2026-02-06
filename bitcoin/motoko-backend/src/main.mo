/// Bitcoin Integration Example
///
/// This canister demonstrates basic Bitcoin integration on the Internet Computer.
/// It provides functions to:
/// - Check Bitcoin balance for any address
/// - Get UTXOs (Unspent Transaction Outputs) for any address
/// - Get current fee percentiles

import Prim "mo:⛔";
import Text "mo:core/Text";

persistent actor Backend {
  // Types from the management canister Bitcoin API
  public type Satoshi = Nat64;
  public type MillisatoshiPerVByte = Nat64;
  public type BitcoinAddress = Text;

  public type Network = {
    #mainnet;
    #testnet;
    #regtest;
  };

  public type Outpoint = {
    txid : Blob;
    vout : Nat32;
  };

  public type Utxo = {
    outpoint : Outpoint;
    value : Satoshi;
    height : Nat32;
  };

  public type GetUtxosResponse = {
    utxos : [Utxo];
    tip_block_hash : Blob;
    tip_height : Nat32;
    next_page : ?Blob;
  };

  public type BitcoinInfo = {
    network : Text;
  };

  // Management canister interface for Bitcoin
  let management_canister : actor {
    bitcoin_get_balance : shared {
      address : BitcoinAddress;
      network : Network;
      min_confirmations : ?Nat32;
    } -> async Satoshi;

    bitcoin_get_utxos : shared {
      address : BitcoinAddress;
      network : Network;
      filter : ?{ #min_confirmations : Nat32; #page : Blob };
    } -> async GetUtxosResponse;

    bitcoin_get_current_fee_percentiles : shared {
      network : Network;
    } -> async [MillisatoshiPerVByte];
  } = actor ("aaaaa-aa");

  /// Get the Bitcoin network from the BITCOIN_NETWORK environment variable.
  private func getNetwork() : Network {
    switch (Prim.envVar<system>("BITCOIN_NETWORK")) {
      case (?value) {
        let networkStr = Text.toLower(value);
        switch (networkStr) {
          case ("mainnet") #mainnet;
          case ("testnet") #testnet;
          case _ #regtest;
        };
      };
      case null #regtest;
    };
  };

  /// Get the balance of a Bitcoin address in satoshis.
  public func get_balance(address : BitcoinAddress) : async Satoshi {
    await management_canister.bitcoin_get_balance({
      address;
      network = getNetwork();
      min_confirmations = null;
    });
  };

  /// Get the UTXOs for a Bitcoin address.
  public func get_utxos(address : BitcoinAddress) : async GetUtxosResponse {
    await management_canister.bitcoin_get_utxos({
      address;
      network = getNetwork();
      filter = null;
    });
  };

  /// Get the current Bitcoin fee percentiles.
  public func get_fee_percentiles() : async [MillisatoshiPerVByte] {
    await management_canister.bitcoin_get_current_fee_percentiles({
      network = getNetwork();
    });
  };

  /// Get information about the Bitcoin canister configuration.
  public query func get_bitcoin_info() : async BitcoinInfo {
    let network = getNetwork();
    let networkText = switch (network) {
      case (#mainnet) "Mainnet";
      case (#testnet) "Testnet";
      case (#regtest) "Regtest";
    };
    { network = networkText };
  };

  /// Simple greeting function to verify the canister is working.
  public query func greet(name : Text) : async Text {
    "Hello, " # name # "! This canister supports Bitcoin integration.";
  };
};
