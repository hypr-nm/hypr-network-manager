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

public class MainWindowVpnFormBuilder : Object {
    public static void append_generic_vpn_fields (
        Gtk.Box target_box,
        VpnFormValues values
    ) {
        var fields = new GenericFormFields ();

        Gtk.Box server_content;
        var server_section = MainWindowHelpers.build_collapsible_section (_("Server"), out server_content, MainWindowUiMetrics.SPACING_TOOLBAR);
        target_box.append (server_section);

        server_content.append (build_form_label (_("Gateway")));
        fields.gateway_entry = new Gtk.Entry ();
        fields.gateway_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (fields.gateway_entry);

        Gtk.Box auth_content;
        var auth_section = MainWindowHelpers.build_collapsible_section (_("Authentication"), out auth_content, MainWindowUiMetrics.SPACING_TOOLBAR);
        target_box.append (auth_section);

        auth_content.append (build_form_label (_("Username (optional)")));
        fields.user_entry = new Gtk.Entry ();
        fields.user_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (fields.user_entry);

        auth_content.append (build_form_label (_("Password (optional)")));
        fields.password_entry = new Gtk.Entry ();
        fields.password_entry.set_visibility (false);
        fields.password_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (fields.password_entry);

        values.generic = fields;
    }

    public static void append_wg_fields (
        Gtk.Box target_box,
        VpnFormValues values
    ) {
        var fields = new WgFormFields ();

        target_box.append (build_form_label (_("Name")));
        fields.interface_name_entry = new Gtk.Entry ();
        fields.interface_name_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        target_box.append (fields.interface_name_entry);

        target_box.append (build_form_label (_("Listen Port (optional)")));
        fields.listen_port_entry = new Gtk.Entry ();
        fields.listen_port_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
        fields.listen_port_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        target_box.append (fields.listen_port_entry);

        target_box.append (build_form_label (_("Private Key")));
        fields.private_key_entry = new Gtk.Entry ();
        fields.private_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        target_box.append (fields.private_key_entry);

        fields.peers_list = new HyprNetworkManager.UI.Widgets.DynamicPeerList ();
        target_box.append (fields.peers_list);

        target_box.append (build_form_label (_("FwMark (optional)")));
        fields.fwmark_entry = new Gtk.Entry ();
        fields.fwmark_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
        fields.fwmark_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        target_box.append (fields.fwmark_entry);

        fields.peer_routes_switch = build_labeled_switch_row (
            _("Automatically add peer routes"),
            true,
            target_box
        );

        values.wg = fields;
    }

    public static void append_openvpn_fields (
        Gtk.Box target_box,
        VpnFormValues values,
        TrackedDropDownFactory create_dropdown,
        bool default_proto_udp = false
    ) {
        var fields = new OpenVpnFormFields ();

        Gtk.Box server_content;
        var server_section = MainWindowHelpers.build_collapsible_section (_("Server"), out server_content, MainWindowUiMetrics.SPACING_TOOLBAR);
        target_box.append (server_section);

        server_content.append (build_form_label (_("Remote")));
        fields.remote_entry = new Gtk.Entry ();
        fields.remote_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (fields.remote_entry);

        server_content.append (build_form_label (_("Port (optional)")));
        fields.port_entry = new Gtk.Entry ();
        fields.port_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
        fields.port_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (fields.port_entry);

        server_content.append (build_form_label (_("Protocol (optional)")));
        var proto_list = new Gtk.StringList (null);
        proto_list.append ("UDP");
        proto_list.append ("TCP");
        fields.proto_dropdown = create_dropdown (proto_list);
        fields.proto_dropdown.set_selected (default_proto_udp ? 0 : 1); // Select udp by default if default_proto_udp is true
        fields.proto_dropdown.add_css_class (MainWindowCssClasses.EDIT_DROPDOWN);
        fields.proto_dropdown.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
        server_content.append (fields.proto_dropdown);

        Gtk.Box auth_content;
        var auth_section = MainWindowHelpers.build_collapsible_section (_("Authentication"), out auth_content, MainWindowUiMetrics.SPACING_TOOLBAR);
        target_box.append (auth_section);

        auth_content.append (build_form_label (_("Username (optional)")));
        fields.user_entry = new Gtk.Entry ();
        fields.user_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (fields.user_entry);

        auth_content.append (build_form_label (_("Password (optional)")));
        fields.password_entry = new Gtk.Entry ();
        fields.password_entry.set_visibility (false);
        fields.password_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (fields.password_entry);

        Gtk.Box certs_content;
        var certs_section = MainWindowHelpers.build_collapsible_section (_("Certificates and Keys"), out certs_content, MainWindowUiMetrics.SPACING_TOOLBAR);
        target_box.append (certs_section);

        certs_content.append (build_form_label (_("CA Certificate Path (optional)")));
        fields.ca_cert_entry = new Gtk.Entry ();
        fields.ca_cert_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (fields.ca_cert_entry);

        certs_content.append (build_form_label (_("Client Certificate Path (optional)")));
        fields.client_cert_entry = new Gtk.Entry ();
        fields.client_cert_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (fields.client_cert_entry);

        certs_content.append (build_form_label (_("Private Key Path (optional)")));
        fields.private_key_entry = new Gtk.Entry ();
        fields.private_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (fields.private_key_entry);

        certs_content.append (build_form_label (_("TLS Auth Key Path (optional)")));
        fields.tls_auth_key_entry = new Gtk.Entry ();
        fields.tls_auth_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (fields.tls_auth_key_entry);

        Gtk.Box advanced_content;
        var advanced_section = MainWindowHelpers.build_collapsible_section (_("Advanced"), out advanced_content, MainWindowUiMetrics.SPACING_TOOLBAR);
        target_box.append (advanced_section);

        advanced_content.append (build_form_label (_("Cipher (optional)")));
        fields.cipher_entry = new Gtk.Entry ();
        fields.cipher_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        advanced_content.append (fields.cipher_entry);

        advanced_content.append (build_form_label (_("Auth (optional)")));
        fields.auth_entry = new Gtk.Entry ();
        fields.auth_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        advanced_content.append (fields.auth_entry);

        values.ovpn = fields;
    }

    private static Gtk.Label build_form_label (string text) {
        var lbl = new Gtk.Label (text);
        lbl.set_xalign (0.0f);
        lbl.add_css_class (MainWindowCssClasses.FORM_LABEL);
        return lbl;
    }

    private static Gtk.Switch build_labeled_switch_row (string label_text, bool default_active, Gtk.Box target_box) {
        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
        row.add_css_class (MainWindowCssClasses.EDIT_MODE_ROW);
        row.add_css_class (MainWindowCssClasses.NM_FLAT);

        var lbl = new Gtk.Label (label_text);
        lbl.set_xalign (0.0f);
        lbl.set_hexpand (true);
        lbl.add_css_class (MainWindowCssClasses.EDIT_MODE_LABEL);
        row.append (lbl);

        var sw = new Gtk.Switch ();
        sw.set_valign (Gtk.Align.CENTER);
        sw.set_active (default_active);
        sw.add_css_class (MainWindowCssClasses.SWITCH);
        sw.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
        sw.add_css_class (MainWindowCssClasses.EDIT_MODE_SWITCH);
        row.append (sw);

        target_box.append (row);
        return sw;
    }
}
