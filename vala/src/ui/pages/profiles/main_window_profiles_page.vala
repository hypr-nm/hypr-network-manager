using Gtk;

public class MainWindowProfilesPage : Gtk.Box {
    public Gtk.ListBox wifi_saved_listbox { get; set; }
    public Gtk.ListBox ethernet_saved_listbox { get; set; }

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
            "nm-page-saved-profiles",
            {"nm-page"}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        MainWindowCssClassResolver.add_best_class (header, {"nm-toolbar-inset", "nm-page-shell-inset"});
        MainWindowCssClassResolver.add_best_class (header, {"nm-toolbar", "nm-status-bar"});

        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
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
        refresh_btn.add_css_class ("nm-toolbar-action");
        refresh_btn.add_css_class ("nm-refresh-button");
        refresh_btn.set_valign (Gtk.Align.CENTER);
        MainWindowCssClassResolver.add_best_class (refresh_btn, {"nm-toolbar-action", "nm-button"});
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
            MainWindowCssClassResolver.add_best_class (delete_btn, {"nm-delete-button", "nm-action-button", "nm-button"});
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
            MainWindowCssClassResolver.add_best_class (details_btn, {"nm-details-button", "nm-action-button", "nm-button"});
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
