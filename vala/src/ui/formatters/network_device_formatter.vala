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

using GLib;
using HyprNetworkManager.Models;

namespace HyprNetworkManager.UI.Formatters {
    public class NetworkDeviceFormatter {
        public static string get_state_label (DeviceState state) {
            switch (state) {
                case DeviceState.UNKNOWN:
                case DeviceState.UNMANAGED:
                    return _("Unknown");
                case DeviceState.UNAVAILABLE:
                    return _("Unavailable");
                case DeviceState.DISCONNECTED:
                    return _("Disconnected");
                case DeviceState.PREPARE:
                    return _("Preparing");
                case DeviceState.CONFIG:
                    return _("Configuring");
                case DeviceState.NEED_AUTH:
                    return _("Auth required");
                case DeviceState.IP_CONFIG:
                    return _("IP configuring");
                case DeviceState.IP_CHECK:
                    return _("IP checking");
                case DeviceState.SECONDARIES:
                    return _("Secondaries");
                case DeviceState.ACTIVATED:
                    return _("Connected");
                case DeviceState.DEACTIVATING:
                    return _("Disconnecting");
                case DeviceState.FAILED:
                    return _("Failed");
                default:
                    return _("State %d").printf ((int) state);
            }
        }

        public static string get_state_identifier (DeviceState state) {
            switch (state) {
                case DeviceState.UNMANAGED:
                    return "unmanaged";
                case DeviceState.UNAVAILABLE:
                    return "unavailable";
                case DeviceState.DISCONNECTED:
                    return "disconnected";
                case DeviceState.PREPARE:
                    return "preparing";
                case DeviceState.CONFIG:
                    return "configuring";
                case DeviceState.NEED_AUTH:
                    return "authentication-required";
                case DeviceState.IP_CONFIG:
                    return "ip-configuring";
                case DeviceState.IP_CHECK:
                    return "ip-checking";
                case DeviceState.SECONDARIES:
                    return "secondaries";
                case DeviceState.ACTIVATED:
                    return "connected";
                case DeviceState.DEACTIVATING:
                    return "deactivating";
                case DeviceState.FAILED:
                    return "failed";
                default:
                    return "unknown";
            }
        }
    }
}
