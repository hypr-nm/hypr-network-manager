using Gtk;

public class MainWindowWifiSavedPage : Gtk.Box {
    public Gtk.ListBox saved_listbox { get; private set; }

    public signal void back ();
    public signal void refresh ();
    public signal void open_profile (WifiSavedProfile profile);
    public signal void delete_profile (WifiSavedProfile profile);

    public MainWindowWifiSavedPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.set_margin_start (12);
        this.set_margin_end (12);
        this.set_margin_top (12);
        this.set_margin_bottom (12);
        this.add_css_class ("nm-page");
        this.add_css_class ("nm-page-wifi-saved");

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);

        var back_btn = MainWindowHelpers.build_back_button (() => {
            this.back ();
        });
        header.append (back_btn);

        var title = new Gtk.Label ("Saved Networks");
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class ("nm-section-title");
        header.append (title);

        var refresh_btn = new Gtk.Button ();
        refresh_btn.add_css_class ("nm-button");
        refresh_btn.add_css_class ("nm-icon-button");
        var refresh_icon = new Gtk.Image.from_icon_name ("view-refresh-symbolic");
        refresh_icon.add_css_class ("nm-toolbar-icon");
        refresh_btn.set_child (refresh_icon);
        refresh_btn.set_tooltip_text ("Refresh Saved Networks");
        refresh_btn.clicked.connect (() => {
            this.refresh ();
        });
        header.append (refresh_btn);

        this.append (header);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");
        scroll.set_vexpand (true);

        this.saved_listbox = new Gtk.ListBox ();
        this.saved_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        this.saved_listbox.add_css_class ("nm-list");
        scroll.set_child (this.saved_listbox);

        this.append (scroll);
    }

    public void set_networks (WifiSavedProfile[] profiles) {
        for (Gtk.Widget? child = this.saved_listbox.get_first_child (); child != null;) {
            Gtk.Widget? next = child.get_next_sibling ();
            this.saved_listbox.remove (child);
            child = next;
        }

        if (profiles.length == 0) {
            var row = new Gtk.ListBoxRow ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            box.add_css_class ("nm-empty-state");
            var label = new Gtk.Label ("No saved networks");
            label.add_css_class ("nm-placeholder-label");
            box.append (label);
            row.set_child (box);
            this.saved_listbox.append (row);
            return;
        }

        foreach (var profile in profiles) {
            var row_profile = profile;
            var row = new Gtk.ListBoxRow ();
            row.add_css_class ("nm-wifi-row");

            var root = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            root.add_css_class ("nm-row-content");

            var info = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
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
            delete_btn.add_css_class ("nm-action-button");
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
            this.saved_listbox.append (row);
        }
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
        var section = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        section.add_css_class ("nm-edit-collapsible");

        var heading = new Gtk.Label (title);
        heading.set_xalign (0.0f);
        heading.add_css_class ("nm-form-label");
        heading.add_css_class ("nm-edit-field-label");
        section.append (heading);

        section_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        section_content.add_css_class ("nm-edit-section-content");
        section.append (section_content);

        return section;
    }

    public MainWindowWifiSavedEditPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.set_margin_start (12);
        this.set_margin_end (12);
        this.set_margin_top (12);
        this.set_margin_bottom (12);
        this.add_css_class ("nm-page");
        this.add_css_class ("nm-page-wifi-edit");
        this.add_css_class ("nm-page-network-edit");

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
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

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        form.add_css_class ("nm-edit-form");
        form.add_css_class ("nm-edit-network-form");

        Gtk.Box profile_content;
        var profile_section = build_section ("Profile", out profile_content);

        var profile_name_label = new Gtk.Label ("Profile Name");
        profile_name_label.set_xalign (0.0f);
        profile_name_label.add_css_class ("nm-form-label");
        profile_content.append (profile_name_label);

        this.profile_name_entry = new Gtk.Entry ();
        this.profile_name_entry.add_css_class ("nm-edit-field-control");
        this.profile_name_entry.add_css_class ("nm-edit-field-entry");
        profile_content.append (this.profile_name_entry);

        var ssid_label = new Gtk.Label ("SSID");
        ssid_label.set_xalign (0.0f);
        ssid_label.add_css_class ("nm-form-label");
        profile_content.append (ssid_label);

        this.ssid_entry = new Gtk.Entry ();
        this.ssid_entry.add_css_class ("nm-edit-field-control");
        this.ssid_entry.add_css_class ("nm-edit-field-entry");
        profile_content.append (this.ssid_entry);

        var bssid_label = new Gtk.Label ("BSSID");
        bssid_label.set_xalign (0.0f);
        bssid_label.add_css_class ("nm-form-label");
        profile_content.append (bssid_label);

        this.bssid_entry = new Gtk.Entry ();
        this.bssid_entry.add_css_class ("nm-edit-field-control");
        this.bssid_entry.add_css_class ("nm-edit-field-entry");
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
        this.security_mode_dropdown.add_css_class ("nm-edit-field-control");
        this.security_mode_dropdown.add_css_class ("nm-edit-dropdown");
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
        this.password_entry.add_css_class ("nm-password-entry");
        this.password_entry.add_css_class ("nm-edit-field-control");
        this.password_entry.add_css_class ("nm-edit-field-entry");
        this.password_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
        this.password_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
        MainWindowActionCallback update_password_visibility_icon = () => {
            bool reveal = this.password_entry.get_visibility ();
            this.password_entry.set_icon_from_icon_name (
                Gtk.EntryIconPosition.SECONDARY,
                reveal ? "view-conceal-symbolic" : "view-reveal-symbolic"
            );
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

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        actions.add_css_class ("nm-edit-actions");

        var save_btn = new Gtk.Button.with_label ("Save");
        save_btn.add_css_class ("nm-button");
        save_btn.add_css_class ("suggested-action");
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
