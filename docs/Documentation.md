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

### Build Scripts (Dev/Prod)

Use one compile script for both build modes:

```bash
./scripts/compile.sh [dev|prod] [build_dir]
```

Examples:

```bash
./scripts/compile.sh            # dev build -> builddir-dev
./scripts/compile.sh dev        # dev build -> builddir-dev
./scripts/compile.sh prod       # prod build -> builddir-prod
./scripts/compile.sh prod out   # prod build -> out
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
  "layer_shell_layer": "overlay",
  "position": "top-right",
  "layer_shell_margin_top": 8,
  "layer_shell_margin_right": 8,
  "layer_shell_margin_bottom": 8,
  "layer_shell_margin_left": 8
}
```

The app reads `config.json` from this precedence order:

1. Explicit path passed via `--config`
2. `~/.config/hypr-network-manager/config.json`
3. `/etc/xdg/hypr-network-manager/config.json`

### Supported config keys

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| window_width | int (> 0) | 360 | Popup window width in pixels. |
| window_height | int (> 0) | 460 | Popup window height in pixels. |
| layer_shell_layer | string | overlay | Layer-shell layer. Supported values: `overlay`, `top`, `bottom`, `background`. |
| position | string | top-right | Position preset used for placement anchors. Supported values: `top-left`, `top-right`, `bottom-left`, `bottom-right`, `top`, `right`, `bottom`, `left`. Invalid values fallback to top-right. |
| layer_shell_margin_top | int | 8 | Top margin in pixels. |
| layer_shell_margin_right | int | 8 | Right margin in pixels. |
| layer_shell_margin_bottom | int | 8 | Bottom margin in pixels. |
| layer_shell_margin_left | int | 8 | Left margin in pixels. |

### Placement behavior

Placement is controlled by `position`, and spacing is controlled by `layer_shell_margin_*`.

### Notes on extra keys

Keys not listed above are ignored by the current app runtime.

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

### Supported theming classes

The application currently assigns these CSS classes in the UI runtime.

| Class | Where it applies |
| --- | --- |
| nm-window | Main app window |
| nm-root | Root container for the popup content |
| nm-status-bar | Top status/header row |
| nm-status-icon | Header icon |
| nm-status-label | Header status text |
| nm-toggle-label | "Networking" label near the global switch |
| nm-switch | Global/network switches |
| nm-notebook | Main tab notebook |
| nm-tab-label | Tab label widgets |
| nm-page | Shared page container class |
| nm-page-wifi | Wi-Fi page container |
| nm-page-ethernet | Ethernet page container |
| nm-page-vpn | VPN page container |
| nm-toolbar | Page toolbar row |
| nm-section-title | Section title labels |
| nm-button | Shared button base class |
| nm-icon-button | Icon-only refresh buttons |
| nm-separator | Horizontal separators |
| nm-scroll | Scrolled container |
| nm-list | ListBox containers for Wi-Fi/Ethernet/VPN lists |
| nm-empty-state | Empty-state placeholder containers |
| nm-placeholder-icon | Empty-state icons |
| nm-placeholder-label | Empty-state labels |
| nm-content-stack | Stacks that switch list vs empty-state views |
| nm-wifi-row | Wi-Fi list rows |
| nm-device-row | Ethernet and VPN rows |
| connected | State class for active/connected rows |
| nm-signal-icon | Per-row signal/device icon |
| nm-ssid-label | Primary row title text |
| nm-sub-label | Secondary row subtitle text |
| nm-action-button | "Forget" action button |
| nm-connect-button | Connect action button |
| nm-disconnect-button | Disconnect action button |
| nm-form-label | Generic form labels |
| nm-password-entry | Password entry base styling |
| nm-inline-password | Inline Wi-Fi password prompt container |
| nm-inline-password-label | Inline password prompt label |
| nm-inline-password-entry | Inline password input |
| nm-inline-password-actions | Inline password action row |
| nm-inline-password-cancel | Inline cancel button |
| nm-inline-password-connect | Inline connect button |
| nm-inline-password-revealer | Inline prompt revealer widget |
| nm-wifi-switch | Wi-Fi-specific switch |
| blank-window | Fullscreen dismiss overlay window |
| blank-window-surface | Click-capture surface inside dismiss overlay |

The app also uses GTK's standard `suggested-action` class on the inline connect button.

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
