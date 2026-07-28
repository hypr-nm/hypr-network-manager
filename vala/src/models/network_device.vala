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
public class NetworkDevice : Object {
    public string name { get; construct set; }
    public string device_path { get; construct set; }
    public uint32 device_type { get; construct set; }
    public uint32 state { get; construct set; }
    public string connection { get; construct set; }
    public string connection_uuid { get; construct set; }

    public bool is_ethernet {
        get {
            return device_type == NM_DEVICE_TYPE_ETHERNET;
        }
    }

    public bool is_wifi {
        get {
            return device_type == NM_DEVICE_TYPE_WIFI;
        }
    }

    public bool is_connected {
        get {
            return state == ((uint32) NM.DeviceState.ACTIVATED);
        }
    }

    public bool is_connecting {
        get {
            return state >= ((uint32) NM.DeviceState.PREPARE) && state < ((uint32) NM.DeviceState.ACTIVATED);
        }
    }

    public string state_label {
        owned get {
            switch (state) {
            case ((uint32) NM.DeviceState.UNMANAGED):
                return _("Unknown");
            case ((uint32) NM.DeviceState.UNAVAILABLE):
                return _("Unavailable");
            case ((uint32) NM.DeviceState.DISCONNECTED):
                return _("Disconnected");
            case ((uint32) NM.DeviceState.PREPARE):
                return _("Preparing");
            case ((uint32) NM.DeviceState.CONFIG):
                return _("Configuring");
            case ((uint32) NM.DeviceState.NEED_AUTH):
                return _("Auth required");
            case ((uint32) NM.DeviceState.IP_CONFIG):
                return _("IP configuring");
            case ((uint32) NM.DeviceState.IP_CHECK):
                return _("IP checking");
            case ((uint32) NM.DeviceState.SECONDARIES):
                return _("Secondaries");
            case ((uint32) NM.DeviceState.ACTIVATED):
                return _("Connected");
            case ((uint32) NM.DeviceState.DEACTIVATING):
                return _("Disconnecting");
            case ((uint32) NM.DeviceState.FAILED):
                return _("Failed");
            default:
                return _("State %u").printf (state);
            }
        }
    }
}
