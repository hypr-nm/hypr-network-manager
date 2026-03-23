#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-builddir-prod}"

if [[ -d "$BUILD_DIR" ]]; then
  meson setup "$BUILD_DIR" --reconfigure --buildtype=release -Dstrip=true
else
  meson setup "$BUILD_DIR" --buildtype=release -Dstrip=true
fi

meson compile -C "$BUILD_DIR"

echo "Prod build complete: $BUILD_DIR/vala/hypr-network-manager"
