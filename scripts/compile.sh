#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/scripts/lib/dependencies.sh"
SCRIPT_DIR="$(nm_script_dir "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(nm_project_root_from_script "${BASH_SOURCE[0]}")"

print_usage() {
  cat <<'EOF'
Usage:
  ./scripts/compile.sh [dev|prod|debug] [build_dir]
  ./scripts/compile.sh --mode dev|prod|debug [--build-dir DIR] [--install-deps]

Examples:
  ./scripts/compile.sh
  ./scripts/compile.sh dev
  ./scripts/compile.sh prod
  ./scripts/compile.sh debug
  ./scripts/compile.sh prod builddir-release
  ./scripts/compile.sh --mode dev --build-dir builddir-dev
  ./scripts/compile.sh --mode dev --install-deps
EOF
}

MODE="dev"
BUILD_DIR=""
INSTALL_DEPS="${INSTALL_DEPS:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode)
      [[ $# -ge 2 ]] || {
        echo "Error: --mode requires a value (dev|prod|debug)." >&2
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
    --install-deps)
      INSTALL_DEPS="true"
      shift
      ;;
    dev|prod|debug)
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

PROFILE_SETTINGS="$(nm_resolve_build_profile "$MODE" "$BUILD_DIR" "" "")" || {
  print_usage
  exit 1
}
IFS=';' read -r BUILD_DIR BUILD_TYPE STRIP_BIN <<<"$PROFILE_SETTINGS"

BUILD_DIR_PATH="$(nm_resolve_path_against_root "$PROJECT_ROOT" "$BUILD_DIR")"

if [[ "$INSTALL_DEPS" == "true" || "$INSTALL_DEPS" == "1" ]]; then
  echo "Installing dependencies via shared helper..."
  nm_install_dependencies
else
  if ! nm_check_build_dependencies; then
    echo "Error: missing dependencies. Re-run with --install-deps or run ./scripts/install.sh" >&2
    exit 1
  fi
fi

nm_meson_setup "$PROJECT_ROOT" "$BUILD_DIR_PATH" "$BUILD_TYPE" "$STRIP_BIN"

nm_meson_compile "$BUILD_DIR_PATH"

echo "${MODE^} build complete: $BUILD_DIR_PATH/vala/hypr-network-manager"
