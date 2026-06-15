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
            return state == NM_DEVICE_STATE_ACTIVATED;
        }
    }

    public bool is_connecting {
        get {
            return state >= 40 && state < NM_DEVICE_STATE_ACTIVATED;
        }
    }

    public string state_label {
        owned get {
            switch (state) {
            case 10:
                return _("Unknown");
            case 20:
                return _("Unavailable");
            case 30:
                return _("Disconnected");
            case 40:
                return _("Preparing");
            case 50:
                return _("Configuring");
            case 60:
                return _("Auth required");
            case 70:
                return _("IP configuring");
            case 80:
                return _("IP checking");
            case 90:
                return _("Secondaries");
            case 100:
                return _("Connected");
            case 110:
                return _("Disconnecting");
            case 120:
                return _("Failed");
            default:
                return _("State %u").printf (state);
            }
        }
    }
}
