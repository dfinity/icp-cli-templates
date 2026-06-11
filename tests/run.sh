#!/usr/bin/env bash
# In-container entrypoint for the template testing pipeline.
# See docs/template-testing-prd.md. M1: a single hardcoded permutation
# (rust template, default arguments). The full matrix arrives in M2.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TEMPLATE=rust
PROJECT=e2e-rust

WORKDIR="$(mktemp -d)"
cleanup() {
  network_stop
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

prepare_template_source "$WORKDIR/template-src"

cd "$WORKDIR"
render "$TEMPLATE" "$PROJECT" -d network_type=Default

cd "$PROJECT"
backend="$(first_canister_name .)"

build
network_start
deploy
call_greet "$backend"

printf '\nPASS: %s (%s)\n' "$TEMPLATE" "$PROJECT"
