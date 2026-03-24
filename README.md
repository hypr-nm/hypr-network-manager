# hypr-network-manager

A lightweight, themeable network manager applet for Wayland compositors such as Hyprland and Sway.

Built with **Vala + GTK 4**, the app uses **layer-shell** for native popup-style placement and interacts with NetworkManager directly over **D-Bus**.

---

## Documentation

A detailed documentation is available [here](./docs/Documentation.md), sectioned by each component of the project, including GUI, D-Bus interactions, theming, configuration, and Waybar/eww integrations.

---

## Getting Started

The best way to get started is to check out the [Documentation](#documentation) for step-by-step instructions, setup guides, and examples.

---

## Features

* **Wi-Fi**: Scan networks, connect (saved or new), disconnect, and forget networks
* **Ethernet**: View status and disconnect wired devices
* **VPN**: List, connect, and disconnect VPN profiles
* **Theming**: CSS-based themes with hot-swapping (no rebuild required)
* **Configurable**: JSON config for layout, behavior, and appearance

---

## Security

* All communication with NetworkManager is done via D-Bus
* No passwords are exposed via CLI arguments or subprocesses
* WPA credentials are passed securely using NetworkManager APIs

---

## License

This project is licensed under GPL-3.0.

Some UI behavior is adapted from SwayNotificationCenter. See `THIRD_PARTY_NOTICES.md` for details.

---

## Contributing

Contributions are welcome. Open an issue or submit a pull request for improvements, bug fixes, or new features.
