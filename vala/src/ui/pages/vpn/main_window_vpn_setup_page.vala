using Gtk;
using HyprNetworkManager.UI.Interfaces;

public class MainWindowVpnSetupPage : Gtk.Box, IMainWindowIpEditPage {
    public Gtk.Label setup_title { get; set; }
    public string vpn_type { get; private set; }

    public Gtk.Entry name_entry { get; set; }
    public Gtk.Entry gateway_entry { get; set; }
    public Gtk.Entry user_entry { get; set; }
    public Gtk.Entry password_entry { get; set; }
    
    // WireGuard specific
    public Gtk.Entry wg_private_key_entry { get; set; }
    public Gtk.Entry wg_peer_public_key_entry { get; set; }
    public Gtk.Entry wg_peer_endpoint_entry { get; set; }
    public Gtk.Entry wg_peer_allowed_ips_entry { get; set; }
    public Gtk.Entry wg_preshared_key_entry { get; set; }
    public Gtk.Entry wg_listen_port_entry { get; set; }
    public Gtk.Entry wg_fwmark_entry { get; set; }
    public Gtk.Switch wg_peer_routes_switch { get; set; }

    // OpenVPN specific
    public Gtk.Entry ovpn_remote_entry { get; set; }
    public Gtk.Entry ovpn_port_entry { get; set; }
    public Gtk.Entry ovpn_proto_entry { get; set; }
    public Gtk.Entry ovpn_user_entry { get; set; }
    public Gtk.Entry ovpn_password_entry { get; set; }
    public Gtk.Entry ovpn_ca_cert_entry { get; set; }
    public Gtk.Entry ovpn_client_cert_entry { get; set; }
    public Gtk.Entry ovpn_private_key_entry { get; set; }
    public Gtk.Entry ovpn_tls_auth_key_entry { get; set; }
    public Gtk.Entry ovpn_cipher_entry { get; set; }
    public Gtk.Entry ovpn_auth_entry { get; set; }

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

    public signal void back ();
    public signal void apply ();

    public void setup_type (string type) {
        this.vpn_type = type;
        this.setup_title.set_text (_("Setup %s").printf (type));
        this.error_revealer.set_reveal_child (false);
        
        // Clear type-specific fields
        MainWindowHelpers.clear_box (type_specific_box);

        if (type == "wireguard") {
            add_wg_fields ();
        } else if (type == "openvpn") {
            add_openvpn_fields ();
        } else {
            add_generic_vpn_fields ();
        }
    }

    private void add_generic_vpn_fields () {
        Gtk.Box server_content;
        var server_section = build_section (_("Server"), out server_content);
        type_specific_box.append (server_section);

        server_content.append (build_form_label (_("Gateway")));
        gateway_entry = new Gtk.Entry ();
        gateway_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (gateway_entry);

        Gtk.Box auth_content;
        var auth_section = build_section (_("Authentication"), out auth_content);
        type_specific_box.append (auth_section);

        auth_content.append (build_form_label (_("Username (optional)")));
        user_entry = new Gtk.Entry ();
        user_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (user_entry);

        auth_content.append (build_form_label (_("Password (optional)")));
        password_entry = new Gtk.Entry ();
        password_entry.set_visibility (false);
        password_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (password_entry);
    }

    private void add_wg_fields () {
        Gtk.Box interface_content;
        var interface_section = build_section (_("Interface"), out interface_content);
        type_specific_box.append (interface_section);

        interface_content.append (build_form_label (_("Interface Private Key")));
        wg_private_key_entry = new Gtk.Entry ();
        wg_private_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        interface_content.append (wg_private_key_entry);

        interface_content.append (build_form_label (_("Listen Port (optional)")));
        wg_listen_port_entry = new Gtk.Entry ();
        wg_listen_port_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
        wg_listen_port_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        interface_content.append (wg_listen_port_entry);

        Gtk.Box peer_content;
        var peer_section = build_section (_("Peer"), out peer_content);
        type_specific_box.append (peer_section);

        peer_content.append (build_form_label (_("Peer Public Key")));
        wg_peer_public_key_entry = new Gtk.Entry ();
        wg_peer_public_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        peer_content.append (wg_peer_public_key_entry);

        peer_content.append (build_form_label (_("Peer Endpoint (host:port)")));
        wg_peer_endpoint_entry = new Gtk.Entry ();
        wg_peer_endpoint_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        peer_content.append (wg_peer_endpoint_entry);

        peer_content.append (build_form_label (_("Allowed IPs (comma-separated)")));
        wg_peer_allowed_ips_entry = new Gtk.Entry ();
        wg_peer_allowed_ips_entry.set_text ("0.0.0.0/0, ::/0");
        wg_peer_allowed_ips_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        peer_content.append (wg_peer_allowed_ips_entry);

        peer_content.append (build_form_label (_("Preshared Key (optional)")));
        wg_preshared_key_entry = new Gtk.Entry ();
        wg_preshared_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        peer_content.append (wg_preshared_key_entry);

        Gtk.Box advanced_content;
        var advanced_section = build_section (_("Advanced"), out advanced_content);
        type_specific_box.append (advanced_section);

        advanced_content.append (build_form_label (_("FwMark (optional)")));
        wg_fwmark_entry = new Gtk.Entry ();
        wg_fwmark_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
        wg_fwmark_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        advanced_content.append (wg_fwmark_entry);

        wg_peer_routes_switch = build_labeled_switch_row (
            _("Automatically add peer routes"),
            true,
            advanced_content
        );
    }

    private void add_openvpn_fields () {
        Gtk.Box server_content;
        var server_section = build_section (_("Server"), out server_content);
        type_specific_box.append (server_section);

        server_content.append (build_form_label (_("Remote")));
        ovpn_remote_entry = new Gtk.Entry ();
        ovpn_remote_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (ovpn_remote_entry);

        server_content.append (build_form_label (_("Port (optional)")));
        ovpn_port_entry = new Gtk.Entry ();
        ovpn_port_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
        ovpn_port_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (ovpn_port_entry);

        server_content.append (build_form_label (_("Protocol (udp/tcp, optional)")));
        ovpn_proto_entry = new Gtk.Entry ();
        ovpn_proto_entry.set_text ("udp");
        ovpn_proto_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        server_content.append (ovpn_proto_entry);

        Gtk.Box auth_content;
        var auth_section = build_section (_("Authentication"), out auth_content);
        type_specific_box.append (auth_section);

        auth_content.append (build_form_label (_("Username (optional)")));
        ovpn_user_entry = new Gtk.Entry ();
        ovpn_user_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (ovpn_user_entry);

        auth_content.append (build_form_label (_("Password (optional)")));
        ovpn_password_entry = new Gtk.Entry ();
        ovpn_password_entry.set_visibility (false);
        ovpn_password_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        auth_content.append (ovpn_password_entry);

        Gtk.Box certs_content;
        var certs_section = build_section (_("Certificates and Keys"), out certs_content);
        type_specific_box.append (certs_section);

        certs_content.append (build_form_label (_("CA Certificate Path (optional)")));
        ovpn_ca_cert_entry = new Gtk.Entry ();
        ovpn_ca_cert_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (ovpn_ca_cert_entry);

        certs_content.append (build_form_label (_("Client Certificate Path (optional)")));
        ovpn_client_cert_entry = new Gtk.Entry ();
        ovpn_client_cert_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (ovpn_client_cert_entry);

        certs_content.append (build_form_label (_("Private Key Path (optional)")));
        ovpn_private_key_entry = new Gtk.Entry ();
        ovpn_private_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (ovpn_private_key_entry);

        certs_content.append (build_form_label (_("TLS Auth Key Path (optional)")));
        ovpn_tls_auth_key_entry = new Gtk.Entry ();
        ovpn_tls_auth_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        certs_content.append (ovpn_tls_auth_key_entry);

        Gtk.Box advanced_content;
        var advanced_section = build_section (_("Advanced"), out advanced_content);
        type_specific_box.append (advanced_section);

        advanced_content.append (build_form_label (_("Cipher (optional)")));
        ovpn_cipher_entry = new Gtk.Entry ();
        ovpn_cipher_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        advanced_content.append (ovpn_cipher_entry);

        advanced_content.append (build_form_label (_("Auth (optional)")));
        ovpn_auth_entry = new Gtk.Entry ();
        ovpn_auth_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        advanced_content.append (ovpn_auth_entry);
    }

    private Gtk.Switch build_labeled_switch_row (string label_text, bool default_active, Gtk.Box target_box) {
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
        sw.add_css_class (MainWindowCssClasses.EDIT_MODE_SWITCH);
        row.append (sw);

        target_box.append (row);
        return sw;
    }

    private void set_section_collapsible_state (
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

    private Gtk.Box build_section (string title, out Gtk.Box section_content) {
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

    private Gtk.Label build_form_label (string text) {
        var lbl = new Gtk.Label (text);
        lbl.set_xalign (0.0f);
        lbl.add_css_class (MainWindowCssClasses.FORM_LABEL);
        return lbl;
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
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

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

        form.append (build_form_label (_("Connection Name")));
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
