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

namespace HyprNetworkManager.Backend.Mappers {

public interface VpnMapper : GLib.Object {
    public abstract void map_to_details (NM.Connection conn, VpnProfileDetails details);
    public abstract void map_from_request (VpnUpdateRequest request, NM.Connection conn) throws Error;
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
            string host = endpoint;
            uint32 port = 0;

            if (endpoint != "") {
                if (endpoint.has_prefix ("[")) {
                    int close_bracket_idx = endpoint.index_of ("]");
                    if (close_bracket_idx != -1) {
                        host = endpoint.substring (1, close_bracket_idx - 1);
                        string remaining = endpoint.substring (close_bracket_idx + 1);
                        if (remaining.has_prefix (":")) {
                            uint parsed_port;
                            if (uint.try_parse (remaining.substring (1), out parsed_port)) {
                                port = (uint32) parsed_port;
                            }
                        }
                    }
                } else {
                    int first_colon_idx = endpoint.index_of (":");
                    int last_colon_idx = endpoint.last_index_of (":");
                    if (first_colon_idx != -1) {
                        if (first_colon_idx == last_colon_idx) {
                            host = endpoint.substring (0, first_colon_idx);
                            uint parsed_port;
                            if (uint.try_parse (endpoint.substring (first_colon_idx + 1), out parsed_port)) {
                                port = (uint32) parsed_port;
                            }
                        } else {
                            host = endpoint;
                            port = 0;
                        }
                    } else {
                        host = endpoint;
                        port = 0;
                    }
                }
            }

            p.endpoint_host = host;
            p.endpoint_port = port;
            
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

    public void map_from_request (VpnUpdateRequest request, NM.Connection conn) throws Error {
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
            if (!peer.set_public_key (p.public_key.strip (), false)) {
                throw new IOError.FAILED ("Invalid WireGuard public key: '%s'".printf (p.public_key.strip ()));
            }
            
            string endpoint = p.endpoint_host.strip ();
            if (endpoint != "") {
                if (endpoint.contains (":") && !endpoint.has_prefix ("[")) {
                    endpoint = "[" + endpoint + "]";
                }
                if (p.endpoint_port > 0) {
                    endpoint += ":%u".printf (p.endpoint_port);
                }
                if (!peer.set_endpoint (endpoint, false)) {
                    throw new IOError.FAILED ("Invalid WireGuard endpoint: '%s'".printf (endpoint));
                }
            }
            
            if (p.preshared_key.strip () != "") {
                if (!peer.set_preshared_key (p.preshared_key.strip (), false)) {
                    throw new IOError.FAILED ("Invalid WireGuard preshared key");
                }
            }

            string[] allowed_ips = p.allowed_ips;
            if (allowed_ips.length == 0) {
                allowed_ips += "0.0.0.0/0";
                allowed_ips += "::/0";
            }
            foreach (var allowed_ip in allowed_ips) {
                if (!peer.append_allowed_ip (allowed_ip, false)) {
                    throw new IOError.FAILED ("Invalid WireGuard allowed IP: '%s'".printf (allowed_ip));
                }
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
        ovpn_details.ovpn_password = setting_vpn.get_secret ("password") ?? "";
        ovpn_details.ovpn_ca_cert = (setting_vpn.get_data_item ("ca") ?? "").strip ();
        ovpn_details.ovpn_client_cert = (setting_vpn.get_data_item ("cert") ?? "").strip ();
        ovpn_details.ovpn_private_key = (setting_vpn.get_data_item ("key") ?? "").strip ();
        ovpn_details.ovpn_tls_auth_key = (setting_vpn.get_data_item ("ta") ?? "").strip ();
        ovpn_details.ovpn_cipher = (setting_vpn.get_data_item ("cipher") ?? "").strip ();
        ovpn_details.ovpn_auth = (setting_vpn.get_data_item ("auth") ?? "").strip ();
    }

    public void map_from_request (VpnUpdateRequest request, NM.Connection conn) throws Error {
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
        generic_details.password = setting_vpn.get_secret ("password") ?? "";
    }

    public void map_from_request (VpnUpdateRequest request, NM.Connection conn) throws Error {
        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            s_conn.type = "vpn";
        }
        conn.remove_setting (typeof (NM.SettingWireGuard));

        var s_vpn = new NM.SettingVpn ();
        string service_key = request.vpn_type.strip ().ascii_down ();
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
        string key = vpn_type_key.strip ().ascii_down ();
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
            return new GenericVpnMapper (plugin_name.ascii_down ());
        }

        return new GenericVpnMapper ("vpn");
    }
}

}
