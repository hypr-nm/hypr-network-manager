# hypr-network-manager Documentation

Comprehensive guide to using, configuring, and extending hypr-network-manager.

---

## Table of Contents

1. [Installation](#installation)
2. [Getting Started](#getting-started)
3. [Configuration](#configuration)
4. [Theming](#theming)
5. [Usage](#usage)

   * [Launching the GUI](#launching-the-gui)
   * [CLI Options](#cli-options)
6. [Waybar Integration](#waybar-integration)
7. [Component Details](#component-details)

   * [Wi-Fi Tab](#wi-fi-tab)
   * [Ethernet Tab](#ethernet-tab)
   * [VPN Tab](#vpn-tab)
   * [NetworkManager D-Bus Client](#networkmanager-d-bus-client)
   * [GUI & Layer-Shell](#gui--layer-shell)
8. [Security](#security)
9. [Troubleshooting](#troubleshooting)

---

## Installation

Detailed installation instructions for Arch, Debian/Ubuntu, and Fedora.

### Quick Install

```bash
./scripts/install.sh
```

This installs dependencies, builds the project, and installs it to `/usr/local` by default.

### Manual Build

```bash
meson setup builddir
meson compile -C builddir
```

### Dependencies

* Vala toolchain
* GTK 4 runtime and development libraries
* gtk4-layer-shell
* NetworkManager

Refer to your distribution's package manager to install these.

---

## Getting Started

1. Ensure dependencies are installed.
2. Build or install the app.
3. Launch the GUI or use CLI commands for status and control.

For step-by-step guidance, see the relevant sections below.

---

## Configuration

Configuration is handled via JSON files.

* User-local: `~/.config/hypr-network-manager/config.json`
* System-wide: `/etc/xdg/hypr-network-manager/config.json`

### Example config

```json
{
  "window_width": 360,
  "window_height": 460,
  "position": "top-right",
  "scan_interval": 30,
  "close_on_connect": true,
  "show_signal_bars": true
}
```

| Key                          | Default   | Description                                            |
| ---------------------------- | --------- | ------------------------------------------------------ |
| window_width / window_height | 360 / 460 | Window dimensions in pixels                            |
| position                     | unset     | Popup position: top-left, top-right, bottom-left, etc. |
| scan_interval                | 30        | Seconds between background Wi-Fi scans                 |
| close_on_connect             | true      | Close window after connecting                          |
| show_signal_bars             | true      | Show signal-strength bars                              |

---

## Theming

Themes are CSS-based and hot-swappable.

### Base CSS Load Order

1. `~/.config/hypr-network-manager/base.css` (user-local)
2. `/etc/xdg/hypr-network-manager/base.css` (system-wide fallback)
3. `themes/base.css` (bundled fallback)

### Custom Theme Example

```css
@import url("./themes/frosted-glass.css");
```

You can create themes in `~/.config/hypr-network-manager/themes/` and import them in `base.css`.

---

## Usage

### Launching the GUI

```bash
hypr-network-manager
```

### CLI Options

```bash
--fullscreen        # Launch fullscreen
--debug             # Enable debug logging
--status            # Output JSON for status bars
--toggle-wifi       # Toggle Wi-Fi on/off
```

---

## Waybar Integration

Add a custom module in Waybar:

```jsonc
"custom/network": {
  "exec": "~/.local/bin/hypr-network-manager --status",
  "on-click": "~/.local/bin/hypr-network-manager",
  "on-click-right": "~/.local/bin/hypr-network-manager --toggle-wifi",
  "interval": 10,
  "return-type": "json"
}
```

Copy CSS snippets from `waybar/style.css` to your bar's style sheet.

---

## Component Details

### Wi-Fi Tab

* Live AP scanning via NetworkManager D-Bus
* Connect to saved or new networks
* Forget saved profiles
* Password prompt integrated

### Ethernet Tab

* Displays wired devices
* Supports disconnecting connections

### VPN Tab

* Lists all profiles
* Connect / Disconnect actions supported

### NetworkManager D-Bus Client

* Handles all D-Bus calls to NetworkManager
* Implements AddAndActivateConnection, ActivateConnection, Disconnect, etc.
* Ensures passwords are never exposed on command line

### GUI & Layer-Shell

* Layer-shell used for proper Wayland popup placement
* Window dimensions, anchors, margins, and opacity configurable
* Frosted-glass effects rely on compositor blur

---

## Security

* All communication with NetworkManager is done over D-Bus
* WPA/WPA2/WPA3 credentials handled securely
* No CLI exposure of passwords

---

## Troubleshooting

* If layer-shell fails, try preloading the library:

```bash
LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so hypr-network-manager --debug
```

* On Debian/Ubuntu:

```bash
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libgtk4-layer-shell.so hypr-network-manager --debug
```

* Check logs for D-Bus connection errors
* Ensure NetworkManager service is running
