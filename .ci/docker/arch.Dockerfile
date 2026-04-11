FROM archlinux:latest

ENV PREFIX=/usr/local \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig \
    LD_LIBRARY_PATH=/usr/local/lib

RUN pacman -Sy --noconfirm archlinux-keyring && \
    pacman -S --noconfirm \
      base-devel git ca-certificates-utils ca-certificates-mozilla meson cmake ninja vala pkgconf python \
      wayland wayland-protocols gtk4 gobject-introspection gtk-doc \
      json-glib networkmanager && \
    pacman -Scc --noconfirm

# build in same environment, no cache reuse ever
RUN mkdir -p /tmp/gtk4-layer-shell && \
    cd /tmp/gtk4-layer-shell && \
    git init && \
    git remote add origin https://github.com/wmww/gtk4-layer-shell && \
    git fetch --depth 1 origin 724be1675be4a92e49e0e1a31330f4c4b3d99526 && \
    git checkout --detach FETCH_HEAD && \
    meson setup build --prefix=$PREFIX && \
    ninja -C build && \
    ninja -C build install && \
    rm -rf /tmp/gtk4-layer-shell