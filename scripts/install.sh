#!/usr/bin/env bash
set -euo pipefail

BUILD_MODE="${BUILD_MODE:-prod}"
BUILD_DIR="${BUILD_DIR:-builddir-install}"
BUILD_TYPE="${BUILD_TYPE:-}"
STRIP_BIN="${STRIP_BIN:-}"
INSTALL_PREFIX="${INSTALL_PREFIX:-}"
INSTALL_SCOPE="${INSTALL_SCOPE:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/scripts/lib/dependencies.sh"
SCRIPT_DIR="$(nm_script_dir "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(nm_project_root_from_script "${BASH_SOURCE[0]}")"
SYSTEM_CONFIG_DIR="/etc/xdg/hypr-network-manager"
CONFIG_TARGET_DIR=""
BUILD_DIR_PATH=""

resolve_target_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s\n' "$SUDO_USER"
    return
  fi
  id -un
}

resolve_target_user_home() {
  local target_user
  target_user="$(resolve_target_user)"
  getent passwd "$target_user" | cut -d: -f6
}

log() {
  printf '[install] %s\n' "$*"
}

choose_install_scope() {
  if [[ -n "$INSTALL_SCOPE" ]]; then
    case "$INSTALL_SCOPE" in
      user|system)
        return
        ;;
      *)
        printf '[install] invalid INSTALL_SCOPE: %s (expected: user|system)\n' "$INSTALL_SCOPE" >&2
        exit 1
        ;;
    esac
  fi

  if [[ -t 0 ]]; then
    local answer
    printf '\nSelect install level for binary and defaults:\n'
    printf '  1) system (/usr/local + /etc/xdg/hypr-network-manager)\n'
    printf '  2) user (~/.local + ~/.config/hypr-network-manager)\n'
    printf 'Choice [1/2] (default: 1): '
    read -r answer
    case "${answer:-1}" in
      1|system|System|SYSTEM)
        INSTALL_SCOPE="system"
        ;;
      2|user|User|USER)
        INSTALL_SCOPE="user"
        ;;
      *)
        printf '[install] invalid choice: %s\n' "$answer" >&2
        exit 1
        ;;
    esac
  else
    INSTALL_SCOPE="system"
    log "No TTY detected; defaulting install level to system"
  fi
}

configure_install_targets() {
  local target_home
  target_home="$(resolve_target_user_home)"

  if [[ "$INSTALL_SCOPE" == "user" ]]; then
    if [[ -z "$INSTALL_PREFIX" ]]; then
      INSTALL_PREFIX="$target_home/.local"
    fi
    CONFIG_TARGET_DIR="$target_home/.config/hypr-network-manager"
  else
    if [[ -z "$INSTALL_PREFIX" ]]; then
      INSTALL_PREFIX="/usr/local"
    fi
    CONFIG_TARGET_DIR="$SYSTEM_CONFIG_DIR"
  fi

  log "Install scope: $INSTALL_SCOPE"
  log "Install prefix: $INSTALL_PREFIX"
  log "Config/theme target: $CONFIG_TARGET_DIR"
}

run_with_privilege() {
  nm_run_with_privilege "$@"
}

run_as_target_user() {
  local target_user current_user
  target_user="$(resolve_target_user)"
  current_user="$(id -un)"

  if [[ "$target_user" == "$current_user" ]]; then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo -u "$target_user" -- "$@"
    return
  fi

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$target_user" -- "$@"
    return
  fi

  printf '[install] cannot run as target user %s (missing sudo/runuser)\n' "$target_user" >&2
  exit 1
}

configure_build() {
  BUILD_DIR_PATH="$(nm_resolve_path_against_root "$PROJECT_ROOT" "$BUILD_DIR")"
  if [[ -d "$BUILD_DIR_PATH" ]]; then
    log "Reconfiguring existing Meson build dir: $BUILD_DIR_PATH"
  else
    log "Creating Meson build dir: $BUILD_DIR_PATH"
  fi

  nm_meson_setup "$PROJECT_ROOT" "$BUILD_DIR_PATH" "$BUILD_TYPE" "$STRIP_BIN" "$INSTALL_PREFIX"
}

build_and_install() {
  log "Compiling project"
  nm_meson_compile "$BUILD_DIR_PATH"

  log "Installing binary and assets"
  if [[ "$INSTALL_SCOPE" == "system" ]]; then
    run_with_privilege meson install -C "$BUILD_DIR_PATH"
  else
    run_as_target_user meson install -C "$BUILD_DIR_PATH"
  fi
}

install_defaults() {
  local target_user target_group target_home user_config_dir
  target_user="$(resolve_target_user)"
  target_group="$(id -gn "$target_user")"
  target_home="$(resolve_target_user_home)"
  user_config_dir="$target_home/.config/hypr-network-manager"

  local base_src tmp_base
  base_src="$PROJECT_ROOT/themes/base.css"
  tmp_base="$(mktemp)"
  # Installed base.css lives at config root, so theme imports must point to ./themes/*.css
  sed -E 's|@import url\("\./([^"]+)"\);|@import url("./themes/\1");|g' "$base_src" > "$tmp_base"
  trap 'rm -f "$tmp_base"' RETURN

  if [[ "$INSTALL_SCOPE" == "system" ]]; then
    log "Installing default config and themes to $CONFIG_TARGET_DIR"
    run_with_privilege install -d -m 755 "$CONFIG_TARGET_DIR"
    run_with_privilege install -d -m 755 "$CONFIG_TARGET_DIR/themes"
    run_with_privilege install -m 644 "$PROJECT_ROOT/config.json" "$CONFIG_TARGET_DIR/config.json"
    run_with_privilege install -m 644 "$tmp_base" "$CONFIG_TARGET_DIR/base.css"

    local css_file css_name
    for css_file in "$PROJECT_ROOT/themes"/*.css; do
      css_name="$(basename "$css_file")"
      if [[ "$css_name" == "base.css" ]]; then
        continue
      fi
      run_with_privilege install -m 644 "$css_file" "$CONFIG_TARGET_DIR/themes/$css_name"
    done
    return
  fi

  log "Installing user defaults to $user_config_dir"
  install -d -m 755 "$user_config_dir"
  install -d -m 755 "$user_config_dir/themes"

  if [[ ! -f "$user_config_dir/config.json" ]]; then
    install -m 644 "$PROJECT_ROOT/config.json" "$user_config_dir/config.json"
  fi

  if [[ ! -f "$user_config_dir/base.css" ]]; then
    install -m 644 "$tmp_base" "$user_config_dir/base.css"
  fi

  local css_file css_name
  for css_file in "$PROJECT_ROOT/themes"/*.css; do
    css_name="$(basename "$css_file")"
    if [[ "$css_name" == "base.css" ]]; then
      continue
    fi
    if [[ ! -f "$user_config_dir/themes/$css_name" ]]; then
      install -m 644 "$css_file" "$user_config_dir/themes/$css_name"
    fi
  done

  if [[ "$(id -un)" == "root" ]]; then
    chown -R "$target_user":"$target_group" "$user_config_dir"
  fi
}

print_summary() {
  cat <<EOF

Install completed.

Binary:
  $INSTALL_PREFIX/bin/hypr-network-manager

Run:
  hypr-network-manager

Optional build customization:
  BUILD_DIR=builddir-dev BUILD_TYPE=debugoptimized STRIP_BIN=false ./scripts/install.sh

Default configs/themes installed to:
  $CONFIG_TARGET_DIR
EOF
}

main() {
  nm_require_command meson || exit 1
  nm_require_command sh || exit 1

  PROFILE_SETTINGS="$(nm_resolve_build_profile "$BUILD_MODE" "$BUILD_DIR" "$BUILD_TYPE" "$STRIP_BIN")" || exit 1
  IFS=';' read -r BUILD_DIR BUILD_TYPE STRIP_BIN <<<"$PROFILE_SETTINGS"

  choose_install_scope
  configure_install_targets

  cd "$PROJECT_ROOT"
  log "Installing build/runtime dependencies"
  nm_install_dependencies
  configure_build
  build_and_install
  install_defaults
  print_summary
}

main "$@"
