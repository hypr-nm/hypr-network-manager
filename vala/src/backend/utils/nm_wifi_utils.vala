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

    public WifiSavedProfile? build_saved_profile (
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
        string profile_name = resolve_profile_name (conn, ssid);

        return new WifiSavedProfile () {
            profile_name = profile_name,
            ssid = ssid,
            saved_connection_uuid = uuid,
            connected = active_uuid != "" && active_uuid == uuid,
            is_secured = conn.get_setting_wireless_security () != null,
            is_hidden = s_wireless.hidden,
            autoconnect = resolve_autoconnect (conn),
            device_path = wifi_device_path
        };
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
