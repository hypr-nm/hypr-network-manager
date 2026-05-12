using Gtk;

public class MainWindowVpnDetailsPage : Gtk.Box, IMainWindowNetworkDetailsPage {
    public Gtk.Label details_title { get; set; }
    public Gtk.ListBox basic_rows { get; set; }
    public Gtk.ListBox advanced_rows { get; set; }
    public Gtk.ListBox ip_rows { get; set; }
    public Gtk.Box action_row { get; set; }
    public Gtk.Button primary_button { get; set; }
    public Gtk.Button edit_button { get; set; }
    public Gtk.Button delete_button { get; set; }

    public signal void back ();
    public signal void primary_action ();
    public signal void edit ();
    public signal void delete ();

    private static string display_secret (string value) {
        return value.strip () != "" ? _("Set") : _("Not set");
    }

    public void render_details (
        VpnConnection conn,
        bool pending
    ) {
        this.details_title.set_text (MainWindowHelpers.safe_text (conn.name));

        MainWindowHelpers.clear_listbox (this.basic_rows);
        MainWindowHelpers.clear_listbox (this.advanced_rows);

        this.basic_rows.append (MainWindowHelpers.build_details_row (_("Name"), conn.name));
        this.basic_rows.append (MainWindowHelpers.build_details_row (_("Type"), conn.vpn_type));
        this.basic_rows.append (MainWindowHelpers.build_details_row (_("State"), conn.state));
        this.basic_rows.append (
            MainWindowHelpers.build_details_row (_("Connected"), conn.is_connected ? _("Yes") : _("No"))
        );

        this.advanced_rows.append (
            MainWindowHelpers.build_details_row (_("UUID"), conn.uuid)
        );

        if (pending) {
            this.primary_button.set_label (_("Updating…"));
            this.primary_button.set_sensitive (false);
        } else if (conn.is_connected) {
            this.primary_button.set_label (_("Disconnect"));
            this.primary_button.set_sensitive (true);
        } else {
            this.primary_button.set_label (_("Connect"));
            this.primary_button.set_sensitive (true);
        }

        this.edit_button.set_sensitive (!pending);
    }

    public void render_profile_fields (VpnConnection conn, VpnProfileDetails details) {
        this.details_title.set_text (MainWindowHelpers.safe_text (conn.name));

        MainWindowHelpers.clear_listbox (this.basic_rows);
        MainWindowHelpers.clear_listbox (this.advanced_rows);

        this.basic_rows.append (MainWindowHelpers.build_details_row (_("Name"), conn.name));
        this.basic_rows.append (
            MainWindowHelpers.build_details_row (_("Type"),
                details.vpn_type_display != "" ? details.vpn_type_display : conn.vpn_type)
        );
        this.basic_rows.append (MainWindowHelpers.build_details_row (_("State"), conn.state));
        this.basic_rows.append (
            MainWindowHelpers.build_details_row (_("Connected"), conn.is_connected ? _("Yes") : _("No"))
        );
        if (details.interface_name != "") {
            this.basic_rows.append (MainWindowHelpers.build_details_row (_("Interface"), details.interface_name));
        }
        this.basic_rows.append (
            MainWindowHelpers.build_details_row (_("Autoconnect"), details.autoconnect ? _("Yes") : _("No"))
        );

        this.advanced_rows.append (
            MainWindowHelpers.build_details_row (_("UUID"),
                details.profile_uuid != "" ? details.profile_uuid : conn.uuid)
        );
        if (details.service_type != "") {
            this.advanced_rows.append (MainWindowHelpers.build_details_row (_("Service"), details.service_type));
        }

        var wg_details = details as WireGuardVpnProfileDetails;
        if (wg_details != null) {
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Private key"), display_secret (wg_details.wg_private_key))
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Peer public key"), wg_details.wg_peer_public_key)
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Peer endpoint"), wg_details.wg_peer_endpoint)
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Allowed IPs"), wg_details.wg_peer_allowed_ips)
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Preshared key"), display_secret (wg_details.wg_preshared_key))
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Listen port"),
                    wg_details.wg_listen_port > 0 ? "%u".printf (wg_details.wg_listen_port) : _("Not set"))
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("FwMark"),
                    wg_details.wg_fwmark > 0 ? "%u".printf (wg_details.wg_fwmark) : _("Not set"))
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Peer routes"), wg_details.wg_peer_routes ? _("Yes") : _("No"))
            );
            return;
        }

        var ovpn_details = details as OpenVpnProfileDetails;
        if (ovpn_details != null) {
            this.advanced_rows.append (MainWindowHelpers.build_details_row (_("Remote"), ovpn_details.ovpn_remote));
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Port"),
                    ovpn_details.ovpn_port > 0 ? "%u".printf (ovpn_details.ovpn_port) : _("Not set"))
            );
            this.advanced_rows.append (MainWindowHelpers.build_details_row (_("Protocol"), ovpn_details.ovpn_proto));
            this.advanced_rows.append (MainWindowHelpers.build_details_row (_("Username"), ovpn_details.ovpn_username));
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Password"), display_secret (ovpn_details.ovpn_password))
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("CA certificate"), ovpn_details.ovpn_ca_cert)
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Client certificate"), ovpn_details.ovpn_client_cert)
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("Private key"), ovpn_details.ovpn_private_key)
            );
            this.advanced_rows.append (
                MainWindowHelpers.build_details_row (_("TLS auth key"), ovpn_details.ovpn_tls_auth_key)
            );
            this.advanced_rows.append (MainWindowHelpers.build_details_row (_("Cipher"), ovpn_details.ovpn_cipher));
            this.advanced_rows.append (MainWindowHelpers.build_details_row (_("Auth"), ovpn_details.ovpn_auth));
            return;
        }

        var generic_details = details as GenericVpnProfileDetails;
        if (generic_details == null) {
            return;
        }
        this.advanced_rows.append (MainWindowHelpers.build_details_row (_("Gateway"), generic_details.gateway));
        this.advanced_rows.append (MainWindowHelpers.build_details_row (_("Username"), generic_details.username));
        this.advanced_rows.append (
            MainWindowHelpers.build_details_row (_("Password"), display_secret (generic_details.password))
        );
    }

    public MainWindowVpnDetailsPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
            MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_VPN_DETAILS,
            {MainWindowCssClasses.PAGE_NETWORK_DETAILS, MainWindowCssClasses.PAGE}
        );

        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_NONE);
        nav_row.add_css_class (MainWindowCssClasses.DETAILS_NAV_ROW);

        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        nav_row.append (back_btn);
        this.append (nav_row);

        var header = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        header.set_halign (Gtk.Align.CENTER);
        header.add_css_class (MainWindowCssClasses.DETAILS_HEADER);

        var icon = new Gtk.Image.from_icon_name ("network-vpn-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.ICON_SIZE_28,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (
            icon,
            {MainWindowCssClasses.DETAILS_NETWORK_ICON, MainWindowCssClasses.VPN_ICON,
                MainWindowCssClasses.SIGNAL_ICON}
        );
        header.append (icon);

        this.details_title = new Gtk.Label (_("VPN"));
        this.details_title.set_xalign (0.5f);
        this.details_title.set_halign (Gtk.Align.CENTER);
        this.details_title.add_css_class (MainWindowCssClasses.DETAILS_NETWORK_TITLE);
        header.append (this.details_title);

        this.action_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        this.action_row.set_halign (Gtk.Align.CENTER);
        this.action_row.add_css_class (MainWindowCssClasses.DETAILS_ACTION_ROW);

        this.primary_button = new Gtk.Button.with_label (_("Connect"));
        this.primary_button.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (
            this.primary_button,
            {MainWindowCssClasses.PRIMARY_ACTION_BUTTON, MainWindowCssClasses.DETAILS_ACTION_BUTTON,
                MainWindowCssClasses.ACTION_BUTTON, MainWindowCssClasses.BUTTON}
        );
        this.primary_button.clicked.connect (() => {
            this.primary_action ();
        });
        this.action_row.append (this.primary_button);

        this.edit_button = new Gtk.Button.with_label (_("Edit"));
        this.edit_button.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (
            this.edit_button,
            {MainWindowCssClasses.EDIT_BUTTON, MainWindowCssClasses.DETAILS_ACTION_BUTTON,
                MainWindowCssClasses.ACTION_BUTTON, MainWindowCssClasses.BUTTON}
        );
        this.edit_button.clicked.connect (() => {
            this.edit ();
        });
        this.action_row.append (this.edit_button);

        this.delete_button = new Gtk.Button.with_label (_("Delete"));
        this.delete_button.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (
            this.delete_button,
            {MainWindowCssClasses.DELETE_BUTTON, MainWindowCssClasses.DETAILS_ACTION_BUTTON,
                MainWindowCssClasses.ACTION_BUTTON, MainWindowCssClasses.BUTTON}
        );
        this.delete_button.clicked.connect (() => {
            this.delete ();
        });
        this.action_row.append (this.delete_button);

        header.append (this.action_row);
        this.append (header);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);

        var body = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        body.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        Gtk.ListBox b_rows, a_rows, i_rows;
        body.append (MainWindowHelpers.build_details_section (_("Basic"), out b_rows));
        body.append (MainWindowHelpers.build_details_section (_("Advanced"), out a_rows));
        body.append (MainWindowHelpers.build_details_section (_("IP"), out i_rows));

        this.basic_rows = b_rows;
        this.advanced_rows = a_rows;
        this.ip_rows = i_rows;

        scroll.set_child (body);
        this.append (scroll);
    }
}
