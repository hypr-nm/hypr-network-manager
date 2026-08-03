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

using Constants;
namespace HyprNetworkManager.Backend.Mappers {
    public class DeviceMapper : GLib.Object {
        public static NetworkDeviceKind map_device_type (uint32 nm_device_type) {
            if (nm_device_type == NM_DEVICE_TYPE_WIFI) {
                return NetworkDeviceKind.WIFI;
            } else if (nm_device_type == NM_DEVICE_TYPE_ETHERNET) {
                return NetworkDeviceKind.ETHERNET;
            }
            return NetworkDeviceKind.UNKNOWN;
        }

        public static DeviceState map_device_state (NM.DeviceState nm_state) {
            switch (nm_state) {
                case NM.DeviceState.UNKNOWN: return DeviceState.UNKNOWN;
                case NM.DeviceState.UNMANAGED: return DeviceState.UNMANAGED;
                case NM.DeviceState.UNAVAILABLE: return DeviceState.UNAVAILABLE;
                case NM.DeviceState.DISCONNECTED: return DeviceState.DISCONNECTED;
                case NM.DeviceState.PREPARE: return DeviceState.PREPARE;
                case NM.DeviceState.CONFIG: return DeviceState.CONFIG;
                case NM.DeviceState.NEED_AUTH: return DeviceState.NEED_AUTH;
                case NM.DeviceState.IP_CONFIG: return DeviceState.IP_CONFIG;
                case NM.DeviceState.IP_CHECK: return DeviceState.IP_CHECK;
                case NM.DeviceState.SECONDARIES: return DeviceState.SECONDARIES;
                case NM.DeviceState.ACTIVATED: return DeviceState.ACTIVATED;
                case NM.DeviceState.DEACTIVATING: return DeviceState.DEACTIVATING;
                case NM.DeviceState.FAILED: return DeviceState.FAILED;
                default: return DeviceState.UNKNOWN;
            }
        }

        public static bool is_connecting_state (DeviceState state) {
            return state == DeviceState.PREPARE
                || state == DeviceState.CONFIG
                || state == DeviceState.NEED_AUTH
                || state == DeviceState.IP_CONFIG
                || state == DeviceState.IP_CHECK
                || state == DeviceState.SECONDARIES;
        }

        public static NetworkDevice map_device (NM.Device dev) {
            NetworkDeviceKind kind = map_device_type (dev.get_device_type ());
            DeviceState state = map_device_state (dev.get_state ());
            var d = new NetworkDevice () {
                name = dev.get_iface () ?? "",
                device_path = ((NM.Object)dev).get_path () ?? "",
                kind = kind,
                state = state,
                connection = "",
                connection_uuid = "",
                is_ethernet = kind == NetworkDeviceKind.ETHERNET,
                is_wifi = kind == NetworkDeviceKind.WIFI,
                is_connected = state == DeviceState.ACTIVATED,
                is_connecting = is_connecting_state (state),
                is_available = state != DeviceState.UNMANAGED && state != DeviceState.UNAVAILABLE
            };

            var ac = dev.get_active_connection ();
            if (ac != null) {
                d.connection = ac.get_id () ?? "";
                d.connection_uuid = ac.get_uuid () ?? "";
            }
            return d;
        }
    }
}
