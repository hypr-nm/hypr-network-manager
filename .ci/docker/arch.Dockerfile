FROM archlinux:latest

ARG GTK4_LAYER_SHELL_VERSION=1.3.0
ARG GTK4_LAYER_SHELL_RELEASE=1

ENV PREFIX=/usr/local \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig \
    LD_LIBRARY_PATH=/usr/local/lib

RUN pacman -Sy --noconfirm archlinux-keyring && \
    pacman -Syu --noconfirm \
      base-devel git ca-certificates-utils ca-certificates-mozilla meson cmake ninja vala pkgconf python \
              wayland wayland-protocols gtk4 gobject-introspection gtk-doc \
            json-glib networkmanager && \
          pacman -U --noconfirm \
              "https://archive.archlinux.org/packages/g/gtk4-layer-shell/gtk4-layer-shell-${GTK4_LAYER_SHELL_VERSION}-${GTK4_LAYER_SHELL_RELEASE}-x86_64.pkg.tar.zst" && \
        pacman -Scc --noconfirm
