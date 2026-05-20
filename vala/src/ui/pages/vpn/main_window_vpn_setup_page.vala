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
            MainWindowVpnFormBuilder.append_wg_fields (type_specific_box, this, true);
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

        string? ip_error = null;
        var ip_request = this.build_ip_update_request (out ip_error);
        if (ip_request == null) {
            error_message = ip_error;
            return null;
        }

        VpnUpdateRequest request;
        if (this.vpn_type == "wireguard") {
            request = new WireGuardVpnUpdateRequest ();
        } else if (this.vpn_type == "openvpn") {
            request = new OpenVpnUpdateRequest ();
        } else {
            request = new GenericVpnUpdateRequest (this.vpn_type);
        }

        request.name = name;
        request.ip_request = ip_request;

        var wg_request = request as WireGuardVpnUpdateRequest;
        if (wg_request != null && wg_private_key_entry != null) {
            wg_request.interface_name = wg_interface_name_entry != null ? wg_interface_name_entry.get_text ().strip () : "";
            wg_request.wg_private_key = wg_private_key_entry.get_text ().strip ();
            if (wg_peers_list != null) {
                wg_request.peers = wg_peers_list.get_peers ();
            }
            wg_request.wg_peer_routes = wg_peer_routes_switch.get_active ();

            uint32 wg_listen_port;
            if (!parse_optional_uint32 (wg_listen_port_entry.get_text (), 65535, out wg_listen_port)) {
                error_message = _("WireGuard listen port must be a number between 0 and 65535.");
                return null;
            }
            wg_request.wg_listen_port = wg_listen_port;

            uint32 wg_fwmark;
            if (!parse_optional_uint32 (wg_fwmark_entry.get_text (), uint32.MAX, out wg_fwmark)) {
                error_message = _("WireGuard fwmark must be a valid unsigned integer.");
                return null;
            }
            wg_request.wg_fwmark = wg_fwmark;
        }

        var ovpn_request = request as OpenVpnUpdateRequest;
        if (ovpn_request != null && ovpn_remote_entry != null) {
            ovpn_request.ovpn_remote = ovpn_remote_entry.get_text ().strip ();
            ovpn_request.ovpn_proto = ovpn_proto_dropdown != null && ovpn_proto_dropdown.get_selected() == 1 ? "tcp" : "udp";
            ovpn_request.ovpn_username = ovpn_user_entry.get_text ().strip ();
            ovpn_request.ovpn_password = ovpn_password_entry.get_text ();
            ovpn_request.ovpn_ca_cert = ovpn_ca_cert_entry.get_text ().strip ();
            ovpn_request.ovpn_client_cert = ovpn_client_cert_entry.get_text ().strip ();
            ovpn_request.ovpn_private_key = ovpn_private_key_entry.get_text ().strip ();
            ovpn_request.ovpn_tls_auth_key = ovpn_tls_auth_key_entry.get_text ().strip ();
            ovpn_request.ovpn_cipher = ovpn_cipher_entry.get_text ().strip ();
            ovpn_request.ovpn_auth = ovpn_auth_entry.get_text ().strip ();

            uint32 ovpn_port;
            if (!parse_optional_uint32 (ovpn_port_entry.get_text (), 65535, out ovpn_port)) {
                error_message = _("OpenVPN port must be a number between 0 and 65535.");
                return null;
            }
            ovpn_request.ovpn_port = ovpn_port;
        }

        var generic_request = request as GenericVpnUpdateRequest;
        if (generic_request != null && gateway_entry != null) {
            generic_request.gateway = gateway_entry.get_text ().strip ();
            generic_request.user = user_entry.get_text ().strip ();
            generic_request.password = password_entry.get_text ();
        }

        if (!request.validate (out error_message)) {
            return null;
        }

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
