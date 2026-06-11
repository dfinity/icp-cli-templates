# Template tests

End-to-end tests that verify every template in this repo renders, builds,
deploys, and serves traffic. For each permutation in
[`matrix.yaml`](./matrix.yaml) the harness:

1. renders the template from the local checkout with `icp new` (the same code
   path end users take),
2. asserts the rendered layout (directory renames, agent files),
3. runs `icp build`,
4. starts a local network (`icp network start -d`),
5. runs `icp deploy`,
6. runs the checks configured per canister in `matrix.yaml`: canister calls
   with an expected reply, and/or a curl through the gateway
   (`http://<canister-name>.local.localhost:8000/`, pinned to `127.0.0.1`
   via `curl --resolve`, expecting HTTP 200),
7. stops the network and cleans up.

Tests always run inside a container, against the `icp` CLI pinned in the
image — the host only needs Docker. They run directly on
[`ghcr.io/dfinity/icp-dev-env-all`](https://github.com/dfinity/icp-dev-env)
(tag pinned in the [`Makefile`](../Makefile)), which provides the icp CLI,
Rust + wasm32 target, mops, and Node.js. The harness installs `yq` at
startup if the image doesn't have it yet.

## Running

```bash
# everything
make test

# a subset, by permutation-id prefix
make test FILTER=hello-world
make test FILTER=hello-world:rust:react

# debugging: shell into the image and drive the harness manually
docker run --rm -it -v "$PWD":/repo:ro ghcr.io/dfinity/icp-dev-env-all:0.3.2 bash
$ /repo/tests/run.sh --fail-fast hello-world
```

Permutations run sequentially in one container; the full suite takes a few
minutes. Local runs mount named volumes for the cargo/npm/mops caches, so
repeated runs skip re-downloading dependencies.

The repo is mounted read-only and the harness copies only files git would
track (tracked + untracked-but-not-ignored), so uncommitted template changes
are tested while local build artifacts (`target/`, `node_modules/`) are not.

## Adding a template or permutation

Everything is configured in [`matrix.yaml`](./matrix.yaml). Each template
entry declares:

- `permutations` — variable sets passed to `icp new` as `--define` (an empty
  entry `{}` renders with the template defaults). Each one gets a test run;
  the permutation id used for filtering and reporting is the template name
  plus the values, e.g. `hello-world:motoko:react`.
- `canisters` — what to verify after deploy, per canister: `curl: true` for
  an HTTP 200 check through the gateway, and/or `call` with `method`, `args`,
  and the `expect`-ed reply substring. A `name` of `{{project-name}}` is
  replaced with the rendered project's name (for templates whose `icp.yaml`
  uses that placeholder).

## CI

[`test-templates.yml`](../.github/workflows/test-templates.yml) runs the full
suite as a single sequential job on every pull request and on pushes to
`main`. If the matrix grows enough that this is too slow, split it into a job
matrix using the `FILTER` argument — the harness needs no changes.
