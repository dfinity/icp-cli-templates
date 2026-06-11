# Shared test steps for the template testing pipeline.
# Sourced by run.sh; runs inside the test container (see tests/Dockerfile).

# Repo root as mounted into the container (read-only).
REPO="${REPO:-/repo}"
GATEWAY_PORT=8000

# Never send icp telemetry from test runs.
export DO_NOT_TRACK=1

# The container runs as root but doesn't set $USER, which cargo-generate
# (inside `icp new`) requires.
export USER="${USER:-root}"

# Stopgap until ghcr.io/dfinity/icp-dev-env-all ships yq: install it at
# startup. Becomes a no-op once the base image includes it.
YQ_VERSION=v4.53.3
ensure_yq() {
  command -v yq >/dev/null && return 0
  step "setup: installing yq $YQ_VERSION"
  curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_$(dpkg --print-architecture)" \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    || fail "could not install yq"
}

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# prepare_template_source <dest-dir>
# Copies the repo into <dest-dir>, restricted to files git would track
# (tracked + untracked-but-not-ignored). Local build artifacts in template
# dirs (target/, node_modules/, ...) would otherwise be copied and
# template-substituted by cargo-generate, which is slow and fails on
# binaries. Sets TEMPLATE_SRC.
prepare_template_source() {
  TEMPLATE_SRC="$1"
  mkdir -p "$TEMPLATE_SRC"
  # The repo bind-mount is owned by the host user; git refuses to read it
  # from a different uid without this.
  git config --global --add safe.directory "$REPO"
  (cd "$REPO" && git ls-files --cached --others --exclude-standard -z \
    | tar --null --ignore-failed-read -cf - -T -) \
    | tar -xf - -C "$TEMPLATE_SRC" \
    || fail "could not copy template source from $REPO"
}

# render <template> <project-name> [-d key=value ...]
# Renders the template from the clean copy of the local checkout via
# `icp new` — the same code path end users take — into the current directory.
render() {
  local template="$1" project="$2"
  shift 2
  step "render: icp new $project --subfolder $template $*"
  icp new "$project" --path "$TEMPLATE_SRC" --subfolder "$template" --silent "$@" \
    || fail "icp new failed for template '$template'"

  [ -f "$project/icp.yaml" ] || fail "rendered project is missing icp.yaml"
  [ -f "$project/AGENTS.md" ] || fail "rendered project is missing AGENTS.md (post-hook)"
  [ -f "$project/CLAUDE.md" ] || fail "rendered project is missing CLAUDE.md (post-hook)"
}

# All remaining steps run from inside the rendered project directory.

build() {
  step "build: icp build"
  icp build || fail "icp build failed"
}

network_start() {
  step "network: icp network start -d"
  icp network start -d || fail "icp network start failed"
}

network_stop() {
  icp network stop >/dev/null 2>&1 || true
}

deploy() {
  step "deploy: icp deploy"
  icp deploy || fail "icp deploy failed"
}

# call_greet <canister-name>
call_greet() {
  local canister="$1" reply
  step "call: icp canister call $canister greet '(\"ICP\")'"
  reply="$(icp canister call "$canister" greet '("ICP")')" \
    || fail "icp canister call failed"
  printf '%s\n' "$reply"
  printf '%s' "$reply" | grep -qF 'Hello, ICP!' \
    || fail "unexpected greet reply: $reply"
}

# http_check <canister-name>
# Curls the asset canister root through the gateway using the name-based
# domain. --resolve is always used because *.localhost DNS resolution is not
# guaranteed inside containers.
http_check() {
  local canister="$1" host status
  host="$canister.local.localhost"
  step "http: curl http://$host:$GATEWAY_PORT/"
  status="$(curl -s -o /tmp/frontend-body -w '%{http_code}' \
    --resolve "$host:$GATEWAY_PORT:127.0.0.1" \
    "http://$host:$GATEWAY_PORT/")" \
    || fail "curl to $host failed"
  [ "$status" = "200" ] || fail "expected HTTP 200 from $host, got $status"
  [ -s /tmp/frontend-body ] || fail "frontend returned an empty body"
}

# canister_specs <project-dir>
# Prints one "name<TAB>recipe-type" line per canister in the rendered
# project. icp.yaml entries are either inline objects (`name: ...`) or paths
# to directories containing a canister.yaml.
canister_specs() {
  local dir="$1" count i entry
  count="$(yq -r '.canisters | length' "$dir/icp.yaml")"
  for ((i = 0; i < count; i++)); do
    if [ "$(yq -r ".canisters[$i] | type" "$dir/icp.yaml")" = "!!map" ]; then
      yq -r ".canisters[$i] | .name + \"\t\" + .recipe.type" "$dir/icp.yaml"
    else
      entry="$(yq -r ".canisters[$i]" "$dir/icp.yaml")"
      [ -f "$dir/$entry/canister.yaml" ] \
        || fail "icp.yaml references '$entry' but $entry/canister.yaml is missing"
      yq -r '.name + "\t" + .recipe.type' "$dir/$entry/canister.yaml"
    fi
  done
}

# verify_canisters <project-dir>
# Exercises every deployed canister: asset canisters get the HTTP check,
# everything else gets the greet call.
verify_canisters() {
  local dir="$1" name type
  while IFS=$'\t' read -r name type; do
    case "$type" in
      *asset-canister*) http_check "$name" ;;
      *) call_greet "$name" ;;
    esac
  done < <(canister_specs "$dir")
}

# assert_hello_world_layout <project-dir>
# The hello-world pre-hook renames the chosen variant dirs to backend/ and
# frontend/; the cargo-generate conditionals drop the unchosen ones.
assert_hello_world_layout() {
  local dir="$1" leftover
  [ -d "$dir/backend" ] || fail "hello-world: backend/ directory missing after render"
  [ -d "$dir/frontend" ] || fail "hello-world: frontend/ directory missing after render"
  for leftover in rust-backend motoko-backend react-frontend vue-frontend; do
    [ ! -e "$dir/$leftover" ] || fail "hello-world: unexpected leftover directory $leftover/"
  done
}

# run_permutation <id> <template> [key=value ...]
# Runs the full flow for one matrix entry in its own project dir under
# $WORKDIR. Always attempts to stop the permutation's network afterwards so
# sequential runs don't fight over the gateway port.
run_permutation() {
  local id="$1" template="$2"
  shift 2
  local project="e2e-$(printf '%s' "$id" | tr ':' '-')"
  local dir="$WORKDIR/$project" rc=0
  mkdir -p "$dir"

  (
    cd "$dir"
    local dargs=() kv
    for kv in "$@"; do dargs+=(-d "$kv"); done
    render "$template" "$project" "${dargs[@]}"
    [ "$template" = hello-world ] && assert_hello_world_layout "$project"
    cd "$project"
    build
    network_start
    deploy
    verify_canisters .
  ) || rc=$?

  icp network stop --project-root-override "$dir/$project" >/dev/null 2>&1 || true
  return $rc
}
