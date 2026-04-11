FROM fedora:latest

ARG GTK4_LAYER_SHELL_VERSION=1.3.0

ENV PREFIX=/usr/local \
    PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig \
    LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib

RUN dnf -y update && \
    dnf -y install \
      meson ninja-build cmake vala pkgconf-pkg-config python3 \
      wayland-devel wayland-protocols-devel \
      gtk4-devel gobject-introspection-devel gtk-doc \
      json-glib-devel NetworkManager-libnm-devel \
            ca-certificates && \
        dnf -y install \
            "gtk4-layer-shell-${GTK4_LAYER_SHELL_VERSION}*" \
            "gtk4-layer-shell-devel-${GTK4_LAYER_SHELL_VERSION}*" && \
        test "$(rpm -q --qf '%{VERSION}' gtk4-layer-shell)" = "$GTK4_LAYER_SHELL_VERSION" && \
    dnf clean all