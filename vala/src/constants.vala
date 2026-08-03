/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

const string APP_VERSION = "0.2.0";
const string NM_SERVICE = "org.freedesktop.NetworkManager";
const string NM_PATH = "/org/freedesktop/NetworkManager";
const string NM_IFACE = "org.freedesktop.NetworkManager";
const string DBUS_PROPS_IFACE = "org.freedesktop.DBus.Properties";
const string NM_DEVICE_IFACE = "org.freedesktop.NetworkManager.Device";
const string NM_WIRELESS_IFACE = "org.freedesktop.NetworkManager.Device.Wireless";
const string NM_AP_IFACE = "org.freedesktop.NetworkManager.AccessPoint";
const string NM_ACTIVE_CONN_IFACE = "org.freedesktop.NetworkManager.Connection.Active";
const string NM_IP4_CONFIG_IFACE = "org.freedesktop.NetworkManager.IP4Config";
const string NM_IP6_CONFIG_IFACE = "org.freedesktop.NetworkManager.IP6Config";
const string NM_SETTINGS_PATH = "/org/freedesktop/NetworkManager/Settings";
const string NM_SETTINGS_IFACE = "org.freedesktop.NetworkManager.Settings";
const string NM_CONN_IFACE = "org.freedesktop.NetworkManager.Settings.Connection";
const int NM_DBUS_TIMEOUT_MS = 20000;
const uint32 NM_DEVICE_TYPE_ETHERNET = 1;
const uint32 NM_DEVICE_TYPE_WIFI = 2;
const uint32 NM_80211_AP_SEC_KEY_MGMT_PSK = 0x00000100;
const uint32 NM_80211_AP_SEC_KEY_MGMT_SAE = 0x00000400;
const uint32 NM_DAEMON_TIMEOUT_MS = 2000;

namespace Constants {
    namespace VpnState {
        public const string ACTIVATED = "activated";
        public const string CONNECTED = "connected";
        public const string ACTIVATING = "activating";
        public const string DEACTIVATING = "deactivating";
        public const string DEACTIVATED = "deactivated";
        public const string UNKNOWN = "unknown";
    }

    namespace WifiKeyMgmt {
        public const string NONE = "none";
        public const string WPA_PSK = "wpa-psk";
        public const string SAE = "sae";
        public const string WPA_EAP = "wpa-eap";
        public const string OWE = "owe";
    }

    namespace WifiSecurity {
        public const string OPEN = "open";
        public const string WEP = "wep";
    }

    namespace WifiBand {
        public const string BAND_2GHZ = "bg";
        public const string BAND_5GHZ = "a";
    }

    namespace EapMethod {
        public const string PEAP = "peap";
        public const string TLS = "tls";
        public const string TTLS = "ttls";
        public const string PWD = "pwd";
    }

    namespace Phase2Auth {
        public const string MSCHAPV2 = "mschapv2";
        public const string MD5 = "md5";
        public const string GTC = "gtc";
        public const string PAP = "pap";
        public const string CHAP = "chap";
    }

    namespace IpMethod {
        public const string AUTO = "auto";
        public const string MANUAL = "manual";
        public const string DISABLED = "disabled";
        public const string SHARED = "shared";
        public const string LINK_LOCAL = "link-local";
        public const string IGNORE = "ignore";
        public const string DHCP = "dhcp";
    }

    namespace VpnType {
        public const string WIREGUARD = "wireguard";
        public const string OPENVPN = "openvpn";
        public const string GENERIC = "vpn";
        public const string TUN = "tun";
        public const string IP_TUNNEL = "ip-tunnel";
    }

    namespace ConnectionType {
        public const string WIFI_ALIAS = "wifi";
    }

    namespace NetworkInterface {
        public const string AUTO = "Auto";
        public const string NONE = "None";
        public const string LOOPBACK = "lo";
    }

    namespace AppPage {
        public const string LIST = "list";
        public const string DETAILS = "details";
        public const string EDIT = "edit";
        public const string ADD = "add";
        public const string SETUP = "setup";
        public const string SHARE = "share";
        public const string SAVED = "saved";
        public const string SAVED_EDIT = "saved-edit";
        public const string PEER_EDIT = "peer_edit";
        public const string HOTSPOT = "hotspot";
        public const string HOTSPOT_ACTIVE = "hotspot-active";
        public const string MAIN = "main";
        public const string PROFILES = "profiles";
        public const string VPN = "vpn";
        public const string EMPTY = "empty";
    }

    namespace WifiState {
        public const string FLIGHT_MODE = "flight-mode";
        public const string DISABLED = "wifi-disabled";
    }

    namespace WifiMode {
        public const string AP = "ap";
    }

    namespace Protocol {
        public const string TCP = "tcp";
        public const string UDP = "udp";
    }

    namespace HotspotMarker {
        public const string READY = "ready";
    }

    namespace HotspotSecurityIndex {
        public const uint SAE = 0;
        public const uint WPA_PSK = 1;
        public const uint NONE = 2;
    }

    namespace HotspotTimeoutIndex {
        public const uint DISABLED = 0;
        public const uint FIVE_MINUTES = 1;
        public const uint TEN_MINUTES = 2;
        public const uint THIRTY_MINUTES = 3;
        public const uint SIXTY_MINUTES = 4;
    }

    namespace HotspotTimeout {
        public const int DISABLED = 0;
        public const int FIVE_MINUTES = 5;
        public const int TEN_MINUTES = 10;
        public const int THIRTY_MINUTES = 30;
        public const int SIXTY_MINUTES = 60;

        public bool is_valid (int minutes) {
            return minutes == DISABLED
                || minutes == FIVE_MINUTES
                || minutes == TEN_MINUTES
                || minutes == THIRTY_MINUTES
                || minutes == SIXTY_MINUTES;
        }
    }

    namespace HotspotCredential {
        public const int SSID_MAX_BYTES = 32;
        public const int PASSPHRASE_MIN_BYTES = 8;
        public const int PASSPHRASE_MAX_BYTES = 63;
        public const int WPA_PSK_HEX_BYTES = 64;
        public const char PRINTABLE_ASCII_MIN = ' ';
        public const char PRINTABLE_ASCII_MAX = '~';
    }

    namespace Keyval {
        public const string ESCAPE = "Escape";
    }

    namespace CssFile {
        public const string STRUCTURE = "structure.css";
        public const string CORE_COMPONENTS = "core-components.css";
    }

    namespace LayerShellAnchor {
        public const string TOP = "top";
        public const string BOTTOM = "bottom";
        public const string LEFT = "left";
        public const string RIGHT = "right";
        public const string TOP_LEFT = "top-left";
        public const string TOP_RIGHT = "top-right";
        public const string BOTTOM_LEFT = "bottom-left";
        public const string BOTTOM_RIGHT = "bottom-right";
    }

    namespace LayerShellLayer {
        public const string BACKGROUND = "background";
        public const string BOTTOM = "bottom";
        public const string TOP = "top";
        public const string OVERLAY = "overlay";
    }

    namespace LogLevel {
        public const string DEBUG = "debug";
        public const string INFO = "info";
        public const string MESSAGE = "message";
        public const string WARN = "warn";
        public const string WARNING = "warning";
        public const string ERROR = "error";
        public const string CRITICAL = "critical";
    }

    public class WifiFreq {
        public const uint32 BAND_2GHZ_MIN = 2412;
        public const uint32 BAND_2GHZ_MAX = 2484;
        public const uint32 BAND_5GHZ_MIN = 5000;
        public const uint32 CHANNEL_14 = 2484;
        public const uint32 CHANNEL_STEP = 5;
    }

    public class WifiChannel {
        public const int DEFAULT_2GHZ = 6;
        public const int DEFAULT_5GHZ = 36;
        public const int CHANNEL_14 = 14;
    }

    public class DropdownIndex {
        public const uint AUTO = 0;
        public const uint NONE = 1;
    }

    public class IpMethodIndex {
        public const uint AUTO = 0;
        public const uint MANUAL = 1;
        public const uint DISABLED = 2;
        public const uint IGNORE = 3;
    }

    public class Timeouts {
        public const uint HOTSPOT_IDLE_CHECK_SECONDS = 60;
        public const uint HOTSPOT_STATUS_POLL_SECONDS = 3;
        public const int CREATE_AP_MAX_ATTEMPTS = 30;
        public const int CREATE_AP_STABLE_POLLS = 4;
        public const uint AP_MONITOR_POLL_INTERVAL_MS = 500;
        public const uint AP_ACTIVATION_TIMEOUT_MS = 10000;
        public const uint ERROR_HIDE_DELAY_MS = 5000;
        public const uint DEFAULT_SCAN_INTERVAL_SECONDS = 30;
        public const uint PENDING_WIFI_CONNECT_TIMEOUT_MS = 45000;
    }

    public class Misc {
        public const int CREATE_AP_LOG_TAIL_LINES = 8;
    }
}
