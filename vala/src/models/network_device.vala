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

public enum NetworkDeviceKind {
    UNKNOWN,
    ETHERNET,
    WIFI
}

public enum DeviceState {
    UNKNOWN,
    UNMANAGED,
    UNAVAILABLE,
    DISCONNECTED,
    PREPARE,
    CONFIG,
    NEED_AUTH,
    IP_CONFIG,
    IP_CHECK,
    SECONDARIES,
    ACTIVATED,
    DEACTIVATING,
    FAILED
}

public class NetworkDevice : GLib.Object {
    public string name { get; construct set; }
    public string device_path { get; construct set; }
    public NetworkDeviceKind kind { get; construct set; }
    public DeviceState state { get; construct set; }
    public string connection { get; construct set; }
    public string connection_uuid { get; construct set; }
    public bool is_ethernet { get; construct set; }
    public bool is_wifi { get; construct set; }
    public bool is_connected { get; construct set; }
    public bool is_connecting { get; construct set; }
    public bool is_available { get; construct set; }
}
