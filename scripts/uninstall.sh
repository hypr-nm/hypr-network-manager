#!/usr/bin/env bash
set -euo pipefail

INSTALL_SCOPE="${INSTALL_SCOPE:-}"
INSTALL_PREFIX="${INSTALL_PREFIX:-}"
SYSTEM_CONFIG_DIR="/etc/xdg/hypr-network-manager"
CONFIG_TARGET_DIR=""
BINARY_PATH=""

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

  if [[ -d "$CONFIG_TARGET_DIR" ]]; then
    rm -rf "$CONFIG_TARGET_DIR"
    log "Removed config/theme directory: $CONFIG_TARGET_DIR"
  else
    log "Config/theme directory not found: $CONFIG_TARGET_DIR"
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
