using GLib;

namespace NmWifiUtils {
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
            is_secured = is_secured,
            is_hidden = s_wireless.hidden,
            saved = true,
            autoconnect = resolve_autoconnect (conn),
            device_path = wifi_device_path,
            ap_path = "saved:" + uuid,
            bssid = "",
            frequency_mhz = 0,
            max_bitrate_kbps = 0,
            mode = 0,
            flags = 0,
            wpa_flags = 0,
            rsn_flags = 0
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
            return "open";
        }

        string key_mgmt = s_sec.key_mgmt != null ? s_sec.key_mgmt.strip ().down () : "";
        if (key_mgmt == "sae") {
            return "sae";
        }
        if (key_mgmt == "owe") {
            return "owe";
        }
        if (key_mgmt == "wpa-psk") {
            return "wpa-psk";
        }
        if (key_mgmt == "none") {
            string wep = s_sec.wep_key0 != null ? s_sec.wep_key0.strip () : "";
            return wep != "" ? "wep" : "open";
        }

        return "wpa-psk";
    }

    public void apply_security_mode (NM.Connection conn, string security_mode) {
        string mode = security_mode.strip ().down ();
        if (mode == "") {
            mode = "open";
        }

        if (mode == "open") {
            conn.remove_setting (typeof (NM.SettingWirelessSecurity));
            return;
        }

        var s_sec = conn.get_setting_wireless_security ();
        if (s_sec == null) {
            s_sec = new NM.SettingWirelessSecurity ();
            conn.add_setting (s_sec);
        }

        switch (mode) {
        case "wep":
            s_sec.key_mgmt = "none";
            break;
        case "sae":
            s_sec.key_mgmt = "sae";
            break;
        case "owe":
            s_sec.key_mgmt = "owe";
            break;
        case "wpa-psk":
        default:
            s_sec.key_mgmt = "wpa-psk";
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
        s_con.type = "802-11-wireless";
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
                s_sec.key_mgmt = "wpa-psk";
                s_sec.psk = password;
            } else if (security_mode == HiddenWifiSecurityMode.WEP) {
                s_sec.key_mgmt = "none";
                s_sec.wep_key0 = password;
                s_sec.wep_key_type = NM.WepKeyType.PASSPHRASE;
            } else if (security_mode == HiddenWifiSecurityMode.SAE
                || security_mode == HiddenWifiSecurityMode.WPA_PSK_SAE) {
                s_sec.key_mgmt = "sae";
                s_sec.psk = password;
            } else {
                s_sec.key_mgmt = "wpa-psk";
                s_sec.psk = password;
            }
            conn.add_setting (s_sec);
        }

        var s_ip4 = new NM.SettingIP4Config ();
        s_ip4.method = "auto";
        conn.add_setting (s_ip4);

        var s_ip6 = new NM.SettingIP6Config ();
        s_ip6.method = "auto";
        conn.add_setting (s_ip6);

        return conn;
    }
}
