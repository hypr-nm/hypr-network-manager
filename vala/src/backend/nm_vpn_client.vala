using GLib;

public class NmVpnClient : GLib.Object {
    private NetworkManagerClient core;

    public NmVpnClient (NetworkManagerClient core) {
        this.core = core;
    }

    private static string normalize_string (string? value) {
        return value != null ? value.strip () : "";
    }

    private static string normalize_key (string? value) {
        return normalize_string (value).down ();
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
            && normalize_connection_type (ac.get_connection_type ()) == normalize_connection_type (conn.get_connection_type ());
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

        switch (normalized) {
        case "vpn":
            return "VPN";
        case "openvpn":
            return "OpenVPN";
        case "openconnect":
            return "OpenConnect";
        case "wireguard":
            return "WireGuard";
        case "vpnc":
            return "VPNC";
        case "l2tp":
            return "L2TP";
        case "pptp":
            return "PPTP";
        case "sstp":
            return "SSTP";
        case "openfortivpn":
            return "OpenFortiVPN";
        case "fortisslvpn":
            return "FortiSSLVPN";
        case "libreswan":
            return "Libreswan";
        case "strongswan":
            return "strongSwan";
        default:
            break;
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

            string lower_piece = piece.down ();
            builder.append (lower_piece.substring (0, 1).up ());
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
        NM.Connection? vpn_conn = null;

        foreach (var conn in client.get_connections ()) {
            if (is_supported_vpn_profile (conn)
                && matches_connection_identity (conn.get_uuid (), conn.get_id (), id)) {
                vpn_conn = conn;
                break;
            }
        }

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

            var vpn = new VpnConnection () {
                uuid = conn.get_uuid (),
                name = conn.get_id (),
                vpn_type = describe_vpn_profile (conn),
                state = "deactivated"
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
                state = map_active_connection_state (ac)
            });
        }

        return vpns;
    }
}
