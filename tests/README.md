# Template tests

End-to-end tests that verify every template in this repo renders, builds,
deploys, and serves traffic. For each permutation in [`matrix.txt`](./matrix.txt)
the harness:

1. renders the template from the local checkout with `icp new` (the same code
   path end users take),
2. asserts the rendered layout (directory renames, agent files),
3. runs `icp build`,
4. starts a local network (`icp network start -d`),
5. runs `icp deploy`,
6. calls `greet` on every backend canister and curls every asset canister
   through the gateway (`http://<canister-name>.local.localhost:8000/`,
   pinned to `127.0.0.1` via `curl --resolve`),
7. stops the network and cleans up.

Tests always run inside a container, against the `icp` CLI pinned in the
image — the host only needs Docker. The image
([`Dockerfile`](./Dockerfile)) is a thin layer over
[`ghcr.io/dfinity/icp-dev-env-all`](https://github.com/dfinity/icp-dev-env),
which provides the icp CLI, Rust + wasm32 target, mops, and Node.js.

## Running

```bash
# everything
make test

# a subset, by permutation-id prefix
make test FILTER=hello-world
make test FILTER=hello-world:rust:react

# debugging: shell into the image and drive the harness manually
docker run --rm -it -v "$PWD":/repo:ro icp-template-tests bash
$ /repo/tests/run.sh --fail-fast hello-world
```

Permutations run sequentially in one container; the full suite takes a few
minutes. Local runs mount named volumes for the cargo/npm/mops caches, so
repeated runs skip re-downloading dependencies.

The repo is mounted read-only and the harness copies only files git would
track (tracked + untracked-but-not-ignored), so uncommitted template changes
are tested while local build artifacts (`target/`, `node_modules/`) are not.

## Adding a permutation

Add a line to [`matrix.txt`](./matrix.txt):

```
<template> [key=value ...]
```

`key=value` pairs are passed to `icp new` as `--define`; omitted template
variables fall back to their defaults. The permutation id used for filtering
and reporting is the template name plus the values, e.g.
`hello-world:motoko:react`.

## CI

[`test-templates.yml`](../.github/workflows/test-templates.yml) runs the full
suite as a single sequential job on every pull request and on pushes to
`main`. If the matrix grows enough that this is too slow, split it into a job
matrix using the `FILTER` argument — the harness needs no changes.
