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

namespace HyprNetworkManager.UI.Interfaces {

public interface IVpnFormFields : GLib.Object {
    public abstract Gtk.Entry? gateway_entry { get; set; }
    public abstract Gtk.Entry? user_entry { get; set; }
    public abstract Gtk.Entry? password_entry { get; set; }
    
    // WireGuard
    public abstract Gtk.Entry? wg_interface_name_entry { get; set; }
    public abstract Gtk.Entry? wg_private_key_entry { get; set; }
    public abstract HyprNetworkManager.UI.Widgets.DynamicPeerList? wg_peers_list { get; set; }
    public abstract Gtk.Entry? wg_listen_port_entry { get; set; }
    public abstract Gtk.Entry? wg_fwmark_entry { get; set; }
    public abstract Gtk.Switch? wg_peer_routes_switch { get; set; }

    // OpenVPN
    public abstract Gtk.Entry? ovpn_remote_entry { get; set; }
    public abstract Gtk.Entry? ovpn_port_entry { get; set; }
    public abstract HyprNetworkManager.UI.Widgets.TrackedDropDown? ovpn_proto_dropdown { get; set; }
    public abstract Gtk.Entry? ovpn_user_entry { get; set; }
    public abstract Gtk.Entry? ovpn_password_entry { get; set; }
    public abstract Gtk.Entry? ovpn_ca_cert_entry { get; set; }
    public abstract Gtk.Entry? ovpn_client_cert_entry { get; set; }
    public abstract Gtk.Entry? ovpn_private_key_entry { get; set; }
    public abstract Gtk.Entry? ovpn_tls_auth_key_entry { get; set; }
    public abstract Gtk.Entry? ovpn_cipher_entry { get; set; }
    public abstract Gtk.Entry? ovpn_auth_entry { get; set; }
}

}
