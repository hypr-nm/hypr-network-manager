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

    // Generic VPN
    public Gtk.Entry gateway_entry { get; set; }
    public Gtk.Entry user_entry { get; set; }
    public Gtk.Entry password_entry { get; set; }

    // WireGuard
    public Gtk.Entry wg_private_key_entry { get; set; }
    public Gtk.Entry wg_peer_public_key_entry { get; set; }
    public Gtk.Entry wg_peer_endpoint_entry { get; set; }
    public Gtk.Entry wg_peer_allowed_ips_entry { get; set; }
    public Gtk.Entry wg_preshared_key_entry { get; set; }
    public Gtk.Entry wg_listen_port_entry { get; set; }
    public Gtk.Entry wg_fwmark_entry { get; set; }
    public Gtk.Switch wg_peer_routes_switch { get; set; }

    // OpenVPN
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

    private Gtk.Box type_specific_box;
    private Gtk.Label error_label;
    private Gtk.Revealer error_revealer;

    public signal void back ();
    public signal void apply ();

    public void setup_edit_form (VpnConnection conn, VpnProfileDetails details) {
        this.error_revealer.set_reveal_child (false);
        this.edit_title.set_text (_("Edit: %s").printf (conn.name));
        this.vpn_type = details.vpn_type_key.strip () != "" ? details.vpn_type_key : "vpn";

        MainWindowHelpers.clear_box (type_specific_box);
        if (this.vpn_type == "wireguard") {
            add_wg_fields ();
        } else if (this.vpn_type == "openvpn") {
            add_openvpn_fields ();
        } else {
            add_generic_vpn_fields ();
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

        if (this.vpn_type == "wireguard") {
            wg_private_key_entry.set_text (details.wg_private_key);
            wg_peer_public_key_entry.set_text (details.wg_peer_public_key);
            wg_peer_endpoint_entry.set_text (details.wg_peer_endpoint);
            wg_peer_allowed_ips_entry.set_text (details.wg_peer_allowed_ips);
            wg_preshared_key_entry.set_text (details.wg_preshared_key);
            wg_listen_port_entry.set_text (details.wg_listen_port > 0 ? "%u".printf (details.wg_listen_port) : "");
            wg_fwmark_entry.set_text (details.wg_fwmark > 0 ? "%u".printf (details.wg_fwmark) : "");
            wg_peer_routes_switch.set_active (details.wg_peer_routes);
        } else if (this.vpn_type == "openvpn") {
            ovpn_remote_entry.set_text (details.ovpn_remote);
            ovpn_port_entry.set_text (details.ovpn_port > 0 ? "%u".printf (details.ovpn_port) : "");
            ovpn_proto_entry.set_text (details.ovpn_proto);
            ovpn_user_entry.set_text (details.ovpn_username);
            ovpn_password_entry.set_text (details.ovpn_password);
            ovpn_ca_cert_entry.set_text (details.ovpn_ca_cert);
            ovpn_client_cert_entry.set_text (details.ovpn_client_cert);
            ovpn_private_key_entry.set_text (details.ovpn_private_key);
            ovpn_tls_auth_key_entry.set_text (details.ovpn_tls_auth_key);
            ovpn_cipher_entry.set_text (details.ovpn_cipher);
            ovpn_auth_entry.set_text (details.ovpn_auth);
        } else {
            gateway_entry.set_text (details.gateway);
            user_entry.set_text (details.username);
            password_entry.set_text (details.password);
        }

        this.sync_edit_gateway_dns_sensitivity ();
    }

    public VpnUpdateRequest? build_update_request (out string? error_message) {
        error_message = null;

        string? ip_error = null;
        var ip_request = this.build_ip_update_request (out ip_error);
        if (ip_request == null) {
            error_message = ip_error;
            return null;
        }

        var request = new VpnUpdateRequest ();
        request.vpn_type = vpn_type;
        request.ip_request = ip_request;
        if (this.autoconnect_switch != null) {
            request.ip_request.autoconnect = this.autoconnect_switch.get_active ();
        }

        if (this.vpn_type == "wireguard") {
            request.wg_private_key = wg_private_key_entry.get_text ().strip ();
            request.wg_peer_public_key = wg_peer_public_key_entry.get_text ().strip ();
            request.wg_peer_endpoint = wg_peer_endpoint_entry.get_text ().strip ();
            request.wg_peer_allowed_ips = wg_peer_allowed_ips_entry.get_text ().strip ();
            request.wg_preshared_key = wg_preshared_key_entry.get_text ().strip ();
            request.wg_peer_routes = wg_peer_routes_switch.get_active ();

            uint32 wg_listen_port;
            if (!parse_optional_uint32 (wg_listen_port_entry.get_text (), 65535, out wg_listen_port)) {
                error_message = _("WireGuard listen port must be a number between 0 and 65535.");
                return null;
            }
            request.wg_listen_port = wg_listen_port;

            uint32 wg_fwmark;
            if (!parse_optional_uint32 (wg_fwmark_entry.get_text (), uint32.MAX, out wg_fwmark)) {
                error_message = _("WireGuard fwmark must be a valid unsigned integer.");
                return null;
            }
            request.wg_fwmark = wg_fwmark;

            if (request.wg_private_key == "" || request.wg_peer_public_key == "" || request.wg_peer_endpoint == "") {
                error_message = _("WireGuard requires private key, peer public key, and endpoint.");
                return null;
            }
            return request;
        }

        if (this.vpn_type == "openvpn") {
            request.ovpn_remote = ovpn_remote_entry.get_text ().strip ();
            request.ovpn_proto = ovpn_proto_entry.get_text ().strip ();
            request.ovpn_username = ovpn_user_entry.get_text ().strip ();
            request.ovpn_password = ovpn_password_entry.get_text ();
            request.ovpn_ca_cert = ovpn_ca_cert_entry.get_text ().strip ();
            request.ovpn_client_cert = ovpn_client_cert_entry.get_text ().strip ();
            request.ovpn_private_key = ovpn_private_key_entry.get_text ().strip ();
            request.ovpn_tls_auth_key = ovpn_tls_auth_key_entry.get_text ().strip ();
            request.ovpn_cipher = ovpn_cipher_entry.get_text ().strip ();
            request.ovpn_auth = ovpn_auth_entry.get_text ().strip ();

            uint32 ovpn_port;
            if (!parse_optional_uint32 (ovpn_port_entry.get_text (), 65535, out ovpn_port)) {
                error_message = _("OpenVPN port must be a number between 0 and 65535.");
                return null;
            }
            request.ovpn_port = ovpn_port;

            if (request.ovpn_remote == "") {
                error_message = _("OpenVPN remote is required.");
                return null;
            }
            return request;
        }

        request.gateway = gateway_entry.get_text ().strip ();
        request.user = user_entry.get_text ().strip ();
        request.password = password_entry.get_text ();
        return request;
    }

    private static bool parse_optional_uint32 (
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

    private Gtk.Label build_form_label (string text) {
        var lbl = new Gtk.Label (text);
        lbl.set_xalign (0.0f);
        lbl.add_css_class (MainWindowCssClasses.FORM_LABEL);
        return lbl;
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

    public void show_error (string message) {
        if (message == null || message == "") {
            this.error_revealer.set_reveal_child (false);
            return;
        }
        this.error_label.set_text (message);
        this.error_revealer.set_reveal_child (true);
    }

    public MainWindowVpnEditPage (IWindowHost window_host) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
            MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_VPN_EDIT,
            {MainWindowCssClasses.PAGE_NETWORK_EDIT, MainWindowCssClasses.PAGE}
        );

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
        MainWindowCssClassResolver.add_best_class (
            form,
            {MainWindowCssClasses.EDIT_NETWORK_FORM, MainWindowCssClasses.EDIT_FORM}
        );
        form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        var auto_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
        auto_row.add_css_class (MainWindowCssClasses.EDIT_MODE_ROW);
        var auto_lbl = new Gtk.Label (_("Connect automatically"));
        auto_lbl.set_xalign (0.0f);
        auto_lbl.set_hexpand (true);
        auto_lbl.add_css_class (MainWindowCssClasses.EDIT_MODE_LABEL);
        auto_row.append (auto_lbl);
        this.autoconnect_switch = new Gtk.Switch ();
        this.autoconnect_switch.set_valign (Gtk.Align.CENTER);
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
        var save_btn = new Gtk.Button.with_label (_("Apply"));
        save_btn.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (save_btn, {MainWindowCssClasses.SUGGESTED_ACTION,
            MainWindowCssClasses.BUTTON});
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
