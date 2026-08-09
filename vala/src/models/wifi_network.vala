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
    public bool is_hidden { get; construct set; default = false; }
    public bool saved { get; construct set; }
    public bool autoconnect { get; construct set; }
    public string device_name { get; construct set; default = ""; }
    public string device_path { get; construct set; }
    public bool device_is_connected { get; construct set; default = false; }
    public bool device_is_connecting { get; construct set; default = false; }
    public bool device_is_available { get; construct set; default = true; }
    public string device_connection { get; construct set; default = ""; }
    public string ap_path { get; construct set; }
    public string bssid { get; construct set; }
    public uint32 frequency_mhz { get; construct set; }
    public uint32 max_bitrate_kbps { get; construct set; }
    public WifiNetworkMode mode { get; construct set; }
    public WifiSecurityCapabilities security { get; construct set; }
    public WifiNetwork[] radio_candidates = {};

    private const string SECURITY_KEY_WPA = "wpa";
    private const string SECURITY_KEY_SAE = "sae";
    private const string SECURITY_KEY_EAP = "eap";
    private const string SECURITY_KEY_SECURED = "secured";

    public bool is_secured {
        get { return security != null && security.is_secured; }
    }

    public string network_key {
        owned get {
            return ssid + ":" + security_key_component ();
        }
    }

    public WifiNetwork? candidate_for_device (string requested_device_path) {
        foreach (var candidate in radio_candidates) {
            if (candidate.device_path == requested_device_path) {
                return candidate;
            }
        }

        if (device_path == requested_device_path) {
            return this;
        }
        return null;
    }

    private string security_key_component () {
        if (security == null || !security.is_secured) {
            return WifiSecurity.OPEN;
        }
        if (security.is_enterprise) {
            return SECURITY_KEY_EAP;
        }
        if (security.supports_psk) {
            return SECURITY_KEY_WPA;
        }
        if (security.supports_sae) {
            return SECURITY_KEY_SAE;
        }
        return SECURITY_KEY_SECURED;
    }
}
