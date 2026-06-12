#!/usr/bin/env bash
# In-container entrypoint for the template testing pipeline.
# See docs/template-testing-prd.md.
#
# Usage: run.sh [--fail-fast] [FILTER ...]
#   FILTER matches permutation ids by prefix, e.g. `hello-world` or
#   `hello-world:rust:react`. With no filter, the whole matrix runs.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

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
done_loop=0

while IFS= read -r template; do
  [ "$done_loop" -eq 1 ] && break
  pcount="$(yq -r ".templates.\"$template\".permutations | length" "$CONFIG")"
  [ "$pcount" -gt 0 ] 2>/dev/null \
    || fail "template '$template' has no permutations in $CONFIG"

  for ((p = 0; p < pcount; p++)); do
    define_args=()
    while IFS= read -r kv; do
      [ -n "$kv" ] && define_args+=("$kv")
    done < <(yq -r ".templates.\"$template\".permutations[$p] | to_entries | .[] | .key + \"=\" + .value" "$CONFIG")

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
      [ "$FAIL_FAST" -eq 1 ] && { done_loop=1; break; }
    fi
  done
done < <(yq -r '.templates | keys | .[]' "$CONFIG")

[ "$ran" -gt 0 ] || fail "no permutations matched filter: ${FILTERS[*]:-<none>}"

printf '\n========== summary ==========\n'
printf '%s\n' "${RESULTS[@]}"
exit "$overall"
