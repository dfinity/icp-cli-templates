# ICP Motoko Recipe Example

This example demonstrates how to use the built-in `motoko` recipe type to build Motoko canisters.

## Overview

The `motoko` recipe type provides a streamlined way to build Motoko canisters using the Motoko compiler (`moc`). This is one of the built-in recipe types provided by ICP-CLI for common canister development workflows.

## Configuration

The [`icp.yaml`](./icp.yaml) file configures a canister using the `motoko` recipe:

```yaml
canisters:
  - name: {{project-name}}
    recipe:
      type: "@dfinity/motoko@<version>"
      configuration:
        main: src/main.mo
        # optional
        candid: {{project-name}}.did
```

### Key Components

- **`type: "@dfinity/motoko@<version>"`**: Uses the Motoko recipe type. See [available versions](https://github.com/dfinity/icp-cli-recipes/releases?q=motoko&expanded=true).
- **`main`**: Specifies the main Motoko source file (defaults to `main.mo` if not provided)

## Source Code

The [`src/main.mo`](./src/main.mo) file contains the Motoko canister implementation. This is the entry point that gets compiled by the `moc` compiler.

## How It Works

1. ICP-CLI uses the built-in `motoko` recipe resolver. This depends on [mops](https://cli.mops.one/), the Motoko package manager.
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

## Run It

```bash
# Start a local network
icp network start -d

# Build and deploy the canister
icp deploy

# Call the canister
icp canister call {{project-name}} greet '("Internet Computer")'

# Stop the network
icp network stop
```
