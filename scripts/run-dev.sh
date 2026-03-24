#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/scripts/lib/dependencies.sh"
SCRIPT_DIR="$(nm_script_dir "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(nm_project_root_from_script "${BASH_SOURCE[0]}")"
BUILD_DIR="${BUILD_DIR:-builddir-dev}"

"$PROJECT_ROOT/scripts/compile.sh" --mode dev --build-dir "$BUILD_DIR"

BUILD_DIR_PATH="$(nm_resolve_path_against_root "$PROJECT_ROOT" "$BUILD_DIR")"

"$BUILD_DIR_PATH/vala/hypr-network-manager"
