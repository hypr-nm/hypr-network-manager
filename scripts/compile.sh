#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'EOF'
Usage:
  ./scripts/compile.sh [dev|prod] [build_dir]
  ./scripts/compile.sh --mode dev|prod [--build-dir DIR]

Examples:
  ./scripts/compile.sh
  ./scripts/compile.sh dev
  ./scripts/compile.sh prod
  ./scripts/compile.sh prod builddir-release
  ./scripts/compile.sh --mode dev --build-dir builddir-dev
EOF
}

MODE="dev"
BUILD_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode)
      [[ $# -ge 2 ]] || {
        echo "Error: --mode requires a value (dev|prod)." >&2
        exit 1
      }
      MODE="$2"
      shift 2
      ;;
    -b|--build-dir)
      [[ $# -ge 2 ]] || {
        echo "Error: --build-dir requires a directory value." >&2
        exit 1
      }
      BUILD_DIR="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    dev|prod)
      if [[ "$MODE" != "dev" ]]; then
        echo "Error: build mode already set to '$MODE'." >&2
        exit 1
      fi
      MODE="$1"
      shift
      ;;
    *)
      if [[ -n "$BUILD_DIR" ]]; then
        echo "Error: unexpected argument '$1'." >&2
        print_usage
        exit 1
      fi
      BUILD_DIR="$1"
      shift
      ;;
  esac
done

case "$MODE" in
  dev)
    BUILD_DIR="${BUILD_DIR:-builddir-dev}"
    BUILD_TYPE="debugoptimized"
    STRIP_BIN="false"
    ;;
  prod)
    BUILD_DIR="${BUILD_DIR:-builddir-prod}"
    BUILD_TYPE="release"
    STRIP_BIN="true"
    ;;
  *)
    echo "Error: invalid mode '$MODE' (expected dev or prod)." >&2
    print_usage
    exit 1
    ;;
esac

if [[ -d "$BUILD_DIR" ]]; then
  meson setup "$BUILD_DIR" --reconfigure --buildtype="$BUILD_TYPE" -Dstrip="$STRIP_BIN"
else
  meson setup "$BUILD_DIR" --buildtype="$BUILD_TYPE" -Dstrip="$STRIP_BIN"
fi

meson compile -C "$BUILD_DIR"

echo "${MODE^} build complete: $BUILD_DIR/vala/hypr-network-manager"
