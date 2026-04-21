# hypr-network-manager Documentation

Comprehensive guide to using, configuring, and extending hypr-network-manager.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Installation](#installation)
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
11. [Release and Support Policies](#release-and-support-policies)

---

## Getting Started

1. Ensure dependencies are installed.
2. Build or install the app.
3. Launch the GUI or use CLI commands for status and control.

For step-by-step guidance, see the relevant sections below.

---

## Installation

### Arch Linux

Install `hypr-network-manager-git` AUR package using yay or any AUR helper.

```bash
yay -S hypr-network-manager-git
```

### Fedora

Enable the COPR repository and install the package:

```bash
dnf copr enable yeab212/hypr-network-manager
dnf install hypr-network-manager
```

### Debian / Ubuntu / Other Distros

Use the installer script:

```bash
bash <(curl -sSfL https://raw.githubusercontent.com/hypr-nm/hypr-network-manager/master/setup.sh)
```

Alternatively, you can skip the interactive prompt and define the `INSTALL_SCOPE` directly:

```bash
INSTALL_SCOPE=system bash <(curl -sSfL https://raw.githubusercontent.com/hypr-nm/hypr-network-manager/master/setup.sh)
```
or 
```bash
INSTALL_SCOPE=user bash <(curl -sSfL https://raw.githubusercontent.com/hypr-nm/hypr-network-manager/master/setup.sh)
```

---

### Dependencies

* GTK 4 runtime and development libraries
* gtk4-layer-shell
* json-glib
* NetworkManager

The install script auto-installs dependencies when supported package managers are available.

### Manual Installation (From Source)

Clone the repository and run the installation script:

```bash
git clone https://github.com/hypr-nm/hypr-network-manager.git
cd hypr-network-manager
./scripts/install.sh
```

You will be prompted to select the install level for the binary and defaults:
1. **System**: `/usr/local` and `/etc/xdg/hypr-network-manager`
2. **User**: `~/.local` and `~/.config/hypr-network-manager`

You can bypass the prompt by defining the `INSTALL_SCOPE` environment variable before running the script:

```bash
INSTALL_SCOPE=system ./scripts/install.sh
```
or 
```bash
INSTALL_SCOPE=user ./scripts/install.sh
```

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
  "log_level": "info",
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
| log_level | string | info | Minimum emitted log severity. Supported values: `debug`, `info`, `warn`, `error`. |
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

Note: All guides provided bellow regarding theming are just a recommended patterns to get started, not a strict requirements. Themes can be structured in any way as long as the root `base.css` is present and valid.

### Base CSS Load Order

1. `~/.config/hypr-network-manager/themes/base.css` (user-local)
2. `/etc/xdg/hypr-network-manager/themes/base.css` (system-wide fallback)


### Recommended Theme Architecture

The bundled default theme is split into four layers:

1. `core/structure.css` (layout and core geometry)
2. `<theme>/tokens.css` (color + typography tokens)
3. `core/core-components.css` (shared component visuals that consume tokens)
4. `<theme>/overrides.css` (optional theme-specific tweaks)

Bundled themes follow this folder layout:

* `themes/<name>/base.css`
* `themes/<name>/tokens.css`
* `themes/<name>/overrides.css`

### Compact Theme Workflow

1. Create a theme directory in `~/.config/hypr-network-manager/themes/` (for example `my-theme/`).
2. Keep your root `base.css` small:

```css
@import url("my-theme/base.css");
```

3. Ideal `my-theme/base.css` structure:

```css
@import url("../core/structure.css");
@import url("tokens.css");
@import url("../core/core-components.css");
@import url("overrides.css");
```

4. Add targeted component changes in `my-theme/overrides.css`.


### Optional Palette Engine Integration

Even though bundled themes are static by default, the token names and structure are designed with material design principles in mind. This allows you to easily integrate dynamic palette generation tools like Matugen or similar.

To integrate generated palettes, map generated colors into the theme token set.

1. Generate a palette file as `~/.config/hypr-network-manager/themes/colors.css`.
2. Create `~/.config/hypr-network-manager/themes/my-theme/tokens.css` with token mappings.
3. Update `~/.config/hypr-network-manager/themes/my-theme/base.css`:

```css
@import url("../structure.css");
@import url("../colors.css");
@import url("tokens.css");
@import url("../shared-components.css");
```

Matugen example:
As the app follows Material color definitions by default, only custom tokens need to be mapped rather than the full palette.

```css
/*
@define-color surface @surface;
@define-color on_surface @on_surface;
@define-color on_surface_variant @on_surface_variant;
@define-color primary @primary;
@define-color secondary @secondary;
@define-color error @error;
*/
@define-color surface_soft @surface_container_high;
@define-color surface_raised @surface_container_highest;
@define-color success @tertiary;
@define-color action @primary_fixed_dim;
@define-color primary_hover @primary_fixed;
```

Generic engine (non-Material naming such as `color_1`, `color_2`, ...) example:

```css
@define-color surface @color_1;
@define-color surface_soft @color_2;
@define-color surface_raised @color_3;
@define-color on_surface @color_15;
@define-color on_surface_variant @color_8;
@define-color primary @color_6;
@define-color secondary @color_5;
@define-color error @color_9;
@define-color success @color_10;
@define-color action @color_14;
@define-color primary_hover @color_12;
```

Tip: keep token names from `default/tokens.css` stable and only change token-to-palette mappings. That keeps the shared component layer unchanged.

### Supported theming classes

The application assigns these CSS classes in the UI runtime, split into three categories based on their purpose: Structural/Layout, Generic, and Specific functional classes.

#### Structural and Layout Classes

These classes dictate the physical geometry, containers, positioning, padding, and scaffolding of the UI.

<details>
<summary>View Structural and Layout Classes</summary>

| Class | Where it applies |
| --- | --- |
| nm-window | Main app window |
| nm-root | Root container for the popup content |
| nm-status-bar | Top status/header row |
| nm-notebook | Main tab notebook |
| nm-page | Shared page container class |
| nm-page-shell-inset | Main layout margin inset for page grids |
| nm-page-wifi | Wi-Fi page container |
| nm-page-network-details | Shared details page container |
| nm-page-network-edit | Shared edit page container |
| nm-page-saved-profiles | Saved networks page container |
| nm-page-ethernet | Ethernet page container |
| nm-page-vpn | VPN page container |
| nm-toolbar | Page toolbar row |
| nm-separator | Horizontal dividers (1px min-height logic) |
| nm-scroll | Scrolled container |
| nm-scroll-body-inset | Details/Form interior vertical grid container |
| nm-list | ListBox containers for Wi-Fi/Ethernet/VPN lists |
| nm-empty-state | Empty-state placeholder containers |
| nm-content-stack | Stacks that switch list vs empty-state views |
| nm-wifi-row | Wi-Fi list rows |
| nm-device-row | Ethernet and VPN rows |
| nm-row-root | Wi-Fi row vertical container |
| nm-row-content | Wi-Fi row horizontal content container |
| nm-row-info | Wi-Fi row text/info container |
| nm-row-actions | Row actions revealing container |
| nm-row-action-buttons | Horizontal strip of buttons (forget/disconnect) |
| nm-inline-password | Inline Wi-Fi password prompt container |
| nm-inline-password-actions | Inline password action row |
| nm-details-nav-row | Details page top navigation row |
| nm-details-header | Details page icon/title header block |
| nm-details-action-row | Details page action buttons row |
| nm-details-section | Details section wrapper (basic/advanced) |
| nm-details-rows | Details rows container |
| nm-details-item | Vertical details item wrapper |
| blank-window | Dismiss overlay window |
| blank-window-surface | Click-capture surface inside dismiss overlay |

</details>

#### Generic Classes

These classes represent base components or reusable elements without a specific designated functional outcome attached to them. They primarily set shared visuals before specific contextual rules take over.

<details>
<summary>View Generic Classes</summary>

| Class | Where it applies |
| --- | --- |
| nm-button | Shared button base class |
| nm-action-button | Generic generic action button (forget, edit, details, etc) |
| nm-toolbar-action | Generic toolbar button class |
| nm-details-action-button | Buttons inside the details action row |
| row-link-action | Text-style row action role class (connect/disconnect/forget) |
| row-icon-action | Icon-only row action role class (details/open buttons) |
| nm-form-label | Generic form labels |
| nm-sub-label | Secondary row subtitle text |
| nm-details-key | Key label class used in details rows |
| nm-details-value | Value label class used in details rows |
| nm-edit-field-entry | General text entries inside edits (IPv4/6, DNS) |
| nm-edit-dropdown | General dropdown boxes inside edits (methods) |
| nm-password-entry | Password entry base styling |
| nm-placeholder-icon | Empty-state icons |
| nm-placeholder-label | Empty-state labels |
| nm-status-icon | Header icon |
| nm-status-label | Header status text |
| nm-signal-icon | Per-row signal/device icon |
| nm-row-expand-icon | Chevron toggle on list elements |
| nm-inline-password-label | Inline password prompt label |
| nm-inline-password-entry | Inline password input |
| nm-inline-password-revealer | Inline prompt revealer widget |

</details>

#### Specific Functional Classes

These classes target specific behaviors, states, and distinct functional outcomes. They are built to be layered over generic/structural classes.

<details>
<summary>View Specific Functional Classes</summary>

| Class | Where it applies |
| --- | --- |
| nm-toggle-label | "Networking" label near the global switch |
| nm-switch | Global/network switches |
| nm-tab-label | Tab label widgets |
| nm-tabs-menu-button | Dropdown expand button in tabs header |
| nm-tabs-menu-popover | Popover for overflowing tabs/saved networks |
| nm-refresh-button | Refresh button |
| nm-add-button | Add network button |
| nm-section-title | Section title labels |
| nm-connected-indicator | State class for active/connected rows |
| nm-signal-icon-secured | Secured Wi-Fi icon variant class |
| nm-ssid-label | Primary row title text |
| nm-primary-action-button | Primary action button in details page |
| nm-forget-button | "Forget" action button |
| nm-delete-button | "Delete" action button |
| nm-edit-button | "Edit" action button |
| nm-details-button | "Details" action button |
| nm-connect-button | Connect action button |
| nm-disconnect-button | Disconnect action button |
| nm-nav-back | Lightweight back navigation button |
| nm-details-network-title | Network title on details/edit pages |
| nm-details-group-title | Group label for sections like BASIC/ADVANCED |
| nm-edit-section-toggle | Advanced network sections expander button |
| nm-inline-password-cancel | Inline cancel button |
| nm-inline-password-connect | Inline connect button |

</details>

---

## Usage

### Launching the GUI

```bash
hypr-network-manager
```

### CLI Options

```bash
--debug             # Override log level to debug
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
* Detailed ethernet profile configuration

### VPN Tab

* Lists all profiles
* Connect / Disconnect actions supported

### GUI & Layer-Shell

* Layer-shell used for proper Wayland popup placement
* Window dimensions, anchors, and margins configurable

---

## Security

* All communication with NetworkManager is done over D-Bus
* network credentials are handled securely

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

* Check logs for D-Bus connection errors:
  `~/.local/state/hypr-network-manager/hypr-network-manager.log`
* Make sure NetworkManager service is running

---

## Release and Support Policies

See the project policy documents for release lifecycle and maintenance expectations:

* [Changelog](../CHANGELOG.md)
* [Support Policy](../SUPPORT.md)
