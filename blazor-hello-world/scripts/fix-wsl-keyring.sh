#!/usr/bin/env bash
# Fix WSL "unlock keyring" freeze for icp-cli
# Symptom:
#   Error: failed to load identity
#     0: failed to load password from keyring entry
#     1: Secret Service: unlock prompt was dismissed
#   + frozen terminal titled "warn copy mode : unlock keyring (ubuntu)"
#
# Cause: icp-cli default --storage keyring uses Linux Secret Service (gnome-keyring).
# WSL has no GUI keyring daemon, so the unlock dialog freezes.
#
# This script creates a headless local identity that never touches the keyring.
# SAFE FOR LOCAL REPLICA ONLY (pocket-ic is ephemeral, no funds at risk).
# Keep your keyring/password identity for mainnet (ic) deploys.
#
# Usage:
#   ./scripts/fix-wsl-keyring.sh              # plaintext (recommended for local)
#   ./scripts/fix-wsl-keyring.sh password     # encrypted + password file
#   ./scripts/fix-wsl-keyring.sh --help
set -euo pipefail

MODE="${1:-plaintext}"

usage() {
  cat <<'EOF'
Usage: ./scripts/fix-wsl-keyring.sh [plaintext|password]

  plaintext  Create/use `local` identity with --storage plaintext (default).
             No prompt, headless, ideal for WSL + local replica.
  password   Create/use `local-pw` with --storage password + file
             ~/.config/icp-cli/.icp-password (chmod 600). More secure.

Examples:
  ./scripts/fix-wsl-keyring.sh
  ./scripts/fix-wsl-keyring.sh password
  icp deploy --identity local
  icp deploy --identity local-pw --identity-password-file ~/.config/icp-cli/.icp-password
EOF
}

if [[ "$MODE" == "-h" || "$MODE" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v icp >/dev/null 2>&1; then
  echo "error: icp not found in PATH (npm install -g @icp-sdk/icp-cli)" >&2
  exit 1
fi

echo "==> icp identity list (before)"
icp identity list || true
echo

if [[ "$MODE" == "plaintext" ]]; then
  if icp identity list 2>&1 | grep -qE '(^|\s)local(\s|$)'; then
    echo "==> identity 'local' already exists, reusing"
  else
    echo "==> creating identity 'local' with --storage plaintext"
    icp identity new local --storage plaintext
  fi
  echo "==> setting default identity to 'local'"
  icp identity default local || true
  echo
  echo "==> verifying (should NOT prompt for keyring unlock)"
  icp identity principal
  echo
  echo "==> done. Try:"
  echo "    icp network start -d"
  echo "    icp network status          # expect gateway 127.0.0.1:8000 (see icp.yaml)"
  echo "    icp deploy                  # or: icp deploy --identity local"
  echo
  echo "Keep 'deployer'/'default' keyring identities for mainnet: icp deploy --network ic --identity deployer"

elif [[ "$MODE" == "password" ]]; then
  PW_FILE="${ICP_PASSWORD_FILE:-$HOME/.config/icp-cli/.icp-password}"
  mkdir -p "$(dirname "$PW_FILE")"
  if [[ ! -f "$PW_FILE" ]]; then
    echo "==> generating password file $PW_FILE"
    openssl rand -base64 24 > "$PW_FILE"
    chmod 600 "$PW_FILE"
    echo "    chmod 600 $PW_FILE"
  else
    echo "==> password file exists: $PW_FILE (chmod 600)"
    chmod 600 "$PW_FILE"
  fi
  if icp identity list 2>&1 | grep -qE '(^|\s)local-pw(\s|$)'; then
    echo "==> identity 'local-pw' already exists"
  else
    echo "==> creating identity 'local-pw' with --storage password"
    icp identity new local-pw --storage password --storage-password-file "$PW_FILE"
  fi
  echo "==> setting default to local-pw (optional)"
  icp identity default local-pw || true
  echo
  echo "==> verifying"
  icp identity principal
  echo
  echo "==> done. Deploy with:"
  echo "    icp deploy --identity local-pw --identity-password-file $PW_FILE"
else
  echo "error: unknown mode '$MODE' (expected plaintext|password)" >&2
  usage
  exit 2
fi
