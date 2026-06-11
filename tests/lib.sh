# Shared test steps for the template testing pipeline.
# Sourced by run.sh; runs inside the test container (see tests/Dockerfile).

# Repo root as mounted into the container (read-only).
REPO="${REPO:-/repo}"
GATEWAY_PORT=8000

# Never send icp telemetry from test runs (also set in tests/Dockerfile, but
# exported here so it holds however the harness is invoked).
export DO_NOT_TRACK=1

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

# first_canister_name <project-dir>
# Reads the first canister's name from the rendered icp.yaml. Entries are
# either inline objects (`name: backend`) or paths to canister.yaml files.
first_canister_name() {
  local dir="$1" entry
  entry="$(yq -r '.canisters[0]' "$dir/icp.yaml")"
  if [ "$(yq -r '.canisters[0] | type' "$dir/icp.yaml")" = "!!map" ]; then
    yq -r '.canisters[0].name' "$dir/icp.yaml"
  else
    yq -r '.name' "$dir/$entry/canister.yaml"
  fi
}
