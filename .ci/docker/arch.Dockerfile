FROM archlinux:latest

ENV PREFIX=/usr/local \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig \
    LD_LIBRARY_PATH=/usr/local/lib

RUN pacman -Sy --noconfirm archlinux-keyring && \
    pacman -S --noconfirm \
      base-devel git meson cmake ninja vala pkgconf python \
      wayland wayland-protocols gtk4 gobject-introspection gtk-doc \
      json-glib networkmanager && \
    pacman -Scc --noconfirm

# 🔥 Critical: build in same environment, no cache reuse ever
RUN git clone https://github.com/wmww/gtk4-layer-shell /tmp/gtk4-layer-shell && \
    cd /tmp/gtk4-layer-shell && \
    git checkout 724be1675be4a92e49e0e1a31330f4c4b3d99526 && \
    meson setup build --prefix=$PREFIX && \
    ninja -C build && \
    ninja -C build install && \
    rm -rf /tmp/gtk4-layer-shell