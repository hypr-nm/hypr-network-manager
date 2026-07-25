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

private static void test_wpa_profile () {
    var conn = NmHotspotUtils.create_connection (
        "Fallback AP",
        "correct horse battery staple",
        "wpa-psk",
        "bg",
        true,
        "wlan-test",
        11);

    try {
        assert (conn.verify ());
    } catch (Error e) {
        error ("Profile verification failed: %s", e.message);
    }

    var s_con = conn.get_setting_connection ();
    var s_wifi = conn.get_setting_wireless ();
    var s_sec = conn.get_setting_wireless_security ();
    var s_ip4 = conn.get_setting_ip4_config ();
    var s_ip6 = conn.get_setting_ip6_config ();

    assert (s_con != null);
    assert (s_con.id == NmHotspotUtils.CONNECTION_ID_PREFIX + "Fallback AP");
    assert (s_con.interface_name == "wlan-test");
    assert (!s_con.autoconnect);
    assert (s_wifi != null);
    assert (s_wifi.mode == "ap");
    assert (s_wifi.band == "bg");
    assert (s_wifi.channel == 11);
    assert (s_wifi.hidden);
    assert (s_wifi.cloned_mac_address == "preserve");
    assert (s_sec != null);
    assert (s_sec.key_mgmt == "wpa-psk");
    assert (s_ip4 != null);
    assert (s_ip4.get_method () == NM.SettingIP4Config.METHOD_SHARED);
    assert (s_ip6 != null);
    assert (s_ip6.get_method () == NM.SettingIP6Config.METHOD_SHARED);
    assert (NmHotspotUtils.is_managed_connection (conn));
    assert (NmHotspotUtils.is_owned_connection (conn, "Fallback AP"));
}

private static void test_open_auto_profile () {
    var conn = NmHotspotUtils.create_connection (
        "Open AP",
        null,
        "none",
        "",
        false,
        "wlan-test");

    try {
        assert (conn.verify ());
    } catch (Error e) {
        error ("Open profile verification failed: %s", e.message);
    }

    var s_wifi = conn.get_setting_wireless ();
    assert (s_wifi != null);
    assert (s_wifi.band == null);
    assert (s_wifi.channel == 0);
    assert (conn.get_setting_wireless_security () == null);
}

private static void test_legacy_profile_recognition () {
    var conn = (NM.SimpleConnection) NM.SimpleConnection.@new ();
    var s_con = new NM.SettingConnection ();
    var s_wifi = new NM.SettingWireless ();
    var s_ip4 = new NM.SettingIP4Config ();

    s_con.id = "Legacy AP";
    s_con.type = "802-11-wireless";
    s_con.uuid = NM.Utils.uuid_generate ();
    s_con.autoconnect = false;
    conn.add_setting (s_con);

    uint8[] legacy_ssid = "Legacy AP".data;
    s_wifi.ssid = new Bytes (legacy_ssid);
    s_wifi.mode = "ap";
    conn.add_setting (s_wifi);

    s_ip4.method = NM.SettingIP4Config.METHOD_SHARED;
    conn.add_setting (s_ip4);

    assert (!NmHotspotUtils.is_managed_connection (conn));
    assert (NmHotspotUtils.is_legacy_managed_connection (
        conn,
        "Legacy AP"));
    assert (!NmHotspotUtils.is_legacy_managed_connection (
        conn,
        "Someone else's AP"));
}

private static void test_backend_selection () {
    assert (NmHotspotUtils.should_use_create_ap (
        true,
        "wlo1",
        true));
    assert (!NmHotspotUtils.should_use_create_ap (
        true,
        "wlo1",
        false));
    assert (!NmHotspotUtils.should_use_create_ap (
        true,
        "wlan0",
        false));
    assert (NmHotspotUtils.should_use_create_ap (
        true,
        "wlan0",
        true));
    assert (NmHotspotUtils.should_use_create_ap (
        true,
        "None",
        false));
    assert (!NmHotspotUtils.should_use_create_ap (
        false,
        "wlo1",
        true));
}

private static void test_gateway_selection () {
    var occupied = new GLib.GenericArray<string> ();

    assert (NmHotspotUtils.choose_create_ap_gateway (occupied)
        == "192.168.12.1");

    occupied.add ("192.168.12.1/24");
    occupied.add ("192.168.13.0/24");
    assert (NmHotspotUtils.choose_create_ap_gateway (occupied)
        == "192.168.14.1");

    var broad_route = new GLib.GenericArray<string> ();
    broad_route.add ("192.168.0.0/16");
    assert (NmHotspotUtils.choose_create_ap_gateway (broad_route)
        == "172.16.0.1");

    assert (NmHotspotUtils.ipv4_networks_overlap (
        "192.168.12.1",
        24,
        "192.168.12.99",
        32));
    assert (!NmHotspotUtils.ipv4_networks_overlap (
        "192.168.12.1",
        24,
        "192.168.13.1",
        24));
}

private static void test_create_ap_command_uses_credential_file () {
    var command = NmHotspotUtils.build_create_ap_command (
        "/opt/create_ap",
        "/run/user/1000/hynm.pid",
        "/state/hynm.log",
        "/run/user/1000/hynm.ready",
        "192.168.14.1",
        "/run/user/1000/hynm.passphrase",
        "wpa-psk",
        "bg",
        false,
        11,
        "wlo1",
        "wlo1",
        "Private AP");

    string joined = string.joinv (" ", (string[]) command.data);
    assert (joined.contains ("--passphrase-file"));
    assert (joined.contains ("/run/user/1000/hynm.passphrase"));
    assert (joined.contains ("-g 192.168.14.1"));
    assert (joined.has_suffix ("-- wlo1 wlo1 Private AP"));

    // The builder deliberately has no passphrase parameter; only the path to
    // the private credential file can reach the process argument vector.
    assert (!joined.contains ("correct horse battery staple"));
}

private static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/nm-hotspot/profile/wpa", test_wpa_profile);
    Test.add_func ("/nm-hotspot/profile/open-auto", test_open_auto_profile);
    Test.add_func (
        "/nm-hotspot/profile/legacy-recognition",
        test_legacy_profile_recognition);
    Test.add_func (
        "/nm-hotspot/backend-selection",
        test_backend_selection);
    Test.add_func (
        "/nm-hotspot/gateway-selection",
        test_gateway_selection);
    Test.add_func (
        "/nm-hotspot/create-ap-command/credential-file",
        test_create_ap_command_uses_credential_file);
    return Test.run ();
}
