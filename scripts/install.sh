#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-builddir-install}"
BUILD_TYPE="${BUILD_TYPE:-release}"
STRIP_BIN="${STRIP_BIN:-true}"
INSTALL_PREFIX="${INSTALL_PREFIX:-}"
INSTALL_SCOPE="${INSTALL_SCOPE:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SYSTEM_CONFIG_DIR="/etc/xdg/hypr-network-manager"
CONFIG_TARGET_DIR=""

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

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '[install] missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

run_with_privilege() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf '[install] need root privileges for: %s\n' "$*" >&2
    printf '[install] re-run as root or install sudo.\n' >&2
    exit 1
  fi
}

install_deps_pacman() {
  log "Installing dependencies with pacman"
  run_with_privilege pacman -Syu --needed --noconfirm \
    vala meson ninja pkgconf gtk4 gtk4-layer-shell networkmanager
}

install_deps_apt() {
  log "Installing dependencies with apt"
  run_with_privilege apt-get update
  run_with_privilege apt-get install -y \
    valac meson ninja-build pkg-config \
    libgtk-4-dev libgtk4-layer-shell-dev network-manager
}

install_deps_dnf() {
  log "Installing dependencies with dnf"
  run_with_privilege dnf install -y \
    vala meson ninja-build pkgconf-pkg-config \
    gtk4-devel gtk4-layer-shell-devel NetworkManager
}

install_deps_zypper() {
  log "Installing dependencies with zypper"
  run_with_privilege zypper --non-interactive refresh
  run_with_privilege zypper --non-interactive install \
    vala meson ninja pkgconf-pkg-config \
    gtk4-devel gtk4-layer-shell-devel NetworkManager
}

install_dependencies() {
  if command -v pacman >/dev/null 2>&1; then
    install_deps_pacman
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    install_deps_apt
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    install_deps_dnf
    return
  fi

  if command -v zypper >/dev/null 2>&1; then
    install_deps_zypper
    return
  fi

  printf '[install] unsupported package manager.\n' >&2
  printf '[install] supported: pacman, apt-get, dnf, zypper\n' >&2
  exit 1
}

configure_build() {
  local setup_args=(--buildtype="$BUILD_TYPE" -Dstrip="$STRIP_BIN" --prefix "$INSTALL_PREFIX")

  if [[ -d "$PROJECT_ROOT/$BUILD_DIR" ]]; then
    log "Reconfiguring existing Meson build dir: $BUILD_DIR"
    meson setup "$PROJECT_ROOT/$BUILD_DIR" --reconfigure "${setup_args[@]}"
  else
    log "Creating Meson build dir: $BUILD_DIR"
    meson setup "$PROJECT_ROOT/$BUILD_DIR" "${setup_args[@]}"
  fi
}

build_and_install() {
  log "Compiling project"
  meson compile -C "$PROJECT_ROOT/$BUILD_DIR"

  log "Installing binary and assets"
  if [[ "$INSTALL_SCOPE" == "system" ]]; then
    run_with_privilege meson install -C "$PROJECT_ROOT/$BUILD_DIR"
  else
    meson install -C "$PROJECT_ROOT/$BUILD_DIR"
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
  need_cmd meson
  need_cmd sh

  choose_install_scope
  configure_install_targets

  cd "$PROJECT_ROOT"
  install_dependencies
  configure_build
  build_and_install
  install_defaults
  print_summary
}

main "$@"
