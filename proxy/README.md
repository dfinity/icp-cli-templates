# ICP Proxy Canister

This template deploys a [proxy canister](https://github.com/dfinity/proxy-canister) to ICP.

## What Is a Proxy Canister?

A proxy canister forwards calls from agents or other canisters to target canisters.
It enables invoking canister methods that are:

- Accessible only to other canisters (not directly callable by agents)
- Require cycles payment for execution

On a managed local network, a proxy canister is provided automatically. On connected networks like `ic`, you need to deploy one yourself.

This template makes it easy to deploy your own proxy canister to `ic` (and other connected networks) so that other projects can route calls through it.

## Deploy to IC

```bash
# Deploy the proxy canister to the IC mainnet
icp deploy -e ic

# Get the canister ID
icp canister status -e ic --id-only proxy
```

Export the canister ID as an environment variable for use in other projects:

```bash
export PROXY_ID=$(icp canister status -e ic --id-only proxy)
```

## Use the Proxy in Another Project

In any other `icp` project that needs proxied canister calls, pass the canister ID via the `--proxy` flag:

```bash
icp canister call --proxy "$PROXY_ID" -e ic ...
```
