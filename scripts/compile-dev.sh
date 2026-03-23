#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-builddir-dev}"

if [[ -d "$BUILD_DIR" ]]; then
  meson setup "$BUILD_DIR" --reconfigure --buildtype=debugoptimized
else
  meson setup "$BUILD_DIR" --buildtype=debugoptimized
fi

meson compile -C "$BUILD_DIR"

echo "Dev build complete: $BUILD_DIR/vala/hypr-network-manager"
