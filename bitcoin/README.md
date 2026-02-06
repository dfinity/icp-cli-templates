# Bitcoin Integration Template

This template demonstrates the full Bitcoin integration on the Internet Computer:

- **Derive a Bitcoin address** controlled by the canister via threshold ECDSA (tECDSA)
- **Receive Bitcoin** by mining to the canister's address (on regtest)
- **Send Bitcoin** to any address
- **Query balances and UTXOs**

## Prerequisites

- [icp-cli](https://github.com/dfinity/icp-cli) installed
- [Docker](https://docs.docker.com/get-docker/) installed and running

## Step 1: Create and Deploy

Create a new project from this template, start the local network, and deploy:

```bash
icp new my-bitcoin-project --template bitcoin
cd my-bitcoin-project
icp network start
icp build && icp deploy
```

This starts a local Bitcoin regtest node and an IC replica with Bitcoin integration via Docker Compose.

## Step 2: Get the Canister's Bitcoin Address

The canister derives a P2WPKH Bitcoin address from its threshold ECDSA key:

```bash
icp canister call backend get_canister_btc_address '()'
```

This returns a `bcrt1q...` address (regtest SegWit format). Save it for the next steps:

```bash
CANISTER_BTC_ADDR=$(icp canister call backend get_canister_btc_address '()' | grep -o '"[^"]*"' | tr -d '"')
echo "$CANISTER_BTC_ADDR"
```

## Step 3: Fund the Canister (Mine Blocks)

On regtest, you fund addresses by mining blocks to them. Bitcoin requires **100 confirmations** before coinbase rewards are spendable, so mine 101 blocks:

```bash
docker compose -p icp-local exec bitcoind \
  bitcoin-cli -regtest \
  -rpcuser=ic-btc-integration -rpcpassword=ic-btc-integration \
  generatetoaddress 101 "$CANISTER_BTC_ADDR"
```

> **Note:** `icp network start` runs the compose project under the name `icp-local`, so use `-p icp-local` instead of `-f docker-compose.bitcoin.yml` when interacting with running services.

This gives the canister 50 BTC (the block reward from the first block, now mature after 100 confirmations).

## Step 4: Check the Balance

Query the canister's balance (in satoshis):

```bash
icp canister call backend get_balance "(\"$CANISTER_BTC_ADDR\")"
```

You should see `5_000_000_000` (50 BTC = 5 billion satoshis).

You can also view the UTXOs:

```bash
icp canister call backend get_utxos "(\"$CANISTER_BTC_ADDR\")"
```

## Step 5: Transfer BTC

Create a wallet in bitcoind, generate a destination address, and transfer BTC to it:

```bash
# Create a wallet in bitcoind (needed once, Bitcoin Core doesn't auto-create one)
docker compose -p icp-local exec bitcoind \
  bitcoin-cli -regtest \
  -rpcuser=ic-btc-integration -rpcpassword=ic-btc-integration \
  createwallet "default"

# Create a destination address
DEST_ADDR=$(docker compose -p icp-local exec bitcoind \
  bitcoin-cli -regtest \
  -rpcuser=ic-btc-integration -rpcpassword=ic-btc-integration \
  getnewaddress)

# Transfer 1 BTC (100,000,000 satoshis)
icp canister call backend transfer_btc \
  "(record { destination = \"$DEST_ADDR\"; amount_in_satoshi = 100_000_000 : nat64 })"
```

This returns the transaction ID.

## Step 6: Confirm and Verify

Mine a block to confirm the transaction:

```bash
docker compose -p icp-local exec bitcoind \
  bitcoin-cli -regtest \
  -rpcuser=ic-btc-integration -rpcpassword=ic-btc-integration \
  generatetoaddress 1 "$CANISTER_BTC_ADDR"
```

Check the updated balances:

```bash
# Canister balance (should be reduced by ~1 BTC + fee)
icp canister call backend get_balance "(\"$CANISTER_BTC_ADDR\")"

# Destination balance
icp canister call backend get_balance "(\"$DEST_ADDR\")"
```

## Canister API

| Function | Type | Description |
|----------|------|-------------|
| `get_canister_btc_address` | update | Returns a Bitcoin address controlled by the canister |
| `get_balance(address)` | update | Returns the balance in satoshis |
| `get_utxos(address)` | update | Returns the UTXOs for an address |
| `get_fee_percentiles` | update | Returns current fee percentiles (millisatoshi/vbyte) |
| `transfer_btc({destination, amount_in_satoshi})` | update | Sends BTC and returns the transaction ID |
| `get_bitcoin_info` | query | Returns the configured Bitcoin network |

## Configuration

### Network Configuration

The `icp.yaml` defines the local network using Docker Compose:

```yaml
networks:
  - name: local
    mode: managed
    compose:
      file: docker-compose.bitcoin.yml
      gateway-service: icp-network
```

This tells icp-cli to use Docker Compose to manage the local network, starting both the Bitcoin regtest node and the IC replica together.

### Bitcoin Network Selection

The backend canister reads the `BITCOIN_NETWORK` environment variable to determine which Bitcoin network to use:

- `regtest` (default) — Local regtest network via Docker Compose
- `testnet` — Bitcoin testnet
- `mainnet` — Bitcoin mainnet

The environment variable is configured in the environments section of `icp.yaml`:

```yaml
environments:
  - name: local
    network: local
    settings:
      backend:
        environment_variables:
          BITCOIN_NETWORK: "regtest"
```

## Project Structure

```
.
├── icp.yaml                    # Project configuration
├── docker-compose.bitcoin.yml  # Local Bitcoin + IC network setup
├── backend/
│   ├── canister.yaml           # Canister build configuration
│   ├── src/
│   │   └── lib.rs              # Backend canister code
│   └── backend.did             # Candid interface
└── README.md
```

## Learn More

- [Internet Computer Bitcoin Integration](https://internetcomputer.org/docs/building-apps/bitcoin/overview)
- [icp-cli Documentation](https://github.com/dfinity/icp-cli)
- [Bitcoin Regtest Mode](https://developer.bitcoin.org/examples/testing.html)
