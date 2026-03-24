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
6. [Integration](#integration)

  * [Waybar Integration](#waybar-integration)
  * [Hyprland Integration](#hyprland-integration)
7. [Development](#development)
8. [Component Details](#component-details)

   * [Wi-Fi Tab](#wi-fi-tab)
   * [Ethernet Tab](#ethernet-tab)
   * [VPN Tab](#vpn-tab)
   * [NetworkManager D-Bus Client](#networkmanager-d-bus-client)
   * [GUI & Layer-Shell](#gui--layer-shell)
9. [Security](#security)
10. [Troubleshooting](#troubleshooting)

---

## Installation

Use the install script for both system-wide and user-local installs in either interactive or non-interactive modes.


* GTK 4 runtime and development libraries
* gtk4-layer-shell
* json-glib
* NetworkManager

The install script auto-installs dependencies when supported package managers are available.

### Manual Build

```bash
meson setup builddir
meson compile -C builddir
```

### Build Scripts (Dev/Prod)

Use one compile script for all build modes:

```bash
./scripts/compile.sh [dev|prod|debug] [build_dir]
```

Examples:

```bash
./scripts/compile.sh            # dev build -> builddir-dev
./scripts/compile.sh dev        # dev build -> builddir-dev
./scripts/compile.sh prod       # prod build -> builddir-prod
./scripts/compile.sh debug      # debug build -> builddir-debug
./scripts/compile.sh prod out   # prod build -> out
./scripts/compile.sh --mode dev --install-deps
```

For run/build convenience during development:

```bash
./scripts/run-dev.sh
```

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
  "window_width": 480,
  "window_height": 560,
  "layer_shell_layer": "overlay",
  "position": "top-right",
  "layer_shell_margin_top": 8,
  "layer_shell_margin_right": 8,
  "layer_shell_margin_bottom": 8,
  "layer_shell_margin_left": 8,
  "scan_interval": 30,
  "close_on_connect": true,
  "show_bssid": false,
  "show_frequency": true,
  "show_band": false
}
```

The app reads `config.json` from this precedence order:

1. Explicit path passed via `--config`
2. `~/.config/hypr-network-manager/config.json`
3. `/etc/xdg/hypr-network-manager/config.json`

### Supported config keys

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| window_width | int (> 0) | 480 | Popup window width in pixels. |
| window_height | int (> 0) | 560 | Popup window height in pixels. |
| layer_shell_layer | string | overlay | Layer-shell layer. Supported values: `overlay`, `top`, `bottom`, `background`. |
| position | string | top-right | Position preset used for placement anchors. Supported values: `top-left`, `top-right`, `bottom-left`, `bottom-right`, `top`, `right`, `bottom`, `left`. Invalid values fallback to top-right. |
| layer_shell_margin_top | int | 8 | Top margin in pixels. |
| layer_shell_margin_right | int | 8 | Right margin in pixels. |
| layer_shell_margin_bottom | int | 8 | Bottom margin in pixels. |
| layer_shell_margin_left | int | 8 | Left margin in pixels. |
| scan_interval | int (> 0) | 30 | Seconds between periodic refresh/scan cycles. |
| close_on_connect | bool | true | Close popup immediately after successful Wi-Fi connect. |
| show_bssid | bool | false | Show access point BSSID in Wi-Fi row subtitle. |
| show_frequency | bool | true | Show access point frequency in MHz in Wi-Fi row subtitle. |
| show_band | bool | false | Show Wi-Fi band label (`2.4 GHz` or `5 GHz`) derived from AP frequency. |

### Placement behavior

Placement is controlled by `position`, and spacing is controlled by `layer_shell_margin_*`.

The shell enforces a minimum size of `480x560` as that is a reasonable size for readability.

### Notes on extra keys

Keys not listed above are ignored by the current app runtime.

---

## Theming

Themes are CSS-based and hot-swappable.

### Base CSS Load Order

1. `~/.config/hypr-network-manager/themes/base.css` (user-local)
2. `/etc/xdg/hypr-network-manager/themes/base.css` (system-wide fallback)

This path is fixed and is not configurable through `config.json`.

### Custom Theme Example

```css
@import url("./frosted-glass.css");
```

You can create themes in `~/.config/hypr-network-manager/themes/` and import them in `themes/base.css`.

### Clean Slate Theming (Strip GTK Defaults)

If you want full visual control, start by neutralizing GTK defaults on app-scoped classes, then build styles back up intentionally.

Recommended baseline reset (scoped to this app):

```css
/* Keep reset scoped so it does not affect other GTK apps */
.nm-window,
.nm-window * {
  background-image: none;
  box-shadow: none;
  text-shadow: none;
  border: none;
  outline: none;
}

.nm-window button,
.nm-window entry,
.nm-window row,
.nm-window box,
.nm-window label,
.nm-window separator {
  border-radius: 0;
  padding: 0;
  margin: 0;
}
```

Then add back explicit styling for containers, buttons, entries, focus, and hover states in your theme. This avoids fighting distro/GTK defaults and gives a predictable theming base.

### Theme Style Overrides

The following appearance settings are CSS-driven and should be edited in your active theme file (for example `themes/default.css`, `themes/nord.css`, etc.):

* Opacity
* Border radius
* Font family
* Font size

Example (already present in bundled theme files):

```css
window.nm-window,
.nm-window {
  opacity: 1.0;
  border-radius: 12px;
}

.nm-root,
.nm-window,
.nm-root label,
.nm-window label,
.nm-root button,
.nm-window button,
.nm-root entry,
.nm-window entry {
  font-family: sans-serif;
  font-size: 13px;
}
```

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
| nm-page-wifi-details | Wi-Fi details page container |
| nm-page-wifi-edit | Wi-Fi edit page container |
| nm-page-ethernet | Ethernet page container |
| nm-page-vpn | VPN page container |
| nm-toolbar | Page toolbar row |
| nm-toolbar-icon | Generic toolbar icon image class |
| nm-refresh-icon | Shared refresh icon class |
| nm-wifi-refresh-icon | Wi-Fi page refresh icon class |
| nm-ethernet-refresh-icon | Ethernet page refresh icon class |
| nm-vpn-refresh-icon | VPN page refresh icon class |
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
| nm-signal-icon-secured | Secured Wi-Fi icon variant class |
| nm-wifi-icon | Wi-Fi icon hook class |
| nm-ethernet-icon | Ethernet icon hook class |
| nm-vpn-icon | VPN icon hook class |
| nm-ssid-label | Primary row title text |
| nm-sub-label | Secondary row subtitle text |
| nm-row-root | Wi-Fi row vertical container |
| nm-row-content | Wi-Fi row horizontal content container |
| nm-row-info | Wi-Fi row text/info container |
| nm-row-actions | Wi-Fi row actions container |
| nm-row-action-button | Text-style row action button (connect/disconnect/forget) |
| nm-row-icon-button | Icon-only row action button |
| nm-action-button | "Forget" action button |
| nm-connect-button | Connect action button |
| nm-disconnect-button | Disconnect action button |
| nm-form-label | Generic form labels |
| nm-nav-back | Lightweight back navigation button |
| nm-details-network-title | Network title on details/edit pages |
| nm-details-group-title | Group label for sections like BASIC/ADVANCED |
| nm-password-entry | Password entry base styling |
| nm-inline-password | Inline Wi-Fi password prompt container |
| nm-inline-password-label | Inline password prompt label |
| nm-inline-password-entry | Inline password input |
| nm-inline-password-actions | Inline password action row |
| nm-inline-password-cancel | Inline cancel button |
| nm-inline-password-connect | Inline connect button |
| nm-inline-password-revealer | Inline prompt revealer widget |
| nm-details-nav-row | Details page top navigation row |
| nm-details-header | Details page icon/title header block |
| nm-details-action-row | Details page action buttons row |
| nm-details-action-button | Details page action button variant |
| nm-details-open-button | Row details-open trigger button |
| nm-details-open-icon | Icon inside details-open trigger button |
| nm-details-button-icon | Details button icon hook class |
| nm-details-key | Key label class used in details rows |
| nm-details-value | Value label class used in details rows |
| nm-details-network-icon | Large network icon on details page |
| nm-details-section | Details section wrapper (basic/advanced) |
| nm-details-rows | Details rows container |
| nm-details-row | Single details key/value row |
| nm-details-item | Vertical details item wrapper |
| nm-details-item-key | Details item key label |
| nm-details-item-value | Details item value label |
| nm-edit-form | Wi-Fi edit form wrapper |
| nm-menu-button | Compact navigation button (e.g. `>` details nav) |
| nm-wifi-switch | Wi-Fi-specific switch |
| nm-wifi-placeholder-icon | Wi-Fi empty-state icon hook class |
| nm-ethernet-placeholder-icon | Ethernet empty-state icon hook class |
| nm-vpn-placeholder-icon | VPN empty-state icon hook class |
| blank-window | Dismiss overlay window |
| blank-window-surface | Click-capture surface inside dismiss overlay |

---

## Usage

### Launching the GUI

```bash
hypr-network-manager
```

### CLI Options

```bash
--debug             # Enable debug logging
--status            # Output JSON for status bars
--toggle-wifi       # Toggle Wi-Fi on/off
```

---

## Integration

### Waybar Integration

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

### Hyprland Integration

For blur on this app's layer-shell surface namespace, add this rule:

```conf
layerrule = match:namespace ^(hypr-network-manager)$, blur on
```

---

## Development

### Dependencies

* Vala toolchain
* GTK 4 runtime and development libraries
* gtk4-layer-shell
* json-glib
* NetworkManager

The install script auto-installs dependencies when supported package managers are available.

### Manual Build

```bash
meson setup builddir
meson compile -C builddir
```

### Build Scripts

Use one compile script for all build modes:

```bash
./scripts/compile.sh [dev|prod|debug] [build_dir]
```

Examples:

```bash
./scripts/compile.sh            # dev build -> builddir-dev
./scripts/compile.sh dev        # dev build -> builddir-dev
./scripts/compile.sh prod       # prod build -> builddir-prod
./scripts/compile.sh debug      # debug build -> builddir-debug
./scripts/compile.sh prod out   # prod build -> out
./scripts/compile.sh --mode dev --install-deps
```

For run/build convenience during development:

```bash
./scripts/run-dev.sh
```

---

## Component Details

### Wi-Fi Tab

* Live AP scanning via NetworkManager D-Bus
* Connect to saved or new networks
* Forget saved profiles
* Password prompt integrated
* Per-network details page with structured Basic and Advanced sections
* Per-network edit page for credential updates and profile actions

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
* Window dimensions, anchors, and margins configurable
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
