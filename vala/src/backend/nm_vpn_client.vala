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

public class NmVpnClient : GLib.Object {
    private NetworkManagerClient core;
    private static GLib.Once<HashTable<string, string>> plugin_names_once;

    public NmVpnClient (NetworkManagerClient core) {
        this.core = core;
    }

    private static unowned HashTable<string, string> get_plugin_names () {
        return plugin_names_once.once (() => {
            var map = new HashTable<string, string> (str_hash, str_equal);
            map.insert ("vpn", "VPN");
            map.insert ("openvpn", "OpenVPN");
            map.insert ("openconnect", "OpenConnect");
            map.insert ("wireguard", "WireGuard");
            map.insert ("vpnc", "VPNC");
            map.insert ("l2tp", "L2TP");
            map.insert ("pptp", "PPTP");
            map.insert ("sstp", "SSTP");
            map.insert ("openfortivpn", "OpenFortiVPN");
            map.insert ("fortisslvpn", "FortiSSLVPN");
            map.insert ("libreswan", "Libreswan");
            map.insert ("strongswan", "strongSwan");
            return map;
        });
    }

    private static string normalize_string (string? value) {
        return value != null ? value.strip () : "";
    }

    private static string normalize_key (string? value) {
        return normalize_string (value).ascii_down ();
    }

    private static string normalize_connection_type (string? value) {
        return normalize_key (value);
    }

    private static bool is_wireguard_connection (NM.Connection conn) {
        return conn.get_setting_by_name (NM.SettingWireGuard.SETTING_NAME) != null
            || conn.is_type ("wireguard")
            || normalize_connection_type (conn.get_connection_type ()) == "wireguard";
    }

    private static bool is_tun_tap_connection (NM.Connection conn) {
        return conn.get_setting_tun () != null
            || conn.get_setting_by_name (NM.SettingTun.SETTING_NAME) != null
            || normalize_connection_type (conn.get_connection_type ()) == "tun";
    }

    private static bool is_ip_tunnel_connection (NM.Connection conn) {
        return conn.get_setting_ip_tunnel () != null
            || conn.get_setting_by_name (NM.SettingIPTunnel.SETTING_NAME) != null
            || normalize_connection_type (conn.get_connection_type ()) == "ip-tunnel";
    }

    private static bool is_supported_vpn_profile (NM.Connection conn) {
        return conn.get_setting_vpn () != null
            || is_wireguard_connection (conn)
            || is_tun_tap_connection (conn)
            || is_ip_tunnel_connection (conn);
    }

    private static bool is_supported_vpn_active_connection (NM.ActiveConnection ac) {
        if (ac.get_vpn ()) {
            return true;
        }

        var conn = ac.get_connection ();
        if (conn != null && is_supported_vpn_profile (conn)) {
            return true;
        }

        string active_type = normalize_connection_type (ac.get_connection_type ());
        return active_type == "wireguard"
            || active_type == "tun"
            || active_type == "ip-tunnel";
    }

    private static bool matches_connection_identity (
        string candidate_uuid,
        string candidate_name,
        string target_id
    ) {
        string normalized_target = normalize_key (target_id);
        if (normalized_target == "") {
            return false;
        }

        return normalize_key (candidate_uuid) == normalized_target
            || normalize_key (candidate_name) == normalized_target;
    }

    private static NM.Connection? find_vpn_connection_by_id (NM.Client client, string id) {
        foreach (var conn in client.get_connections ()) {
            if (is_supported_vpn_profile (conn)
                && matches_connection_identity (conn.get_uuid (), conn.get_id (), id)) {
                return conn;
            }
        }
        return null;
    }

    private static bool active_connection_matches_profile (NM.ActiveConnection ac, NM.Connection conn) {
        string active_uuid = normalize_key (ac.get_uuid ());
        string profile_uuid = normalize_key (conn.get_uuid ());
        if (active_uuid != "" && profile_uuid != "" && active_uuid == profile_uuid) {
            return true;
        }

        var active_profile = ac.get_connection ();
        if (active_profile != null) {
            string active_path = normalize_string (active_profile.get_path ());
            string profile_path = normalize_string (conn.get_path ());
            if (active_path != "" && profile_path != "" && active_path == profile_path) {
                return true;
            }
        }

        return normalize_key (ac.get_id ()) == normalize_key (conn.get_id ())
            && normalize_connection_type (
                ac.get_connection_type ()) == normalize_connection_type (conn.get_connection_type ());
    }

    private static string map_active_connection_state (NM.ActiveConnection ac) {
        var state = ac.get_state ();
        if (state == NM.ActiveConnectionState.ACTIVATED) {
            return "activated";
        }

        if (state == NM.ActiveConnectionState.ACTIVATING) {
            return "activating";
        }

        if (state == NM.ActiveConnectionState.DEACTIVATING) {
            return "deactivating";
        }

        return "deactivated";
    }

    private static string humanize_plugin_name (string? value) {
        string normalized = normalize_key (value);
        if (normalized == "") {
            return "VPN";
        }

        string? named_value = get_plugin_names ().lookup (normalized);
        if (named_value != null) {
            return named_value;
        }

        var pieces = normalized.split_set ("-_. ");
        var builder = new StringBuilder ();
        bool first = true;
        foreach (var piece in pieces) {
            if (piece == "") {
                continue;
            }

            if (!first) {
                builder.append (" ");
            }

            string lower_piece = piece.ascii_down ();
            builder.append (lower_piece.substring (0, 1).ascii_up ());
            if (lower_piece.length > 1) {
                builder.append (lower_piece.substring (1));
            }
            first = false;
        }

        return first ? "VPN" : builder.str;
    }

    private static string describe_tun_mode (NM.SettingTunMode mode) {
        switch (mode) {
        case NM.SettingTunMode.TUN:
            return "TUN";
        case NM.SettingTunMode.TAP:
            return "TAP";
        default:
            return "TUN/TAP";
        }
    }

    private static string describe_ip_tunnel_mode (NM.IPTunnelMode mode) {
        switch (mode) {
        case NM.IPTunnelMode.IPIP:
            return "IPIP";
        case NM.IPTunnelMode.GRE:
            return "GRE";
        case NM.IPTunnelMode.SIT:
            return "SIT";
        case NM.IPTunnelMode.ISATAP:
            return "ISATAP";
        case NM.IPTunnelMode.VTI:
            return "VTI";
        case NM.IPTunnelMode.IP6IP6:
            return "IP6IP6";
        case NM.IPTunnelMode.IPIP6:
            return "IPIP6";
        case NM.IPTunnelMode.IP6GRE:
            return "IP6GRE";
        case NM.IPTunnelMode.VTI6:
            return "VTI6";
        case NM.IPTunnelMode.GRETAP:
            return "GRETAP";
        case NM.IPTunnelMode.IP6GRETAP:
            return "IP6GRETAP";
        default:
            return "IP Tunnel";
        }
    }

    private static string describe_vpn_profile (NM.Connection conn) {
        if (is_wireguard_connection (conn)) {
            return "WireGuard";
        }

        var setting_tun = conn.get_setting_tun ();
        if (setting_tun != null) {
            return describe_tun_mode (setting_tun.get_mode ());
        }

        var setting_ip_tunnel = conn.get_setting_ip_tunnel ();
        if (setting_ip_tunnel != null) {
            return describe_ip_tunnel_mode (setting_ip_tunnel.get_mode ());
        }

        var setting_vpn = conn.get_setting_vpn ();
        if (setting_vpn != null) {
            string service_type = normalize_string (setting_vpn.get_service_type ());
            if (service_type != "") {
                string[] parts = service_type.split (".");
                string plugin_name = parts.length > 0 ? parts[parts.length - 1] : service_type;
                return humanize_plugin_name (plugin_name);
            }
        }

        return humanize_plugin_name (conn.get_connection_type ());
    }

    private static string describe_active_connection (NM.ActiveConnection ac) {
        var conn = ac.get_connection ();
        if (conn != null) {
            return describe_vpn_profile (conn);
        }

        string active_type = normalize_connection_type (ac.get_connection_type ());
        if (active_type == "tun") {
            return "TUN/TAP";
        }
        if (active_type == "ip-tunnel") {
            return "IP Tunnel";
        }

        return humanize_plugin_name (ac.get_connection_type ());
    }

    private static bool list_contains_connection (List<VpnConnection> vpns, NM.ActiveConnection ac) {
        string active_uuid = normalize_key (ac.get_uuid ());
        string active_name = normalize_key (ac.get_id ());

        foreach (var vpn in vpns) {
            if (active_uuid != "" && normalize_key (vpn.uuid) == active_uuid) {
                return true;
            }

            if (active_uuid == "" && normalize_key (vpn.name) == active_name) {
                return true;
            }
        }

        return false;
    }

    public new async bool connect (string id, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        NM.Connection? vpn_conn = find_vpn_connection_by_id (client, id);

        if (vpn_conn == null) {
            throw new IOError.NOT_FOUND ("VPN connection not found");
        }

        yield client.activate_connection_async (vpn_conn, null, null, cancellable);
        return true;
    }

    public new async bool disconnect (string id, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        foreach (var ac in client.get_active_connections ()) {
            if (is_supported_vpn_active_connection (ac)
                && matches_connection_identity (ac.get_uuid (), ac.get_id (), id)) {
                yield client.deactivate_connection_async (ac, cancellable);
                return true;
            }
        }

        throw new IOError.NOT_FOUND ("Active VPN connection not found");
    }

    public async List<VpnConnection> get_connections (Cancellable? cancellable = null) throws Error {
        var vpns = new List<VpnConnection> ();
        var client = core.nm_client;

        foreach (var conn in client.get_connections ()) {
            if (!is_supported_vpn_profile (conn)) {
                continue;
            }

            var s_conn = conn.get_setting_connection ();
            var vpn = new VpnConnection () {
                uuid = conn.get_uuid (),
                name = conn.get_id (),
                vpn_type = describe_vpn_profile (conn),
                state = "deactivated",
                autoconnect = s_conn != null ? s_conn.autoconnect : true
            };

            foreach (var ac in client.get_active_connections ()) {
                if (is_supported_vpn_active_connection (ac)
                    && active_connection_matches_profile (ac, conn)) {
                    vpn.state = map_active_connection_state (ac);
                    break;
                }
            }

            vpns.append (vpn);
        }

        foreach (var ac in client.get_active_connections ()) {
            if (!is_supported_vpn_active_connection (ac) || list_contains_connection (vpns, ac)) {
                continue;
            }

            vpns.append (new VpnConnection () {
                uuid = ac.get_uuid (),
                name = ac.get_id (),
                vpn_type = describe_active_connection (ac),
                state = map_active_connection_state (ac),
                autoconnect = false
            });
        }

        return vpns;
    }

    public async VpnProfileDetails get_details (string id, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        VpnProfileDetails details;

        NM.Connection? vpn_conn = find_vpn_connection_by_id (client, id);

        if (vpn_conn == null) {
            throw new IOError.NOT_FOUND ("VPN connection not found");
        }

        var mapper = VpnMapperFactory.create_for_connection (vpn_conn);
        string vpn_type_key = mapper.get_vpn_type_key ();

        if (vpn_type_key == "wireguard") {
            details = new WireGuardVpnProfileDetails ();
        } else if (vpn_type_key == "openvpn") {
            details = new OpenVpnProfileDetails ();
        } else {
            details = new GenericVpnProfileDetails ();
        }

        NmIpConfigHelper.populate_configured_ip_settings (details, vpn_conn);

        details.profile_name = normalize_string (vpn_conn.get_id ());
        details.profile_uuid = normalize_string (vpn_conn.get_uuid ());
        details.vpn_type_key = vpn_type_key;
        details.vpn_type_display = describe_vpn_profile (vpn_conn);
        
        var s_conn = vpn_conn.get_setting_connection ();
        if (s_conn != null) {
            details.autoconnect = s_conn.autoconnect;
            details.interface_name = normalize_string (s_conn.interface_name);
        }

        var setting_vpn = vpn_conn.get_setting_vpn ();
        if (setting_vpn != null) {
            details.service_type = normalize_string (setting_vpn.get_service_type ());
        }

        mapper.map_to_details (vpn_conn, details);

        foreach (var ac in client.get_active_connections ()) {
            if (is_supported_vpn_active_connection (ac)
                && matches_connection_identity (ac.get_uuid (), ac.get_id (), id)) {
                
                var ip4 = ac.get_ip4_config ();
                if (ip4 != null) {
                    if (ip4.get_addresses ().length > 0) {
                        unowned NM.IPAddress addr = ip4.get_addresses ().get (0);
                        details.current_address = addr.get_address () ?? "";
                        details.current_prefix = addr.get_prefix ();
                    }
                    details.current_gateway = ip4.get_gateway () ?? "";
                    foreach (unowned string nameserver in ip4.get_nameservers ()) {
                        details.current_dns = nameserver;
                        break;
                    }
                }

                var ip6 = ac.get_ip6_config ();
                if (ip6 != null) {
                    if (ip6.get_addresses ().length > 0) {
                        unowned NM.IPAddress addr = ip6.get_addresses ().get (0);
                        details.current_ipv6_address = addr.get_address () ?? "";
                        details.current_ipv6_prefix = addr.get_prefix ();
                    }
                    details.current_ipv6_gateway = ip6.get_gateway () ?? "";
                    foreach (unowned string nameserver in ip6.get_nameservers ()) {
                        details.current_ipv6_dns = nameserver;
                        break;
                    }
                }
                break;
            }
        }

        return details;
    }

    public async bool update_vpn_settings (
        string id,
        VpnUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        NM.Connection? vpn_conn = find_vpn_connection_by_id (client, id);

        if (vpn_conn == null) {
            throw new IOError.NOT_FOUND ("VPN connection not found");
        }

        string? validation_error;
        if (!request.validate (out validation_error)) {
            throw new IOError.FAILED (validation_error);
        }

        var s_conn = vpn_conn.get_setting_connection ();
        if (s_conn != null) {
            string new_name = request.name.strip ();
            if (new_name != "") {
                s_conn.id = new_name;
            }
            if (request.interface_name.strip () != "") {
                s_conn.interface_name = request.interface_name.strip ();
            }
            s_conn.autoconnect = request.ip_request.autoconnect;
        }

        var mapper = VpnMapperFactory.create (request.vpn_type);
        mapper.map_from_request (request, vpn_conn);

        var s_ip4 = NmIpConfigHelper.ensure_ip4_setting (vpn_conn);
        NmIpConfigHelper.apply_ipv4_settings (s_ip4, request.ip_request.get_ipv4_section ());

        var s_ip6 = NmIpConfigHelper.ensure_ip6_setting (vpn_conn);
        NmIpConfigHelper.apply_ipv6_settings (s_ip6, request.ip_request.get_ipv6_section ());

        if (vpn_conn is NM.RemoteConnection) {
            yield ((NM.RemoteConnection)vpn_conn).commit_changes_async (true, cancellable);
        }
        return true;
    }

    public async bool delete_vpn (string id, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        foreach (var conn in client.get_connections ()) {
            if (is_supported_vpn_profile (conn)
                && matches_connection_identity (conn.get_uuid (), conn.get_id (), id)) {
                if (conn is NM.RemoteConnection) {
                    yield ((NM.RemoteConnection)conn).delete_async (cancellable);
                    return true;
                }
            }
        }

        throw new IOError.NOT_FOUND ("VPN connection profile not found");
    }

    public async bool create_vpn (VpnUpdateRequest request, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var conn = (NM.SimpleConnection) NM.SimpleConnection.@new ();

        string? validation_error;
        if (!request.validate (out validation_error)) {
            throw new IOError.FAILED (validation_error);
        }

        request.name = request.name.strip ();
        if (request.name == "") {
            throw new IOError.FAILED ("Connection name is required");
        }

        var s_conn = new NM.SettingConnection ();
        s_conn.id = request.name;
        if (request.interface_name.strip () != "") {
            s_conn.interface_name = request.interface_name.strip ();
        }
        s_conn.uuid = NM.Utils.uuid_generate ();
        s_conn.autoconnect = request.ip_request.autoconnect;
        conn.add_setting (s_conn);

        var mapper = VpnMapperFactory.create (request.vpn_type);
        mapper.map_from_request (request, conn);

        var s_ip4 = NmIpConfigHelper.ensure_ip4_setting (conn);
        NmIpConfigHelper.apply_ipv4_settings (s_ip4, request.ip_request.get_ipv4_section ());

        var s_ip6 = NmIpConfigHelper.ensure_ip6_setting (conn);
        NmIpConfigHelper.apply_ipv6_settings (s_ip6, request.ip_request.get_ipv6_section ());

        yield client.add_connection_async (conn, true, cancellable);
        return true;
    }
}
