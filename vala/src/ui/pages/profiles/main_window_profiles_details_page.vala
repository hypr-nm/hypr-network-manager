using Gtk;

public class MainWindowProfilesDetailsPage : Gtk.Box {
    public Gtk.Label title_label { get; set; }
    public Gtk.Label subtitle_label { get; set; }
    public Gtk.Box rows { get; set; }
    public Gtk.Button edit_button { get; set; }
    public Gtk.Button delete_button { get; set; }

    public signal void back ();
    public signal void edit ();
    public signal void delete_profile ();

    public MainWindowProfilesDetailsPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET, MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_best_class (
            this,
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

        var icon = new Gtk.Image.from_icon_name ("avatar-default-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.ICON_SIZE_28, MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.DETAILS_NETWORK_ICON, MainWindowCssClasses.ICON_SIZE});
        header.append (icon);

        this.title_label = new Gtk.Label ("Profile");
        this.title_label.set_xalign (0.5f);
        this.title_label.set_halign (Gtk.Align.CENTER);
        this.title_label.add_css_class (MainWindowCssClasses.DETAILS_NETWORK_TITLE);
        header.append (this.title_label);

        this.subtitle_label = new Gtk.Label ("");
        this.subtitle_label.set_xalign (0.5f);
        this.subtitle_label.set_halign (Gtk.Align.CENTER);
        this.subtitle_label.add_css_class (MainWindowCssClasses.SUB_LABEL);
        header.append (this.subtitle_label);

        var action_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        action_row.set_halign (Gtk.Align.CENTER);
        action_row.add_css_class (MainWindowCssClasses.DETAILS_ACTION_ROW);

        this.edit_button = new Gtk.Button.with_label ("Edit");
        this.edit_button.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (
            this.edit_button,
            {MainWindowCssClasses.EDIT_BUTTON, MainWindowCssClasses.DETAILS_ACTION_BUTTON, MainWindowCssClasses.ACTION_BUTTON, MainWindowCssClasses.BUTTON}
        );
        this.edit_button.clicked.connect (() => {
            this.edit ();
        });
        action_row.append (this.edit_button);

        this.delete_button = new Gtk.Button.with_label ("Delete");
        this.delete_button.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (
            this.delete_button,
            {MainWindowCssClasses.DELETE_BUTTON, MainWindowCssClasses.DETAILS_ACTION_BUTTON, MainWindowCssClasses.ACTION_BUTTON, MainWindowCssClasses.BUTTON}
        );
        this.delete_button.clicked.connect (() => {
            this.delete_profile ();
        });
        action_row.append (this.delete_button);

        header.append (action_row);
        this.append (header);

        var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep.add_css_class (MainWindowCssClasses.SEPARATOR);
        this.append (sep);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);

        var body = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        body.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        Gtk.Box rows_out;
        body.append (MainWindowHelpers.build_details_section ("Details", out rows_out));
        this.rows = rows_out;

        scroll.set_child (body);
        this.append (scroll);
    }

    public void set_wifi_profile (WifiSavedProfile profile) {
        MainWindowHelpers.clear_box (this.rows);

        string profile_name = MainWindowHelpers.safe_text (profile.profile_name).strip ();
        string ssid = MainWindowHelpers.safe_text (profile.ssid).strip ();
        string title = profile_name != "" ? profile_name : (ssid != "" ? ssid : "Saved Wi-Fi Profile");
        this.title_label.set_text (title);
        this.subtitle_label.set_text ("Wi-Fi profile");

        this.rows.append (MainWindowHelpers.build_details_row (
            "Profile Name",
            MainWindowHelpers.display_text_or_na (profile.profile_name)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "SSID",
            MainWindowHelpers.display_text_or_na (profile.ssid)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "UUID",
            MainWindowHelpers.display_text_or_na (profile.saved_connection_uuid)
        ));

        this.delete_button.set_visible (true);
        this.edit_button.set_visible (true);
    }

    public void set_ethernet_profile (NetworkDevice device) {
        MainWindowHelpers.clear_box (this.rows);

        this.title_label.set_text (MainWindowHelpers.display_text_or_na (device.name));
        this.subtitle_label.set_text ("Ethernet profile");

        this.rows.append (MainWindowHelpers.build_details_row (
            "Interface",
            MainWindowHelpers.display_text_or_na (device.name)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Profile",
            MainWindowHelpers.display_text_or_na (device.connection)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "State",
            MainWindowHelpers.display_text_or_na (device.state_label)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "UUID",
            MainWindowHelpers.display_text_or_na (device.connection_uuid)
        ));

        this.delete_button.set_visible (false);
        this.edit_button.set_visible (true);
    }

    public void apply_wifi_ip_settings (WifiSavedProfileSettings settings) {
        this.rows.append (MainWindowHelpers.build_details_row (
            "Security",
            MainWindowHelpers.display_text_or_na (settings.security_mode.up ())
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Auto-connect",
            settings.autoconnect ? "Yes" : "No"
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "All users",
            settings.available_to_all_users ? "Yes" : "No"
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv4",
            MainWindowHelpers.get_ipv4_method_label (settings.ipv4_method)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv4 Address",
            MainWindowHelpers.format_ip_with_prefix (settings.configured_address, settings.configured_prefix)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv4 Gateway",
            MainWindowHelpers.display_text_or_na (settings.configured_gateway)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv4 DNS",
            MainWindowHelpers.display_text_or_na (settings.configured_dns)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv6",
            MainWindowHelpers.get_ipv6_method_label (settings.ipv6_method)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv6 Address",
            MainWindowHelpers.format_ip_with_prefix (settings.configured_ipv6_address, settings.configured_ipv6_prefix)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv6 Gateway",
            MainWindowHelpers.display_text_or_na (settings.configured_ipv6_gateway)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv6 DNS",
            MainWindowHelpers.display_text_or_na (settings.configured_ipv6_dns)
        ));
    }

    public void apply_ethernet_ip_settings (NetworkIpSettings settings) {
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv4",
            MainWindowHelpers.get_ipv4_method_label (settings.ipv4_method)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv4 Address",
            MainWindowHelpers.format_ip_with_prefix (settings.configured_address, settings.configured_prefix)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv4 Gateway",
            MainWindowHelpers.display_text_or_na (settings.configured_gateway)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv4 DNS",
            MainWindowHelpers.display_text_or_na (settings.configured_dns)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv6",
            MainWindowHelpers.get_ipv6_method_label (settings.ipv6_method)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv6 Address",
            MainWindowHelpers.format_ip_with_prefix (settings.configured_ipv6_address, settings.configured_ipv6_prefix)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv6 Gateway",
            MainWindowHelpers.display_text_or_na (settings.configured_ipv6_gateway)
        ));
        this.rows.append (MainWindowHelpers.build_details_row (
            "Configured IPv6 DNS",
            MainWindowHelpers.display_text_or_na (settings.configured_ipv6_dns)
        ));
    }
}
