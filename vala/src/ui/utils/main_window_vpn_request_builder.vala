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
using Gtk;
using HyprNetworkManager.UI.Interfaces;

namespace MainWindowVpnRequestBuilder {
    public VpnUpdateRequest? build (
        VpnFormValues values,
        out string? error_message
    ) {
        error_message = null;

        if (values.ip_page == null) {
            error_message = _("IP settings are required.");
            return null;
        }

        string? ip_error = null;
        var ip_request = values.ip_page.build_ip_update_request (out ip_error);
        if (ip_request == null) {
            error_message = ip_error;
            return null;
        }

        VpnUpdateRequest request;
        if (values.wg != null) {
            var wg = values.wg;
            var wg_request = new WireGuardVpnUpdateRequest ();
            wg_request.interface_name = wg.interface_name_entry.get_text ().strip ();
            wg_request.wg_private_key = wg.private_key_entry.get_text ().strip ();
            wg_request.peers = wg.peers_list.get_peers ();
            wg_request.wg_peer_routes = wg.peer_routes_switch.get_active ();

            uint32 wg_listen_port;
            if (!try_parse_optional_uint32 (wg.listen_port_entry.get_text (), 65535, out wg_listen_port)) {
                error_message = _("WireGuard listen port must be a number between 0 and 65535.");
                return null;
            }
            wg_request.wg_listen_port = wg_listen_port;

            uint32 wg_fwmark;
            if (!try_parse_optional_uint32 (wg.fwmark_entry.get_text (), uint32.MAX, out wg_fwmark)) {
                error_message = _("WireGuard fwmark must be a valid unsigned integer.");
                return null;
            }
            wg_request.wg_fwmark = wg_fwmark;

            request = wg_request;
        } else if (values.ovpn != null) {
            var ovpn = values.ovpn;
            var ovpn_request = new OpenVpnUpdateRequest ();
            ovpn_request.ovpn_remote = ovpn.remote_entry.get_text ().strip ();
            ovpn_request.ovpn_proto = ovpn.proto_dropdown.get_selected () == 1 ? "tcp" : "udp";
            ovpn_request.ovpn_username = ovpn.user_entry.get_text ().strip ();
            ovpn_request.ovpn_password = ovpn.password_entry.get_text ();
            ovpn_request.ovpn_ca_cert = ovpn.ca_cert_entry.get_text ().strip ();
            ovpn_request.ovpn_client_cert = ovpn.client_cert_entry.get_text ().strip ();
            ovpn_request.ovpn_private_key = ovpn.private_key_entry.get_text ().strip ();
            ovpn_request.ovpn_tls_auth_key = ovpn.tls_auth_key_entry.get_text ().strip ();
            ovpn_request.ovpn_cipher = ovpn.cipher_entry.get_text ().strip ();
            ovpn_request.ovpn_auth = ovpn.auth_entry.get_text ().strip ();

            uint32 ovpn_port;
            if (!try_parse_optional_uint32 (ovpn.port_entry.get_text (), 65535, out ovpn_port)) {
                error_message = _("OpenVPN port must be a number between 0 and 65535.");
                return null;
            }
            ovpn_request.ovpn_port = ovpn_port;

            request = ovpn_request;
        } else if (values.generic != null) {
            var generic = values.generic;
            var generic_request = new GenericVpnUpdateRequest (values.vpn_type);
            generic_request.gateway = generic.gateway_entry.get_text ().strip ();
            generic_request.user = generic.user_entry.get_text ().strip ();
            generic_request.password = generic.password_entry.get_text ();
            request = generic_request;
        } else {
            error_message = _("VPN form fields are required.");
            return null;
        }

        request.ip_request = ip_request;
        if (values.ip_page.autoconnect_switch != null) {
            request.ip_request.autoconnect = values.ip_page.autoconnect_switch.get_active ();
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
