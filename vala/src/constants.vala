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
const uint32 NM_DEVICE_STATE_UNAVAILABLE = 20;
const uint32 NM_DEVICE_STATE_DISCONNECTED = 30;
const uint32 NM_DEVICE_STATE_ACTIVATED = 100;
const uint32 NM_DEVICE_STATE_FAILED = 120;
const uint32 NM_80211_AP_SEC_KEY_MGMT_PSK = 0x00000100;
const uint32 NM_80211_AP_SEC_KEY_MGMT_SAE = 0x00000400;
const uint32 NM_DAEMON_TIMEOUT_MS = 2000;
