#!/usr/bin/env bash
# In-container entrypoint for the template testing pipeline.
# See docs/template-testing-prd.md.
#
# Usage: run.sh [--fail-fast] [FILTER ...]
#   FILTER matches permutation ids by prefix, e.g. `hello-world` or
#   `hello-world:rust:react`. With no filter, the whole matrix runs.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
MATRIX_FILE="$(dirname "${BASH_SOURCE[0]}")/matrix.txt"

FAIL_FAST=0
FILTERS=()
for arg in "$@"; do
  case "$arg" in
    --fail-fast) FAIL_FAST=1 ;;
    -*) fail "unknown option: $arg" ;;
    *) FILTERS+=("$arg") ;;
  esac
done

matches_filter() {
  local id="$1" f
  [ ${#FILTERS[@]} -eq 0 ] && return 0
  for f in "${FILTERS[@]}"; do
    [[ "$id" == "$f" || "$id" == "$f":* ]] && return 0
  done
  return 1
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

ensure_yq
prepare_template_source "$WORKDIR/template-src"

RESULTS=()
overall=0
ran=0

while read -r template defines; do
  [[ -z "$template" || "$template" == \#* ]] && continue

  read -ra define_args <<<"${defines:-}"
  id="$template"
  for kv in ${define_args[@]+"${define_args[@]}"}; do
    id+=":${kv#*=}"
  done

  matches_filter "$id" || continue
  ran=$((ran + 1))

  printf '\n========== %s ==========\n' "$id"
  start="$(date +%s)"
  if run_permutation "$id" "$template" ${define_args[@]+"${define_args[@]}"}; then
    RESULTS+=("PASS  $id  ($(($(date +%s) - start))s)")
  else
    RESULTS+=("FAIL  $id  ($(($(date +%s) - start))s)")
    overall=1
    [ "$FAIL_FAST" -eq 1 ] && break
  fi
done <"$MATRIX_FILE"

[ "$ran" -gt 0 ] || fail "no permutations matched filter: ${FILTERS[*]:-<none>}"

printf '\n========== summary ==========\n'
printf '%s\n' "${RESULTS[@]}"
exit "$overall"
