/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Constants;
using Gtk;

public class MainWindowProfilesPage : Gtk.Box {
    public Gtk.ListBox wifi_saved_listbox { get; set; }
    public Gtk.ListBox ethernet_saved_listbox { get; set; }

    public signal void back ();
    public signal void open_profile (WifiSavedProfile profile);
    public signal void delete_profile (WifiSavedProfile profile);
    public signal void open_ethernet_profile (NetworkDevice device);

    private Gtk.Notebook notebook;
    private Gtk.Label wifi_tab_label;
    private Gtk.Label eth_tab_label;
    private int wifi_count = 0;
    private int eth_count = 0;
        private Gtk.SearchEntry wifi_search_entry;
        private Gtk.SearchEntry eth_search_entry;
        private Gtk.ScrolledWindow wifi_scroll;
        private Gtk.ScrolledWindow eth_scroll;
        private double saved_wifi_scroll = 0;
        private double saved_eth_scroll = 0;

        public MainWindowProfilesPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: MainWindowUiMetrics.SPACING_NONE);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        this.add_css_class (MainWindowCssClasses.PAGE_NETWORK_DETAILS);
        this.add_css_class (MainWindowCssClasses.PAGE_SAVED_PROFILES);

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        header.add_css_class (MainWindowCssClasses.DETAILS_NAV_ROW);

        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        header.append (back_btn);

        var title = new Gtk.Label (_("Profiles"));
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.append (title);

        this.append (header);

        notebook = new Gtk.Notebook ();
        notebook.add_css_class (MainWindowCssClasses.NOTEBOOK);
        notebook.set_scrollable (true);
        notebook.set_show_border (false);
        notebook.set_show_tabs (true);
        notebook.set_vexpand (true);
        notebook.margin_top = MainWindowUiMetrics.SPACING_COMPACT; // Give perfect compact breathing room below back button header

        // Wi-Fi Page Box
        var wifi_page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        wifi_page_box.set_vexpand (true);

        wifi_search_entry = new Gtk.SearchEntry ();
        wifi_search_entry.placeholder_text = _("Search Wi-Fi profiles");
        wifi_search_entry.margin_start = 12;
        wifi_search_entry.margin_end = 12;
        wifi_search_entry.margin_top = MainWindowUiMetrics.SPACING_COMPACT;
        wifi_search_entry.margin_bottom = 6;
        wifi_search_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        wifi_page_box.append (wifi_search_entry);

        this.wifi_saved_listbox = new Gtk.ListBox ();
        this.wifi_saved_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        this.wifi_saved_listbox.add_css_class (MainWindowCssClasses.LIST);
        this.wifi_saved_listbox.row_activated.connect ((row) => {
            var profile = row.get_data<WifiSavedProfile> ("profile");
            if (profile != null) {
                this.open_profile (profile);
            }
        });

        // Filter Wi-Fi saved profiles
        this.wifi_saved_listbox.set_filter_func ((row) => {
            string query = wifi_search_entry.get_text ().down ().strip ();
            if (query == "") {
                return true;
            }
            unowned string? search_key = row.get_data<string> ("search-key");
            if (search_key == null) {
                return true;
            }
            return search_key.contains (query);
        });

        wifi_search_entry.search_changed.connect (() => {
            this.wifi_saved_listbox.invalidate_filter ();
        });

        var wifi_scroll = new Gtk.ScrolledWindow ();
        wifi_scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        wifi_scroll.add_css_class (MainWindowCssClasses.SCROLL);
        wifi_scroll.set_vexpand (true);
        wifi_scroll.set_child (this.wifi_saved_listbox);
        wifi_page_box.append (wifi_scroll);
        this.wifi_scroll = wifi_scroll;

        // Ethernet Page Box
        var eth_page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        eth_page_box.set_vexpand (true);

        eth_search_entry = new Gtk.SearchEntry ();
        eth_search_entry.placeholder_text = _("Search Ethernet profiles");
        eth_search_entry.margin_start = 12;
        eth_search_entry.margin_end = 12;
        eth_search_entry.margin_top = MainWindowUiMetrics.SPACING_COMPACT;
        eth_search_entry.margin_bottom = 6;
        eth_search_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        eth_page_box.append (eth_search_entry);

        this.ethernet_saved_listbox = new Gtk.ListBox ();
        this.ethernet_saved_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        this.ethernet_saved_listbox.add_css_class (MainWindowCssClasses.LIST);
        this.ethernet_saved_listbox.row_activated.connect ((row) => {
            var device = row.get_data<NetworkDevice> ("device");
            if (device != null) {
                this.open_ethernet_profile (device);
            }
        });

        // Filter Ethernet saved profiles
        this.ethernet_saved_listbox.set_filter_func ((row) => {
            string query = eth_search_entry.get_text ().down ().strip ();
            if (query == "") {
                return true;
            }
            unowned string? search_key = row.get_data<string> ("search-key");
            if (search_key == null) {
                return true;
            }
            return search_key.contains (query);
        });

        eth_search_entry.search_changed.connect (() => {
            this.ethernet_saved_listbox.invalidate_filter ();
        });

        var eth_scroll = new Gtk.ScrolledWindow ();
        eth_scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        eth_scroll.add_css_class (MainWindowCssClasses.SCROLL);
        eth_scroll.set_vexpand (true);
        eth_scroll.set_child (this.ethernet_saved_listbox);
        eth_page_box.append (eth_scroll);
        this.eth_scroll = eth_scroll;

        wifi_tab_label = new Gtk.Label (_("Wi-Fi (%d)").printf (0));
        wifi_tab_label.add_css_class (MainWindowCssClasses.TAB_LABEL);

        eth_tab_label = new Gtk.Label (_("Ethernet (%d)").printf (0));
        eth_tab_label.add_css_class (MainWindowCssClasses.TAB_LABEL);

        notebook.append_page (wifi_page_box, wifi_tab_label);
        notebook.append_page (eth_page_box, eth_tab_label);

        this.append (notebook);
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
        this.wifi_count = profiles.length;
        update_tab_labels ();

        if (profiles.length == 0) {
            var row = new Gtk.ListBoxRow ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            box.add_css_class (MainWindowCssClasses.EMPTY_STATE);
            var label = new Gtk.Label (_("No saved Wi-Fi profiles"));
            label.add_css_class (MainWindowCssClasses.PLACEHOLDER_LABEL);
            box.append (label);
            row.set_child (box);
            this.wifi_saved_listbox.append (row);
            return;
        }

        foreach (var profile in profiles) {
            var row_profile = profile;
            var row = new Gtk.ListBoxRow ();
            row.add_css_class (MainWindowCssClasses.WIFI_ROW);

            var root = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
            root.add_css_class (MainWindowCssClasses.ROW_CONTENT);

            var info = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_GROUP);
            info.set_hexpand (true);
            info.set_valign (Gtk.Align.CENTER);
            string profile_name = MainWindowHelpers.safe_text (row_profile.profile_name).strip ();
            string ssid = MainWindowHelpers.safe_text (row_profile.ssid).strip ();
            string primary = profile_name != "" ? profile_name : (ssid != "" ? ssid : _("Saved profile"));

            var primary_lbl = new Gtk.Label (primary);
            primary_lbl.set_xalign (0.0f);
            primary_lbl.add_css_class (MainWindowCssClasses.SSID_LABEL);
            info.append (primary_lbl);

            string subtitle = "";
            if (ssid != "" && ssid != primary) {
                subtitle = _("SSID: %s").printf (ssid);
            }

            if (subtitle != "") {
                var sub = new Gtk.Label (subtitle);
                sub.set_xalign (0.0f);
                sub.add_css_class (MainWindowCssClasses.SUB_LABEL);
                info.append (sub);
            }
            root.append (info);

            row.set_data<string> ("search-key", primary.down () + " " + (subtitle != "" ? subtitle.down () : ""));
            row.set_data<WifiSavedProfile> ("profile", row_profile);

            var details_btn = new Gtk.Button ();
        details_btn.add_css_class (MainWindowCssClasses.ROW_ICON_ACTION);
        details_btn.add_css_class (MainWindowCssClasses.BUTTON);
        details_btn.add_css_class (MainWindowCssClasses.DETAILS_OPEN_BUTTON);
            details_btn.set_valign (Gtk.Align.CENTER);
            details_btn.set_tooltip_text (_("Details"));
            var details_icon = new Gtk.Image.from_icon_name ("document-properties-symbolic");
            details_icon.add_css_class (MainWindowCssClasses.DETAILS_BUTTON_ICON);
            details_icon.add_css_class (MainWindowCssClasses.DETAILS_OPEN_ICON);
            details_btn.set_child (details_icon);
            details_btn.clicked.connect (() => {
                this.open_profile (row_profile);
            });

            var delete_btn = new Gtk.Button.with_label (_("Delete"));
            delete_btn.add_css_class (MainWindowCssClasses.ROW_LINK_ACTION);
            delete_btn.add_css_class (MainWindowCssClasses.BUTTON);
            delete_btn.add_css_class (MainWindowCssClasses.ACTION_BUTTON);
            delete_btn.add_css_class (MainWindowCssClasses.DELETE_BUTTON);
            delete_btn.set_valign (Gtk.Align.CENTER);
            delete_btn.clicked.connect (() => {
                this.delete_profile (row_profile);
            });

            var actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
            actions_box.set_valign (Gtk.Align.CENTER);
            actions_box.append (details_btn);
            actions_box.append (delete_btn);
            root.append (actions_box);

            row.set_child (root);
            this.wifi_saved_listbox.append (row);
        }
    }

    public void set_ethernet_profiles (NetworkDevice[] devices) {
        clear_listbox (this.ethernet_saved_listbox);
        this.eth_count = devices.length;
        update_tab_labels ();

        if (devices.length == 0) {
            var row = new Gtk.ListBoxRow ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            box.add_css_class (MainWindowCssClasses.EMPTY_STATE);
            var label = new Gtk.Label (_("No saved Ethernet profiles"));
            label.add_css_class (MainWindowCssClasses.PLACEHOLDER_LABEL);
            box.append (label);
            row.set_child (box);
            this.ethernet_saved_listbox.append (row);
            return;
        }

        foreach (var device in devices) {
            var row_device = device;
            var row = new Gtk.ListBoxRow ();
            row.add_css_class (MainWindowCssClasses.WIFI_ROW);

            var root = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
            root.add_css_class (MainWindowCssClasses.ROW_CONTENT);

            var info = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_GROUP);
            info.set_hexpand (true);
            info.set_valign (Gtk.Align.CENTER);
 
            string iface = MainWindowHelpers.safe_text (row_device.name).strip ();
            string profile_name = MainWindowHelpers.safe_text (row_device.connection).strip ();
            string primary = iface != "" ? iface : _("Ethernet device");
            var primary_lbl = new Gtk.Label (primary);
            primary_lbl.set_xalign (0.0f);
            primary_lbl.add_css_class (MainWindowCssClasses.SSID_LABEL);
            info.append (primary_lbl);

            string subtitle = "";
            if (profile_name != "") {
                subtitle = _("Profile: %s").printf (profile_name);
            }

            if (subtitle != "") {
                var sub = new Gtk.Label (subtitle);
                sub.set_xalign (0.0f);
                sub.add_css_class (MainWindowCssClasses.SUB_LABEL);
                info.append (sub);
            }
            root.append (info);

            row.set_data<string> ("search-key", primary.down () + " " + (subtitle != "" ? subtitle.down () : ""));
            row.set_data<NetworkDevice> ("device", row_device);

            var details_btn = new Gtk.Button ();
        details_btn.add_css_class (MainWindowCssClasses.ROW_ICON_ACTION);
        details_btn.add_css_class (MainWindowCssClasses.BUTTON);
        details_btn.add_css_class (MainWindowCssClasses.DETAILS_OPEN_BUTTON);
            details_btn.set_valign (Gtk.Align.CENTER);
            details_btn.set_tooltip_text (_("Details"));
            var details_icon = new Gtk.Image.from_icon_name ("document-properties-symbolic");
            details_icon.add_css_class (MainWindowCssClasses.DETAILS_BUTTON_ICON);
            details_icon.add_css_class (MainWindowCssClasses.DETAILS_OPEN_ICON);
            details_btn.set_child (details_icon);
            details_btn.clicked.connect (() => {
                this.open_ethernet_profile (row_device);
            });
            root.append (details_btn);

            row.set_child (root);
            this.ethernet_saved_listbox.append (row);
        }
    }

    private void update_tab_labels () {
        wifi_tab_label.set_label (_("Wi-Fi (%d)").printf (wifi_count));
        eth_tab_label.set_label (_("Ethernet (%d)").printf (eth_count));
    }

    public void focus_wifi_section () {
        notebook.set_current_page (0);
        this.wifi_saved_listbox.grab_focus ();
    }

    public void focus_ethernet_section () {
        notebook.set_current_page (1);
        this.ethernet_saved_listbox.grab_focus ();
    }

    public void remember_scroll_position () {
        saved_wifi_scroll = wifi_scroll.get_vadjustment ().get_value ();
        saved_eth_scroll = eth_scroll.get_vadjustment ().get_value ();
    }

    public void restore_scroll_position () {
        wifi_scroll.get_vadjustment ().set_value (saved_wifi_scroll);
        eth_scroll.get_vadjustment ().set_value (saved_eth_scroll);
    }
}
