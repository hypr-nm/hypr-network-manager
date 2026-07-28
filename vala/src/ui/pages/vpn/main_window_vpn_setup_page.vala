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

public class MainWindowVpnSetupPage : Gtk.Box, IMainWindowIpEditPage, IVpnFormFields {
    public Gtk.Label setup_title { get; set; }
    public string vpn_type { get; private set; }

    public Gtk.Entry name_entry { get; set; }
    
    // IVpnFormFields implementation
    public Gtk.Entry? gateway_entry { get; set; }
    public Gtk.Entry? user_entry { get; set; }
    public Gtk.Entry? password_entry { get; set; }
    
    // WireGuard specific
    public Gtk.Entry? wg_interface_name_entry { get; set; }
    public Gtk.Entry? wg_private_key_entry { get; set; }
    public HyprNetworkManager.UI.Widgets.DynamicPeerList? wg_peers_list { get; set; }
    public Gtk.Entry? wg_listen_port_entry { get; set; }
    public Gtk.Entry? wg_fwmark_entry { get; set; }
    public Gtk.Switch? wg_peer_routes_switch { get; set; }

    // OpenVPN specific
    public Gtk.Entry? ovpn_remote_entry { get; set; }
    public Gtk.Entry? ovpn_port_entry { get; set; }
    public HyprNetworkManager.UI.Widgets.TrackedDropDown? ovpn_proto_dropdown { get; set; }
    public Gtk.Entry? ovpn_user_entry { get; set; }
    public Gtk.Entry? ovpn_password_entry { get; set; }
    public Gtk.Entry? ovpn_ca_cert_entry { get; set; }
    public Gtk.Entry? ovpn_client_cert_entry { get; set; }
    public Gtk.Entry? ovpn_private_key_entry { get; set; }
    public Gtk.Entry? ovpn_tls_auth_key_entry { get; set; }
    public Gtk.Entry? ovpn_cipher_entry { get; set; }
    public Gtk.Entry? ovpn_auth_entry { get; set; }

    // IMainWindowIpEditPage implementation
    public HyprNetworkManager.UI.Widgets.TrackedDropDown ipv4_method_dropdown { get; set; }
    public Gtk.Entry ipv4_address_entry { get; set; }
    public Gtk.Entry ipv4_prefix_entry { get; set; }
    public Gtk.Entry ipv4_gateway_entry { get; set; }
    public Gtk.Switch dns_auto_switch { get; set; }
    public Gtk.Entry ipv4_dns_entry { get; set; }
    public HyprNetworkManager.UI.Widgets.TrackedDropDown ipv6_method_dropdown { get; set; }
    public Gtk.Entry ipv6_address_entry { get; set; }
    public Gtk.Entry ipv6_prefix_entry { get; set; }
    public Gtk.Entry ipv6_gateway_entry { get; set; }
    public Gtk.Switch ipv6_dns_auto_switch { get; set; }
    public Gtk.Entry ipv6_dns_entry { get; set; }
    public Gtk.Switch? autoconnect_switch { get; set; }

    private Gtk.Box type_specific_box;
    private Gtk.Revealer error_revealer;
    private Gtk.Label error_label;
    private TrackedDropDownFactory create_dropdown_func;

    public signal void back ();
    public signal void apply ();
    public signal void edit_peer_requested (int index, WireGuardPeerModel peer);

    public void setup_type (string type) {
        this.vpn_type = type;
        this.setup_title.set_text (_("Setup %s").printf (type));
        this.error_revealer.set_reveal_child (false);
        
        // Clear type-specific fields
        MainWindowHelpers.clear_box (type_specific_box);

        if (this.vpn_type == "wireguard") {
            MainWindowVpnFormBuilder.append_wg_fields (type_specific_box, this);
            if (this.wg_peers_list != null) {
                this.wg_peers_list.edit_peer_requested.connect ((index, peer) => {
                    this.edit_peer_requested (index, peer);
                });
            }
        } else if (this.vpn_type == "openvpn") {
            MainWindowVpnFormBuilder.append_openvpn_fields (type_specific_box, this, this.create_dropdown_func, true);
        } else {
            MainWindowVpnFormBuilder.append_generic_vpn_fields (type_specific_box, this);
        }
    }

    public VpnUpdateRequest? build_create_request (out string? error_message) {
        error_message = null;

        string name = name_entry.get_text ().strip ();
        if (name == "") {
            error_message = _("Connection name is required.");
            return null;
        }

        var request = MainWindowVpnRequestBuilder.build (this, this.vpn_type, out error_message);
        if (request == null) {
            return null;
        }
        request.name = name;
        return request;
    }

    public void show_error (string message) {
        if (message == null || message == "") {
            this.error_revealer.set_reveal_child (false);
            return;
        }
        this.error_label.set_text (message);
        this.error_revealer.set_reveal_child (true);
    }

    public MainWindowVpnSetupPage (IWindowHost window_host) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: MainWindowUiMetrics.SPACING_ROW);
        this.create_dropdown_func = window_host.create_tracked_dropdown;

        this.set_hexpand (true);
        this.set_vexpand (true);
        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
            MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_VPN_SETUP,
            {MainWindowCssClasses.PAGE_NETWORK_ADD, MainWindowCssClasses.PAGE_NETWORK_EDIT, MainWindowCssClasses.PAGE}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        header.append (back_btn);

        this.setup_title = new Gtk.Label (_("Setup VPN"));
        this.setup_title.set_xalign (0.0f);
        this.setup_title.set_hexpand (true);
        this.setup_title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.append (this.setup_title);
        this.append (header);

        this.error_label = new Gtk.Label ("");
        this.error_label.set_xalign (0.0f);
        this.error_label.set_wrap (true);
        this.error_label.add_css_class (MainWindowCssClasses.ERROR_LABEL);

        this.error_revealer = new Gtk.Revealer ();
        this.error_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        this.error_revealer.set_child (this.error_label);
        this.append (this.error_revealer);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        MainWindowCssClassResolver.add_best_class (
            form,
            {MainWindowCssClasses.ADD_NETWORK_FORM, MainWindowCssClasses.EDIT_NETWORK_FORM,
                MainWindowCssClasses.EDIT_FORM}
        );
        form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        var name_lbl = new Gtk.Label (_("Connection Name")) { xalign = 0.0f };
        name_lbl.add_css_class (MainWindowCssClasses.FORM_LABEL);
        form.append (name_lbl);
        name_entry = new Gtk.Entry ();
        name_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        form.append (name_entry);

        type_specific_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        form.append (type_specific_box);

        HyprNetworkManager.UI.Widgets.TrackedDropDown v4_method;
        Gtk.Entry v4_address, v4_prefix, v4_gw, v4_dns;
        Gtk.Switch v4_dns_auto;

        MainWindowIpEditFormBuilder.append_ipv4_section (
            form,
            out v4_method,
            out v4_address,
            out v4_prefix,
            out v4_gw,
            out v4_dns_auto,
            out v4_dns,
            window_host.create_tracked_dropdown,
            true
        );

        this.ipv4_method_dropdown = v4_method;
        this.ipv4_address_entry = v4_address;
        this.ipv4_prefix_entry = v4_prefix;
        this.ipv4_gateway_entry = v4_gw;
        this.dns_auto_switch = v4_dns_auto;
        this.ipv4_dns_entry = v4_dns;

        HyprNetworkManager.UI.Widgets.TrackedDropDown v6_method;
        Gtk.Entry v6_address, v6_prefix, v6_gw, v6_dns;
        Gtk.Switch v6_dns_auto;

        MainWindowIpEditFormBuilder.append_ipv6_section (
            form,
            out v6_method,
            out v6_address,
            out v6_prefix,
            out v6_gw,
            out v6_dns_auto,
            out v6_dns,
            window_host.create_tracked_dropdown,
            true
        );

        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_entry = v6_gw;
        this.ipv6_dns_auto_switch = v6_dns_auto;
        this.ipv6_dns_entry = v6_dns;

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var save_btn = new Gtk.Button.with_label (_("Create"));
        save_btn.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (save_btn, {MainWindowCssClasses.SUGGESTED_ACTION,
            MainWindowCssClasses.BUTTON});
        save_btn.clicked.connect (() => {
            this.apply ();
        });
        actions.append (save_btn);
        form.append (actions);

        scroll.set_child (form);
        this.append (scroll);
    }
}
