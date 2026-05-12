using Gtk;
using HyprNetworkManager.UI.Interfaces;

public class MainWindowVpnFormBuilder : Object {
    public static void append_generic_vpn_fields (
        Gtk.Box target_box,
        IVpnFormFields fields
    ) {
        Gtk.Box server_content;
        var server_section = build_section (_("Server"), out server_content);
        target_box.append (server_section);

        server_content.append (build_form_label (_("Gateway")));
        fields.gateway_entry = new Gtk.Entry ();
        fields.gateway_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (fields.gateway_entry);

        Gtk.Box auth_content;
        var auth_section = build_section (_("Authentication"), out auth_content);
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
    }

    public static void append_wg_fields (
        Gtk.Box target_box,
        IVpnFormFields fields,
        bool default_allowed_ips = false
    ) {
        target_box.append (build_form_label (_("Name")));
        fields.wg_interface_name_entry = new Gtk.Entry ();
        fields.wg_interface_name_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        target_box.append (fields.wg_interface_name_entry);

        target_box.append (build_form_label (_("Listen Port (optional)")));
        fields.wg_listen_port_entry = new Gtk.Entry ();
        fields.wg_listen_port_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
        fields.wg_listen_port_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        target_box.append (fields.wg_listen_port_entry);

        target_box.append (build_form_label (_("Private Key")));
        fields.wg_private_key_entry = new Gtk.Entry ();
        fields.wg_private_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        target_box.append (fields.wg_private_key_entry);

        fields.wg_peers_list = new HyprNetworkManager.UI.Widgets.DynamicPeerList ();
        if (default_allowed_ips) {
            var default_peer = new WireGuardPeerModel ();
            default_peer.allowed_ips = {"0.0.0.0/0", "::/0"};
            fields.wg_peers_list.add_peer (default_peer);
        }
        target_box.append (fields.wg_peers_list);

        var advanced_expander = new Gtk.Expander (_("Advanced Configuration"));
        var advanced_content = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        advanced_content.set_margin_top (6);
        
        advanced_content.append (build_form_label (_("FwMark (optional)")));
        fields.wg_fwmark_entry = new Gtk.Entry ();
        fields.wg_fwmark_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
        fields.wg_fwmark_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        advanced_content.append (fields.wg_fwmark_entry);

        fields.wg_peer_routes_switch = build_labeled_switch_row (
            _("Automatically add peer routes"),
            true,
            advanced_content
        );

        advanced_expander.set_child (advanced_content);
        target_box.append (advanced_expander);
    }

    public static void append_openvpn_fields (
        Gtk.Box target_box,
        IVpnFormFields fields,
        TrackedDropDownFactory create_dropdown,
        bool default_proto_udp = false
    ) {
        Gtk.Box server_content;
        var server_section = build_section (_("Server"), out server_content);
        target_box.append (server_section);

        server_content.append (build_form_label (_("Remote")));
        fields.ovpn_remote_entry = new Gtk.Entry ();
        fields.ovpn_remote_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (fields.ovpn_remote_entry);

        server_content.append (build_form_label (_("Port (optional)")));
        fields.ovpn_port_entry = new Gtk.Entry ();
        fields.ovpn_port_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
        fields.ovpn_port_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (fields.ovpn_port_entry);

        server_content.append (build_form_label (_("Protocol (optional)")));
        var proto_list = new Gtk.StringList (null);
        proto_list.append ("UDP");
        proto_list.append ("TCP");
        fields.ovpn_proto_dropdown = create_dropdown (proto_list);
        fields.ovpn_proto_dropdown.set_selected (default_proto_udp ? 0 : 1); // Select udp by default if default_proto_udp is true
        MainWindowCssClassResolver.add_best_class (
            fields.ovpn_proto_dropdown,
            {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        server_content.append (fields.ovpn_proto_dropdown);

        Gtk.Box auth_content;
        var auth_section = build_section (_("Authentication"), out auth_content);
        target_box.append (auth_section);

        auth_content.append (build_form_label (_("Username (optional)")));
        fields.ovpn_user_entry = new Gtk.Entry ();
        fields.ovpn_user_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (fields.ovpn_user_entry);

        auth_content.append (build_form_label (_("Password (optional)")));
        fields.ovpn_password_entry = new Gtk.Entry ();
        fields.ovpn_password_entry.set_visibility (false);
        fields.ovpn_password_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (fields.ovpn_password_entry);

        Gtk.Box certs_content;
        var certs_section = build_section (_("Certificates and Keys"), out certs_content);
        target_box.append (certs_section);

        certs_content.append (build_form_label (_("CA Certificate Path (optional)")));
        fields.ovpn_ca_cert_entry = new Gtk.Entry ();
        fields.ovpn_ca_cert_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (fields.ovpn_ca_cert_entry);

        certs_content.append (build_form_label (_("Client Certificate Path (optional)")));
        fields.ovpn_client_cert_entry = new Gtk.Entry ();
        fields.ovpn_client_cert_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (fields.ovpn_client_cert_entry);

        certs_content.append (build_form_label (_("Private Key Path (optional)")));
        fields.ovpn_private_key_entry = new Gtk.Entry ();
        fields.ovpn_private_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (fields.ovpn_private_key_entry);

        certs_content.append (build_form_label (_("TLS Auth Key Path (optional)")));
        fields.ovpn_tls_auth_key_entry = new Gtk.Entry ();
        fields.ovpn_tls_auth_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (fields.ovpn_tls_auth_key_entry);

        Gtk.Box advanced_content;
        var advanced_section = build_section (_("Advanced"), out advanced_content);
        target_box.append (advanced_section);

        advanced_content.append (build_form_label (_("Cipher (optional)")));
        fields.ovpn_cipher_entry = new Gtk.Entry ();
        fields.ovpn_cipher_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        advanced_content.append (fields.ovpn_cipher_entry);

        advanced_content.append (build_form_label (_("Auth (optional)")));
        fields.ovpn_auth_entry = new Gtk.Entry ();
        fields.ovpn_auth_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        advanced_content.append (fields.ovpn_auth_entry);
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

        var lbl = new Gtk.Label (label_text);
        lbl.set_xalign (0.0f);
        lbl.set_hexpand (true);
        lbl.add_css_class (MainWindowCssClasses.EDIT_MODE_LABEL);
        row.append (lbl);

        var sw = new Gtk.Switch ();
        sw.set_valign (Gtk.Align.CENTER);
        sw.set_active (default_active);
        MainWindowCssClassResolver.add_best_class (
            sw,
            {MainWindowCssClasses.SWITCH, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        MainWindowCssClassResolver.add_best_class (
            sw,
            {MainWindowCssClasses.EDIT_MODE_SWITCH, MainWindowCssClasses.SWITCH}
        );
        row.append (sw);

        target_box.append (row);
        return sw;
    }

    private static void set_section_collapsible_state (
        Gtk.Box container,
        Gtk.Button toggle_button,
        Gtk.Revealer content_revealer,
        Gtk.Image toggle_icon,
        bool expanded
    ) {
        content_revealer.set_reveal_child (expanded);
        MainWindowIconResources.set_expand_indicator_icon (toggle_icon, expanded);
        if (expanded) {
            container.add_css_class ("is-expanded");
            container.remove_css_class ("is-collapsed");
            toggle_button.set_tooltip_text (_("Collapse section"));
        } else {
            container.add_css_class ("is-collapsed");
            container.remove_css_class ("is-expanded");
            toggle_button.set_tooltip_text (_("Expand section"));
        }
    }

    private static Gtk.Box build_section (string title, out Gtk.Box section_content) {
        var section = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        section.add_css_class (MainWindowCssClasses.EDIT_COLLAPSIBLE);

        var toggle_button = new Gtk.Button ();
        toggle_button.set_has_frame (false);
        toggle_button.set_halign (Gtk.Align.FILL);
        toggle_button.set_hexpand (true);
        toggle_button.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE);

        var toggle_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        toggle_row.set_halign (Gtk.Align.FILL);
        toggle_row.set_hexpand (true);
        toggle_row.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_ROW);

        var toggle_icon = new Gtk.Image ();
        MainWindowIconResources.set_expand_indicator_icon (toggle_icon, false);
        toggle_icon.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_ICON);
        toggle_row.append (toggle_icon);

        var heading = new Gtk.Label (title);
        heading.set_xalign (0.0f);
        heading.set_hexpand (true);
        heading.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_LABEL);
        toggle_row.append (heading);

        toggle_button.set_child (toggle_row);
        section.append (toggle_button);

        section_content = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        section_content.add_css_class (MainWindowCssClasses.EDIT_SECTION_CONTENT);

        var content_revealer = new Gtk.Revealer ();
        content_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        content_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_MS);
        content_revealer.add_css_class (MainWindowCssClasses.EDIT_SECTION_REVEALER);
        content_revealer.set_child (section_content);
        section.append (content_revealer);

        set_section_collapsible_state (section, toggle_button, content_revealer, toggle_icon, true);
        toggle_button.clicked.connect (() => {
            bool expanded = !content_revealer.get_reveal_child ();
            set_section_collapsible_state (section, toggle_button, content_revealer, toggle_icon, expanded);
        });

        return section;
    }
}
