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

namespace HyprNetworkManager.UI.Interfaces {

/**
 * Concrete widget bundles for each VPN form variant.
 *
 * Fields are non-nullable: every field of a variant is populated whenever that
 * variant is rendered, so readers can access them directly without null checks.
 */
public class WgFormFields : GLib.Object {
    public Gtk.Entry interface_name_entry;
    public Gtk.Entry private_key_entry;
    public Gtk.Entry listen_port_entry;
    public Gtk.Entry fwmark_entry;
    public Gtk.Switch peer_routes_switch;
    public HyprNetworkManager.UI.Widgets.DynamicPeerList peers_list;
}

public class OpenVpnFormFields : GLib.Object {
    public Gtk.Entry remote_entry;
    public Gtk.Entry port_entry;
    public HyprNetworkManager.UI.Widgets.TrackedDropDown proto_dropdown;
    public Gtk.Entry user_entry;
    public Gtk.Entry password_entry;
    public Gtk.Entry ca_cert_entry;
    public Gtk.Entry client_cert_entry;
    public Gtk.Entry private_key_entry;
    public Gtk.Entry tls_auth_key_entry;
    public Gtk.Entry cipher_entry;
    public Gtk.Entry auth_entry;
}

public class GenericFormFields : GLib.Object {
    public Gtk.Entry gateway_entry;
    public Gtk.Entry user_entry;
    public Gtk.Entry password_entry;
}

/**
 * Collects the rendered VPN form widgets plus the IP settings surface.
 *
 * Exactly one variant (wg/ovpn/generic) is non-null for a given form, which is
 * what lets the request builder branch without runtime casts or field probes.
 */
public class VpnFormValues : GLib.Object {
    public string vpn_type { get; set; default = "vpn"; }
    public IMainWindowIpEditPage ip_page { get; set; }

    public WgFormFields? wg { get; set; }
    public OpenVpnFormFields? ovpn { get; set; }
    public GenericFormFields? generic { get; set; }
}

}
