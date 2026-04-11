#!/usr/bin/env bash

# Shared helpers for install/compile/run scripts.

nm_script_dir() {
  local script_source="$1"
  dirname "$(cd "$(dirname "$script_source")" && pwd)/$(basename "$script_source")"
}

nm_project_root_from_script() {
  local script_source="$1"
  local script_dir
  script_dir="$(nm_script_dir "$script_source")"
  cd "$script_dir/.." && pwd
}

nm_resolve_path_against_root() {
  local root="$1"
  local path="$2"

  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$root" "$path"
  fi
}

nm_require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf '[deps] missing required command: %s\n' "$cmd" >&2
    return 1
  fi
}

nm_resolve_build_profile() {
  local mode="$1"
  local build_dir_override="$2"
  local build_type_override="$3"
  local strip_override="$4"
  local default_build_dir
  local default_build_type
  local default_strip

  case "$mode" in
    dev)
      default_build_dir="builddir-dev"
      default_build_type="debugoptimized"
      default_strip="false"
      ;;
    prod)
      default_build_dir="builddir-prod"
      default_build_type="release"
      default_strip="true"
      ;;
    debug)
      default_build_dir="builddir-debug"
      default_build_type="debug"
      default_strip="false"
      ;;
    *)
      printf '[deps] invalid build mode: %s (expected: dev|prod|debug)\n' "$mode" >&2
      return 1
      ;;
  esac

  printf '%s;%s;%s\n' \
    "${build_dir_override:-$default_build_dir}" \
    "${build_type_override:-$default_build_type}" \
    "${strip_override:-$default_strip}"
}

nm_meson_setup() {
  local project_root="$1"
  local build_dir_path="$2"
  local build_type="$3"
  local strip_bin="$4"
  local install_prefix="${5:-}"
  local setup_args=(--buildtype="$build_type" -Dstrip="$strip_bin")

  if [[ -n "$install_prefix" ]]; then
    setup_args+=(--prefix "$install_prefix")
  fi

  if [[ -d "$build_dir_path" ]]; then
    meson setup "$build_dir_path" "$project_root" --reconfigure "${setup_args[@]}"
  else
    meson setup "$build_dir_path" "$project_root" "${setup_args[@]}"
  fi
}

nm_meson_compile() {
  local build_dir_path="$1"
  meson compile -C "$build_dir_path"
}

nm_run_with_privilege() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf '[deps] need root privileges for: %s\n' "$*" >&2
    printf '[deps] re-run as root or install sudo.\n' >&2
    return 1
  fi
}

nm_detect_pkg_manager() {
  if command -v pacman >/dev/null 2>&1; then
    printf 'pacman\n'
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    printf 'apt-get\n'
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    printf 'dnf\n'
    return 0
  fi

  if command -v zypper >/dev/null 2>&1; then
    printf 'zypper\n'
    return 0
  fi

  return 1
}

_nm_install_deps_pacman() {
  nm_run_with_privilege pacman -S --needed --noconfirm \
    vala meson ninja pkgconf gtk4 gtk4-layer-shell json-glib networkmanager cmake
}

_nm_install_deps_apt() {
  nm_run_with_privilege apt-get update
  nm_run_with_privilege apt-get install -y \
    valac meson ninja-build pkg-config \
    libgtk-4-dev libgtk4-layer-shell-dev libjson-glib-dev network-manager libnm-dev cmake
}

_nm_install_deps_dnf() {
  nm_run_with_privilege dnf install -y \
    vala meson ninja-build pkgconf-pkg-config \
    gtk4-devel gtk4-layer-shell-devel json-glib-devel NetworkManager NetworkManager-libnm-devel cmake
}

_nm_install_deps_zypper() {
  nm_run_with_privilege zypper --non-interactive refresh
  nm_run_with_privilege zypper --non-interactive install \
    vala meson ninja pkgconf-pkg-config \
    gtk4-devel gtk4-layer-shell-devel json-glib-devel NetworkManager NetworkManager-devel libnm
}

nm_install_dependencies() {
  local manager
  if ! manager="$(nm_detect_pkg_manager)"; then
    printf '[deps] unsupported package manager.\n' >&2
    printf '[deps] supported: pacman, apt-get, dnf, zypper\n' >&2
    return 1
  fi

  case "$manager" in
    pacman)
      _nm_install_deps_pacman
      ;;
    apt-get)
      _nm_install_deps_apt
      ;;
    dnf)
      _nm_install_deps_dnf
      ;;
    zypper)
      _nm_install_deps_zypper
      ;;
  esac
}

nm_check_build_dependencies() {
  local missing=()
  local cmd
  local pkg

  for cmd in meson valac ninja pkg-config; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("cmd:$cmd")
    fi
  done

  if command -v pkg-config >/dev/null 2>&1; then
    for pkg in gtk4 gio-2.0 gtk4-layer-shell-0 json-glib-1.0 libnm; do
      if ! pkg-config --exists "$pkg"; then
        missing+=("pkg:$pkg")
      fi
    done
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '[deps] missing dependencies:\n' >&2
    printf '  - %s\n' "${missing[@]}" >&2
    return 1
  fi

  return 0
}
