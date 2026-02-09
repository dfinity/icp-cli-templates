# Bitcoin Integration Template

Demonstrates reading Bitcoin balance from a canister on the Internet Computer using the [Bitcoin canister API](https://github.com/dfinity/bitcoin-canister/blob/master/INTERFACE_SPECIFICATION.md).

## Bitcoin Canister IDs

| IC Network | Bitcoin Network | Bitcoin Canister ID |
|------------|----------------|---------------------|
| Local (PocketIC) | regtest | `g4xu7-jiaaa-aaaan-aaaaq-cai` |
| IC mainnet | testnet | `g4xu7-jiaaa-aaaan-aaaaq-cai` |
| IC mainnet | mainnet | `ghsi2-tqaaa-aaaan-aaaca-cai` |

The `BITCOIN_NETWORK` environment variable controls which network and canister to use. It is configured per environment in `icp.yaml`.

## Prerequisites

- [icp-cli](https://github.com/dfinity/icp-cli) installed
- [Docker](https://docs.docker.com/get-docker/) installed and running (optional, but recommended)

> **Note:** Docker is used in this guide to run `bitcoind` for simplicity. If you prefer, you can install and run `bitcoind` natively instead — just make sure it is listening on the same ports (`18443` for RPC, `18444` for P2P) with the same credentials.

## Getting Started

Start a Bitcoin regtest node:

```bash
docker run -d --name bitcoind \
  -p 18443:18443 -p 18444:18444 \
  lncm/bitcoind:v27.2 \
  -regtest -server -rpcbind=0.0.0.0 -rpcallowip=0.0.0.0/0 \
  -rpcuser=ic-btc-integration -rpcpassword=ic-btc-integration \
  -fallbackfee=0.00001 -txindex=1
```

Start the local IC network and deploy:

```bash
icp network start -d
icp deploy
```

## Usage

Verify the configured network and Bitcoin canister ID:

```bash
icp canister call backend get_config '()'
```

Create a wallet and get a Bitcoin address:

```bash
docker exec bitcoind bitcoin-cli -regtest \
  -rpcuser=ic-btc-integration -rpcpassword=ic-btc-integration \
  createwallet "default"

ADDR=$(docker exec bitcoind bitcoin-cli -regtest \
  -rpcuser=ic-btc-integration -rpcpassword=ic-btc-integration \
  getnewaddress)
```

Check the balance (should be 0):

```bash
icp canister call backend get_balance "(\"$ADDR\")"
```

Mine a block to the address (each block rewards 50 BTC):

```bash
docker exec bitcoind bitcoin-cli -regtest \
  -rpcuser=ic-btc-integration -rpcpassword=ic-btc-integration \
  generatetoaddress 1 "$ADDR"
```

Check the balance again (should be 5,000,000,000 satoshis = 50 BTC):

> **Note:** Coinbase rewards require 100 confirmations before they can be spent. If you extend this example to send transactions, mine at least 101 blocks so the first block's reward becomes spendable.

```bash
icp canister call backend get_balance "(\"$ADDR\")"
```

## Cleanup

```bash
icp network stop
docker stop bitcoind && docker rm bitcoind
```

## Environments

| Environment | IC Network | Bitcoin Network | Usage |
|-------------|-----------|----------------|-------|
| `local` | Local (PocketIC) | regtest | `icp deploy` |
| `staging` | IC mainnet | testnet | `icp deploy --env staging` |
| `production` | IC mainnet | mainnet | `icp deploy --env production` |

## Cycle Costs

Bitcoin canister API calls require cycles. The canister must attach cycles when calling the Bitcoin canister — the Rust CDK handles this automatically, while the Motoko backend attaches them explicitly via `(with cycles = amount)`.

| API Call | Testnet / Regtest | Mainnet |
|----------|-------------------|---------|
| `bitcoin_get_balance` | 40,000,000 | 100,000,000 |
| `bitcoin_get_utxos` | 4,000,000,000 | 10,000,000,000 |
| `bitcoin_send_transaction` | 2,000,000,000 | 5,000,000,000 |

See [Bitcoin API costs](https://docs.internetcomputer.org/references/bitcoin-how-it-works) for the full reference.

## Learn More

- [Bitcoin Canister API Specification](https://github.com/dfinity/bitcoin-canister/blob/master/INTERFACE_SPECIFICATION.md) — full API reference (get_utxos, send_transaction, fee percentiles, etc.)
- [Internet Computer Bitcoin Integration](https://internetcomputer.org/docs/building-apps/bitcoin/overview)
- [icp-cli Documentation](https://github.com/dfinity/icp-cli)
