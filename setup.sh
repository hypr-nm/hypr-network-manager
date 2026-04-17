#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/hypr-nm/hypr-network-manager.git"

echo "========================================="
echo " hypr-network-manager Web Installer"
echo "========================================="

if ! command -v git >/dev/null 2>&1; then
    echo "Error: 'git' is required but was not found." >&2
    exit 1
fi

TMP_DIR=$(mktemp -d -t hypr-nm-XXXXXX)

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "=> Cloning repository into a temporary directory..."
git clone --quiet --depth 1 "$REPO_URL" "$TMP_DIR"

cd "$TMP_DIR"

echo "=> Bootstrapping installer..."

# Re-attach stdin to terminal if piped, so interactive prompts still work!
if [[ ! -t 0 ]] && [[ -c /dev/tty ]]; then
    exec < /dev/tty
fi

./scripts/install.sh
