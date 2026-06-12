# Shared test steps for the template testing pipeline.
# Sourced by run.sh; runs inside the test container (see tests/Dockerfile).

# Repo root as mounted into the container (read-only).
REPO="${REPO:-/repo}"
GATEWAY_PORT=8000
CONFIG="${CONFIG:-$(dirname "${BASH_SOURCE[0]}")/matrix.yaml}"

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

# call_check <canister-name> <method> <args> <expected-substring>
call_check() {
  local canister="$1" method="$2" args="$3" expect="$4" reply
  step "call: icp canister call $canister $method '$args'"
  reply="$(icp canister call "$canister" "$method" "$args")" \
    || fail "icp canister call failed"
  printf '%s\n' "$reply"
  printf '%s' "$reply" | grep -qF "$expect" \
    || fail "expected reply to contain '$expect', got: $reply"
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

# verify_canisters <template> <project-name>
# Runs the checks configured in matrix.yaml for each of the template's
# canisters: a gateway curl if `curl: true`, a canister call if `call` is
# configured (both, if both are present).
verify_canisters() {
  local template="$1" project="$2"
  local base count i name
  count="$(yq -r ".templates.\"$template\".canisters | length" "$CONFIG")"
  [ "$count" -gt 0 ] 2>/dev/null \
    || fail "no canister checks configured for template '$template' in $CONFIG"

  for ((i = 0; i < count; i++)); do
    base=".templates.\"$template\".canisters[$i]"
    name="$(yq -r "$base.name" "$CONFIG")"
    [ -n "$name" ] && [ "$name" != "null" ] \
      || fail "canister #$i of template '$template' has no name in $CONFIG"
    name="${name//"{{project-name}}"/$project}"

    if [ "$(yq -r "$base.curl // false" "$CONFIG")" = "true" ]; then
      http_check "$name"
    fi
    if [ "$(yq -r "$base.call" "$CONFIG")" != "null" ]; then
      call_check "$name" \
        "$(yq -r "$base.call.method" "$CONFIG")" \
        "$(yq -r "$base.call.args" "$CONFIG")" \
        "$(yq -r "$base.call.expect" "$CONFIG")"
    fi
  done
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
    verify_canisters "$template" "$project"
  ) || rc=$?

  icp network stop --project-root-override "$dir/$project" >/dev/null 2>&1 || true
  return $rc
}
