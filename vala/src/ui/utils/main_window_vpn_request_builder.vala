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

using Gtk;
using HyprNetworkManager.UI.Interfaces;

namespace MainWindowVpnRequestBuilder {
    public VpnUpdateRequest? build (
        IVpnFormFields fields,
        string vpn_type,
        out string? error_message
    ) {
        error_message = null;

        var ip_page = fields as IMainWindowIpEditPage;
        if (ip_page == null) {
            error_message = _("IP settings are required.");
            return null;
        }

        string? ip_error = null;
        var ip_request = ip_page.build_ip_update_request (out ip_error);
        if (ip_request == null) {
            error_message = ip_error;
            return null;
        }

        VpnUpdateRequest request;
        if (vpn_type == "wireguard") {
            request = new WireGuardVpnUpdateRequest ();
        } else if (vpn_type == "openvpn") {
            request = new OpenVpnUpdateRequest ();
        } else {
            request = new GenericVpnUpdateRequest (vpn_type);
        }
        request.ip_request = ip_request;
        if (ip_page.autoconnect_switch != null) {
            request.ip_request.autoconnect = ip_page.autoconnect_switch.get_active ();
        }

        var wg_request = request as WireGuardVpnUpdateRequest;
        if (wg_request != null && fields.wg_private_key_entry != null) {
            wg_request.interface_name = fields.wg_interface_name_entry != null
                ? fields.wg_interface_name_entry.get_text ().strip ()
                : "";
            wg_request.wg_private_key = fields.wg_private_key_entry.get_text ().strip ();
            if (fields.wg_peers_list != null) {
                wg_request.peers = fields.wg_peers_list.get_peers ();
            }
            wg_request.wg_peer_routes = fields.wg_peer_routes_switch.get_active ();

            uint32 wg_listen_port;
            if (!try_parse_optional_uint32 (fields.wg_listen_port_entry.get_text (), 65535, out wg_listen_port)) {
                error_message = _("WireGuard listen port must be a number between 0 and 65535.");
                return null;
            }
            wg_request.wg_listen_port = wg_listen_port;

            uint32 wg_fwmark;
            if (!try_parse_optional_uint32 (fields.wg_fwmark_entry.get_text (), uint32.MAX, out wg_fwmark)) {
                error_message = _("WireGuard fwmark must be a valid unsigned integer.");
                return null;
            }
            wg_request.wg_fwmark = wg_fwmark;
        }

        var ovpn_request = request as OpenVpnUpdateRequest;
        if (ovpn_request != null && fields.ovpn_remote_entry != null) {
            ovpn_request.ovpn_remote = fields.ovpn_remote_entry.get_text ().strip ();
            ovpn_request.ovpn_proto = fields.ovpn_proto_dropdown != null
                && fields.ovpn_proto_dropdown.get_selected () == 1 ? "tcp" : "udp";
            ovpn_request.ovpn_username = fields.ovpn_user_entry.get_text ().strip ();
            ovpn_request.ovpn_password = fields.ovpn_password_entry.get_text ();
            ovpn_request.ovpn_ca_cert = fields.ovpn_ca_cert_entry.get_text ().strip ();
            ovpn_request.ovpn_client_cert = fields.ovpn_client_cert_entry.get_text ().strip ();
            ovpn_request.ovpn_private_key = fields.ovpn_private_key_entry.get_text ().strip ();
            ovpn_request.ovpn_tls_auth_key = fields.ovpn_tls_auth_key_entry.get_text ().strip ();
            ovpn_request.ovpn_cipher = fields.ovpn_cipher_entry.get_text ().strip ();
            ovpn_request.ovpn_auth = fields.ovpn_auth_entry.get_text ().strip ();

            uint32 ovpn_port;
            if (!try_parse_optional_uint32 (fields.ovpn_port_entry.get_text (), 65535, out ovpn_port)) {
                error_message = _("OpenVPN port must be a number between 0 and 65535.");
                return null;
            }
            ovpn_request.ovpn_port = ovpn_port;
        }

        var generic_request = request as GenericVpnUpdateRequest;
        if (generic_request != null && fields.gateway_entry != null) {
            generic_request.gateway = fields.gateway_entry.get_text ().strip ();
            generic_request.user = fields.user_entry.get_text ().strip ();
            generic_request.password = fields.password_entry.get_text ();
        }

        if (!request.validate (out error_message)) {
            return null;
        }

        return request;
    }

    private static bool try_parse_optional_uint32 (
        string raw_value,
        uint32 max_value,
        out uint32 parsed_value
    ) {
        parsed_value = 0;
        string trimmed = raw_value.strip ();
        if (trimmed == "") {
            return true;
        }

        uint parsed_uint;
        if (!uint.try_parse (trimmed, out parsed_uint) || parsed_uint > max_value) {
            return false;
        }

        parsed_value = (uint32) parsed_uint;
        return true;
    }
}
