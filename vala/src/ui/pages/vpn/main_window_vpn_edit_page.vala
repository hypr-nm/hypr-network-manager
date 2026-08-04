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

public class MainWindowVpnEditPage : Gtk.Box, IMainWindowIpEditPage {
    public Gtk.Label edit_title { get; set; }
    public string vpn_type { get; private set; default = "vpn"; }

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

    private VpnFormValues form_values;

    public HyprNetworkManager.UI.Widgets.DynamicPeerList? wg_peers_list {
        get {
            return form_values != null && form_values.wg != null ? form_values.wg.peers_list : null;
        }
    }

    private Gtk.Box type_specific_box;
    private Gtk.Label error_label;
    private Gtk.Revealer error_revealer;
    private TrackedDropDownFactory create_dropdown_func;

    public signal void back ();
    public signal void apply ();
    public signal void edit_peer_requested (int index, WireGuardPeerModel peer);

    public void setup_edit_form (VpnConnection conn, VpnProfileDetails details) {
        this.error_revealer.set_reveal_child (false);
        this.edit_title.set_text (_("Edit: %s").printf (conn.name));
        if (details is WireGuardVpnProfileDetails) {
            this.vpn_type = "wireguard";
        } else if (details is OpenVpnProfileDetails) {
            this.vpn_type = "openvpn";
        } else {
            this.vpn_type = details.vpn_type_key.strip () != "" ? details.vpn_type_key : "vpn";
        }

        this.form_values = new VpnFormValues ();
        this.form_values.vpn_type = this.vpn_type;
        this.form_values.ip_page = this;

        MainWindowHelpers.clear_box (type_specific_box);
        if (this.vpn_type == "wireguard") {
            MainWindowVpnFormBuilder.append_wg_fields (type_specific_box, this.form_values);
            if (this.form_values.wg != null) {
                this.form_values.wg.peers_list.edit_peer_requested.connect ((index, peer) => {
                    this.edit_peer_requested (index, peer);
                });
            }
        } else if (this.vpn_type == "openvpn") {
            MainWindowVpnFormBuilder.append_openvpn_fields (type_specific_box, this.form_values, this.create_dropdown_func);
        } else {
            MainWindowVpnFormBuilder.append_generic_vpn_fields (type_specific_box, this.form_values);
        }

        this.ipv4_method_dropdown.set_selected (MainWindowIpConfigHelper.method_to_index (details.ipv4_method));
        this.ipv4_address_entry.set_text (details.configured_address);
        this.ipv4_prefix_entry.set_text ("%u".printf (details.configured_prefix));
        this.ipv4_gateway_entry.set_text (details.configured_gateway);
        this.dns_auto_switch.set_active (details.dns_auto);
        this.ipv4_dns_entry.set_text (details.configured_dns);

        this.ipv6_method_dropdown.set_selected (MainWindowIpConfigHelper.method_to_index (details.ipv6_method, false));
        this.ipv6_address_entry.set_text (details.configured_ipv6_address);
        this.ipv6_prefix_entry.set_text ("%u".printf (details.configured_ipv6_prefix));
        this.ipv6_gateway_entry.set_text (details.configured_ipv6_gateway);
        this.ipv6_dns_auto_switch.set_active (details.ipv6_dns_auto);
        this.ipv6_dns_entry.set_text (details.configured_ipv6_dns);

        if (this.autoconnect_switch != null) {
            this.autoconnect_switch.set_active (details.autoconnect);
        }

        if (this.form_values.wg != null) {
            var wg_details = details as WireGuardVpnProfileDetails;
            if (wg_details != null) {
                var wg = this.form_values.wg;
                wg.interface_name_entry.set_text (wg_details.interface_name);
                wg.private_key_entry.set_text (wg_details.wg_private_key);
                wg.peers_list.set_peers (wg_details.peers);
                wg.listen_port_entry.set_text (wg_details.wg_listen_port > 0 ? "%u".printf (wg_details.wg_listen_port) : "");
                wg.fwmark_entry.set_text (wg_details.wg_fwmark > 0 ? "%u".printf (wg_details.wg_fwmark) : "");
                wg.peer_routes_switch.set_active (wg_details.wg_peer_routes);
            }
        } else if (this.form_values.ovpn != null) {
            var ovpn_details = details as OpenVpnProfileDetails;
            if (ovpn_details != null) {
                var ovpn = this.form_values.ovpn;
                ovpn.remote_entry.set_text (ovpn_details.ovpn_remote);
                ovpn.port_entry.set_text (ovpn_details.ovpn_port > 0 ? "%u".printf (ovpn_details.ovpn_port) : "");
                if (ovpn_details.ovpn_proto.down() == "tcp") {
                    ovpn.proto_dropdown.set_selected (1);
                } else {
                    ovpn.proto_dropdown.set_selected (0);
                }
                ovpn.user_entry.set_text (ovpn_details.ovpn_username);
                ovpn.password_entry.set_text (ovpn_details.ovpn_password);
                ovpn.ca_cert_entry.set_text (ovpn_details.ovpn_ca_cert);
                ovpn.client_cert_entry.set_text (ovpn_details.ovpn_client_cert);
                ovpn.private_key_entry.set_text (ovpn_details.ovpn_private_key);
                ovpn.tls_auth_key_entry.set_text (ovpn_details.ovpn_tls_auth_key);
                ovpn.cipher_entry.set_text (ovpn_details.ovpn_cipher);
                ovpn.auth_entry.set_text (ovpn_details.ovpn_auth);
            }
        } else if (this.form_values.generic != null) {
            var generic_details = details as GenericVpnProfileDetails;
            if (generic_details != null) {
                var generic = this.form_values.generic;
                generic.gateway_entry.set_text (generic_details.gateway);
                generic.user_entry.set_text (generic_details.username);
                generic.password_entry.set_text (generic_details.password);
            }
        }

        this.sync_edit_gateway_dns_sensitivity ();
    }

    public VpnUpdateRequest? build_update_request (out string? error_message) {
        return MainWindowVpnRequestBuilder.build (this.form_values, out error_message);
    }

    public void show_error (string message) {
        if (message == null || message == "") {
            this.error_revealer.set_reveal_child (false);
            return;
        }
        this.error_label.set_text (message);
        this.error_revealer.set_reveal_child (true);
    }

    public MainWindowVpnEditPage (IWidgetFactory widget_factory) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: MainWindowUiMetrics.SPACING_ROW);
        this.create_dropdown_func = widget_factory.create_tracked_dropdown;

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        this.add_css_class (MainWindowCssClasses.PAGE_VPN_EDIT);
        this.add_css_class (MainWindowCssClasses.PAGE_NETWORK_EDIT);

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        header.append (back_btn);

        this.edit_title = new Gtk.Label (_("Edit VPN"));
        this.edit_title.set_xalign (0.0f);
        this.edit_title.set_hexpand (true);
        this.edit_title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.append (this.edit_title);
        this.append (header);

        this.error_label = new Gtk.Label ("");
        this.error_label.set_xalign (0.0f);
        this.error_label.set_wrap (true);
        this.error_label.add_css_class (MainWindowCssClasses.ERROR_LABEL);
        this.error_label.add_css_class (MainWindowCssClasses.ROW_CONTENT_INSET);

        this.error_revealer = new Gtk.Revealer ();
        this.error_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        this.error_revealer.set_child (this.error_label);
        this.append (this.error_revealer);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        form.add_css_class (MainWindowCssClasses.EDIT_NETWORK_FORM);
        form.add_css_class (MainWindowCssClasses.EDIT_FORM);
        form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        var auto_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
        auto_row.add_css_class (MainWindowCssClasses.EDIT_MODE_ROW);
        auto_row.add_css_class (MainWindowCssClasses.NM_FLAT);
        var auto_lbl = new Gtk.Label (_("Connect automatically"));
        auto_lbl.set_xalign (0.0f);
        auto_lbl.set_hexpand (true);
        auto_lbl.add_css_class (MainWindowCssClasses.EDIT_MODE_LABEL);
        auto_row.append (auto_lbl);
        this.autoconnect_switch = new Gtk.Switch ();
        this.autoconnect_switch.set_valign (Gtk.Align.CENTER);
        this.autoconnect_switch.add_css_class (MainWindowCssClasses.SWITCH);
        this.autoconnect_switch.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
        this.autoconnect_switch.add_css_class (MainWindowCssClasses.EDIT_MODE_SWITCH);
        auto_row.append (this.autoconnect_switch);
        form.append (auto_row);

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
            widget_factory.create_tracked_dropdown,
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
            widget_factory.create_tracked_dropdown,
            true
        );

        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_entry = v6_gw;
        this.ipv6_dns_auto_switch = v6_dns_auto;
        this.ipv6_dns_entry = v6_dns;

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var save_btn = new Gtk.Button.with_label (_("Apply"));
        save_btn.add_css_class (MainWindowCssClasses.BUTTON);
        save_btn.add_css_class (MainWindowCssClasses.SUGGESTED_ACTION);
        save_btn.clicked.connect (() => {
            this.apply ();
        });
        actions.append (save_btn);
        form.append (actions);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);
        scroll.set_child (form);

        this.append (scroll);
    }
}
