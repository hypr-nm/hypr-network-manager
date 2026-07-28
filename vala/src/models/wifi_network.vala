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
public class WifiNetwork : Object {
    public string ssid { get; construct set; }
    public string saved_connection_uuid { get; construct set; }
    public uint8 signal { get; construct set; }
    public bool connected { get; construct set; }
        private bool _is_secured;
    public bool is_secured {
        get {
            if (flags != 0 || wpa_flags != 0 || rsn_flags != 0) {
                return true;
            }
            return _is_secured;
        }
        construct set {
            _is_secured = value;
        }
    }
    public bool is_hidden { get; construct set; default = false; }
    public bool saved { get; construct set; }
    public bool autoconnect { get; construct set; }
    public string device_path { get; construct set; }
    public string ap_path { get; construct set; }
    public string bssid { get; construct set; }
    public uint32 frequency_mhz { get; construct set; }
    public uint32 max_bitrate_kbps { get; construct set; }
    public uint32 mode { get; construct set; }
    public uint32 flags { get; construct set; }
    public uint32 wpa_flags { get; construct set; }
    public uint32 rsn_flags { get; construct set; }

    public string network_key {
        owned get {
            return ssid + ":" + (is_secured ? "secured" : WifiSecurity.OPEN);
        }
    }

    public string signal_label {
        owned get {
            return WifiSignalLevels.get_label (signal);
        }
    }

    public string signal_icon_name {
        owned get {
            return WifiSignalLevels.get_icon_name (signal);
        }
    }
}
