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

namespace NmHotspotUtils {
    public const string CONNECTION_ID_PREFIX = "hypr-network-manager hotspot: ";

    private bool parse_ipv4 (string address, out uint32 value) {
        value = 0;
        string[] octets = address.split (".");
        if (octets.length != 4) {
            return false;
        }

        foreach (string octet in octets) {
            if (octet.length == 0 || octet.length > 3) {
                return false;
            }
            uint32 octet_value = 0;
            for (int i = 0; i < octet.length; i++) {
                uint8 b = octet.data[i];
                if (b < '0' || b > '9') {
                    return false;
                }
                octet_value = octet_value * 10 + (uint32) (b - '0');
            }
            if (octet_value > 255) {
                return false;
            }
            value = (value << 8) | octet_value;
        }
        return true;
    }

    private uint32 prefix_mask (uint prefix) {
        if (prefix == 0) {
            return 0;
        }
        return uint32.MAX << (int) (32 - prefix);
    }

    public bool ipv4_networks_overlap (
        string first_address,
        uint first_prefix,
        string second_address,
        uint second_prefix
    ) {
        uint32 first = 0;
        uint32 second = 0;
        if (first_prefix > 32
            || second_prefix > 32
            || !parse_ipv4 (first_address, out first)
            || !parse_ipv4 (second_address, out second)) {
            return false;
        }

        uint common_prefix = uint.min (first_prefix, second_prefix);
        uint32 mask = prefix_mask (common_prefix);
        return (first & mask) == (second & mask);
    }

    private bool gateway_is_available (
        string gateway,
        GLib.GenericArray<string> occupied_networks
    ) {
        for (uint i = 0; i < occupied_networks.length; i++) {
            string[] parts = occupied_networks[i].split ("/");
            if (parts.length != 2) {
                continue;
            }

            int prefix;
            if (!int.try_parse (parts[1], out prefix)
                || prefix <= 0
                || prefix > 32) {
                continue;
            }
            if (ipv4_networks_overlap (
                    gateway,
                    24,
                    parts[0],
                    (uint) prefix)) {
                return false;
            }
        }
        return true;
    }

    public string choose_create_ap_gateway (
        GLib.GenericArray<string> occupied_networks
    ) {
        // Preserve create_ap's historical default when it is free, then walk
        // the rest of RFC1918 space in deterministic /24 increments.
        for (int third = 12; third <= 254; third++) {
            string candidate = "192.168.%d.1".printf (third);
            if (gateway_is_available (candidate, occupied_networks)) {
                return candidate;
            }
        }
        for (int third = 0; third < 12; third++) {
            string candidate = "192.168.%d.1".printf (third);
            if (gateway_is_available (candidate, occupied_networks)) {
                return candidate;
            }
        }
        for (int second = 16; second <= 31; second++) {
            for (int third = 0; third <= 254; third++) {
                string candidate = "172.%d.%d.1".printf (second, third);
                if (gateway_is_available (candidate, occupied_networks)) {
                    return candidate;
                }
            }
        }
        for (int third = 0; third <= 254; third++) {
            string candidate = "10.42.%d.1".printf (third);
            if (gateway_is_available (candidate, occupied_networks)) {
                return candidate;
            }
        }
        return "";
    }

    public GLib.GenericArray<string> build_create_ap_command (
        string create_ap_binary,
        string pidfile,
        string logfile,
        string ready_file,
        string gateway,
        string passphrase_file,
        string security,
        string band,
        bool hidden,
        int channel,
        string ap_interface,
        string uplink_interface,
        string ssid
    ) {
        var argv = new GLib.GenericArray<string> ();
        argv.add ("pkexec");
        argv.add (create_ap_binary);
        argv.add ("--daemon");
        argv.add ("--pidfile"); argv.add (pidfile);
        argv.add ("--logfile"); argv.add (logfile);
        argv.add ("--ready-file"); argv.add (ready_file);
        argv.add ("-g"); argv.add (gateway);

        if (passphrase_file != "") {
            argv.add ("--passphrase-file");
            argv.add (passphrase_file);
        }
        if (security == WifiKeyMgmt.SAE) {
            argv.add ("-w"); argv.add ("3");
        }
        if (band == WifiBand.BAND_5GHZ) {
            argv.add ("--freq-band"); argv.add ("5");
        } else {
            argv.add ("--freq-band"); argv.add ("2.4");
        }
        if (hidden) {
            argv.add ("--hidden");
        }
        argv.add ("-c"); argv.add (channel.to_string ());

        if (uplink_interface == "None") {
            argv.add ("-m");
            argv.add ("none");
            argv.add ("--");
            argv.add (ap_interface);
        } else {
            argv.add ("--");
            argv.add (ap_interface);
            argv.add (uplink_interface);
        }
        argv.add (ssid);
        return argv;
    }

    public bool should_use_create_ap (
        bool create_ap_available,
        string uplink_interface,
        bool uplink_is_active
    ) {
        return create_ap_available
            && (uplink_interface == "None"
                || uplink_is_active);
    }

    public bool is_managed_connection (NM.Connection conn) {
        var s_con = conn.get_setting_connection ();
        var s_wifi = conn.get_setting_wireless ();
        return s_con != null
            && s_con.id != null
            && s_con.id.has_prefix (CONNECTION_ID_PREFIX)
            && s_wifi != null
            && s_wifi.mode == "ap";
    }

    public bool is_legacy_managed_connection (
        NM.Connection conn,
        string configured_ssid
    ) {
        var s_con = conn.get_setting_connection ();
        var s_wifi = conn.get_setting_wireless ();
        var s_ip4 = conn.get_setting_ip4_config ();

        return configured_ssid != ""
            && s_con != null
            && s_con.id == configured_ssid
            && !s_con.autoconnect
            && s_wifi != null
            && s_wifi.mode == "ap"
            && s_ip4 != null
            && s_ip4.get_method () == NM.SettingIP4Config.METHOD_SHARED;
    }

    public bool is_owned_connection (
        NM.Connection conn,
        string configured_ssid
    ) {
        return is_managed_connection (conn)
            || is_legacy_managed_connection (conn, configured_ssid);
    }

    public NM.Connection create_connection (
        string ssid,
        string? password,
        string security,
        string band,
        bool is_hidden,
        string interface_name,
        uint32 channel = 0
    ) {
        var conn = (NM.SimpleConnection) NM.SimpleConnection.@new ();

        var s_con = new NM.SettingConnection ();
        s_con.id = CONNECTION_ID_PREFIX + ssid;
        s_con.type = NM.SettingWireless.SETTING_NAME;
        s_con.uuid = NM.Utils.uuid_generate ();
        s_con.autoconnect = false;
        s_con.interface_name = interface_name;
        conn.add_setting (s_con);

        var s_wifi = new NM.SettingWireless ();
        uint8[] ssid_data = ssid.data;
        s_wifi.ssid = new Bytes (ssid_data);
        s_wifi.mode = "ap";
        s_wifi.hidden = is_hidden;
        s_wifi.cloned_mac_address = "preserve";
        if (band != "") {
            s_wifi.band = band;
        }
        if (channel > 0) {
            s_wifi.channel = channel;
        } else if (band == WifiBand.BAND_5GHZ) {
            s_wifi.channel = WifiChannel.DEFAULT_5GHZ;
        } else if (band == WifiBand.BAND_2GHZ) {
            s_wifi.channel = WifiChannel.DEFAULT_2GHZ;
        }
        conn.add_setting (s_wifi);

        if (security != WifiKeyMgmt.NONE) {
            var s_sec = new NM.SettingWirelessSecurity ();
            s_sec.key_mgmt = security;
            if (password != null && password != "") {
                s_sec.psk = password;
            }
            s_sec.proto = new string[] { "rsn" };
            s_sec.pairwise = new string[] { "ccmp" };
            s_sec.group = new string[] { "ccmp" };
            conn.add_setting (s_sec);
        }

        var s_ip4 = new NM.SettingIP4Config ();
        s_ip4.method = NM.SettingIP4Config.METHOD_SHARED;
        conn.add_setting (s_ip4);

        var s_ip6 = new NM.SettingIP6Config ();
        s_ip6.method = NM.SettingIP6Config.METHOD_SHARED;
        conn.add_setting (s_ip6);

        return conn;
    }
}
