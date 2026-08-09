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
using GLib;

namespace NmWifiUtils {
    public NM.DeviceWifi? primary_wifi_device (NM.Client client) {
        foreach (var dev in client.get_devices ()) {
            if (dev is NM.DeviceWifi) {
                return (NM.DeviceWifi) dev;
            }
        }
        return null;
    }

    public string bytes_to_ssid (Bytes? value) {
        if (value == null) {
            return "";
        }

        string? converted = NM.Utils.ssid_to_utf8 (value.get_data ());
        return converted != null ? converted : "";
    }

    public bool is_valid_specific_object (string path) {
        return GLib.Variant.is_object_path (path);
    }

    public string? resolve_specific_object (NM.Device dev, string ap_path) {
        if (!is_valid_specific_object (ap_path)) {
            return null;
        }
        var wifi = dev as NM.DeviceWifi;
        if (wifi == null) {
            return ap_path;
        }
        foreach (var ap in wifi.get_access_points ()) {
            if (((NM.Object) ap).get_path () == ap_path) {
                return ap_path;
            }
        }
        // The captured AP is no longer in the device's scan list (e.g. it went
        // offline while another AP for the same SSID remains). Returning null
        // lets NetworkManager pick a currently-visible compatible AP instead of
        // failing with "access point ... was not in the scan list".
        return null;
    }

    public string resolve_saved_ssid (NM.Connection conn, NM.SettingWireless s_wireless) {
        string ssid = bytes_to_ssid (s_wireless.ssid).strip ();
        if (ssid != "") {
            return ssid;
        }

        var s_conn = conn.get_setting_connection ();
        if (s_conn != null && s_conn.id != null && s_conn.id.strip () != "") {
            return s_conn.id.strip ();
        }

        return "Saved network";
    }

    public bool resolve_autoconnect (NM.Connection conn) {
        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            return s_conn.autoconnect;
        }
        return true;
    }

    public string resolve_profile_name (NM.Connection conn, string fallback) {
        var s_conn = conn.get_setting_connection ();
        if (s_conn != null && s_conn.id != null && s_conn.id.strip () != "") {
            return s_conn.id.strip ();
        }
        return fallback;
    }

    public WifiNetwork? build_saved_network (
        NM.Connection conn,
        string wifi_device_path,
        string active_uuid
    ) {
        var s_wireless = conn.get_setting_wireless ();
        if (s_wireless == null) {
            return null;
        }

        string uuid = conn.get_uuid ().strip ();
        if (uuid == "") {
            return null;
        }

        string ssid = resolve_saved_ssid (conn, s_wireless);
        bool is_secured = conn.get_setting_wireless_security () != null;

        return new WifiNetwork () {
            ssid = ssid,
            saved_connection_uuid = uuid,
            signal = 0,
            connected = active_uuid != "" && active_uuid == uuid,
            is_hidden = s_wireless.hidden,
            saved = true,
            autoconnect = resolve_autoconnect (conn),
            device_path = wifi_device_path,
            ap_path = "saved:" + uuid,
            bssid = "",
            frequency_mhz = 0,
            max_bitrate_kbps = 0,
            mode = WifiNetworkMode.UNKNOWN,
            security = new WifiSecurityCapabilities () {
                is_secured = is_secured,
                is_enterprise = false,
                supports_psk = false,
                supports_sae = false
            }
        };
    }

    public WifiSavedProfile? build_saved_profile (NM.Connection conn) {
        var s_wireless = conn.get_setting_wireless ();
        if (s_wireless == null) {
            return null;
        }

        string uuid = conn.get_uuid () != null ? conn.get_uuid ().strip () : "";
        if (uuid == "") {
            return null;
        }

        string ssid = resolve_saved_ssid (conn, s_wireless);
        string profile_name = resolve_profile_name (conn, ssid);

        return new WifiSavedProfile () {
            profile_name = profile_name,
            ssid = ssid,
            saved_connection_uuid = uuid
        };
    }

    public string connection_key_mgmt (NM.Connection conn) {
        var s_sec = conn.get_setting_wireless_security ();
        if (s_sec == null) {
            return "";
        }
        return s_sec.key_mgmt != null ? s_sec.key_mgmt.strip ().ascii_down () : "";
    }

    private bool connection_has_exact_interface (
        NM.Connection connection,
        string device_iface
    ) {
        var setting = connection.get_setting_connection ();
        string bound_iface = setting != null && setting.interface_name != null
            ? setting.interface_name.strip ()
            : "";
        return bound_iface != "" && bound_iface == device_iface;
    }

    private bool connection_has_exact_bssid (
        NM.Connection connection,
        string ap_bssid
    ) {
        var setting = connection.get_setting_wireless ();
        string bound_bssid = setting != null && setting.bssid != null
            ? setting.bssid.strip ().ascii_down ()
            : "";
        string normalized_ap_bssid = ap_bssid.strip ().ascii_down ();
        return bound_bssid != ""
            && normalized_ap_bssid != ""
            && bound_bssid == normalized_ap_bssid;
    }

    private int32 connection_autoconnect_priority (NM.Connection connection) {
        var setting = connection.get_setting_connection ();
        return setting != null ? setting.autoconnect_priority : 0;
    }

    /**
     * Orders two profiles that are already valid for the same access point.
     * A negative result means @first should be preferred.
     */
    public int compare_profile_preference (
        NM.Connection first,
        NM.Connection second,
        string active_uuid,
        string device_iface,
        string ap_bssid
    ) {
        string first_uuid = first.get_uuid () != null ? first.get_uuid ().strip () : "";
        string second_uuid = second.get_uuid () != null ? second.get_uuid ().strip () : "";
        string normalized_active_uuid = active_uuid.strip ();

        bool first_is_active = normalized_active_uuid != ""
            && first_uuid == normalized_active_uuid;
        bool second_is_active = normalized_active_uuid != ""
            && second_uuid == normalized_active_uuid;
        if (first_is_active != second_is_active) {
            return first_is_active ? -1 : 1;
        }

        bool first_matches_interface = connection_has_exact_interface (first, device_iface);
        bool second_matches_interface = connection_has_exact_interface (second, device_iface);
        if (first_matches_interface != second_matches_interface) {
            return first_matches_interface ? -1 : 1;
        }

        bool first_matches_bssid = connection_has_exact_bssid (first, ap_bssid);
        bool second_matches_bssid = connection_has_exact_bssid (second, ap_bssid);
        if (first_matches_bssid != second_matches_bssid) {
            return first_matches_bssid ? -1 : 1;
        }

        int32 first_priority = connection_autoconnect_priority (first);
        int32 second_priority = connection_autoconnect_priority (second);
        if (first_priority != second_priority) {
            return first_priority > second_priority ? -1 : 1;
        }

        return first_uuid.collate (second_uuid);
    }

    public bool should_populate_runtime_ip (
        bool candidate_connected,
        string requested_uuid,
        string active_uuid
    ) {
        if (!candidate_connected) {
            return false;
        }

        string requested = requested_uuid.strip ();
        return requested == "" || requested == active_uuid.strip ();
    }

    public bool enable_manual_multi_connect (NM.Connection conn) {
        var s_conn = conn.get_setting_connection ();
        if (s_conn == null) {
            return false;
        }

        NM.ConnectionMultiConnect current = s_conn.get_multi_connect ();
        if (current == NM.ConnectionMultiConnect.MANUAL_MULTIPLE
            || current == NM.ConnectionMultiConnect.MULTIPLE) {
            return false;
        }

        s_conn.multi_connect = (int) NM.ConnectionMultiConnect.MANUAL_MULTIPLE;
        return true;
    }

    public string infer_security_mode (NM.SettingWirelessSecurity? s_sec) {
        if (s_sec == null) {
            return WifiSecurity.OPEN;
        }

        string key_mgmt = s_sec.key_mgmt != null ? s_sec.key_mgmt.strip ().ascii_down () : "";
        if (key_mgmt == WifiKeyMgmt.SAE) {
            return WifiKeyMgmt.SAE;
        }
        if (key_mgmt == WifiKeyMgmt.OWE) {
            return WifiKeyMgmt.OWE;
        }
        if (key_mgmt == WifiKeyMgmt.WPA_PSK) {
            return WifiKeyMgmt.WPA_PSK;
        }
        if (key_mgmt == WifiKeyMgmt.WPA_EAP) {
            return WifiKeyMgmt.WPA_EAP;
        }
        if (key_mgmt == WifiKeyMgmt.NONE) {
            string wep = s_sec.wep_key0 != null ? s_sec.wep_key0.strip () : "";
            return wep != "" ? WifiSecurity.WEP : WifiSecurity.OPEN;
        }

        return WifiKeyMgmt.WPA_PSK;
    }

    public void apply_security_mode (NM.Connection conn, string security_mode) {
        string mode = security_mode.strip ().ascii_down ();
        if (mode == "") {
            mode = WifiSecurity.OPEN;
        }

        if (mode == WifiSecurity.OPEN) {
            conn.remove_setting (typeof (NM.SettingWirelessSecurity));
            conn.remove_setting (typeof (NM.Setting8021x));
            return;
        }

        var s_sec = conn.get_setting_wireless_security ();
        if (s_sec == null) {
            s_sec = new NM.SettingWirelessSecurity ();
            conn.add_setting (s_sec);
        }

        switch (mode) {
        case WifiSecurity.WEP:
            s_sec.key_mgmt = WifiKeyMgmt.NONE;
            conn.remove_setting (typeof (NM.Setting8021x));
            break;
        case WifiKeyMgmt.SAE:
            s_sec.key_mgmt = WifiKeyMgmt.SAE;
            conn.remove_setting (typeof (NM.Setting8021x));
            break;
        case WifiKeyMgmt.OWE:
            s_sec.key_mgmt = WifiKeyMgmt.OWE;
            conn.remove_setting (typeof (NM.Setting8021x));
            break;
        case WifiKeyMgmt.WPA_EAP:
            s_sec.key_mgmt = WifiKeyMgmt.WPA_EAP;
            var s_8021x = conn.get_setting_802_1x ();
            if (s_8021x == null) {
                s_8021x = new NM.Setting8021x ();
                conn.add_setting (s_8021x);
            }
            s_8021x.add_eap_method (EapMethod.PEAP);
            s_8021x.phase2_auth = Phase2Auth.MSCHAPV2;
            break;
        case WifiKeyMgmt.WPA_PSK:
        default:
            s_sec.key_mgmt = WifiKeyMgmt.WPA_PSK;
            conn.remove_setting (typeof (NM.Setting8021x));
            break;
        }
    }

    public NM.Connection create_hidden_wifi_connection (
        string ssid,
        string? password,
        HiddenWifiSecurityMode security_mode = HiddenWifiSecurityMode.OPEN
    ) {
        var conn = (NM.SimpleConnection) NM.SimpleConnection.@new ();

        var s_con = new NM.SettingConnection ();
        s_con.id = ssid;
        s_con.type = NM.SettingWireless.SETTING_NAME;
        s_con.uuid = NM.Utils.uuid_generate ();
        s_con.autoconnect = true;
        conn.add_setting (s_con);

        var s_wifi = new NM.SettingWireless ();
        uint8[] ssid_arr = ssid.data;
        s_wifi.ssid = new Bytes (ssid_arr);
        s_wifi.hidden = true;
        conn.add_setting (s_wifi);

        if (password != null && password != "") {
            var s_sec = new NM.SettingWirelessSecurity ();

            if (security_mode == HiddenWifiSecurityMode.WPA_PSK) {
                s_sec.key_mgmt = WifiKeyMgmt.WPA_PSK;
                s_sec.psk = password;
            } else if (security_mode == HiddenWifiSecurityMode.WEP) {
                s_sec.key_mgmt = WifiKeyMgmt.NONE;
                s_sec.wep_key0 = password;
                s_sec.wep_key_type = NM.WepKeyType.PASSPHRASE;
            } else if (security_mode == HiddenWifiSecurityMode.SAE
                || security_mode == HiddenWifiSecurityMode.WPA_PSK_SAE) {
                s_sec.key_mgmt = WifiKeyMgmt.SAE;
                s_sec.psk = password;
            } else {
                s_sec.key_mgmt = WifiKeyMgmt.WPA_PSK;
                s_sec.psk = password;
            }
            conn.add_setting (s_sec);
        }

        var s_ip4 = new NM.SettingIP4Config ();
        s_ip4.method = IpMethod.AUTO;
        conn.add_setting (s_ip4);

        var s_ip6 = new NM.SettingIP6Config ();
        s_ip6.method = IpMethod.AUTO;
        conn.add_setting (s_ip6);

        return conn;
    }

}
