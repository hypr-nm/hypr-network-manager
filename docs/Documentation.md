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

   * [Palette Engine Integration](#palette-engine-integration)
   * [Waybar Integration](#waybar-integration)
   * [Hyprland Integration](#hyprland-integration)

7. [Development](#development)
8. [Security](#security)
9. [Troubleshooting](#troubleshooting)
10. [Release and Support Policies](#release-and-support-policies)

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

### Nix

Run directly without installing:

```bash
nix run github:hypr-nm/hypr-network-manager
```

Or install into your profile:

```bash
nix profile install github:hypr-nm/hypr-network-manager
```

To start a development shell with all build dependencies:

```bash
nix develop github:hypr-nm/hypr-network-manager
```

If you have a local clone:

```bash
nix run .                # run the application
nix develop              # enter dev shell
```

### Debian / Ubuntu / Other Distros

Use the installer script:

```bash
bash <(curl -sSfL https://raw.githubusercontent.com/hypr-nm/hypr-network-manager/master/setup.sh)
```

Alternatively, the interactive prompt can be skipped by defining the `INSTALL_SCOPE` directly:

```bash
INSTALL_SCOPE=system bash <(curl -sSfL https://raw.githubusercontent.com/hypr-nm/hypr-network-manager/master/setup.sh)
```

or

```bash
INSTALL_SCOPE=user bash <(curl -sSfL https://raw.githubusercontent.com/hypr-nm/hypr-network-manager/master/setup.sh)
```

---

### Dependencies

#### Build

* `meson`, `ninja`, `vala`, `pkg-config`
* `gtk4` (>= 4.12), `gtk4-layer-shell`, `json-glib`, `libsecret`, `libnm` (>= 1.16)
* `libnl-3` and `libnl-genl-3`

#### Runtime

* `gtk4`, `gtk4-layer-shell`, `json-glib`, `libsecret`, `networkmanager`, `libnl-3`, `libnl-genl-3`
* `polkit` (allows passwordless hotspot operations for `wheel`/`sudo` users)

#### Optional Runtime (Wi-Fi Hotspot Internet Sharing)

To enable internet sharing via the vendored `create_ap` script, the following are required:

* `hostapd`, `dnsmasq`, `iptables`, `iproute2`, `iw`, `util-linux`

If these optional tools are not present, hotspot functionality falls back to NetworkManager's built-in hotspot manager.

The install script auto-installs dependencies when supported package managers are available.

### Manual Installation (From Source)

Clone the repository and run the installation script:

```bash
git clone https://github.com/hypr-nm/hypr-network-manager.git
cd hypr-network-manager
./scripts/install.sh
```

The script prompts for the install level for the binary and defaults:

1. **System**: `/usr/local` and `/etc/xdg/hypr-network-manager`
2. **User**: `~/.local` and `~/.config/hypr-network-manager`

The prompt can be bypassed by defining the `INSTALL_SCOPE` environment variable before running the script:

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
  "window_height": 680,
  "layer_shell_layer": "overlay",
  "log_level": "info",
  "position": "top-right",
  "layer_shell_margin_top": 8,
  "layer_shell_margin_right": 8,
  "layer_shell_margin_bottom": 8,
  "layer_shell_margin_left": 8,
  "scan_interval": 30,
  "pending_wifi_connect_timeout_ms": 15000,
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
| window_height | int (> 0) | 680 | Popup window height in pixels. |
| layer_shell_layer | string | overlay | Layer-shell layer. Supported values: `overlay`, `top`, `bottom`, `background`. |
| log_level | string | info | Minimum emitted log severity. Supported values: `debug`, `info`, `warn`, `error`. |
| position | string | top-right | Position preset used for placement anchors. Supported values: `top-left`, `top-right`, `bottom-left`, `bottom-right`, `top`, `right`, `bottom`, `left`. Invalid values fallback to top-right. |
| layer_shell_margin_top | int | 8 | Top margin in pixels. |
| layer_shell_margin_right | int | 8 | Right margin in pixels. |
| layer_shell_margin_bottom | int | 8 | Bottom margin in pixels. |
| layer_shell_margin_left | int | 8 | Left margin in pixels. |
| scan_interval | int (> 0) | 30 | Seconds between periodic refresh/scan cycles. |
| pending_wifi_connect_timeout_ms | int (> 0) | 15000 | Maximum time in milliseconds to wait for a Wi-Fi connection to succeed before timing out. |
| close_on_connect | bool | true | Close popup immediately after successful Wi-Fi connect. |
| show_bssid | bool | false | Show access point BSSID in Wi-Fi row subtitle. |
| show_frequency | bool | true | Show access point frequency in MHz in Wi-Fi row subtitle. |
| show_band | bool | false | Show Wi-Fi band label (`2.4 GHz` or `5 GHz`) derived from AP frequency. |

### Placement behavior

Placement is controlled by `position`, and spacing is controlled by `layer_shell_margin_*`.

The shell enforces a minimum size of `480x680` as that is a reasonable size for readability.

### Notes on extra keys

Keys not listed above are ignored by the current app runtime.

---

## Theming

Themes are CSS files that adjust the app's colors, shapes, spacing, typography, and interaction states. The app always provides the layout and technical widget styling needed for its controls to work correctly. A theme changes the documented variables below instead of rebuilding those styles.

### Where themes are loaded from

The app looks for `base.css` in this order:

1. `~/.config/hypr-network-manager/themes/base.css`
2. `/etc/xdg/hypr-network-manager/themes/base.css`

If neither file exists, the app uses its embedded Default theme, so the interface remains fully styled. When you provide a custom theme, `base.css` is its only required entry point. You may keep everything in that file or split the theme into smaller files. The bundled themes use this optional structure:

* `themes/<name>/base.css` — imports the other files
* `themes/<name>/tokens.css` — colors and other shared values
* `themes/<name>/overrides.css` — component-specific changes

### Creating a theme

1. Create `~/.config/hypr-network-manager/themes/base.css`. For a small theme, you can put all your token changes directly in this file.
2. For a larger theme, create a subdirectory such as `~/.config/hypr-network-manager/themes/custom-theme/`.
3. Make the top-level `base.css` select that theme:

```css
@import url("custom-theme/base.css");
```

1. Inside `custom-theme/base.css`, import any files you want to keep separate:

```css
@import url("tokens.css");
@import url("overrides.css");
```

1. Put the documented variables from this guide in `tokens.css`, `overrides.css`, or directly in either `base.css`. Each import path is resolved relative to the file containing it.

### Customizing the interface

Most changes need only a CSS variable, also called a token. Set a token on `:root` to change every matching component:

```css
:root {
  --nm-button-radius: 6px;
  --nm-field-background: #1e1e2e;
  --nm-row-content-padding: 8px 10px;
}
```

To limit a change, place the token on one of the documented classes. This example makes only the VPN page more compact:

```css
.nm-page-vpn {
  --nm-field-min-height: 26px;
  --nm-row-content-padding: 6px 8px;
}
```

The documented tokens and classes are the supported theming interface. Classes not listed here are used internally and may change between releases. Avoid selectors that reach into a control's internal parts, such as `button > label` or `list > row:last-child`; the app already applies token values to those parts.

#### Available scopes

Use these classes only when a token should affect a particular page or kind of component. Prefix the class name with a dot when writing CSS—for example, `.nm-button`.

| Class | Selects |
| --- | --- |
| `nm-page` | Every app page. |
| `nm-page-wifi` | The main Wi-Fi page. |
| `nm-page-ethernet` | The main Ethernet page. |
| `nm-page-vpn` | The main VPN page. |
| `nm-page-saved-profiles` | The saved-profiles page. |
| `nm-button` | Push buttons and icon buttons. |
| `nm-toolbar-action` | Compact toolbar buttons such as Add and Refresh. |
| `nm-input` | Text, search, password, and inline input fields. |
| `nm-select` | Dropdown/select controls. |
| `nm-switch` | On/off switch controls. |
| `nm-checkbox` | Checkbox controls and their labels. |
| `nm-row` | Main network and profile rows. |
| `nm-data-list` | Grouped lists of information. |
| `nm-data-row` | One record inside a grouped information list. |
| `nm-section` | A titled group on a details or edit page. |

#### Action button scopes

Action buttons also have classes describing where they appear and what they do. A button can match more than one class—for example, a Connect button on a details page matches both `nm-details-action` and `nm-action-connect`.

| Class | Selects |
| --- | --- |
| `nm-action` | Every action button, such as Connect, Edit, or Delete. |
| `nm-row-action` | Text actions shown inside a network or profile row. |
| `nm-row-icon-action` | Compact icon actions shown inside a row. |
| `nm-details-action` | Actions shown on details pages. |
| `nm-action-primary` | The main action on a page. |
| `nm-action-connect` | Connect actions. |
| `nm-action-disconnect` | Disconnect actions. |
| `nm-action-destructive` | Destructive actions such as Forget or Delete. |

#### Action component tokens

Use these tokens to change action colors and borders. "Resting" means the button is visible but is not currently being hovered.

| Token | Affects | Property |
| --- | --- | --- |
| `--nm-action-color` | Any `nm-action` at rest | Text/icon color |
| `--nm-action-hover-color` | Any `nm-action` on hover | Text/icon color |
| `--nm-action-border-color` | Any `nm-action` at rest | Border color |
| `--nm-action-hover-background` | Any `nm-action` on hover | Background |
| `--nm-connect-action-color` | Connect actions at rest | Text/icon color |
| `--nm-connect-action-hover-color` | Connect actions on hover | Text/icon color |
| `--nm-connect-action-border-color` | Connect actions at rest | Border color |
| `--nm-connect-action-hover-background` | Connect actions on hover | Background |
| `--nm-danger-action-color` | Disconnect and destructive actions at rest | Text/icon color |
| `--nm-danger-action-hover-color` | Disconnect and destructive actions on hover | Text/icon color |
| `--nm-danger-action-border-color` | Disconnect and destructive actions at rest | Border color |
| `--nm-danger-action-hover-background` | Disconnect and destructive actions on hover | Background |
| `--nm-row-action-color` | Text actions inside rows at rest | Text/icon color |
| `--nm-row-action-hover-color` | Text actions inside rows on hover | Text/icon color |
| `--nm-row-action-background` | Text actions inside rows at rest | Background |
| `--nm-row-action-hover-background` | Text actions inside rows on hover | Background |
| `--nm-details-action-color` | Details-page actions at rest | Text/icon color |
| `--nm-details-action-hover-color` | Details-page actions on hover | Text/icon color |
| `--nm-details-action-border-color` | Details-page actions at rest | Border color |
| `--nm-details-action-hover-background` | Details-page actions on hover | Background |
| `--nm-details-danger-hover-color` | Destructive details-page actions on hover | Text/icon color |
| `--nm-details-danger-hover-border-color` | Destructive details-page actions on hover | Border color |
| `--nm-details-danger-hover-background` | Destructive details-page actions on hover | Background |
| `--nm-row-icon-action-color` | Icon actions inside rows at rest | Text/icon color |
| `--nm-row-icon-action-hover-color` | Icon actions inside rows on hover | Text/icon color |
| `--nm-row-icon-action-hover-background` | Icon actions inside rows on hover | Background |
| `--nm-row-icon-action-hover-border-color` | Icon actions inside rows on hover | Border color |

##### Examples

Global row action customization:

```css
:root {
  --nm-row-action-color: #89b4fa;
  --nm-row-action-hover-color: #b4d0fb;
}
```

Scoped page customization (only VPN rows change; Wi-Fi/Ethernet stay unchanged):

```css
.nm-page-vpn {
  --nm-row-action-color: #a6e3a1;
  --nm-row-action-hover-color: #c6f0c2;
}
```

Destructive details hover customization:

```css
:root {
  --nm-details-danger-hover-color: #f38ba8;
  --nm-details-danger-hover-background: alpha(#f38ba8, .16);
}
```

#### Component appearance tokens

The remaining tokens control component shape, spacing, typography, surfaces, and interaction states. Set them globally on `:root`, or place them on one of the scopes above when the change should be more specific. Use familiar CSS-style values such as `#89b4fa`, `6px`, `6px 10px`, or a shadow expression.

##### Button tokens

| Token | Category | Affects |
| --- | --- | --- |
| `--nm-button-color` | Visual | Resting text/icon foreground |
| `--nm-button-background` | Visual | Resting surface |
| `--nm-button-border-color` | Visual | Resting border |
| `--nm-button-hover-color` | Visual | Hover text/icon foreground |
| `--nm-button-hover-background` | Visual | Hover surface |
| `--nm-button-hover-border-color` | Visual | Hover border |
| `--nm-button-disabled-color` | Visual | Disabled text/icon foreground |
| `--nm-button-disabled-background` | Visual | Disabled surface |
| `--nm-button-disabled-border-color` | Visual | Disabled border |
| `--nm-button-disabled-opacity` | Visual | Disabled component opacity |
| `--nm-button-radius` | Geometry | Shape |
| `--nm-button-border-width` | Geometry | Border width |
| `--nm-button-min-height` | Geometry | Minimum height |
| `--nm-button-padding` | Geometry | Content inset |
| `--nm-button-shadow` | Visual | Resting shadow |
| `--nm-button-font-size` | Typography | Label size |
| `--nm-button-font-weight` | Typography | Label weight |
| `--nm-button-letter-spacing` | Typography | Label tracking |

The action tokens above control action colors and borders. These general button tokens control shape, spacing, shadow, and typography.

Toolbar actions such as **Add network** and **Refresh** use a compact, flat context rather than the generic pill surface:

| Token | Category | Affects |
| --- | --- | --- |
| `--nm-toolbar-action-color` | Visual | Resting foreground |
| `--nm-toolbar-action-background` | Visual | Resting surface |
| `--nm-toolbar-action-border-color` | Visual | Resting border |
| `--nm-toolbar-action-hover-color` | Visual | Hover foreground |
| `--nm-toolbar-action-hover-background` | Visual | Hover surface |
| `--nm-toolbar-action-hover-border-color` | Visual | Hover border |
| `--nm-toolbar-action-disabled-color` | Visual | Disabled foreground |
| `--nm-toolbar-action-disabled-background` | Visual | Disabled surface |
| `--nm-toolbar-action-disabled-border-color` | Visual | Disabled border |
| `--nm-toolbar-action-radius` | Geometry | Toolbar button shape |
| `--nm-toolbar-action-min-height` | Geometry | Minimum height |
| `--nm-toolbar-action-padding` | Geometry | Content inset |

##### Field tokens (shared by `nm-input` and `nm-select`)

| Token | Category | Affects |
| --- | --- | --- |
| `--nm-field-color` | Visual | Resting input/select foreground |
| `--nm-field-background` | Visual | Resting surface |
| `--nm-field-border-color` | Visual | Resting border |
| `--nm-field-focus-border-color` | Visual | Input focus or select open/focus border |
| `--nm-field-focus-background` | Visual | Focus/open surface |
| `--nm-field-disabled-color` | Visual | Disabled foreground |
| `--nm-field-disabled-opacity` | Visual | Disabled component opacity |
| `--nm-field-radius` | Geometry | Input/select shape |
| `--nm-field-border-width` | Geometry | Outer border width |
| `--nm-field-min-height` | Geometry | Minimum control height |
| `--nm-field-padding` | Geometry | Content inset |
| `--nm-field-shadow` | Visual | Resting shadow |
| `--nm-field-focus-shadow` | Visual | Focus/open ring or shadow |

Inputs and selects share these tokens. The app applies them to the visible parts of each control, including a select's trigger and popover.

##### Switch tokens

These tokens style the switch track and the movable thumb. "Active" means the switch is on.

| Token | Category | Affects |
| --- | --- | --- |
| `--nm-switch-background` | Visual | Resting track background |
| `--nm-switch-border-color` | Visual | Resting track border |
| `--nm-switch-hover-background` | Visual | Track background on hover |
| `--nm-switch-hover-border-color` | Visual | Track border on hover |
| `--nm-switch-active-background` | Visual | Active track background |
| `--nm-switch-active-border-color` | Visual | Active track border |
| `--nm-switch-active-hover-background` | Visual | Active track background on hover |
| `--nm-switch-active-hover-border-color` | Visual | Active track border on hover |
| `--nm-switch-thumb-color` | Visual | Resting thumb color |
| `--nm-switch-active-thumb-color` | Visual | Active thumb color |
| `--nm-switch-disabled-background` | Visual | Disabled track background |
| `--nm-switch-disabled-border-color` | Visual | Disabled track border |
| `--nm-switch-disabled-thumb-color` | Visual | Disabled thumb color |
| `--nm-switch-active-disabled-background` | Visual | Disabled active track background |
| `--nm-switch-active-disabled-border-color` | Visual | Disabled active track border |
| `--nm-switch-active-disabled-thumb-color` | Visual | Disabled active thumb color |
| `--nm-switch-disabled-opacity` | Visual | Disabled switch opacity |
| `--nm-switch-radius` | Geometry | Track shape |
| `--nm-switch-border-width` | Geometry | Track border width |
| `--nm-switch-min-width` | Geometry | Minimum track width |
| `--nm-switch-min-height` | Geometry | Minimum track height |
| `--nm-switch-padding` | Geometry | Space inside the track |
| `--nm-switch-shadow` | Visual | Resting track shadow |
| `--nm-switch-hover-shadow` | Visual | Track shadow on hover |
| `--nm-switch-focus-shadow` | Visual | Keyboard-focus ring or shadow |
| `--nm-switch-thumb-size` | Geometry | Thumb width and height |
| `--nm-switch-thumb-radius` | Geometry | Thumb shape |
| `--nm-switch-thumb-shadow` | Visual | Thumb shadow |

##### Checkbox tokens

Checkbox tokens cover the label, box, checkmark, interaction states, sizing, and typography.

| Token | Category | Affects |
| --- | --- | --- |
| `--nm-checkbox-color` | Visual | Resting label color |
| `--nm-checkbox-hover-color` | Visual | Label color on hover |
| `--nm-checkbox-checked-color` | Visual | Checked label color |
| `--nm-checkbox-checked-hover-color` | Visual | Checked label color on hover |
| `--nm-checkbox-background` | Visual | Resting box background |
| `--nm-checkbox-border-color` | Visual | Resting box border |
| `--nm-checkbox-hover-background` | Visual | Box background on hover |
| `--nm-checkbox-hover-border-color` | Visual | Box border on hover |
| `--nm-checkbox-checked-background` | Visual | Checked box background |
| `--nm-checkbox-checked-border-color` | Visual | Checked box border |
| `--nm-checkbox-checkmark-color` | Visual | Checkmark color |
| `--nm-checkbox-checked-hover-background` | Visual | Checked box background on hover |
| `--nm-checkbox-checked-hover-border-color` | Visual | Checked box border on hover |
| `--nm-checkbox-checked-hover-checkmark-color` | Visual | Checkmark color on hover |
| `--nm-checkbox-disabled-color` | Visual | Disabled label color |
| `--nm-checkbox-disabled-background` | Visual | Disabled box background |
| `--nm-checkbox-disabled-border-color` | Visual | Disabled box border |
| `--nm-checkbox-disabled-checkmark-color` | Visual | Disabled checkmark color |
| `--nm-checkbox-checked-disabled-background` | Visual | Disabled checked box background |
| `--nm-checkbox-checked-disabled-border-color` | Visual | Disabled checked box border |
| `--nm-checkbox-checked-disabled-checkmark-color` | Visual | Disabled checked checkmark color |
| `--nm-checkbox-disabled-opacity` | Visual | Disabled checkbox opacity |
| `--nm-checkbox-radius` | Geometry | Box shape |
| `--nm-checkbox-border-width` | Geometry | Box border width |
| `--nm-checkbox-box-size` | Geometry | Box width and height |
| `--nm-checkbox-min-height` | Geometry | Minimum height of the full control |
| `--nm-checkbox-padding` | Geometry | Outer content inset |
| `--nm-checkbox-label-gap` | Geometry | Space between box and label |
| `--nm-checkbox-shadow` | Visual | Resting box shadow |
| `--nm-checkbox-hover-shadow` | Visual | Box shadow on hover |
| `--nm-checkbox-focus-shadow` | Visual | Keyboard-focus ring or shadow |
| `--nm-checkbox-font-size` | Typography | Label size |
| `--nm-checkbox-font-weight` | Typography | Label weight |
| `--nm-checkbox-letter-spacing` | Typography | Label tracking |

##### Primary row tokens

| Token | Category | Affects |
| --- | --- | --- |
| `--nm-row-background` | Visual | Resting surface |
| `--nm-row-hover-background` | Visual | Hover surface |
| `--nm-row-connected-background` | Visual | Connected surface |
| `--nm-row-border-color` | Visual | Resting border |
| `--nm-row-hover-border-color` | Visual | Hover border |
| `--nm-row-connected-border-color` | Visual | Connected border |
| `--nm-row-radius` | Geometry | Shape |
| `--nm-row-border-width` | Geometry | Border width |
| `--nm-row-shadow` | Visual | Resting shadow |
| `--nm-row-outer-margin` | Geometry | Row separation/page inset |
| `--nm-row-content-padding` | Geometry | Main content inset |
| `--nm-row-actions-padding` | Geometry | Expanded action-strip inset |

##### Data list / row tokens

| Token | Category | Affects |
| --- | --- | --- |
| `--nm-data-list-background` | Visual | Grouped-list surface |
| `--nm-data-list-border-color` | Visual | Grouped-list outer border |
| `--nm-data-list-radius` | Geometry | Grouped-list shape |
| `--nm-data-list-shadow` | Visual | Grouped-list shadow |
| `--nm-data-row-background` | Visual | Record resting surface |
| `--nm-data-row-hover-background` | Visual | Record hover surface |
| `--nm-data-row-divider-color` | Visual | Divider between records |
| `--nm-data-row-padding` | Geometry | Record content inset |

##### Section tokens

| Token | Category | Affects |
| --- | --- | --- |
| `--nm-section-background` | Visual | Section surface |
| `--nm-section-border-color` | Visual | Section border |
| `--nm-section-border-width` | Geometry | Section border width |
| `--nm-section-radius` | Geometry | Section shape |
| `--nm-section-shadow` | Visual | Section shadow |
| `--nm-section-padding` | Geometry | Section content inset |

Setting `--nm-section-padding` gives details sections and expandable edit sections the same inset.

##### Appearance examples

Flat, square controls:

```css
:root {
  --nm-button-radius: 0;
  --nm-field-radius: 0;
  --nm-row-radius: 0;
  --nm-data-list-radius: 0;
  --nm-section-radius: 0;
}
```

Rounded buttons and selects:

```css
:root {
  --nm-button-radius: 999px;
}

.nm-select {
  --nm-field-radius: 999px;
}
```

Square switches and checkboxes with stronger hover feedback:

```css
:root {
  --nm-switch-radius: 3px;
  --nm-switch-thumb-radius: 2px;
  --nm-switch-hover-border-color: #89b4fa;
  --nm-checkbox-radius: 2px;
  --nm-checkbox-hover-border-color: #89b4fa;
  --nm-checkbox-checked-background: #89b4fa;
}
```

Card-like rows and sections:

```css
:root {
  --nm-row-radius: 14px;
  --nm-row-shadow: 0 4px 14px alpha(#000000, .18);
  --nm-section-background: var(--surface_soft);
  --nm-section-border-width: 1px;
  --nm-section-border-color: var(--line);
  --nm-section-radius: 14px;
  --nm-section-shadow: 0 4px 16px alpha(#000000, .12);
}
```

Compact density scoped to the VPN page only:

```css
.nm-page-vpn {
  --nm-button-min-height: 24px;
  --nm-field-min-height: 26px;
  --nm-field-padding: 4px 8px;
  --nm-row-content-padding: 6px 8px;
  --nm-data-row-padding: 7px 10px;
}
```

Select-only specialization via a scoped field token:

```css
.nm-select {
  --nm-field-radius: 999px;
}
```

Input-only specialization without affecting selects:

```css
.nm-input {
  --nm-field-background: var(--surface_soft);
  --nm-field-border-color: var(--line_strong);
  --nm-field-radius: 2px;
}
```

---

## Usage

### Launching the GUI

```bash
hypr-network-manager
```

### CLI Options

```bash
--debug             # Override log level to debug
--status            # Output JSON status of current network state.
--toggle-wifi       # Toggle Wi-Fi on/off
--quit              # Terminate the daemon and exit
```

---

## Integration

### Palette Engine Integration

Bundled themes use standard CSS variables under the `:root` pseudo-class. This allows for easy integration with dynamic palette generation tools like Matugen, Pywal, or similar.

To integrate generated palettes, you should import your generated colors into your theme's `tokens.css` (or `base.css`). Ensure that the **derived variables** (like `--text`, `--hover_soft`, etc.) and typography settings remain intact.

1. Generate a palette file as `~/.config/hypr-network-manager/themes/colors.css`.
2. Create `~/.config/hypr-network-manager/themes/custom-theme/tokens.css` that imports the colors and defines the derived variables.
3. Update `~/.config/hypr-network-manager/themes/custom-theme/base.css`:

```css
/* Import your tokens (which now include the dynamic colors) */
@import url("tokens.css");
@import url("overrides.css");
```

#### Matugen Example

1. Create a Matugen template (`~/.config/matugen/templates/colors.css`) that outputs standard CSS variables, including mapping the custom UI-specific tokens directly:

```css
/*
* Css Colors
* Generated with Matugen
*/
:root {
  --blur_background: {{colors.surface.default.rgba | set_alpha: 0.3}};
  --blur_background8: {{colors.surface.default.rgba | set_alpha: 0.8}};

  /* Material Base Colors */
<* for name, value in colors *>
  --{{name}}: {{value.default.hex}};
<* endfor *>

  /* Custom UI-specific mappings */
  --surface_soft: {{colors.surface_container_high.default.hex}};
  --surface_raised: {{colors.surface_container_highest.default.hex}};
  --success: {{colors.tertiary.default.hex}};
  --action: {{colors.primary_fixed_dim.default.hex}};
  --primary_hover: {{colors.primary_fixed.default.hex}};
}
```

1. Add the template to the Matugen configuration (`~/.config/matugen/config.toml`):

```toml
[templates.hypr-network-manager]
input_path = '~/.config/matugen/templates/colors.css'
output_path = '~/.config/hypr-network-manager/themes/colors.css'
```

1. In the theme directory, import the generated `colors.css` into your `tokens.css` and keep the derived variables:

```css
/* ~/.config/hypr-network-manager/themes/custom-theme/tokens.css */

@import url("../colors.css");

:root {
  /* Derived variables */
  --text: var(--on_surface);
  --background-alt: alpha(var(--surface), .4);
  --selected: var(--primary);
  --hover: alpha(var(--secondary), .16);
  --urgent: var(--error);

  --line: alpha(var(--on_surface), .13);
  --line_strong: alpha(var(--on_surface), .24);
  --active: alpha(var(--secondary), .22);
  --hover_soft: alpha(var(--secondary), .11);
  --hover_row: alpha(var(--secondary), .06);
  --selected_soft: alpha(var(--secondary), .09);
}

* {
  color: var(--text);
  font-size: 14px;
  font-family: "JetBrains Mono Nerd Font 10", sans-serif;
}
```

#### Generic Engine Example

For engines with non-Material naming, create a similar `tokens.css` mapping those colors to the required base variables:

```css
/* ~/.config/hypr-network-manager/themes/custom-theme/tokens.css */

@import url("../colors.css");

:root {
  /* Map generic variables to application base variables */
  --surface: var(--color1);
  --surface_soft: var(--color2);
  --surface_raised: var(--color3);
  --on_surface: var(--color15);
  --on_surface_variant: var(--color8);
  --primary: var(--color6);
  --secondary: var(--color5);
  --error: var(--color9);
  --success: var(--color10);
  --action: var(--color14);
  --primary_hover: var(--color12);

  /* Derived variables */
  --text: var(--on_surface);
  --background-alt: alpha(var(--surface), .4);
  --selected: var(--primary);
  --hover: alpha(var(--secondary), .16);
  --urgent: var(--error);
  --line: alpha(var(--on_surface), .13);
  --line_strong: alpha(var(--on_surface), .24);
  --active: alpha(var(--secondary), .22);
  --hover_soft: alpha(var(--secondary), .11);
  --hover_row: alpha(var(--secondary), .06);
  --selected_soft: alpha(var(--secondary), .09);
}

* {
  color: var(--text);
  font-size: 14px;
  font-family: sans-serif;
}
```

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

Keep `on-click` as a plain `hypr-network-manager` invocation. The first invocation
stays resident, and later clicks activate the existing application instead of
creating another instance.

If you want the application ready before the first click, start it once from your
Hyprland configuration:

```conf
exec-once = hypr-network-manager --daemon
```

`--daemon` starts the resident application without showing its window initially. It should not be added to the Waybar click command.

### Hyprland Integration

For blur on this app's layer-shell surface namespace, add this rule:

```conf
layerrule = match:namespace ^(hypr-network-manager)$, blur on
```

---

## Development

### Dependencies

See the [Build Dependencies](#build) under the Installation section.

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

## Security

* Network configuration and management is performed through NetworkManager over D-Bus
* Information related with Hotspot are read directly from the kernel through `nl80211`.
* Hotspot passwords are stored in Secret Service when available.

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
