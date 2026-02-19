# ICP Static Website Example

This example demonstrates how to deploy a static website to ICP using the `asset-canister` recipe.

## Overview

The `asset-canister` recipe makes it easy to deploy a canister hosting static assets.

## Configuration

The [`icp.yaml`](./icp.yaml) file configures a canister using the `asset-canister` recipe:

```yaml
canisters:
  - name: frontend
    recipe:
      type: "@dfinity/asset-canister@<version>"
      configuration:
        build:
          - npm run build
        dir: dist
```

### Key Components

- **`type: "@dfinity/asset-canister@<version>"`**: Uses the asset-canister recipe for hosting static files. See [available versions](https://github.com/dfinity/icp-cli-recipes/releases?q=asset-canister&expanded=true).
- **`build`**: Specifies the build commands to run before uploading assets
- **`dir`**: Specifies the directory containing the built assets to upload

## Project Structure

- [`package.json`](./package.json): npm package configuration with build scripts
- [`src/index.html`](./src/index.html): HTML entry point for the website
- [`src/main.ts`](./src/main.ts): TypeScript entry point
- [`src/style.css`](./src/style.css): CSS styles
- [`public/`](./public/): Static assets served as-is
- [`vite.config.ts`](./vite.config.ts): Vite build configuration

## How It Works

1. ICP-CLI uses the `asset-canister` recipe to expand the build and sync steps of the canister.
2. The build command (`npm run build`) uses Vite to compile and bundle assets into the `dist` directory.
3. The asset canister is deployed.
4. The contents of the `dist` directory are synchronized to the asset canister.

## Prerequisites

- [Node.js](https://nodejs.org/)
- [npm](https://docs.npmjs.com/)

## Use Cases

- Static websites and landing pages
- Single-page applications (SPAs)
- Frontend applications built with Vite
- Projects that don't require a backend canister

## Run It

```bash
# Install dependencies:
# Vite is required for this example to bundle assets
npm ci

# Start a local network
icp network start -d

# Build and deploy the canister
icp deploy

# Open the deployed frontend in a browser using the canister ID from the output of
# `icp deploy`: http://<frontend_canister_id>.localhost:8000/

# Stop the network
icp network stop
```

