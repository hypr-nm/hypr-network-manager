#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-builddir}"

if [ ! -d "$BUILD_DIR" ]; then
  meson setup "$BUILD_DIR"
fi

meson compile -C "$BUILD_DIR"
"./$BUILD_DIR/vala/hypr-network-manager"
