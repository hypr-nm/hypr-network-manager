using Gtk;

public class MainWindowProfilesPage : Gtk.Box {
    public Gtk.ListBox wifi_saved_listbox { get; private set; }
    public Gtk.ListBox ethernet_saved_listbox { get; private set; }

    public signal void back ();
    public signal void refresh ();
    public signal void open_profile (WifiSavedProfile profile);
    public signal void delete_profile (WifiSavedProfile profile);
    public signal void open_ethernet_profile (NetworkDevice device);

    private Gtk.ScrolledWindow scroll;
    private double saved_scroll_value = 0.0;

    public MainWindowProfilesPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class ("nm-page");
        this.add_css_class ("nm-page-shell-inset");
        MainWindowCssClassResolver.add_best_class (this, {"nm-page-shell-inset", "nm-page"});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            "nm-page-wifi-saved",
            {"nm-page"}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);

        var back_btn = MainWindowHelpers.build_back_button (() => {
            this.back ();
        });
        header.append (back_btn);

        var title = new Gtk.Label ("Profiles");
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class ("nm-section-title");
        header.append (title);

        var refresh_btn = new Gtk.Button.with_label ("Refresh");
        refresh_btn.add_css_class ("nm-button");
        refresh_btn.add_css_class ("nm-wifi-toolbar-action");
        MainWindowCssClassResolver.add_best_class (refresh_btn, {"nm-wifi-toolbar-action", "nm-button"});
        refresh_btn.set_tooltip_text ("Refresh Profiles");
        refresh_btn.clicked.connect (() => {
            this.refresh ();
        });
        header.append (refresh_btn);

        this.append (header);

        scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");
        scroll.set_vexpand (true);

        var body = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        body.add_css_class ("nm-profiles-page-body");
        body.add_css_class ("nm-details-scroll-body-inset");

        var wifi_heading = new Gtk.Label ("Wi-Fi Profiles");
        wifi_heading.set_xalign (0.0f);
        wifi_heading.add_css_class ("nm-form-label");
        body.append (wifi_heading);

        this.wifi_saved_listbox = new Gtk.ListBox ();
        this.wifi_saved_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        this.wifi_saved_listbox.add_css_class ("nm-list");
        body.append (this.wifi_saved_listbox);

        var ethernet_heading = new Gtk.Label ("Ethernet Profiles");
        ethernet_heading.set_xalign (0.0f);
        ethernet_heading.add_css_class ("nm-form-label");
        body.append (ethernet_heading);

        this.ethernet_saved_listbox = new Gtk.ListBox ();
        this.ethernet_saved_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        this.ethernet_saved_listbox.add_css_class ("nm-list");
        body.append (this.ethernet_saved_listbox);

        scroll.set_child (body);

        this.append (scroll);
    }

    private void clear_listbox (Gtk.ListBox listbox) {
        for (Gtk.Widget? child = listbox.get_first_child (); child != null;) {
            Gtk.Widget? next = child.get_next_sibling ();
            listbox.remove (child);
            child = next;
        }
    }

    public void set_wifi_networks (WifiSavedProfile[] profiles) {
        clear_listbox (this.wifi_saved_listbox);

        if (profiles.length == 0) {
            var row = new Gtk.ListBoxRow ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            box.add_css_class ("nm-empty-state");
            var label = new Gtk.Label ("No saved Wi-Fi profiles");
            label.add_css_class ("nm-placeholder-label");
            box.append (label);
            row.set_child (box);
            this.wifi_saved_listbox.append (row);
            return;
        }

        foreach (var profile in profiles) {
            var row_profile = profile;
            var row = new Gtk.ListBoxRow ();
            row.add_css_class ("nm-wifi-row");

            var root = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
            root.add_css_class ("nm-row-content");

            var info = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_GROUP);
            info.set_hexpand (true);
            string profile_name = MainWindowHelpers.safe_text (row_profile.profile_name).strip ();
            string ssid = MainWindowHelpers.safe_text (row_profile.ssid).strip ();
            string primary = profile_name != "" ? profile_name : (ssid != "" ? ssid : "Saved profile");

            var primary_lbl = new Gtk.Label (primary);
            primary_lbl.set_xalign (0.0f);
            primary_lbl.add_css_class ("nm-ssid-label");
            info.append (primary_lbl);

            string subtitle = "Saved profile";
            if (ssid != "" && ssid != primary) {
                subtitle = "SSID: %s".printf (ssid);
            }

            var sub = new Gtk.Label (subtitle);
            sub.set_xalign (0.0f);
            sub.add_css_class ("nm-sub-label");
            info.append (sub);
            root.append (info);

            var delete_btn = new Gtk.Button.with_label ("Delete");
            delete_btn.add_css_class ("nm-button");
            MainWindowCssClassResolver.add_best_class (delete_btn, {"nm-action-button", "nm-button"});
            delete_btn.clicked.connect (() => {
                this.delete_profile (row_profile);
            });
            root.append (delete_btn);

            var click = new Gtk.GestureClick ();
            click.released.connect ((n_press, x, y) => {
                this.open_profile (row_profile);
            });
            info.add_controller (click);

            row.set_child (root);
            this.wifi_saved_listbox.append (row);
        }
    }

    public void set_ethernet_profiles (NetworkDevice[] devices) {
        clear_listbox (this.ethernet_saved_listbox);

        if (devices.length == 0) {
            var row = new Gtk.ListBoxRow ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            box.add_css_class ("nm-empty-state");
            var label = new Gtk.Label ("No saved Ethernet profiles");
            label.add_css_class ("nm-placeholder-label");
            box.append (label);
            row.set_child (box);
            this.ethernet_saved_listbox.append (row);
            return;
        }

        foreach (var device in devices) {
            var row_device = device;
            var row = new Gtk.ListBoxRow ();
            row.add_css_class ("nm-wifi-row");

            var root = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
            root.add_css_class ("nm-row-content");

            var info = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_GROUP);
            info.set_hexpand (true);

            string iface = MainWindowHelpers.safe_text (row_device.name).strip ();
            string profile_name = MainWindowHelpers.safe_text (row_device.connection).strip ();
            string primary = iface != "" ? iface : "Ethernet device";
            var primary_lbl = new Gtk.Label (primary);
            primary_lbl.set_xalign (0.0f);
            primary_lbl.add_css_class ("nm-ssid-label");
            info.append (primary_lbl);

            string subtitle = profile_name != "" ? "Profile: %s".printf (profile_name) : "Saved Ethernet profile";
            var sub = new Gtk.Label (subtitle);
            sub.set_xalign (0.0f);
            sub.add_css_class ("nm-sub-label");
            info.append (sub);
            root.append (info);

            var details_btn = new Gtk.Button.with_label ("Details");
            details_btn.add_css_class ("nm-button");
            MainWindowCssClassResolver.add_best_class (details_btn, {"nm-action-button", "nm-button"});
            details_btn.clicked.connect (() => {
                this.open_ethernet_profile (row_device);
            });
            root.append (details_btn);

            var click = new Gtk.GestureClick ();
            click.released.connect ((n_press, x, y) => {
                this.open_ethernet_profile (row_device);
            });
            info.add_controller (click);

            row.set_child (root);
            this.ethernet_saved_listbox.append (row);
        }
    }

    public void focus_wifi_section () {
        this.wifi_saved_listbox.grab_focus ();
    }

    public void focus_ethernet_section () {
        this.ethernet_saved_listbox.grab_focus ();
    }

    public void remember_scroll_position () {
        var adj = scroll.get_vadjustment ();
        if (adj != null) {
            saved_scroll_value = adj.get_value ();
        }
    }

    public void restore_scroll_position () {
        var adj = scroll.get_vadjustment ();
        if (adj != null) {
            double target = saved_scroll_value;
            Idle.add (() => {
                adj.set_value (target);
                return false;
            });
        }
    }
}

public class MainWindowProfilesDetailsPage : Gtk.Box {
    public Gtk.Label title_label { get; private set; }
    public Gtk.Label subtitle_label { get; private set; }
    public Gtk.Box rows { get; private set; }
    public Gtk.Button edit_button { get; private set; }
    public Gtk.Button delete_button { get; private set; }

    public signal void back ();
    public signal void edit ();
    public signal void delete_profile ();

    public MainWindowProfilesDetailsPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class ("nm-page");
        this.add_css_class ("nm-page-shell-inset");
        MainWindowCssClassResolver.add_best_class (this, {"nm-page-shell-inset", "nm-page"});
        MainWindowCssClassResolver.add_best_class (
            this,
            {"nm-page-network-details", "nm-page"}
        );

        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_NONE);
        nav_row.add_css_class ("nm-details-nav-row");

        var back_btn = MainWindowHelpers.build_back_button (() => {
            this.back ();
        });
        nav_row.append (back_btn);
        this.append (nav_row);

        var header = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        header.set_halign (Gtk.Align.CENTER);
        header.add_css_class ("nm-details-header");

        var icon = new Gtk.Image.from_icon_name ("avatar-default-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {"nm-icon-size-28", "nm-icon-size"});
        MainWindowCssClassResolver.add_best_class (icon, {"nm-details-network-icon", "nm-icon-size"});
        header.append (icon);

        this.title_label = new Gtk.Label ("Profile");
        this.title_label.set_xalign (0.5f);
        this.title_label.set_halign (Gtk.Align.CENTER);
        this.title_label.add_css_class ("nm-details-network-title");
        header.append (this.title_label);

        this.subtitle_label = new Gtk.Label ("");
        this.subtitle_label.set_xalign (0.5f);
        this.subtitle_label.set_halign (Gtk.Align.CENTER);
        this.subtitle_label.add_css_class ("nm-sub-label");
        header.append (this.subtitle_label);

        var action_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        action_row.set_halign (Gtk.Align.CENTER);
        action_row.add_css_class ("nm-details-action-row");

        this.edit_button = new Gtk.Button.with_label ("Edit");
        this.edit_button.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (
            this.edit_button,
            {"nm-details-action-button", "nm-action-button", "nm-button"}
        );
        this.edit_button.clicked.connect (() => {
            this.edit ();
        });
        action_row.append (this.edit_button);

        this.delete_button = new Gtk.Button.with_label ("Delete");
        this.delete_button.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (
            this.delete_button,
            {"nm-details-action-button", "nm-action-button", "nm-button"}
        );
        this.delete_button.clicked.connect (() => {
            this.delete_profile ();
        });
        action_row.append (this.delete_button);

        header.append (action_row);
        this.append (header);

        var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep.add_css_class ("nm-separator");
        this.append (sep);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");
        scroll.set_vexpand (true);

        var body = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        body.add_css_class ("nm-details-scroll-body-inset");

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

public class MainWindowWifiSavedEditPage : Gtk.Box {
    private static string[] SECURITY_MODE_KEYS = {
        "open",
        "wpa-psk",
        "sae",
        "owe",
        "wep"
    };

    public Gtk.Label title_label { get; private set; }
    public Gtk.Entry profile_name_entry { get; private set; }
    public Gtk.Entry ssid_entry { get; private set; }
    public Gtk.Entry bssid_entry { get; private set; }
    public Gtk.DropDown security_mode_dropdown { get; private set; }
    public Gtk.CheckButton autoconnect_check { get; private set; }
    public Gtk.CheckButton all_users_check { get; private set; }
    public Gtk.Entry password_entry { get; private set; }

    public Gtk.DropDown ipv4_method_dropdown { get; private set; }
    public Gtk.Entry ipv4_address_entry { get; private set; }
    public Gtk.Entry ipv4_prefix_entry { get; private set; }
    public Gtk.Entry ipv4_gateway_entry { get; private set; }
    public Gtk.Switch dns_auto_switch { get; private set; }
    public Gtk.Entry ipv4_dns_entry { get; private set; }

    public Gtk.DropDown ipv6_method_dropdown { get; private set; }
    public Gtk.Entry ipv6_address_entry { get; private set; }
    public Gtk.Entry ipv6_prefix_entry { get; private set; }
    public Gtk.Entry ipv6_gateway_entry { get; private set; }
    public Gtk.Switch ipv6_dns_auto_switch { get; private set; }
    public Gtk.Entry ipv6_dns_entry { get; private set; }

    public signal void back ();
    public signal void save ();
    public signal void sync_sensitivity ();

    private Gtk.Box build_section (string title, out Gtk.Box section_content) {
        var section = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        section.add_css_class ("nm-edit-collapsible");

        var heading = new Gtk.Label (title);
        heading.set_xalign (0.0f);
        MainWindowCssClassResolver.add_best_class (heading, {"nm-edit-field-label", "nm-form-label"});
        section.append (heading);

        section_content = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        section_content.add_css_class ("nm-edit-section-content");
        section.append (section_content);

        return section;
    }

    public MainWindowWifiSavedEditPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class ("nm-page");
        this.add_css_class ("nm-page-shell-inset");
        MainWindowCssClassResolver.add_best_class (this, {"nm-page-shell-inset", "nm-page"});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            "nm-page-wifi-edit",
            {"nm-page-network-edit", "nm-page"}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button (() => {
            this.back ();
        });
        header.append (back_btn);

        this.title_label = new Gtk.Label ("Edit Saved Profile");
        this.title_label.set_xalign (0.0f);
        this.title_label.set_hexpand (true);
        this.title_label.add_css_class ("nm-section-title");
        header.append (this.title_label);
        this.append (header);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");
        scroll.set_vexpand (true);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        MainWindowCssClassResolver.add_best_class (form, {"nm-edit-network-form", "nm-edit-form"});
        form.add_css_class ("nm-details-scroll-body-inset");

        Gtk.Box profile_content;
        var profile_section = build_section ("Profile", out profile_content);

        var profile_name_label = new Gtk.Label ("Profile Name");
        profile_name_label.set_xalign (0.0f);
        profile_name_label.add_css_class ("nm-form-label");
        profile_content.append (profile_name_label);

        this.profile_name_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.profile_name_entry,
            {"nm-edit-field-entry", "nm-edit-field-control"}
        );
        profile_content.append (this.profile_name_entry);

        var ssid_label = new Gtk.Label ("SSID");
        ssid_label.set_xalign (0.0f);
        ssid_label.add_css_class ("nm-form-label");
        profile_content.append (ssid_label);

        this.ssid_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.ssid_entry,
            {"nm-edit-field-entry", "nm-edit-field-control"}
        );
        profile_content.append (this.ssid_entry);

        var bssid_label = new Gtk.Label ("BSSID");
        bssid_label.set_xalign (0.0f);
        bssid_label.add_css_class ("nm-form-label");
        profile_content.append (bssid_label);

        this.bssid_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.bssid_entry,
            {"nm-edit-field-entry", "nm-edit-field-control"}
        );
        profile_content.append (this.bssid_entry);

        var security_label = new Gtk.Label ("Security Mode");
        security_label.set_xalign (0.0f);
        security_label.add_css_class ("nm-form-label");
        profile_content.append (security_label);

        var security_modes = new Gtk.StringList (null);
        security_modes.append ("Open");
        security_modes.append ("WPA/WPA2 Personal (PSK)");
        security_modes.append ("WPA3 Personal (SAE)");
        security_modes.append ("Enhanced Open (OWE)");
        security_modes.append ("WEP");
        this.security_mode_dropdown = new Gtk.DropDown (security_modes, null);
        MainWindowCssClassResolver.add_best_class (
            this.security_mode_dropdown,
            {"nm-edit-dropdown", "nm-edit-field-control"}
        );
        profile_content.append (this.security_mode_dropdown);

        form.append (profile_section);

        Gtk.Box access_content;
        var access_section = build_section ("Access", out access_content);

        this.autoconnect_check = new Gtk.CheckButton.with_label ("Connect automatically");
        this.autoconnect_check.add_css_class ("nm-row-autoconnect-check");
        access_content.append (this.autoconnect_check);

        this.all_users_check = new Gtk.CheckButton.with_label ("Available to all users");
        this.all_users_check.add_css_class ("nm-row-autoconnect-check");
        access_content.append (this.all_users_check);

        form.append (access_section);

        Gtk.Box auth_content;
        var auth_section = build_section ("Authentication", out auth_content);

        var password_label = new Gtk.Label ("Password");
        password_label.set_xalign (0.0f);
        password_label.add_css_class ("nm-form-label");
        auth_content.append (password_label);

        this.password_entry = new Gtk.Entry ();
        this.password_entry.set_visibility (false);
        this.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        MainWindowCssClassResolver.add_best_class (
            this.password_entry,
            {"nm-edit-field-entry", "nm-edit-field-control", "nm-password-entry"}
        );
        this.password_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
        this.password_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
        MainWindowActionCallback update_password_visibility_icon = () => {
            bool reveal = this.password_entry.get_visibility ();
            MainWindowIconResources.set_password_visibility_icon (this.password_entry, reveal);
            this.password_entry.set_icon_tooltip_text (
                Gtk.EntryIconPosition.SECONDARY,
                reveal ? "Hide password" : "Show password"
            );
        };
        update_password_visibility_icon ();

        this.password_entry.icon_press.connect ((icon_pos) => {
            if (icon_pos != Gtk.EntryIconPosition.SECONDARY) {
                return;
            }
            this.password_entry.set_visibility (!this.password_entry.get_visibility ());
            update_password_visibility_icon ();
        });
        auth_content.append (this.password_entry);

        form.append (auth_section);

        Gtk.DropDown v4_method;
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
            () => this.sync_sensitivity (),
            true
        );

        this.ipv4_method_dropdown = v4_method;
        this.ipv4_address_entry = v4_address;
        this.ipv4_prefix_entry = v4_prefix;
        this.ipv4_gateway_entry = v4_gw;
        this.dns_auto_switch = v4_dns_auto;
        this.ipv4_dns_entry = v4_dns;

        Gtk.DropDown v6_method;
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
            () => this.sync_sensitivity (),
            true
        );

        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_entry = v6_gw;
        this.ipv6_dns_auto_switch = v6_dns_auto;
        this.ipv6_dns_entry = v6_dns;

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        actions.add_css_class ("nm-edit-actions");

        var save_btn = new Gtk.Button.with_label ("Save");
        save_btn.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (save_btn, {"suggested-action", "nm-button"});
        save_btn.clicked.connect (() => {
            this.save ();
        });
        actions.append (save_btn);

        form.append (actions);

        scroll.set_child (form);
        this.append (scroll);
    }

    public string get_selected_security_mode_key () {
        uint idx = this.security_mode_dropdown.get_selected ();
        if (idx >= SECURITY_MODE_KEYS.length) {
            return "open";
        }
        return SECURITY_MODE_KEYS[idx];
    }

    public void set_selected_security_mode_key (string mode_key) {
        string key = mode_key.strip ().down ();
        for (uint i = 0; i < SECURITY_MODE_KEYS.length; i++) {
            if (SECURITY_MODE_KEYS[i] == key) {
                this.security_mode_dropdown.set_selected (i);
                return;
            }
        }
        this.security_mode_dropdown.set_selected (0);
    }
}
