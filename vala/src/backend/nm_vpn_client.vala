using GLib;

public class NmVpnClient : GLib.Object {
    private NetworkManagerClient core;
    private static HashTable<string, string>? plugin_names = null;

    public NmVpnClient (NetworkManagerClient core) {
        this.core = core;
    }

    private static HashTable<string, string> get_plugin_names () {
        if (plugin_names != null) {
            return plugin_names;
        }

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
        plugin_names = map;
        return plugin_names;
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

    private static string service_type_to_key (string service_type) {
        string normalized = normalize_string (service_type);
        if (normalized == "") {
            return "vpn";
        }

        string[] parts = normalized.split (".");
        string plugin_name = parts.length > 0 ? parts[parts.length - 1] : normalized;
        return normalize_key (plugin_name);
    }

    private static string get_vpn_type_key (NM.Connection conn) {
        if (is_wireguard_connection (conn)) {
            return "wireguard";
        }

        var setting_vpn = conn.get_setting_vpn ();
        if (setting_vpn != null) {
            string key = service_type_to_key (setting_vpn.get_service_type ());
            return key != "" ? key : "vpn";
        }

        return normalize_connection_type (conn.get_connection_type ());
    }

    private static string vpn_data_item (NM.SettingVpn setting_vpn, string key) {
        return normalize_string (setting_vpn.get_data_item (key));
    }

    private static string vpn_secret_item (NM.SettingVpn setting_vpn, string key) {
        return normalize_string (setting_vpn.get_secret (key));
    }

    private static uint32 parse_uint32_or_zero (string value) {
        uint parsed;
        if (!uint.try_parse (normalize_string (value), out parsed)) {
            return 0;
        }
        return (uint32) parsed;
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
        VpnProfileDetails details = new GenericVpnProfileDetails ();

        NM.Connection? vpn_conn = null;
        foreach (var conn in client.get_connections ()) {
            if (is_supported_vpn_profile (conn)
                && matches_connection_identity (conn.get_uuid (), conn.get_id (), id)) {
                vpn_conn = conn;
                break;
            }
        }

        if (vpn_conn != null) {
            string vpn_type_key = get_vpn_type_key (vpn_conn);
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
            }

            var setting_vpn = vpn_conn.get_setting_vpn ();
            if (setting_vpn != null) {
                details.service_type = normalize_string (setting_vpn.get_service_type ());
                var ovpn_details = details as OpenVpnProfileDetails;
                if (ovpn_details != null) {
                    ovpn_details.ovpn_remote = vpn_data_item (setting_vpn, "remote");
                    ovpn_details.ovpn_port = parse_uint32_or_zero (vpn_data_item (setting_vpn, "port"));
                    ovpn_details.ovpn_proto = vpn_data_item (setting_vpn, "proto");
                    ovpn_details.ovpn_username = vpn_data_item (setting_vpn, "username");
                    ovpn_details.ovpn_password = vpn_secret_item (setting_vpn, "password");
                    ovpn_details.ovpn_ca_cert = vpn_data_item (setting_vpn, "ca");
                    ovpn_details.ovpn_client_cert = vpn_data_item (setting_vpn, "cert");
                    ovpn_details.ovpn_private_key = vpn_data_item (setting_vpn, "key");
                    ovpn_details.ovpn_tls_auth_key = vpn_data_item (setting_vpn, "ta");
                    ovpn_details.ovpn_cipher = vpn_data_item (setting_vpn, "cipher");
                    ovpn_details.ovpn_auth = vpn_data_item (setting_vpn, "auth");
                } else {
                    var generic_details = details as GenericVpnProfileDetails;
                    if (generic_details != null) {
                        generic_details.gateway = vpn_data_item (setting_vpn, "gateway");
                        generic_details.username = vpn_data_item (setting_vpn, "username");
                        generic_details.password = vpn_secret_item (setting_vpn, "password");
                    }
                }
            }

            var setting_wg = (NM.SettingWireGuard) vpn_conn.get_setting_by_name (NM.SettingWireGuard.SETTING_NAME);
            if (setting_wg != null) {
                var wg_details = details as WireGuardVpnProfileDetails;
                if (wg_details != null) {
                    wg_details.wg_private_key = normalize_string (setting_wg.get_private_key ());
                    wg_details.wg_listen_port = (uint32) setting_wg.get_listen_port ();
                    wg_details.wg_fwmark = setting_wg.get_fwmark ();
                    wg_details.wg_peer_routes = setting_wg.get_peer_routes ();

                    if (setting_wg.get_peers_len () > 0) {
                        unowned NM.WireGuardPeer peer = setting_wg.get_peer (0);
                        wg_details.wg_peer_public_key = normalize_string (peer.get_public_key ());
                        wg_details.wg_peer_endpoint = normalize_string (peer.get_endpoint ());
                        wg_details.wg_preshared_key = normalize_string (peer.get_preshared_key ());

                        string[] allowed_ips = {};
                        uint allowed_len = peer.get_allowed_ips_len ();
                        for (uint idx = 0; idx < allowed_len; idx++) {
                            string? allowed_ip = peer.get_allowed_ip (idx, null);
                            if (allowed_ip != null) {
                                string item = allowed_ip.strip ();
                                if (item != "") {
                                    allowed_ips += item;
                                }
                            }
                        }
                        wg_details.wg_peer_allowed_ips = string.joinv (", ", allowed_ips);
                    }
                }
            }
        }

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

        var s_conn = vpn_conn.get_setting_connection ();
        if (s_conn != null) {
            string new_name = request.name.strip ();
            if (new_name != "") {
                s_conn.id = new_name;
            }
            s_conn.autoconnect = request.ip_request.autoconnect;
        }

        var wg_request = request as WireGuardVpnUpdateRequest;
        var ovpn_request = request as OpenVpnUpdateRequest;
        var generic_request = request as GenericVpnUpdateRequest;

        if (wg_request != null) {
            if (s_conn != null) {
                s_conn.type = "wireguard";
            }
            vpn_conn.remove_setting (typeof (NM.SettingVpn));

            var s_wg = new NM.SettingWireGuard ();
            s_wg.private_key = wg_request.wg_private_key.strip ();
            if (wg_request.wg_listen_port > 0) {
                s_wg.listen_port = wg_request.wg_listen_port;
            }
            if (wg_request.wg_fwmark > 0) {
                s_wg.fwmark = wg_request.wg_fwmark;
            }
            s_wg.peer_routes = wg_request.wg_peer_routes;

            if (wg_request.wg_private_key.strip () == "") {
                throw new IOError.FAILED ("WireGuard private key is required");
            }
            if (wg_request.wg_peer_public_key.strip () == "") {
                throw new IOError.FAILED ("WireGuard peer public key is required");
            }
            if (wg_request.wg_peer_endpoint.strip () == "") {
                throw new IOError.FAILED ("WireGuard peer endpoint is required");
            }

            var peer = new NM.WireGuardPeer ();
            if (!peer.set_public_key (wg_request.wg_peer_public_key.strip (), false)) {
                throw new IOError.FAILED ("Invalid WireGuard peer public key");
            }
            if (!peer.set_endpoint (wg_request.wg_peer_endpoint.strip (), false)) {
                throw new IOError.FAILED ("Invalid WireGuard peer endpoint");
            }
            if (wg_request.wg_preshared_key.strip () != ""
                && !peer.set_preshared_key (wg_request.wg_preshared_key.strip (), false)) {
                throw new IOError.FAILED ("Invalid WireGuard preshared key");
            }

            string[] allowed_ips = {};
            foreach (var ip in wg_request.wg_peer_allowed_ips.split (",")) {
                string item = ip.strip ();
                if (item != "") {
                    allowed_ips += item;
                }
            }
            if (allowed_ips.length == 0) {
                allowed_ips += "0.0.0.0/0";
                allowed_ips += "::/0";
            }
            foreach (var allowed_ip in allowed_ips) {
                if (!peer.append_allowed_ip (allowed_ip, false)) {
                    throw new IOError.FAILED ("Invalid WireGuard allowed IP: " + allowed_ip);
                }
            }

            s_wg.append_peer (peer);
            vpn_conn.remove_setting (typeof (NM.SettingWireGuard));
            vpn_conn.add_setting (s_wg);
        } else {
            if (s_conn != null) {
                s_conn.type = "vpn";
            }

            vpn_conn.remove_setting (typeof (NM.SettingWireGuard));
            var s_vpn = new NM.SettingVpn ();

            if (ovpn_request != null) {
                ovpn_request.ovpn_remote = ovpn_request.ovpn_remote.strip ();
                if (ovpn_request.ovpn_remote == "") {
                    throw new IOError.FAILED ("OpenVPN remote is required");
                }

                s_vpn.service_type = "org.freedesktop.NetworkManager.openvpn";
                s_vpn.add_data_item ("remote", ovpn_request.ovpn_remote);
                if (ovpn_request.ovpn_port > 0) {
                    s_vpn.add_data_item ("port", "%u".printf (ovpn_request.ovpn_port));
                }
                if (ovpn_request.ovpn_proto.strip () != "") {
                    s_vpn.add_data_item ("proto", ovpn_request.ovpn_proto.strip ());
                }
                if (ovpn_request.ovpn_username.strip () != "") {
                    string username = ovpn_request.ovpn_username.strip ();
                    s_vpn.user_name = username;
                    s_vpn.add_data_item ("username", username);
                }
                if (ovpn_request.ovpn_password != "") {
                    s_vpn.add_secret ("password", ovpn_request.ovpn_password);
                }
                if (ovpn_request.ovpn_ca_cert.strip () != "") s_vpn.add_data_item ("ca", ovpn_request.ovpn_ca_cert.strip ());
                if (ovpn_request.ovpn_client_cert.strip () != "") s_vpn.add_data_item ("cert", ovpn_request.ovpn_client_cert.strip ());
                if (ovpn_request.ovpn_private_key.strip () != "") s_vpn.add_data_item ("key", ovpn_request.ovpn_private_key.strip ());
                if (ovpn_request.ovpn_tls_auth_key.strip () != "") s_vpn.add_data_item ("ta", ovpn_request.ovpn_tls_auth_key.strip ());
                if (ovpn_request.ovpn_cipher.strip () != "") s_vpn.add_data_item ("cipher", ovpn_request.ovpn_cipher.strip ());
                if (ovpn_request.ovpn_auth.strip () != "") s_vpn.add_data_item ("auth", ovpn_request.ovpn_auth.strip ());
            } else {
                string service_key = normalize_key (request.vpn_type);
                if (service_key == "" || service_key == "vpn") {
                    service_key = "vpn";
                }
                s_vpn.service_type = "org.freedesktop.NetworkManager." + service_key;
                if (generic_request != null) {
                    if (generic_request.gateway.strip () != "") s_vpn.add_data_item ("gateway", generic_request.gateway.strip ());
                    if (generic_request.user.strip () != "") s_vpn.add_data_item ("username", generic_request.user.strip ());
                    if (generic_request.password != "") s_vpn.add_secret ("password", generic_request.password);
                }
            }

            vpn_conn.remove_setting (typeof (NM.SettingVpn));
            vpn_conn.add_setting (s_vpn);
        }

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

        request.name = request.name.strip ();
        if (request.name == "") {
            throw new IOError.FAILED ("Connection name is required");
        }

        var s_conn = new NM.SettingConnection ();
        s_conn.id = request.name;
        s_conn.uuid = NM.Utils.uuid_generate ();
        s_conn.autoconnect = request.ip_request.autoconnect;
        conn.add_setting (s_conn);

        var wg_request = request as WireGuardVpnUpdateRequest;
        var ovpn_request = request as OpenVpnUpdateRequest;
        var generic_request = request as GenericVpnUpdateRequest;

        if (wg_request != null) {
            s_conn.type = "wireguard";

            wg_request.wg_private_key = wg_request.wg_private_key.strip ();
            wg_request.wg_peer_public_key = wg_request.wg_peer_public_key.strip ();
            wg_request.wg_peer_endpoint = wg_request.wg_peer_endpoint.strip ();
            wg_request.wg_peer_allowed_ips = wg_request.wg_peer_allowed_ips.strip ();

            if (wg_request.wg_private_key == "") {
                throw new IOError.FAILED ("WireGuard private key is required");
            }
            if (wg_request.wg_peer_public_key == "") {
                throw new IOError.FAILED ("WireGuard peer public key is required");
            }
            if (wg_request.wg_peer_endpoint == "") {
                throw new IOError.FAILED ("WireGuard peer endpoint is required");
            }

            var s_wg = new NM.SettingWireGuard ();
            s_wg.private_key = wg_request.wg_private_key;
            if (wg_request.wg_listen_port > 0) {
                s_wg.listen_port = wg_request.wg_listen_port;
            }
            if (wg_request.wg_fwmark > 0) {
                s_wg.fwmark = wg_request.wg_fwmark;
            }
            s_wg.peer_routes = wg_request.wg_peer_routes;
            
            var peer = new NM.WireGuardPeer ();
            if (!peer.set_public_key (wg_request.wg_peer_public_key, false)) {
                throw new IOError.FAILED ("Invalid WireGuard peer public key");
            }
            if (!peer.set_endpoint (wg_request.wg_peer_endpoint, false)) {
                throw new IOError.FAILED ("Invalid WireGuard peer endpoint");
            }
            if (wg_request.wg_preshared_key.strip () != ""
                && !peer.set_preshared_key (wg_request.wg_preshared_key.strip (), false)) {
                throw new IOError.FAILED ("Invalid WireGuard preshared key");
            }

            string[] allowed_ips = {};
            foreach (var ip in wg_request.wg_peer_allowed_ips.split (",")) {
                string item = ip.strip ();
                if (item != "") {
                    allowed_ips += item;
                }
            }
            if (allowed_ips.length == 0) {
                allowed_ips += "0.0.0.0/0";
                allowed_ips += "::/0";
            }
            foreach (var allowed_ip in allowed_ips) {
                if (!peer.append_allowed_ip (allowed_ip, false)) {
                    throw new IOError.FAILED ("Invalid WireGuard allowed IP: " + allowed_ip);
                }
            }
            s_wg.append_peer (peer);
            
            conn.add_setting (s_wg);
        } else if (ovpn_request != null) {
            s_conn.type = "vpn";
            var s_vpn = new NM.SettingVpn ();
            s_vpn.service_type = "org.freedesktop.NetworkManager.openvpn";

            ovpn_request.ovpn_remote = ovpn_request.ovpn_remote.strip ();
            if (ovpn_request.ovpn_remote == "") {
                throw new IOError.FAILED ("OpenVPN remote is required");
            }
            s_vpn.add_data_item ("remote", ovpn_request.ovpn_remote);

            if (ovpn_request.ovpn_port > 0) {
                s_vpn.add_data_item ("port", "%u".printf (ovpn_request.ovpn_port));
            }
            if (ovpn_request.ovpn_proto.strip () != "") {
                s_vpn.add_data_item ("proto", ovpn_request.ovpn_proto.strip ());
            }
            if (ovpn_request.ovpn_username.strip () != "") {
                string username = ovpn_request.ovpn_username.strip ();
                s_vpn.user_name = username;
                s_vpn.add_data_item ("username", username);
            }
            if (ovpn_request.ovpn_password != "") {
                s_vpn.add_secret ("password", ovpn_request.ovpn_password);
            }
            if (ovpn_request.ovpn_ca_cert.strip () != "") {
                s_vpn.add_data_item ("ca", ovpn_request.ovpn_ca_cert.strip ());
            }
            if (ovpn_request.ovpn_client_cert.strip () != "") {
                s_vpn.add_data_item ("cert", ovpn_request.ovpn_client_cert.strip ());
            }
            if (ovpn_request.ovpn_private_key.strip () != "") {
                s_vpn.add_data_item ("key", ovpn_request.ovpn_private_key.strip ());
            }
            if (ovpn_request.ovpn_tls_auth_key.strip () != "") {
                s_vpn.add_data_item ("ta", ovpn_request.ovpn_tls_auth_key.strip ());
            }
            if (ovpn_request.ovpn_cipher.strip () != "") {
                s_vpn.add_data_item ("cipher", ovpn_request.ovpn_cipher.strip ());
            }
            if (ovpn_request.ovpn_auth.strip () != "") {
                s_vpn.add_data_item ("auth", ovpn_request.ovpn_auth.strip ());
            }

            conn.add_setting (s_vpn);
        } else {
            s_conn.type = "vpn";
            var s_vpn = new NM.SettingVpn ();
            string service_key = normalize_key (request.vpn_type);
            if (service_key == "" || service_key == "vpn") {
                service_key = "vpn";
            }
            s_vpn.service_type = "org.freedesktop.NetworkManager." + service_key;
            if (generic_request != null) {
                if (generic_request.gateway != "") s_vpn.add_data_item ("gateway", generic_request.gateway);
                if (generic_request.user != "") s_vpn.add_data_item ("username", generic_request.user);
                if (generic_request.password != "") s_vpn.add_secret ("password", generic_request.password);
            }
            
            conn.add_setting (s_vpn);
        }

        var s_ip4 = NmIpConfigHelper.ensure_ip4_setting (conn);
        NmIpConfigHelper.apply_ipv4_settings (s_ip4, request.ip_request.get_ipv4_section ());

        var s_ip6 = NmIpConfigHelper.ensure_ip6_setting (conn);
        NmIpConfigHelper.apply_ipv6_settings (s_ip6, request.ip_request.get_ipv6_section ());

        yield client.add_connection_async (conn, true, cancellable);
        return true;
    }
}
