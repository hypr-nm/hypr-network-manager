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

// SPDX-License-Identifier: GPL-3.0-or-later

using Constants;
namespace HyprNetworkManager.Models {
    public class HotspotConfig : GLib.Object {
        public string ssid { get; set; }
        public string password { get; set; }
        public bool is_active { get; set; }
        public bool is_starting { get; set; }
        public string connection_uuid { get; set; }
        public string security { get; set; } // "none", WifiKeyMgmt.WPA_PSK, WifiKeyMgmt.SAE
        public string band { get; set; } // "", WifiBand.BAND_2GHZ, WifiBand.BAND_5GHZ
        public bool supports_2ghz { get; set; }
        public bool supports_5ghz { get; set; }
        public bool is_hidden { get; set; }
        public int timeout { get; set; } // in minutes, 0 = never
        public string ap_interface { get; set; }
        public string uplink_interface { get; set; }
        public int connected_clients { get; set; }

        public HotspotConfig () {
            ssid = "";
            password = "";
            is_active = false;
            is_starting = false;
            connection_uuid = "";
            security = WifiKeyMgmt.WPA_PSK;
            band = "";
            supports_2ghz = false;
            supports_5ghz = false;
            is_hidden = false;
            timeout = 0;
            ap_interface = "";
            uplink_interface = "";
            connected_clients = 0;
        }
    }
}
