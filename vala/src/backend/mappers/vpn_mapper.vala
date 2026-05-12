using GLib;

namespace HyprNetworkManager.Backend.Mappers {

public interface VpnMapper : GLib.Object {
    public abstract void map_to_details (NM.Connection conn, VpnProfileDetails details);
    public abstract void map_from_request (VpnUpdateRequest request, NM.Connection conn);
    public abstract string get_vpn_type_key ();
}

public class WireGuardMapper : GLib.Object, VpnMapper {
    public void map_to_details (NM.Connection conn, VpnProfileDetails details) {
        var wg_details = details as WireGuardVpnProfileDetails;
        if (wg_details == null) return;

        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            wg_details.interface_name = s_conn.interface_name ?? "";
        }

        var setting_wg = (NM.SettingWireGuard) conn.get_setting_by_name (NM.SettingWireGuard.SETTING_NAME);
        if (setting_wg == null) return;

        wg_details.wg_private_key = (setting_wg.get_private_key () ?? "").strip ();
        wg_details.wg_listen_port = (uint32) setting_wg.get_listen_port ();
        wg_details.wg_fwmark = setting_wg.get_fwmark ();
        wg_details.wg_peer_routes = setting_wg.get_peer_routes ();

        WireGuardPeerModel[] peers_array = {};
        for (uint i = 0; i < setting_wg.get_peers_len (); i++) {
            unowned NM.WireGuardPeer nm_peer = setting_wg.get_peer (i);
            var p = new WireGuardPeerModel ();
            p.public_key = (nm_peer.get_public_key () ?? "").strip ();
            
            string endpoint = (nm_peer.get_endpoint () ?? "").strip ();
            string[] parts = endpoint.split (":");
            if (parts.length > 1) {
                p.endpoint_host = string.joinv (":", parts[0:parts.length-1]);
                uint parsed_port;
                if (uint.try_parse (parts[parts.length-1], out parsed_port)) {
                    p.endpoint_port = (uint32) parsed_port;
                }
            } else {
                p.endpoint_host = endpoint;
            }
            
            p.preshared_key = (nm_peer.get_preshared_key () ?? "").strip ();

            string[] allowed_ips = {};
            uint allowed_len = nm_peer.get_allowed_ips_len ();
            for (uint idx = 0; idx < allowed_len; idx++) {
                string? allowed_ip = nm_peer.get_allowed_ip (idx, null);
                if (allowed_ip != null) {
                    string item = allowed_ip.strip ();
                    if (item != "") {
                        allowed_ips += item;
                    }
                }
            }
            p.allowed_ips = allowed_ips;
            peers_array += p;
        }
        wg_details.peers = peers_array;
    }

    public void map_from_request (VpnUpdateRequest request, NM.Connection conn) {
        var wg_request = request as WireGuardVpnUpdateRequest;
        if (wg_request == null) return;

        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            s_conn.type = "wireguard";
            if (wg_request.interface_name.strip () != "") {
                s_conn.interface_name = wg_request.interface_name.strip ();
            }
        }
        conn.remove_setting (typeof (NM.SettingVpn));

        var s_wg = new NM.SettingWireGuard ();
        s_wg.private_key = wg_request.wg_private_key.strip ();
        if (wg_request.wg_listen_port > 0) {
            s_wg.listen_port = wg_request.wg_listen_port;
        }
        if (wg_request.wg_fwmark > 0) {
            s_wg.fwmark = wg_request.wg_fwmark;
        }
        s_wg.peer_routes = wg_request.wg_peer_routes;

        foreach (var p in wg_request.peers) {
            var peer = new NM.WireGuardPeer ();
            peer.set_public_key (p.public_key.strip (), false);
            
            string endpoint = p.endpoint_host.strip ();
            if (p.endpoint_port > 0) {
                endpoint += ":%u".printf (p.endpoint_port);
            }
            peer.set_endpoint (endpoint, false);
            
            if (p.preshared_key.strip () != "") {
                peer.set_preshared_key (p.preshared_key.strip (), false);
            }

            string[] allowed_ips = p.allowed_ips;
            if (allowed_ips.length == 0) {
                allowed_ips += "0.0.0.0/0";
                allowed_ips += "::/0";
            }
            foreach (var allowed_ip in allowed_ips) {
                peer.append_allowed_ip (allowed_ip, false);
            }
            s_wg.append_peer (peer);
        }

        conn.remove_setting (typeof (NM.SettingWireGuard));
        conn.add_setting (s_wg);
    }

    public string get_vpn_type_key () {
        return "wireguard";
    }
}

public class OpenVpnMapper : GLib.Object, VpnMapper {
    public void map_to_details (NM.Connection conn, VpnProfileDetails details) {
        var ovpn_details = details as OpenVpnProfileDetails;
        if (ovpn_details == null) return;

        var setting_vpn = conn.get_setting_vpn ();
        if (setting_vpn == null) return;

        ovpn_details.ovpn_remote = (setting_vpn.get_data_item ("remote") ?? "").strip ();
        ovpn_details.ovpn_port = parse_uint32_or_zero (setting_vpn.get_data_item ("port"));
        ovpn_details.ovpn_proto = (setting_vpn.get_data_item ("proto") ?? "").strip ();
        ovpn_details.ovpn_username = (setting_vpn.get_data_item ("username") ?? "").strip ();
        ovpn_details.ovpn_password = (setting_vpn.get_secret ("password") ?? "").strip ();
        ovpn_details.ovpn_ca_cert = (setting_vpn.get_data_item ("ca") ?? "").strip ();
        ovpn_details.ovpn_client_cert = (setting_vpn.get_data_item ("cert") ?? "").strip ();
        ovpn_details.ovpn_private_key = (setting_vpn.get_data_item ("key") ?? "").strip ();
        ovpn_details.ovpn_tls_auth_key = (setting_vpn.get_data_item ("ta") ?? "").strip ();
        ovpn_details.ovpn_cipher = (setting_vpn.get_data_item ("cipher") ?? "").strip ();
        ovpn_details.ovpn_auth = (setting_vpn.get_data_item ("auth") ?? "").strip ();
    }

    public void map_from_request (VpnUpdateRequest request, NM.Connection conn) {
        var ovpn_request = request as OpenVpnUpdateRequest;
        if (ovpn_request == null) return;

        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            s_conn.type = "vpn";
        }
        conn.remove_setting (typeof (NM.SettingWireGuard));

        var s_vpn = new NM.SettingVpn ();
        s_vpn.service_type = "org.freedesktop.NetworkManager.openvpn";
        s_vpn.add_data_item ("remote", ovpn_request.ovpn_remote.strip ());
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

        conn.remove_setting (typeof (NM.SettingVpn));
        conn.add_setting (s_vpn);
    }

    public string get_vpn_type_key () {
        return "openvpn";
    }

    private uint32 parse_uint32_or_zero (string? value) {
        if (value == null) return 0;
        uint parsed;
        if (!uint.try_parse (value.strip (), out parsed)) {
            return 0;
        }
        return (uint32) parsed;
    }
}

public class GenericVpnMapper : GLib.Object, VpnMapper {
    private string vpn_type;

    public GenericVpnMapper (string vpn_type = "vpn") {
        this.vpn_type = vpn_type;
    }

    public void map_to_details (NM.Connection conn, VpnProfileDetails details) {
        var generic_details = details as GenericVpnProfileDetails;
        if (generic_details == null) return;

        var setting_vpn = conn.get_setting_vpn ();
        if (setting_vpn == null) return;

        generic_details.gateway = (setting_vpn.get_data_item ("gateway") ?? "").strip ();
        generic_details.username = (setting_vpn.get_data_item ("username") ?? "").strip ();
        generic_details.password = (setting_vpn.get_secret ("password") ?? "").strip ();
    }

    public void map_from_request (VpnUpdateRequest request, NM.Connection conn) {
        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            s_conn.type = "vpn";
        }
        conn.remove_setting (typeof (NM.SettingWireGuard));

        var s_vpn = new NM.SettingVpn ();
        string service_key = request.vpn_type.strip ().down ();
        if (service_key == "" || service_key == "vpn") {
            service_key = "vpn";
        }
        s_vpn.service_type = "org.freedesktop.NetworkManager." + service_key;

        var generic_request = request as GenericVpnUpdateRequest;
        if (generic_request != null) {
            if (generic_request.gateway.strip () != "") s_vpn.add_data_item ("gateway", generic_request.gateway.strip ());
            if (generic_request.user.strip () != "") s_vpn.add_data_item ("username", generic_request.user.strip ());
            if (generic_request.password != "") s_vpn.add_secret ("password", generic_request.password);
        }

        conn.remove_setting (typeof (NM.SettingVpn));
        conn.add_setting (s_vpn);
    }

    public string get_vpn_type_key () {
        return vpn_type;
    }
}

public class VpnMapperFactory : GLib.Object {
    public static VpnMapper create (string vpn_type_key) {
        string key = vpn_type_key.strip ().down ();
        if (key == "wireguard") {
            return new WireGuardMapper ();
        } else if (key == "openvpn") {
            return new OpenVpnMapper ();
        } else {
            return new GenericVpnMapper (key);
        }
    }

    public static VpnMapper create_for_connection (NM.Connection conn) {
        if (conn.get_setting_by_name (NM.SettingWireGuard.SETTING_NAME) != null
            || conn.is_type ("wireguard")) {
            return new WireGuardMapper ();
        }

        var setting_vpn = conn.get_setting_vpn ();
        if (setting_vpn != null) {
            string service_type = (setting_vpn.get_service_type () ?? "").strip ();
            if (service_type.has_suffix (".openvpn")) {
                return new OpenVpnMapper ();
            }
            
            string[] parts = service_type.split (".");
            string plugin_name = parts.length > 0 ? parts[parts.length - 1] : "vpn";
            return new GenericVpnMapper (plugin_name.down ());
        }

        return new GenericVpnMapper ("vpn");
    }
}

}
