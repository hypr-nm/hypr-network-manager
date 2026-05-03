public class MainWindowVpnController : Object {
    private MainWindowVpnPageBuilder page_builder;

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

    public signal void refresh_started ();
    public signal void refresh_finished ();
    public signal void details_requested (VpnConnection conn);
    public signal void add_requested ();

    public MainWindowVpnController (
        NetworkManagerClient nm,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        page_builder = new MainWindowVpnPageBuilder (
            nm,
            host,
            state_context
        );

        page_builder.refresh_started.connect (() => {
            refresh_started ();
        });
        page_builder.refresh_finished.connect (() => {
            refresh_finished ();
        });
        page_builder.open_details.connect ((conn) => {
            details_requested (conn);
        });
        page_builder.add_clicked.connect (() => {
            add_requested ();
        });
    }

    public void populate_details (
        NetworkManagerClient nm,
        VpnConnection conn,
        MainWindowVpnDetailsPage details_page
    ) {
        details_page.render_details (conn, false);
        details_page.show_loading_ip ();

        string connection_id = conn.uuid != "" ? conn.uuid : conn.name;
        nm.get_vpn_details.begin (connection_id, null, (obj, res) => {
            try {
                var settings = nm.get_vpn_details.end (res);
                details_page.render_ip_settings (settings, conn.is_connected);
            } catch (Error e) {
                log_error ("vpn-controller", "Failed to fetch VPN details: " + e.message);
            }
        });
    }

    public void open_details (
        ref VpnConnection? selected_vpn,
        VpnConnection conn,
        Gtk.Stack stack
    ) {
        selected_vpn = conn;
        stack.set_visible_child_name ("details");
    }

    public void open_edit (
        ref VpnConnection? selected_vpn,
        NetworkManagerClient nm,
        VpnConnection conn,
        MainWindowVpnEditPage edit_page,
        Gtk.Stack stack
    ) {
        selected_vpn = conn;
        string connection_id = conn.uuid != "" ? conn.uuid : conn.name;
        nm.get_vpn_details.begin (connection_id, null, (obj, res) => {
            try {
                var settings = nm.get_vpn_details.end (res);
                edit_page.setup_edit_form (conn, settings);
                stack.set_visible_child_name ("edit");
            } catch (Error e) {
                log_error ("vpn-controller", "Failed to fetch VPN details for edit: " + e.message);
            }
        });
    }

    public bool apply_edit (
        ref VpnConnection? selected_vpn,
        NetworkManagerClient nm,
        MainWindowVpnEditPage edit_page,
        Gtk.Stack stack,
        MainWindowVpnDetailsPage details_page,
        bool close_after_apply
    ) {
        if (selected_vpn == null) return false;
        var conn = selected_vpn;

        var request = new NetworkIpUpdateRequest ();
        if (edit_page.autoconnect_switch != null) {
            request.autoconnect = edit_page.autoconnect_switch.get_active ();
        }

        request.ipv4_method = MainWindowIpConfigHelper.index_to_method (
            edit_page.ipv4_method_dropdown.get_selected (), true);
        request.ipv4_address = edit_page.ipv4_address_entry.get_text ();
        request.ipv4_prefix = (uint32) int.parse (edit_page.ipv4_prefix_entry.get_text ());
        request.ipv4_gateway = edit_page.ipv4_gateway_entry.get_text ();
        request.ipv4_dns_auto = edit_page.dns_auto_switch.get_active ();
        request.ipv4_dns_servers = edit_page.ipv4_dns_entry.get_text ().split (",");

        request.ipv6_method = MainWindowIpConfigHelper.index_to_method (
            edit_page.ipv6_method_dropdown.get_selected (), false);
        request.ipv6_address = edit_page.ipv6_address_entry.get_text ();
        request.ipv6_prefix = (uint32) int.parse (edit_page.ipv6_prefix_entry.get_text ());
        request.ipv6_gateway = edit_page.ipv6_gateway_entry.get_text ();
        request.ipv6_dns_auto = edit_page.ipv6_dns_auto_switch.get_active ();
        request.ipv6_dns_servers = edit_page.ipv6_dns_entry.get_text ().split (",");

        string connection_id = conn.uuid != "" ? conn.uuid : conn.name;
        nm.update_vpn_settings.begin (connection_id, request, null, (obj, res) => {
            try {
                nm.update_vpn_settings.end (res);
                if (close_after_apply) {
                    this.populate_details (nm, conn, details_page);
                    stack.set_visible_child_name ("details");
                }
            } catch (Error e) {
                edit_page.show_error (e.message);
            }
        });

        return true;
    }

    public void apply_setup (
        NetworkManagerClient nm,
        MainWindowVpnSetupPage setup_page,
        Gtk.Stack stack
    ) {
        var request = new VpnUpdateRequest ();
        request.name = setup_page.name_entry.get_text ().strip ();
        request.vpn_type = setup_page.vpn_type;

        if (request.name == "") {
            setup_page.show_error (_("Connection name is required."));
            return;
        }

        string? ip_error = null;
        var ip_request = setup_page.build_ip_update_request (out ip_error);
        if (ip_request == null) {
            setup_page.show_error (MainWindowHelpers.safe_text (ip_error));
            return;
        }
        request.ip_request = ip_request;

        if (request.vpn_type == "wireguard") {
            request.wg_private_key = setup_page.wg_private_key_entry.get_text ().strip ();
            request.wg_peer_public_key = setup_page.wg_peer_public_key_entry.get_text ().strip ();
            request.wg_peer_endpoint = setup_page.wg_peer_endpoint_entry.get_text ().strip ();
            request.wg_peer_allowed_ips = setup_page.wg_peer_allowed_ips_entry.get_text ().strip ();
            request.wg_preshared_key = setup_page.wg_preshared_key_entry.get_text ().strip ();
            request.wg_peer_routes = setup_page.wg_peer_routes_switch.get_active ();

            uint32 parsed_listen_port;
            if (!try_parse_optional_uint32 (
                setup_page.wg_listen_port_entry.get_text (),
                65535,
                out parsed_listen_port
            )) {
                setup_page.show_error (_("WireGuard listen port must be a number between 0 and 65535."));
                return;
            }
            request.wg_listen_port = parsed_listen_port;

            uint32 parsed_fwmark;
            if (!try_parse_optional_uint32 (
                setup_page.wg_fwmark_entry.get_text (),
                uint32.MAX,
                out parsed_fwmark
            )) {
                setup_page.show_error (_("WireGuard fwmark must be a valid unsigned integer."));
                return;
            }
            request.wg_fwmark = parsed_fwmark;

            if (request.wg_private_key == "" || request.wg_peer_public_key == "" || request.wg_peer_endpoint == "") {
                setup_page.show_error (_("WireGuard requires private key, peer public key, and endpoint."));
                return;
            }
        } else if (request.vpn_type == "openvpn") {
            request.ovpn_remote = setup_page.ovpn_remote_entry.get_text ().strip ();
            request.ovpn_proto = setup_page.ovpn_proto_entry.get_text ().strip ();
            request.ovpn_username = setup_page.ovpn_user_entry.get_text ().strip ();
            request.ovpn_password = setup_page.ovpn_password_entry.get_text ();
            request.ovpn_ca_cert = setup_page.ovpn_ca_cert_entry.get_text ().strip ();
            request.ovpn_client_cert = setup_page.ovpn_client_cert_entry.get_text ().strip ();
            request.ovpn_private_key = setup_page.ovpn_private_key_entry.get_text ().strip ();
            request.ovpn_tls_auth_key = setup_page.ovpn_tls_auth_key_entry.get_text ().strip ();
            request.ovpn_cipher = setup_page.ovpn_cipher_entry.get_text ().strip ();
            request.ovpn_auth = setup_page.ovpn_auth_entry.get_text ().strip ();

            uint32 parsed_openvpn_port;
            if (!try_parse_optional_uint32 (
                setup_page.ovpn_port_entry.get_text (),
                65535,
                out parsed_openvpn_port
            )) {
                setup_page.show_error (_("OpenVPN port must be a number between 0 and 65535."));
                return;
            }
            request.ovpn_port = parsed_openvpn_port;

            if (request.ovpn_remote == "") {
                setup_page.show_error (_("OpenVPN remote is required."));
                return;
            }
        } else {
            request.gateway = setup_page.gateway_entry.get_text ().strip ();
            request.user = setup_page.user_entry.get_text ().strip ();
            request.password = setup_page.password_entry.get_text ();
        }

        nm.create_vpn.begin (request, null, (obj, res) => {
            try {
                nm.create_vpn.end (res);
                stack.set_visible_child_name ("list");
                this.refresh ();
            } catch (Error e) {
                setup_page.show_error (e.message);
            }
        });
    }

    public void on_page_leave () {
        page_builder.on_page_leave ();
    }

    public void dispose_controller () {
        page_builder.dispose_controller ();
    }

    public Gtk.Widget build_page (
        out Gtk.ListBox vpn_listbox,
        out Gtk.Stack vpn_stack
    ) {
        return page_builder.build_page (
            out vpn_listbox,
            out vpn_stack
        );
    }

    public void refresh () {
        page_builder.refresh ();
    }
}
