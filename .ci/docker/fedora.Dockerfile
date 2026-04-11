FROM fedora:latest

ENV PREFIX=/usr/local \
    PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig \
    LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib

RUN dnf -y update && \
    dnf -y install \
      meson ninja-build cmake vala pkgconf-pkg-config python3 \
      wayland-devel wayland-protocols-devel \
      gtk4-devel gobject-introspection-devel gtk-doc \
      json-glib-devel NetworkManager-libnm-devel \
      git ca-certificates && \
    dnf clean all

RUN git clone https://github.com/wmww/gtk4-layer-shell /tmp/gtk4-layer-shell && \
    cd /tmp/gtk4-layer-shell && \
    git checkout 724be1675be4a92e49e0e1a31330f4c4b3d99526 && \
    meson setup build --prefix=$PREFIX && \
    ninja -C build && \
    ninja -C build install && \
    rm -rf /tmp/gtk4-layer-shell