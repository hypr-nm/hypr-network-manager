FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV PREFIX=/usr/local \
    PKG_CONFIG_PATH=/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig \
    LD_LIBRARY_PATH=/usr/local/lib/x86_64-linux-gnu:/usr/local/lib

RUN apt-get update && apt-get install -y \
    meson cmake ninja-build valac pkg-config python3 \
    libwayland-dev wayland-protocols \
    libgtk-4-dev gobject-introspection libgirepository1.0-dev gtk-doc-tools \
    libjson-glib-dev network-manager libnm-dev \
    git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Build gtk4-layer-shell once
RUN git clone https://github.com/wmww/gtk4-layer-shell /tmp/gtk4-layer-shell && \
    cd /tmp/gtk4-layer-shell && \
    git checkout 724be1675be4a92e49e0e1a31330f4c4b3d99526 && \
    meson setup build --prefix=$PREFIX && \
    ninja -C build && \
    ninja -C build install && \
    rm -rf /tmp/gtk4-layer-shell