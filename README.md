# icp-cli-templates

Project templates to quickly get up and running building for the [Internet Computer](https://internetcomputer.org).

## Getting Started

Install [icp-cli](https://github.com/dfinity/icp-cli), then run:

```bash
# interactively select a template
icp new <project-name>

# use a specific template
icp new <project-name> --subfolder <template-name>
```

## Templates

| Template | Description |
| --- | --- |
| [motoko](./motoko/) | A basic Motoko canister |
| [rust](./rust/) | A basic Rust canister |
| [hello-world](./hello-world/) | Full-stack dapp with a frontend and backend canister (Rust or Motoko) |
| [static-website](./static-website/) | A static website deployed to an asset canister |

