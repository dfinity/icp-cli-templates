# Vendored asset canister

`assetstorage.wasm.gz` is the prebuilt **asset canister** module that serves the
Blazor frontend. It is checked in so `icp build` / `icp deploy` never has to
download it:

| | |
|---|---|
| Source | `https://github.com/dfinity/sdk/releases/download/0.32.0/assetstorage.wasm.gz` (dfx release 0.32.0) |
| Size | 465,172 bytes |
| sha256 | `04e565b3425fe7510ee16b02adcfe3f01abc9a2725c82a21cb08969241debd62` |

## Why it is vendored

`frontend/canister.yaml` used to use the `@dfinity/asset-canister@v2.2.1` recipe.
That recipe's build step fetches the module from
`https://github.com/dfinity/sdk/releases/latest/download/assetstorage.wasm.gz`
and does **not** supply a `sha256`, and icp-cli only caches a remote WASM when a
checksum is given (`Remote without sha256: always downloads`). Every deploy
therefore re-downloaded ~465 KB through GitHub's `releases/latest` redirect. When
that request failed at the transport level (reset/TLS/DNS/timeout) the build
aborted with:

```
[frontend] ✘ Failed to build canister: failed to fetch wasm file
```

Keeping the module in the repository makes the build hermetic: the
`pre-built` step reads it from disk, verifies the checksum above, and no network
access is needed for the canister WASM.

## Refreshing the module

Pick a dfx release tag from <https://github.com/dfinity/sdk/releases>, download
it and update `sha256` in `frontend/canister.yaml`:

```bash
cd frontend
curl -sL -o vendor/assetstorage.wasm.gz \
  https://github.com/dfinity/sdk/releases/download/<DFX_VERSION>/assetstorage.wasm.gz
sha256sum vendor/assetstorage.wasm.gz   # copy this into canister.yaml
```

If the checksum in `canister.yaml` does not match the file, the build fails with
`checksum mismatch, expected: ..., actual: ...`.
