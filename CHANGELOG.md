# Changelog

All notable changes to this project are documented in this file.

## [0.1.1] - 2026-04-29

### Added
- **Theming:** Built-in `catppuccin` theme (contributed by @alba4k)
- **Logging:** File-based logging with configurable levels  
- **CLI Utilities:** `--version` for version info, `--quit` to stop the daemon  

### Changed
- **UI/UX:** Stabilized Wi-Fi list rendering and improved network sorting priority  
- **UI/UX:** Disabled controls (Wi-Fi toggle, Add Network, refresh) when Flight Mode or adapter is off  
- **UI/UX:** Replaced combined lock icons with signal icon + padlock indicator  
- **UI/UX:** Added password visibility toggle in Add Network  
- **UI/UX:** Moved Flight Mode toggle to “More actions” menu  
- **Theming Architecture:** Switched to CSS variables

### Fixed
- **Ghost Networks:** Removed out-of-range saved profiles from available networks  
- **Popup/Focus Handling:** Fixed keyboard focus loss and improved click-away dismissal
- **Menu States:** Corrected stale active tab states  
- **Expand/Collapse Icons:** Fixed swapped arrow indicators  
- **Security:** Prevented recursion and directory traversal in CSS inliner

## [0.1.0] - 2026-04-17

### Added
- Initial public release of the `hypr-network-manager`.
- Comprehensive core network management: Wi-Fi, Ethernet, and VPN profiles.
