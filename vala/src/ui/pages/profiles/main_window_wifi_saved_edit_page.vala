using Gtk;

public class MainWindowWifiSavedEditPage : Gtk.Box, IMainWindowIpEditPage {
    private static string[] SECURITY_MODE_KEYS = {
        "open",
        "wpa-psk",
        "sae",
        "owe",
        "wep"
    };

    public Gtk.Label title_label { get; set; }
    public Gtk.Entry profile_name_entry { get; set; }
    public Gtk.Entry ssid_entry { get; set; }
    public Gtk.Entry bssid_entry { get; set; }
    public Gtk.DropDown security_mode_dropdown { get; set; }
    public Gtk.CheckButton autoconnect_check { get; set; }
    public Gtk.CheckButton all_users_check { get; set; }
    public Gtk.Entry password_entry { get; set; }

    public Gtk.DropDown ipv4_method_dropdown { get; set; }
    public Gtk.Entry ipv4_address_entry { get; set; }
    public Gtk.Entry ipv4_prefix_entry { get; set; }
    public Gtk.Entry ipv4_gateway_entry { get; set; }
    public Gtk.Switch dns_auto_switch { get; set; }
    public Gtk.Entry ipv4_dns_entry { get; set; }

    public Gtk.DropDown ipv6_method_dropdown { get; set; }
    public Gtk.Entry ipv6_address_entry { get; set; }
    public Gtk.Entry ipv6_prefix_entry { get; set; }
    public Gtk.Entry ipv6_gateway_entry { get; set; }
    public Gtk.Switch ipv6_dns_auto_switch { get; set; }
    public Gtk.Entry ipv6_dns_entry { get; set; }

    public signal void back ();
    public signal void save ();

    public override void sync_edit_gateway_dns_sensitivity () {
        bool ipv4_disabled = this.ipv4_method_dropdown.get_selected () == 2;
        if (ipv4_disabled) {
            this.dns_auto_switch.set_active (true);
        }

        uint ipv6_selected = this.ipv6_method_dropdown.get_selected ();
        bool ipv6_disabled_or_ignore = ipv6_selected == 2 || ipv6_selected == 3;
        if (ipv6_disabled_or_ignore) {
            this.ipv6_dns_auto_switch.set_active (true);
        }

        this.ipv4_dns_entry.set_sensitive (!this.dns_auto_switch.get_active ());
        this.ipv6_dns_entry.set_sensitive (!this.ipv6_dns_auto_switch.get_active ());
    }

    public void apply_settings_to_edit_page (WifiSavedProfileSettings settings) {
        this.profile_name_entry.set_text (settings.profile_name);
        this.ssid_entry.set_text (settings.ssid);
        this.bssid_entry.set_text (settings.bssid);
        this.set_selected_security_mode_key (settings.security_mode);
        this.autoconnect_check.set_active (settings.autoconnect);
        this.all_users_check.set_active (settings.available_to_all_users);
        this.password_entry.set_text (settings.configured_password);

        this.ipv4_method_dropdown.set_selected (
            MainWindowHelpers.get_ipv4_method_dropdown_index (settings.ipv4_method)
        );
        this.ipv4_address_entry.set_text (settings.configured_address);
        this.ipv4_prefix_entry.set_text (
            settings.configured_prefix > 0 ? "%u".printf (settings.configured_prefix) : ""
        );
        this.ipv4_gateway_entry.set_text (settings.configured_gateway);
        this.dns_auto_switch.set_active (settings.dns_auto);
        this.ipv4_dns_entry.set_text (settings.configured_dns);

        this.ipv6_method_dropdown.set_selected (
            MainWindowHelpers.get_ipv6_method_dropdown_index (settings.ipv6_method)
        );
        this.ipv6_address_entry.set_text (settings.configured_ipv6_address);
        this.ipv6_prefix_entry.set_text (
            settings.configured_ipv6_prefix > 0 ? "%u".printf (settings.configured_ipv6_prefix) : ""
        );
        this.ipv6_gateway_entry.set_text (settings.configured_ipv6_gateway);
        this.ipv6_dns_auto_switch.set_active (settings.ipv6_dns_auto);
        this.ipv6_dns_entry.set_text (settings.configured_ipv6_dns);
    }

    public bool build_update_requests (
        out WifiSavedProfileUpdateRequest profile_request,
        out WifiNetworkUpdateRequest network_request,
        out string error_message
    ) {
        error_message = "";

        string password = this.password_entry.get_text ().strip ();

        string method = MainWindowWifiEditUtils.get_selected_ipv4_method (this.ipv4_method_dropdown);
        string ipv4_address = this.ipv4_address_entry.get_text ().strip ();
        string ipv4_gateway = this.ipv4_gateway_entry.get_text ().strip ();
        bool gateway_auto = method != "manual";
        bool dns_auto = this.dns_auto_switch.get_active ();
        string dns_csv = this.ipv4_dns_entry.get_text ().strip ();

        string method6 = MainWindowWifiEditUtils.get_selected_ipv6_method (this.ipv6_method_dropdown);
        string ipv6_address = this.ipv6_address_entry.get_text ().strip ();
        string ipv6_gateway = this.ipv6_gateway_entry.get_text ().strip ();
        bool ipv6_gateway_auto = method6 != "manual";
        bool ipv6_dns_auto = this.ipv6_dns_auto_switch.get_active ();
        string ipv6_dns_csv = this.ipv6_dns_entry.get_text ().strip ();

        if (method == "disabled") {
            dns_auto = true;
        }
        if (method6 == "disabled" || method6 == "ignore") {
            ipv6_dns_auto = true;
        }

        uint32 ipv4_prefix;
        if (!MainWindowWifiEditUtils.try_parse_prefix (
            this.ipv4_prefix_entry.get_text (),
            out ipv4_prefix,
            out error_message
        )) {
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        uint32 ipv6_prefix;
        if (!MainWindowWifiEditUtils.try_parse_ipv6_prefix (
            this.ipv6_prefix_entry.get_text (),
            out ipv6_prefix,
            out error_message
        )) {
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        if (method == "manual") {
            if (ipv4_address == "") {
                error_message = "Manual IPv4 requires an address.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
            if (ipv4_prefix == 0) {
                error_message = "Manual IPv4 requires a prefix between 1 and 32.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
            if (ipv4_gateway == "") {
                error_message = "Manual IPv4 requires a gateway address.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
        }

        string[] dns_servers = MainWindowWifiEditUtils.parse_dns_csv (dns_csv);
        if (!dns_auto && dns_servers.length == 0) {
            error_message = "Manual DNS is enabled; provide at least one DNS server.";
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        if (method6 == "manual") {
            if (ipv6_address == "") {
                error_message = "Manual IPv6 requires an address.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
            if (ipv6_prefix == 0) {
                error_message = "Manual IPv6 requires a prefix between 1 and 128.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
            if (ipv6_gateway == "") {
                error_message = "Manual IPv6 requires a gateway address.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
        }

        string[] ipv6_dns_servers = MainWindowWifiEditUtils.parse_dns_csv (ipv6_dns_csv);
        if (!ipv6_dns_auto && ipv6_dns_servers.length == 0) {
            error_message = "Manual IPv6 DNS is enabled; provide at least one DNS server.";
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        profile_request = new WifiSavedProfileUpdateRequest () {
            profile_name = this.profile_name_entry.get_text ().strip (),
            ssid = this.ssid_entry.get_text ().strip (),
            bssid = this.bssid_entry.get_text ().strip (),
            security_mode = this.get_selected_security_mode_key (),
            autoconnect = this.autoconnect_check.get_active (),
            available_to_all_users = this.all_users_check.get_active ()
        };

        network_request = new WifiNetworkUpdateRequest () {
            password = password,
            ipv4_method = method,
            ipv4_address = ipv4_address,
            ipv4_prefix = ipv4_prefix,
            ipv4_gateway_auto = gateway_auto,
            ipv4_gateway = ipv4_gateway,
            ipv4_dns_auto = dns_auto,
            ipv4_dns_servers = dns_servers,
            ipv6_method = method6,
            ipv6_address = ipv6_address,
            ipv6_prefix = ipv6_prefix,
            ipv6_gateway_auto = ipv6_gateway_auto,
            ipv6_gateway = ipv6_gateway,
            ipv6_dns_auto = ipv6_dns_auto,
            ipv6_dns_servers = ipv6_dns_servers
        };

        return true;
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

    private Gtk.Box build_section (string title, out Gtk.Box section_content) {
        var section = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        section.add_css_class (MainWindowCssClasses.EDIT_COLLAPSIBLE);

        var heading = new Gtk.Label (title);
        heading.set_xalign (0.0f);
        MainWindowCssClassResolver.add_best_class (heading, {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL});
        section.append (heading);

        section_content = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        section_content.add_css_class (MainWindowCssClasses.EDIT_SECTION_CONTENT);
        section.append (section_content);

        return section;
    }

    public MainWindowWifiSavedEditPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET, MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_WIFI_EDIT,
            {MainWindowCssClasses.PAGE_NETWORK_EDIT, MainWindowCssClasses.PAGE}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        header.append (back_btn);

        this.title_label = new Gtk.Label ("Edit Saved Profile");
        this.title_label.set_xalign (0.0f);
        this.title_label.set_hexpand (true);
        this.title_label.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.append (this.title_label);
        this.append (header);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        MainWindowCssClassResolver.add_best_class (form, {MainWindowCssClasses.EDIT_NETWORK_FORM, MainWindowCssClasses.EDIT_FORM});
        form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        Gtk.Box profile_content;
        var profile_section = build_section ("Profile", out profile_content);

        var profile_name_label = new Gtk.Label ("Profile Name");
        profile_name_label.set_xalign (0.0f);
        profile_name_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        profile_content.append (profile_name_label);

        this.profile_name_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.profile_name_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        profile_content.append (this.profile_name_entry);

        var ssid_label = new Gtk.Label ("SSID");
        ssid_label.set_xalign (0.0f);
        ssid_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        profile_content.append (ssid_label);

        this.ssid_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.ssid_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        profile_content.append (this.ssid_entry);

        var bssid_label = new Gtk.Label ("BSSID");
        bssid_label.set_xalign (0.0f);
        bssid_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        profile_content.append (bssid_label);

        this.bssid_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.bssid_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        profile_content.append (this.bssid_entry);

        var security_label = new Gtk.Label ("Security Mode");
        security_label.set_xalign (0.0f);
        security_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
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
            {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        profile_content.append (this.security_mode_dropdown);

        form.append (profile_section);

        Gtk.Box access_content;
        var access_section = build_section ("Access", out access_content);

        this.autoconnect_check = new Gtk.CheckButton.with_label ("Connect automatically");
        this.autoconnect_check.add_css_class (MainWindowCssClasses.ROW_AUTOCONNECT_CHECK);
        access_content.append (this.autoconnect_check);

        this.all_users_check = new Gtk.CheckButton.with_label ("Available to all users");
        this.all_users_check.add_css_class (MainWindowCssClasses.ROW_AUTOCONNECT_CHECK);
        access_content.append (this.all_users_check);

        form.append (access_section);

        Gtk.Box auth_content;
        var auth_section = build_section ("Authentication", out auth_content);

        var password_label = new Gtk.Label ("Password");
        password_label.set_xalign (0.0f);
        password_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        auth_content.append (password_label);

        this.password_entry = new Gtk.Entry ();
        this.password_entry.set_visibility (false);
        this.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        MainWindowCssClassResolver.add_best_class (
            this.password_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL, MainWindowCssClasses.PASSWORD_ENTRY}
        );
        this.password_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
        this.password_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
        MainWindowHelpers.sync_password_visibility_icon (this.password_entry);

        this.password_entry.icon_press.connect ((icon_pos) => {
            if (icon_pos != Gtk.EntryIconPosition.SECONDARY) {
                return;
            }
            this.password_entry.set_visibility (!this.password_entry.get_visibility ());
            MainWindowHelpers.sync_password_visibility_icon (this.password_entry);
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
            true
        );

        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_entry = v6_gw;
        this.ipv6_dns_auto_switch = v6_dns_auto;
        this.ipv6_dns_entry = v6_dns;

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        actions.add_css_class (MainWindowCssClasses.EDIT_ACTIONS);

        var save_btn = new Gtk.Button.with_label ("Save");
        save_btn.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (save_btn, {MainWindowCssClasses.SUGGESTED_ACTION, MainWindowCssClasses.BUTTON});
        save_btn.clicked.connect (() => {
            this.save ();
        });
        actions.append (save_btn);

        form.append (actions);

        scroll.set_child (form);
        this.append (scroll);
    }
}
