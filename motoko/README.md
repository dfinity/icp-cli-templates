# ICP Motoko Recipe Example

This example demonstrates how to use the built-in `motoko` recipe type to build Motoko canisters.

## Overview

The `motoko` recipe type provides a streamlined way to build Motoko canisters using the Motoko compiler (`moc`). This is one of the built-in recipe types provided by ICP-CLI for common canister development workflows.

## Configuration

The [`icp.yaml`](./icp.yaml) file configures a canister using the latest `motoko` recipe:

```yaml
canisters:
  - name: {{project-name}}
    recipe:
      type: "@dfinity/motoko"
      configuration:
        main: src/main.mo
        args: --incremental-gc
        # optional
        candid: {{project-name}}.did
```

### Key Components

- **`type: motoko`**: Uses the Motoko recipe type
- **`entry`**: Specifies the main Motoko source file (defaults to `main.mo` if not provided)

## Source Code

The [`src/main.mo`](./src/main.mo) file contains the Motoko canister implementation. This is the entry point that gets compiled by the `moc` compiler.

## How It Works

1. ICP-CLI uses the built-in `motoko` recipe resolver this depends on [mops](https://cli.mops.one/), the Motoko package manager.
2. The recipe is expanded into build steps that:
   - check if mops is installed
   - use the correct motoko toolchain to build the canister
3. Once the canister is built, it is ready for deployment

## Prerequisites

- Make sure you've followed the instructions to install [mops](https://cli.mops.one/) and
that the mops toolchain has been initialized: `mops toolchain init`

## Use Cases

- Standard Motoko canister development
- Simple build workflows for Motoko projects
- Projects that don't require custom build logic

## Run it

```
# Start a local network
icp network start --background

# Build and deploy the canister
icp deploy

# make a call the canister
icp canister call {{project-name}} greet '("Internet Computer")'

# Stop the network
icp network stop
```
