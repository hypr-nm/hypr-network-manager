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
using HyprNetworkManager.Backend.Mappers;

private static void test_openvpn_roundtrip () {
    var conn = (NM.SimpleConnection) NM.SimpleConnection.@new ();
    var s_vpn = new NM.SettingVpn ();
    s_vpn.service_type = "org.freedesktop.NetworkManager.openvpn";
    s_vpn.add_data_item ("remote", "10.0.0.1");
    s_vpn.add_data_item ("unknown-plugin-key", "some-value");
    s_vpn.add_secret ("password", "my-secret-pass");
    s_vpn.add_secret ("agent-owned-secret", "another-secret");

    try {
        s_vpn.set_secret_flags ("password", NM.SettingSecretFlags.AGENT_OWNED);
        s_vpn.set_secret_flags ("agent-owned-secret", NM.SettingSecretFlags.AGENT_OWNED);
    } catch (Error e) {
        error ("Unable to configure OpenVPN test secrets: %s", e.message);
    }
    conn.add_setting (s_vpn);

    var mapper = VpnMapperFactory.create_for_connection (conn);
    var details = new OpenVpnProfileDetails ();
    mapper.map_to_details (conn, details);

    assert (details.ovpn_remote == "10.0.0.1");

    var req = new OpenVpnUpdateRequest ();
    req.ovpn_remote = "10.0.0.2";
    req.ovpn_password = "my-secret-pass";

    try {
        mapper.map_from_request (req, conn);
    } catch (Error e) {
        error ("Mapping failed: %s", e.message);
    }

    var s_vpn_after = conn.get_setting_vpn ();
    assert (s_vpn_after != null);

    assert (s_vpn_after.get_data_item ("remote") == "10.0.0.2");
    assert (s_vpn_after.get_data_item ("unknown-plugin-key") == "some-value");
    assert (s_vpn_after.get_secret ("password") == "my-secret-pass");
    assert (s_vpn_after.get_secret ("agent-owned-secret") == "another-secret");
}

private static void test_wireguard_roundtrip () {
    var conn = (NM.SimpleConnection) NM.SimpleConnection.@new ();
    var s_wg = new NM.SettingWireGuard ();
    s_wg.private_key = "test-private-key";
    try {
        s_wg.set_secret_flags (
            "private-key",
            NM.SettingSecretFlags.AGENT_OWNED
        );
    } catch (Error e) {
        error ("Unable to configure WireGuard test secrets: %s", e.message);
    }
    conn.add_setting (s_wg);

    var mapper = VpnMapperFactory.create_for_connection (conn);
    var details = new WireGuardVpnProfileDetails ();
    mapper.map_to_details (conn, details);

    assert (details.wg_private_key == "test-private-key");

    var req = new WireGuardVpnUpdateRequest ();
    req.wg_private_key = "test-private-key";
    req.wg_listen_port = 51820;

    try {
        mapper.map_from_request (req, conn);
    } catch (Error e) {
        error ("Mapping failed: %s", e.message);
    }

    var s_wg_after = (NM.SettingWireGuard) conn.get_setting_by_name (NM.SettingWireGuard.SETTING_NAME);
    assert (s_wg_after != null);
    assert (s_wg_after.private_key == "test-private-key");
    assert (s_wg_after.listen_port == 51820);
}

private static void test_failed_validation () {
    var req = new WireGuardVpnUpdateRequest ();
    string? err;
    assert (req.validate (out err) == false);

    var conn = (NM.SimpleConnection) NM.SimpleConnection.@new ();
    var s_wg = new NM.SettingWireGuard ();
    conn.add_setting (s_wg);

    var req2 = new WireGuardVpnUpdateRequest ();
    req2.interface_name = "wg0";
    var p = new WireGuardPeerModel ();
    p.public_key = "invalid-key";
    p.endpoint_host = "1.2.3.4";
    req2.peers = new WireGuardPeerModel[] { p };

    var mapper = VpnMapperFactory.create_for_connection (conn);
    bool caught = false;
    try {
        mapper.map_from_request (req2, conn);
    } catch (Error e) {
        caught = true;
    }
    assert (caught == true);
}

private static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/vpn/roundtrip-openvpn", test_openvpn_roundtrip);
    Test.add_func ("/vpn/roundtrip-wireguard", test_wireguard_roundtrip);
    Test.add_func ("/vpn/failed-validation", test_failed_validation);
    return Test.run ();
}
