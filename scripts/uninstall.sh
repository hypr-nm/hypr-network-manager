#!/usr/bin/env bash
set -euo pipefail

INSTALL_SCOPE="${INSTALL_SCOPE:-}"
INSTALL_PREFIX="${INSTALL_PREFIX:-}"
SYSTEM_CONFIG_DIR="/etc/xdg/hypr-network-manager"
CONFIG_TARGET_DIR=""
BINARY_PATH=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() {
  printf '[uninstall] %s\n' "$*"
}

run_with_privilege() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf '[uninstall] need root privileges for: %s\n' "$*" >&2
    printf '[uninstall] re-run as root or install sudo.\n' >&2
    exit 1
  fi
}

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

choose_install_scope() {
  if [[ -n "$INSTALL_SCOPE" ]]; then
    case "$INSTALL_SCOPE" in
      user|system)
        return
        ;;
      *)
        printf '[uninstall] invalid INSTALL_SCOPE: %s (expected: user|system)\n' "$INSTALL_SCOPE" >&2
        exit 1
        ;;
    esac
  fi

  if [[ -t 0 ]]; then
    local answer
    printf '\nSelect uninstall level for binary and defaults:\n'
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
        printf '[uninstall] invalid choice: %s\n' "$answer" >&2
        exit 1
        ;;
    esac
  else
    INSTALL_SCOPE="system"
    log "No TTY detected; defaulting uninstall level to system"
  fi
}

configure_targets() {
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

  BINARY_PATH="$INSTALL_PREFIX/bin/hypr-network-manager"

  log "Uninstall scope: $INSTALL_SCOPE"
  log "Binary target: $BINARY_PATH"
  log "Config/theme target: $CONFIG_TARGET_DIR"
}

remove_binary() {
  if [[ "$INSTALL_SCOPE" == "system" ]]; then
    if run_with_privilege test -f "$BINARY_PATH"; then
      run_with_privilege rm -f "$BINARY_PATH"
      log "Removed binary: $BINARY_PATH"
    else
      log "Binary not found: $BINARY_PATH"
    fi
    return
  fi

  if [[ -f "$BINARY_PATH" ]]; then
    rm -f "$BINARY_PATH"
    log "Removed binary: $BINARY_PATH"
  else
    log "Binary not found: $BINARY_PATH"
  fi
}

remove_defaults() {
  if [[ "$CONFIG_TARGET_DIR" == "/" || -z "$CONFIG_TARGET_DIR" ]]; then
    printf '[uninstall] refusing to remove unsafe config path: %s\n' "$CONFIG_TARGET_DIR" >&2
    exit 1
  fi

  if [[ "$INSTALL_SCOPE" == "system" ]]; then
    if run_with_privilege test -d "$CONFIG_TARGET_DIR"; then
      run_with_privilege rm -rf "$CONFIG_TARGET_DIR"
      log "Removed config/theme directory: $CONFIG_TARGET_DIR"
    else
      log "Config/theme directory not found: $CONFIG_TARGET_DIR"
    fi
    return
  fi

  if [[ ! -d "$CONFIG_TARGET_DIR" ]]; then
    log "Config/theme directory not found: $CONFIG_TARGET_DIR"
    return
  fi

  local removed_any=false
  local user_themes_dir="$CONFIG_TARGET_DIR/themes"

  if [[ -f "$CONFIG_TARGET_DIR/config.json" ]]; then
    rm -f "$CONFIG_TARGET_DIR/config.json"
    removed_any=true
  fi

  if [[ -d "$user_themes_dir" ]]; then
    if [[ -f "$user_themes_dir/base.css" ]]; then
      rm -f "$user_themes_dir/base.css"
      removed_any=true
    fi

    local css_file css_name
    for css_file in "$PROJECT_ROOT/themes"/*.css; do
      css_name="$(basename "$css_file")"
      if [[ "$css_name" == "base.css" ]]; then
        continue
      fi
      if [[ -f "$user_themes_dir/$css_name" ]]; then
        rm -f "$user_themes_dir/$css_name"
        removed_any=true
      fi
    done

    rmdir "$user_themes_dir" 2>/dev/null || true
  fi

  rmdir "$CONFIG_TARGET_DIR" 2>/dev/null || true

  if [[ "$removed_any" == true ]]; then
    log "Removed installer-managed defaults from: $CONFIG_TARGET_DIR"
  else
    log "No installer-managed defaults found in: $CONFIG_TARGET_DIR"
  fi
}

print_summary() {
  cat <<EOF

Uninstall completed.

Removed targets:
  Binary: $BINARY_PATH
  Config/themes: $CONFIG_TARGET_DIR
EOF
}

main() {
  choose_install_scope
  configure_targets
  remove_binary
  remove_defaults
  print_summary
}

main "$@"
