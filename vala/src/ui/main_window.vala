// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file includes behavior adapted from SwayNotificationCenter
// (control-center keyboard/open-close patterns):
// https://github.com/ErikReider/SwayNotificationCenter
// Original license: GPL-3.0

using GLib;
using Gtk;
using Gdk;
using GtkLayerShell;

public class MainWindow : Gtk.ApplicationWindow {
    private const int MIN_WINDOW_WIDTH = 480;
    private const int MIN_WINDOW_HEIGHT = 560;

    private bool debug_enabled;
    private int window_width;
    private int window_height;
    private bool anchor_top;
    private bool anchor_right;
    private bool anchor_bottom;
    private bool anchor_left;
    private int shell_margin_top;
    private int shell_margin_right;
    private int shell_margin_bottom;
    private int shell_margin_left;
    private string shell_layer;
    private uint refresh_interval_seconds;
    private bool close_on_connect;
    private bool show_bssid;
    private bool show_frequency;
    private bool show_band;
    private NetworkManagerClientVala nm;
    private Gtk.Label status_label;
    private Gtk.Image status_icon;
    private Gtk.Switch networking_switch;
    private Gtk.Switch wifi_switch;
    private Gtk.ListBox wifi_listbox;
    private Gtk.Stack wifi_stack;
    private WifiNetwork? selected_wifi_network = null;
    private Gtk.Label wifi_details_title;
    private Gtk.Box wifi_details_basic_rows;
    private Gtk.Box wifi_details_advanced_rows;
    private Gtk.Box wifi_details_ip_rows;
    private Gtk.Box wifi_details_action_row;
    private Gtk.Button wifi_details_forget_button;
    private Gtk.Button wifi_details_edit_button;
    private Gtk.Label wifi_edit_title;
    private Gtk.Entry wifi_edit_password_entry;
    private Gtk.Label wifi_edit_note;
    private Gtk.DropDown wifi_edit_ipv4_method_dropdown;
    private Gtk.Entry wifi_edit_ipv4_address_entry;
    private Gtk.Switch wifi_edit_gateway_auto_switch;
    private Gtk.Entry wifi_edit_ipv4_prefix_entry;
    private Gtk.Switch wifi_edit_dns_auto_switch;
    private Gtk.Entry wifi_edit_ipv4_gateway_entry;
    private Gtk.Entry wifi_edit_ipv4_dns_entry;
    private Gtk.Revealer? active_wifi_password_revealer = null;
    private Gtk.Entry? active_wifi_password_entry = null;
    private Gtk.ListBox ethernet_listbox;
    private Gtk.Stack ethernet_stack;
    private Gtk.ListBox vpn_listbox;
    private Gtk.Stack vpn_stack;
    private HashTable<string, bool> pending_wifi_connect;
    private HashTable<string, bool> pending_wifi_seen_connecting;
    private bool updating_switches = false;
    private Gtk.EventControllerKey key_controller;

    public MainWindow(
        Gtk.Application app,
        bool debug_enabled,
        int window_width,
        int window_height,
        bool anchor_top,
        bool anchor_right,
        bool anchor_bottom,
        bool anchor_left,
        int margin_top,
        int margin_right,
        int margin_bottom,
        int margin_left,
        string shell_layer,
        int scan_interval,
        bool close_on_connect,
        bool show_bssid,
        bool show_frequency,
        bool show_band
    ) {
        Object(application: app, title: "Network Manager");
        this.debug_enabled = debug_enabled;
        this.window_width = window_width;
        this.window_height = window_height;
        this.anchor_top = anchor_top;
        this.anchor_right = anchor_right;
        this.anchor_bottom = anchor_bottom;
        this.anchor_left = anchor_left;
        this.shell_margin_top = margin_top;
        this.shell_margin_right = margin_right;
        this.shell_margin_bottom = margin_bottom;
        this.shell_margin_left = margin_left;
        this.shell_layer = shell_layer;
        this.refresh_interval_seconds = (uint) (scan_interval > 0 ? scan_interval : 30);
        this.close_on_connect = close_on_connect;
        this.show_bssid = show_bssid;
        this.show_frequency = show_frequency;
        this.show_band = show_band;

        int effective_width = window_width < MIN_WINDOW_WIDTH ? MIN_WINDOW_WIDTH : window_width;
        int effective_height = window_height < MIN_WINDOW_HEIGHT ? MIN_WINDOW_HEIGHT : window_height;

        set_default_size(effective_width, effective_height);
        set_size_request(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT);
        set_resizable(false);
        set_opacity(1.0);
        add_css_class("nm-window");
        nm = new NetworkManagerClientVala(debug_enabled);
        pending_wifi_connect = new HashTable<string, bool>(str_hash, str_equal);
        pending_wifi_seen_connecting = new HashTable<string, bool>(str_hash, str_equal);

        configure_layer_shell();
        build_ui();
        configure_key_handling();
        refresh_all();
        Timeout.add_seconds(refresh_interval_seconds, () => {
            string error_message;
            if (!nm.scan_wifi(out error_message)) {
                debug_log("Could not request periodic Wi-Fi scan: " + error_message);
            }
            refresh_all();
            return true;
        });

        debug_log("Main window created");
    }

    private void debug_log(string message) {
        if (debug_enabled) {
            stderr.printf("[vala-gui] %s\n", message);
        }
    }

    private void configure_layer_shell() {
        GtkLayerShell.Layer layer_mode = parse_layer_mode(shell_layer);

        if (!GtkLayerShell.is_supported()) {
            stderr.printf(
                "Warning: GtkLayerShell.is_supported() returned false; attempting init anyway.\n"
            );
        }

        GtkLayerShell.init_for_window(this);
        if (!GtkLayerShell.is_layer_window(this)) {
            stderr.printf(
                "Error: failed to initialize layer-shell surface.\n"
                + "Try launching with LD_PRELOAD for libgtk4-layer-shell.\n"
            );
            Process.exit(1);
        }

        GtkLayerShell.set_namespace(this, "hypr-network-manager");
        GtkLayerShell.set_layer(this, layer_mode);

        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.TOP, anchor_top);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.RIGHT, anchor_right);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.BOTTOM, anchor_bottom);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.LEFT, anchor_left);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.TOP, shell_margin_top);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.RIGHT, shell_margin_right);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.BOTTOM, shell_margin_bottom);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.LEFT, shell_margin_left);

        GtkLayerShell.set_keyboard_mode(this, GtkLayerShell.KeyboardMode.ON_DEMAND);
        GtkLayerShell.auto_exclusive_zone_enable(this);
    }

    private GtkLayerShell.Layer parse_layer_mode(string value) {
        switch (value.strip().down()) {
        case "top":
            return GtkLayerShell.Layer.TOP;
        case "bottom":
            return GtkLayerShell.Layer.BOTTOM;
        case "background":
            return GtkLayerShell.Layer.BACKGROUND;
        case "overlay":
        default:
            return GtkLayerShell.Layer.OVERLAY;
        }
    }

    private void configure_key_handling() {
        key_controller = new Gtk.EventControllerKey();
        key_controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
        ((Gtk.Widget) this).add_controller(key_controller);
        key_controller.key_pressed.connect(key_press_event_cb);
    }

    private bool key_press_event_cb(uint keyval, uint keycode, Gdk.ModifierType state) {
        // Keep text entry usable (for Wi-Fi password prompts), but still allow Esc to close.
        if (get_focus() is Gtk.Editable) {
            if (Gdk.keyval_name(keyval) == "Escape") {
                this.close();
                return true;
            }
            return false;
        }

        switch (Gdk.keyval_name(keyval)) {
        case "Escape":
            this.close();
            return true;
        default:
            break;
        }

        return false;
    }

    public void set_popup_text_input_mode(bool enabled) {
        if (enabled) {
            GtkLayerShell.set_keyboard_mode(this, GtkLayerShell.KeyboardMode.ON_DEMAND);
            return;
        }

        bool keep_input_for_wifi_edit = wifi_stack != null
            && wifi_stack.get_visible_child_name() == "edit";
        bool keep_input_for_inline_prompt = active_wifi_password_revealer != null
            && active_wifi_password_revealer.get_reveal_child();

        if (keep_input_for_wifi_edit || keep_input_for_inline_prompt) {
            GtkLayerShell.set_keyboard_mode(this, GtkLayerShell.KeyboardMode.ON_DEMAND);
            return;
        }

        GtkLayerShell.set_keyboard_mode(this, GtkLayerShell.KeyboardMode.NONE);
    }

    private Gtk.Widget build_status_bar() {
        var bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        bar.add_css_class("nm-status-bar");
        bar.set_margin_start(12);
        bar.set_margin_end(8);
        bar.set_margin_top(8);
        bar.set_margin_bottom(8);

        status_icon = new Gtk.Image.from_icon_name("network-wireless-offline-symbolic");
        status_icon.set_pixel_size(16);
        status_icon.add_css_class("nm-status-icon");
        bar.append(status_icon);

        status_label = new Gtk.Label("Loading networks...");
        status_label.set_xalign(0.0f);
        status_label.set_hexpand(true);
        status_label.add_css_class("nm-status-label");
        bar.append(status_label);

        var switch_label = new Gtk.Label("Networking");
        switch_label.add_css_class("nm-toggle-label");
        networking_switch = new Gtk.Switch();
        networking_switch.add_css_class("nm-switch");
        networking_switch.set_valign(Gtk.Align.CENTER);
        networking_switch.notify["active"].connect(() => {
            on_networking_switch_changed();
        });

        var switch_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
        switch_box.append(switch_label);
        switch_box.append(networking_switch);
        bar.append(switch_box);

        return bar;
    }

    private Gtk.Widget build_wifi_page() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-wifi");

        var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        toolbar.set_margin_start(12);
        toolbar.set_margin_end(8);
        toolbar.set_margin_top(8);
        toolbar.set_margin_bottom(8);
        toolbar.add_css_class("nm-toolbar");

        var title = new Gtk.Label("Wi-Fi");
        title.set_xalign(0.0f);
        title.set_hexpand(true);
        title.add_css_class("nm-section-title");
        toolbar.append(title);

        var refresh_btn = new Gtk.Button();
        refresh_btn.add_css_class("nm-button");
        refresh_btn.add_css_class("nm-icon-button");
        var refresh_icon = new Gtk.Image.from_icon_name("view-refresh-symbolic");
        refresh_icon.add_css_class("nm-toolbar-icon");
        refresh_icon.add_css_class("nm-refresh-icon");
        refresh_icon.add_css_class("nm-wifi-refresh-icon");
        refresh_btn.set_child(refresh_icon);
        refresh_btn.clicked.connect(() => {
            refresh_wifi();
        });
        toolbar.append(refresh_btn);

        wifi_switch = new Gtk.Switch();
        wifi_switch.add_css_class("nm-switch");
        wifi_switch.add_css_class("nm-wifi-switch");
        wifi_switch.set_valign(Gtk.Align.CENTER);
        wifi_switch.notify["active"].connect(() => {
            on_wifi_switch_changed();
        });
        toolbar.append(wifi_switch);

        page.append(toolbar);
        var toolbar_sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        toolbar_sep.add_css_class("nm-separator");
        page.append(toolbar_sep);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");

        wifi_listbox = new Gtk.ListBox();
        wifi_listbox.set_selection_mode(Gtk.SelectionMode.NONE);
        wifi_listbox.add_css_class("nm-list");
        scroll.set_child(wifi_listbox);

        var wifi_placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        wifi_placeholder.set_halign(Gtk.Align.CENTER);
        wifi_placeholder.set_valign(Gtk.Align.CENTER);
        wifi_placeholder.add_css_class("nm-empty-state");
        var ph_icon = new Gtk.Image.from_icon_name("network-wireless-offline-symbolic");
        ph_icon.set_pixel_size(24);
        ph_icon.add_css_class("nm-placeholder-icon");
        ph_icon.add_css_class("nm-wifi-placeholder-icon");
        var ph_lbl = new Gtk.Label("No networks found");
        ph_lbl.add_css_class("nm-placeholder-label");
        wifi_placeholder.append(ph_icon);
        wifi_placeholder.append(ph_lbl);

        wifi_stack = new Gtk.Stack();
        wifi_stack.set_vexpand(true);
        wifi_stack.add_css_class("nm-content-stack");
        wifi_stack.add_named(scroll, "list");
        wifi_stack.add_named(wifi_placeholder, "empty");
        wifi_stack.add_named(build_wifi_details_page(), "details");
        wifi_stack.add_named(build_wifi_edit_page(), "edit");
        wifi_stack.set_visible_child_name("empty");

        page.append(wifi_stack);

        return page;
    }

    private static void clear_listbox(Gtk.ListBox listbox) {
        Gtk.Widget? child = listbox.get_first_child();
        while (child != null) {
            Gtk.Widget? next = child.get_next_sibling();
            listbox.remove(child);
            child = next;
        }
    }

    private static void clear_box(Gtk.Box box) {
        Gtk.Widget? child = box.get_first_child();
        while (child != null) {
            Gtk.Widget? next = child.get_next_sibling();
            box.remove(child);
            child = next;
        }
    }

    private string get_mode_label(uint32 mode) {
        switch (mode) {
        case 1:
            return "Ad-hoc";
        case 2:
            return "Infrastructure";
        case 3:
            return "Access Point";
        default:
            return "Unknown";
        }
    }

    private int get_channel_from_frequency(uint32 frequency_mhz) {
        if (frequency_mhz >= 2412 && frequency_mhz <= 2484) {
            return (int) ((frequency_mhz - 2407) / 5);
        }
        if (frequency_mhz >= 5000) {
            return (int) ((frequency_mhz - 5000) / 5);
        }
        return 0;
    }

    private string get_signal_bars(uint8 signal) {
        if (signal >= 80) {
            return "||||";
        }
        if (signal >= 60) {
            return "|||.";
        }
        if (signal >= 40) {
            return "||..";
        }
        if (signal >= 20) {
            return "|...";
        }
        return "....";
    }

    private bool icon_exists(string icon_name) {
        var display = Gdk.Display.get_default();
        if (display == null) {
            return false;
        }

        var icon_theme = Gtk.IconTheme.get_for_display(display);
        return icon_theme.has_icon(icon_name);
    }

    private string get_secured_signal_icon_name(uint8 signal) {
        if (signal >= 80) {
            return "network-wireless-signal-excellent-secure-symbolic";
        }
        if (signal >= 60) {
            return "network-wireless-signal-good-secure-symbolic";
        }
        if (signal >= 40) {
            return "network-wireless-signal-ok-secure-symbolic";
        }
        if (signal >= 20) {
            return "network-wireless-signal-weak-secure-symbolic";
        }
        return "network-wireless-signal-none-secure-symbolic";
    }

    private string resolve_wifi_row_icon_name(WifiNetwork net) {
        if (!net.is_secured) {
            return net.signal_icon_name;
        }

        string secure_signal_icon = get_secured_signal_icon_name(net.signal);
        if (icon_exists(secure_signal_icon)) {
            return secure_signal_icon;
        }

        if (icon_exists("network-wireless-encrypted-symbolic")) {
            return "network-wireless-encrypted-symbolic";
        }

        return net.signal_icon_name;
    }

    private Gtk.Widget build_details_row(string key, string value) {
        var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
        row.add_css_class("nm-details-row");
        row.add_css_class("nm-details-item");

        var key_label = new Gtk.Label(key);
        key_label.set_xalign(0.0f);
        key_label.set_halign(Gtk.Align.START);
        key_label.set_hexpand(false);
        key_label.add_css_class("nm-details-key");
        key_label.add_css_class("nm-details-item-key");

        var value_label = new Gtk.Label(value);
        value_label.set_xalign(0.0f);
        value_label.set_halign(Gtk.Align.START);
        value_label.set_wrap(true);
        value_label.add_css_class("nm-details-value");
        value_label.add_css_class("nm-details-item-value");

        row.append(key_label);
        row.append(value_label);
        return row;
    }

    private Gtk.Widget build_details_section(string title, out Gtk.Box rows_container) {
        var section = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        section.add_css_class("nm-details-section");

        var heading = new Gtk.Label(title);
        heading.set_xalign(0.5f);
        heading.add_css_class("nm-details-group-title");
        section.append(heading);

        var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        separator.add_css_class("nm-separator");
        section.append(separator);

        rows_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        rows_container.add_css_class("nm-details-rows");
        section.append(rows_container);

        return section;
    }

    private string get_ipv4_method_label(string method) {
        switch (method.strip().down()) {
        case "manual":
            return "Manual";
        case "disabled":
            return "Disabled";
        case "auto":
        default:
            return "Automatic (DHCP)";
        }
    }

    private uint get_ipv4_method_dropdown_index(string method) {
        switch (method.strip().down()) {
        case "manual":
            return 1;
        case "disabled":
            return 2;
        case "auto":
        default:
            return 0;
        }
    }

    private string get_selected_ipv4_method() {
        switch (wifi_edit_ipv4_method_dropdown.get_selected()) {
        case 1:
            return "manual";
        case 2:
            return "disabled";
        case 0:
        default:
            return "auto";
        }
    }

    private string format_ip_with_prefix(string address, uint32 prefix) {
        string ip = address.strip();
        if (ip == "") {
            return "n/a";
        }
        if (prefix > 0) {
            return "%s/%u".printf(ip, prefix);
        }
        return ip;
    }

    private void sync_wifi_edit_gateway_dns_sensitivity() {
        if (wifi_edit_ipv4_gateway_entry != null && wifi_edit_gateway_auto_switch != null) {
            wifi_edit_ipv4_gateway_entry.set_sensitive(!wifi_edit_gateway_auto_switch.get_active());
        }

        if (wifi_edit_ipv4_dns_entry != null && wifi_edit_dns_auto_switch != null) {
            wifi_edit_ipv4_dns_entry.set_sensitive(!wifi_edit_dns_auto_switch.get_active());
        }
    }

    private void populate_wifi_details(WifiNetwork net) {
        wifi_details_title.set_text(net.ssid);
        bool can_manage_saved_profile = net.saved;
        wifi_details_action_row.set_visible(can_manage_saved_profile);
        wifi_details_forget_button.set_visible(can_manage_saved_profile);
        wifi_details_edit_button.set_visible(can_manage_saved_profile);

        clear_box(wifi_details_basic_rows);
        clear_box(wifi_details_advanced_rows);
        clear_box(wifi_details_ip_rows);

        wifi_details_basic_rows.append(build_details_row("Connection Status", net.connected ? "Connected" : "Not connected"));
        wifi_details_basic_rows.append(build_details_row("Signal Strength", "%u%%".printf(net.signal)));
        wifi_details_basic_rows.append(build_details_row("Bars", get_signal_bars(net.signal)));
        wifi_details_basic_rows.append(build_details_row("Security", net.is_secured ? "Secured" : "Open"));
        wifi_details_basic_rows.append(build_details_row("Saved Profile", net.saved ? "Yes" : "No"));

        string band = get_band_label(net.frequency_mhz);
        int channel = get_channel_from_frequency(net.frequency_mhz);
        wifi_details_advanced_rows.append(
            build_details_row(
                "Frequency",
                net.frequency_mhz > 0 ? "%.1f GHz".printf((double) net.frequency_mhz / 1000.0) : "n/a"
            )
        );
        wifi_details_advanced_rows.append(build_details_row("Channel", channel > 0 ? "%d".printf(channel) : "n/a"));
        wifi_details_advanced_rows.append(build_details_row("Band", band != "" ? band : "n/a"));
        wifi_details_advanced_rows.append(build_details_row("BSSID", net.bssid != "" ? net.bssid : "n/a"));
        wifi_details_advanced_rows.append(
            build_details_row(
                "Max bitrate",
                net.max_bitrate_kbps > 0 ? "%.1f Mbps".printf((double) net.max_bitrate_kbps / 1000.0) : "n/a"
            )
        );
        wifi_details_advanced_rows.append(build_details_row("Mode", get_mode_label(net.mode)));

        NetworkIpSettings ip_settings;
        string ip_error;
        bool ip_ok = nm.get_wifi_network_ip_settings(net, out ip_settings, out ip_error);
        if (!ip_ok && ip_error != "") {
            debug_log("Could not read IP settings for details page: " + ip_error);
        }

        wifi_details_ip_rows.append(
            build_details_row("Configured IPv4 Method", get_ipv4_method_label(ip_settings.ipv4_method))
        );
        wifi_details_ip_rows.append(
            build_details_row(
                "Configured IPv4 Address",
                format_ip_with_prefix(ip_settings.configured_address, ip_settings.configured_prefix)
            )
        );
        wifi_details_ip_rows.append(
            build_details_row(
                "Configured Gateway",
                ip_settings.configured_gateway.strip() != "" ? ip_settings.configured_gateway : "n/a"
            )
        );
        wifi_details_ip_rows.append(
            build_details_row(
                "Configured DNS",
                ip_settings.configured_dns.strip() != "" ? ip_settings.configured_dns : "n/a"
            )
        );
        wifi_details_ip_rows.append(
            build_details_row(
                "Current IPv4 Address",
                format_ip_with_prefix(ip_settings.current_address, ip_settings.current_prefix)
            )
        );
        wifi_details_ip_rows.append(
            build_details_row(
                "Current Gateway",
                ip_settings.current_gateway.strip() != "" ? ip_settings.current_gateway : "n/a"
            )
        );
        wifi_details_ip_rows.append(
            build_details_row(
                "Current DNS",
                ip_settings.current_dns.strip() != "" ? ip_settings.current_dns : "n/a"
            )
        );
    }

    private void open_wifi_details(WifiNetwork net) {
        selected_wifi_network = net;
        populate_wifi_details(net);
        wifi_stack.set_visible_child_name("details");
    }

    private void open_wifi_edit(WifiNetwork net) {
        if (!net.saved) {
            return;
        }

        selected_wifi_network = net;
        wifi_edit_title.set_text("Edit: %s".printf(net.ssid));
        wifi_edit_password_entry.set_text("");

        if (net.is_secured) {
            wifi_edit_note.set_text(
                "Leave password empty to keep current credentials.\n"
                + "IPv4 settings can be changed below (DHCP or manual)."
            );
        } else {
            wifi_edit_note.set_text("Open network. Password is not required.");
        }

        NetworkIpSettings ip_settings;
        string ip_error;
        if (nm.get_wifi_network_ip_settings(net, out ip_settings, out ip_error)) {
            wifi_edit_ipv4_method_dropdown.set_selected(get_ipv4_method_dropdown_index(ip_settings.ipv4_method));
            wifi_edit_ipv4_address_entry.set_text(ip_settings.configured_address);
            wifi_edit_ipv4_prefix_entry.set_text(
                ip_settings.configured_prefix > 0 ? "%u".printf(ip_settings.configured_prefix) : ""
            );
            wifi_edit_gateway_auto_switch.set_active(ip_settings.gateway_auto);
            wifi_edit_ipv4_gateway_entry.set_text(ip_settings.configured_gateway);
            wifi_edit_dns_auto_switch.set_active(ip_settings.dns_auto);
            wifi_edit_ipv4_dns_entry.set_text(ip_settings.configured_dns);
        } else {
            debug_log("Could not load current IP settings for edit: " + ip_error);
            wifi_edit_ipv4_method_dropdown.set_selected(0);
            wifi_edit_ipv4_address_entry.set_text("");
            wifi_edit_ipv4_prefix_entry.set_text("");
            wifi_edit_gateway_auto_switch.set_active(true);
            wifi_edit_ipv4_gateway_entry.set_text("");
            wifi_edit_dns_auto_switch.set_active(true);
            wifi_edit_ipv4_dns_entry.set_text("");
        }

        sync_wifi_edit_gateway_dns_sensitivity();

        wifi_stack.set_visible_child_name("edit");
        set_popup_text_input_mode(true);
        wifi_edit_password_entry.grab_focus();
    }

    private bool apply_wifi_edit() {
        if (selected_wifi_network == null) {
            return false;
        }

        var net = selected_wifi_network;
        string password = wifi_edit_password_entry.get_text().strip();

        string method = get_selected_ipv4_method();
        string ipv4_address = wifi_edit_ipv4_address_entry.get_text().strip();
        bool gateway_auto = wifi_edit_gateway_auto_switch.get_active();
        string ipv4_gateway = wifi_edit_ipv4_gateway_entry.get_text().strip();
        bool dns_auto = wifi_edit_dns_auto_switch.get_active();
        string dns_csv = wifi_edit_ipv4_dns_entry.get_text().strip();
        uint32 ipv4_prefix = 0;

        string prefix_text = wifi_edit_ipv4_prefix_entry.get_text().strip();
        if (prefix_text != "") {
            uint parsed_prefix;
            if (!uint.try_parse(prefix_text, out parsed_prefix) || parsed_prefix > 32) {
                show_error("IPv4 prefix must be a number between 0 and 32.");
                return false;
            }
            ipv4_prefix = (uint32) parsed_prefix;
        }

        if (method == "manual") {
            if (ipv4_address == "") {
                show_error("Manual IPv4 requires an address.");
                return false;
            }
            if (ipv4_prefix == 0) {
                show_error("Manual IPv4 requires a prefix between 1 and 32.");
                return false;
            }
        }

        if (!gateway_auto && ipv4_gateway == "") {
            show_error("Manual gateway is enabled; please provide a gateway address.");
            return false;
        }

        string[] dns_servers = {};
        foreach (string token in dns_csv.split(",")) {
            string item = token.strip();
            if (item != "") {
                dns_servers += item;
            }
        }

        if (!dns_auto && dns_servers.length == 0) {
            show_error("Manual DNS is enabled; provide at least one DNS server.");
            return false;
        }

        string error_message;
        if (!nm.update_wifi_network_settings(
            net,
            password,
            method,
            ipv4_address,
            ipv4_prefix,
            gateway_auto,
            ipv4_gateway,
            dns_auto,
            dns_servers,
            out error_message
        )) {
            show_error("Apply failed: " + error_message);
            return false;
        }

        if (net.connected) {
            string disconnect_error;
            if (!nm.disconnect_wifi(net, out disconnect_error)) {
                show_error("Disconnect before reconnect failed: " + disconnect_error);
                return false;
            }

            Timeout.add(750, () => {
                pending_wifi_connect.insert(net.ssid, true);
                pending_wifi_seen_connecting.remove(net.ssid);
                string reconnect_error;
                if (!nm.connect_wifi(net, null, out reconnect_error)) {
                    pending_wifi_connect.remove(net.ssid);
                    pending_wifi_seen_connecting.remove(net.ssid);
                    show_error("Reconnect after edit failed: " + reconnect_error);
                }
                refresh_after_action(true);
                return false;
            });
        } else {
            refresh_after_action(method != "disabled");
        }

        open_wifi_details(net);
        set_popup_text_input_mode(false);
        return true;
    }

    private Gtk.Widget build_wifi_details_page() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        page.set_margin_start(12);
        page.set_margin_end(12);
        page.set_margin_top(12);
        page.set_margin_bottom(12);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-wifi-details");

        var nav_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        nav_row.add_css_class("nm-details-nav-row");

        var back_btn = new Gtk.Button.with_label("← Back");
        back_btn.add_css_class("nm-button");
        back_btn.add_css_class("nm-nav-back");
        back_btn.set_halign(Gtk.Align.START);
        back_btn.clicked.connect(() => {
            set_popup_text_input_mode(false);
            wifi_stack.set_visible_child_name("list");
        });
        nav_row.append(back_btn);
        page.append(nav_row);

        var network_header = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        network_header.set_halign(Gtk.Align.CENTER);
        network_header.add_css_class("nm-details-header");

        var network_icon = new Gtk.Image.from_icon_name("network-wireless-signal-excellent-symbolic");
        network_icon.set_pixel_size(28);
        network_icon.add_css_class("nm-signal-icon");
        network_icon.add_css_class("nm-wifi-icon");
        network_icon.add_css_class("nm-details-network-icon");
        network_header.append(network_icon);

        wifi_details_title = new Gtk.Label("Network");
        wifi_details_title.set_xalign(0.5f);
        wifi_details_title.set_halign(Gtk.Align.CENTER);
        wifi_details_title.add_css_class("nm-details-network-title");
        network_header.append(wifi_details_title);

        wifi_details_action_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        wifi_details_action_row.set_halign(Gtk.Align.CENTER);
        wifi_details_action_row.add_css_class("nm-details-action-row");

        wifi_details_forget_button = new Gtk.Button.with_label("Forget");
        wifi_details_forget_button.add_css_class("nm-button");
        wifi_details_forget_button.add_css_class("nm-action-button");
        wifi_details_forget_button.add_css_class("nm-details-action-button");
        wifi_details_forget_button.clicked.connect(() => {
            if (selected_wifi_network == null) {
                return;
            }

            string error_message;
            if (!nm.forget_network(selected_wifi_network.ssid, out error_message)) {
                show_error("Forget failed: " + error_message);
                return;
            }

            refresh_after_action(true);
            wifi_stack.set_visible_child_name("list");
        });
        wifi_details_action_row.append(wifi_details_forget_button);

        wifi_details_edit_button = new Gtk.Button.with_label("Edit");
        wifi_details_edit_button.add_css_class("nm-button");
        wifi_details_edit_button.add_css_class("nm-action-button");
        wifi_details_edit_button.add_css_class("nm-details-action-button");
        wifi_details_edit_button.clicked.connect(() => {
            if (selected_wifi_network != null) {
                open_wifi_edit(selected_wifi_network);
            }
        });
        wifi_details_action_row.append(wifi_details_edit_button);

        network_header.append(wifi_details_action_row);
        page.append(network_header);

        var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        sep.add_css_class("nm-separator");
        page.append(sep);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");
        scroll.set_vexpand(true);

        var body = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        body.set_margin_top(4);
        body.set_margin_bottom(4);
        body.append(build_details_section("Basic", out wifi_details_basic_rows));
        body.append(build_details_section("Advanced", out wifi_details_advanced_rows));
        body.append(build_details_section("IP", out wifi_details_ip_rows));

        scroll.set_child(body);
        page.append(scroll);
        return page;
    }

    private Gtk.Widget build_wifi_edit_page() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        page.set_margin_start(12);
        page.set_margin_end(12);
        page.set_margin_top(12);
        page.set_margin_bottom(12);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-wifi-edit");

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var back_btn = new Gtk.Button.with_label("Back");
        back_btn.add_css_class("nm-button");
        back_btn.add_css_class("nm-nav-back");
        back_btn.clicked.connect(() => {
            set_popup_text_input_mode(false);
            if (selected_wifi_network != null) {
                open_wifi_details(selected_wifi_network);
            } else {
                wifi_stack.set_visible_child_name("list");
            }
        });
        header.append(back_btn);

        wifi_edit_title = new Gtk.Label("Edit Network");
        wifi_edit_title.set_xalign(0.0f);
        wifi_edit_title.set_hexpand(true);
        wifi_edit_title.add_css_class("nm-section-title");
        header.append(wifi_edit_title);
        page.append(header);

        var form = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        form.add_css_class("nm-edit-form");
        form.add_css_class("nm-edit-wifi-form");

        wifi_edit_note = new Gtk.Label("");
        wifi_edit_note.set_xalign(0.0f);
        wifi_edit_note.set_wrap(true);
        wifi_edit_note.add_css_class("nm-sub-label");
        wifi_edit_note.add_css_class("nm-edit-note");
        form.append(wifi_edit_note);

        var password_label = new Gtk.Label("Password");
        password_label.set_xalign(0.0f);
        password_label.add_css_class("nm-form-label");
        password_label.add_css_class("nm-edit-field-label");
        password_label.add_css_class("nm-edit-password-label");
        form.append(password_label);

        wifi_edit_password_entry = new Gtk.Entry();
        wifi_edit_password_entry.set_visibility(false);
        wifi_edit_password_entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
        wifi_edit_password_entry.set_placeholder_text("New password");
        wifi_edit_password_entry.add_css_class("nm-password-entry");
        wifi_edit_password_entry.add_css_class("nm-edit-field-control");
        wifi_edit_password_entry.add_css_class("nm-edit-field-entry");
        wifi_edit_password_entry.add_css_class("nm-edit-password-entry");
        wifi_edit_password_entry.activate.connect(() => {
            apply_wifi_edit();
        });
        form.append(wifi_edit_password_entry);

        var ipv4_method_label = new Gtk.Label("IPv4 Method");
        ipv4_method_label.set_xalign(0.0f);
        ipv4_method_label.add_css_class("nm-form-label");
        ipv4_method_label.add_css_class("nm-edit-field-label");
        ipv4_method_label.add_css_class("nm-edit-ipv4-method-label");
        form.append(ipv4_method_label);

        var ipv4_method_list = new Gtk.StringList(null);
        ipv4_method_list.append("Automatic (DHCP)");
        ipv4_method_list.append("Manual");
        ipv4_method_list.append("Disabled");
        wifi_edit_ipv4_method_dropdown = new Gtk.DropDown(ipv4_method_list, null);
        wifi_edit_ipv4_method_dropdown.add_css_class("nm-edit-field-control");
        wifi_edit_ipv4_method_dropdown.add_css_class("nm-edit-dropdown");
        wifi_edit_ipv4_method_dropdown.add_css_class("nm-edit-ipv4-method-dropdown");
        form.append(wifi_edit_ipv4_method_dropdown);

        var ipv4_address_label = new Gtk.Label("IPv4 Address");
        ipv4_address_label.set_xalign(0.0f);
        ipv4_address_label.add_css_class("nm-form-label");
        ipv4_address_label.add_css_class("nm-edit-field-label");
        ipv4_address_label.add_css_class("nm-edit-ipv4-address-label");
        form.append(ipv4_address_label);

        wifi_edit_ipv4_address_entry = new Gtk.Entry();
        wifi_edit_ipv4_address_entry.set_placeholder_text("192.168.1.100");
        wifi_edit_ipv4_address_entry.add_css_class("nm-edit-field-control");
        wifi_edit_ipv4_address_entry.add_css_class("nm-edit-field-entry");
        wifi_edit_ipv4_address_entry.add_css_class("nm-edit-ipv4-address-entry");
        form.append(wifi_edit_ipv4_address_entry);

        var ipv4_prefix_label = new Gtk.Label("Prefix (CIDR)");
        ipv4_prefix_label.set_xalign(0.0f);
        ipv4_prefix_label.add_css_class("nm-form-label");
        ipv4_prefix_label.add_css_class("nm-edit-field-label");
        ipv4_prefix_label.add_css_class("nm-edit-ipv4-prefix-label");
        form.append(ipv4_prefix_label);

        wifi_edit_ipv4_prefix_entry = new Gtk.Entry();
        wifi_edit_ipv4_prefix_entry.set_placeholder_text("24");
        wifi_edit_ipv4_prefix_entry.add_css_class("nm-edit-field-control");
        wifi_edit_ipv4_prefix_entry.add_css_class("nm-edit-field-entry");
        wifi_edit_ipv4_prefix_entry.add_css_class("nm-edit-ipv4-prefix-entry");
        form.append(wifi_edit_ipv4_prefix_entry);

        var ipv4_gateway_label = new Gtk.Label("Gateway");
        ipv4_gateway_label.set_xalign(0.0f);
        ipv4_gateway_label.add_css_class("nm-form-label");
        ipv4_gateway_label.add_css_class("nm-edit-field-label");
        ipv4_gateway_label.add_css_class("nm-edit-gateway-label");
        form.append(ipv4_gateway_label);

        var gateway_mode_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        gateway_mode_row.add_css_class("nm-edit-mode-row");
        gateway_mode_row.add_css_class("nm-edit-gateway-mode-row");
        gateway_mode_row.set_halign(Gtk.Align.FILL);
        gateway_mode_row.set_hexpand(true);
        var gateway_mode_label = new Gtk.Label("Automatic gateway");
        gateway_mode_label.set_xalign(0.0f);
        gateway_mode_label.set_hexpand(true);
        gateway_mode_label.set_valign(Gtk.Align.CENTER);
        gateway_mode_label.add_css_class("nm-edit-mode-label");
        gateway_mode_label.add_css_class("nm-edit-gateway-mode-label");
        gateway_mode_row.append(gateway_mode_label);
        wifi_edit_gateway_auto_switch = new Gtk.Switch();
        wifi_edit_gateway_auto_switch.add_css_class("nm-switch");
        wifi_edit_gateway_auto_switch.add_css_class("nm-edit-field-control");
        wifi_edit_gateway_auto_switch.add_css_class("nm-edit-mode-switch");
        wifi_edit_gateway_auto_switch.add_css_class("nm-edit-gateway-mode-switch");
        wifi_edit_gateway_auto_switch.set_valign(Gtk.Align.CENTER);
        wifi_edit_gateway_auto_switch.set_active(true);
        wifi_edit_gateway_auto_switch.notify["active"].connect(() => {
            sync_wifi_edit_gateway_dns_sensitivity();
        });
        gateway_mode_row.append(wifi_edit_gateway_auto_switch);
        form.append(gateway_mode_row);

        wifi_edit_ipv4_gateway_entry = new Gtk.Entry();
        wifi_edit_ipv4_gateway_entry.set_placeholder_text("192.168.1.1");
        wifi_edit_ipv4_gateway_entry.add_css_class("nm-edit-field-control");
        wifi_edit_ipv4_gateway_entry.add_css_class("nm-edit-field-entry");
        wifi_edit_ipv4_gateway_entry.add_css_class("nm-edit-gateway-entry");
        form.append(wifi_edit_ipv4_gateway_entry);

        var ipv4_dns_label = new Gtk.Label("DNS Servers (comma-separated)");
        ipv4_dns_label.set_xalign(0.0f);
        ipv4_dns_label.add_css_class("nm-form-label");
        ipv4_dns_label.add_css_class("nm-edit-field-label");
        ipv4_dns_label.add_css_class("nm-edit-dns-label");
        form.append(ipv4_dns_label);

        var dns_mode_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        dns_mode_row.add_css_class("nm-edit-mode-row");
        dns_mode_row.add_css_class("nm-edit-dns-mode-row");
        dns_mode_row.set_halign(Gtk.Align.FILL);
        dns_mode_row.set_hexpand(true);
        var dns_mode_label = new Gtk.Label("Automatic DNS");
        dns_mode_label.set_xalign(0.0f);
        dns_mode_label.set_hexpand(true);
        dns_mode_label.set_valign(Gtk.Align.CENTER);
        dns_mode_label.add_css_class("nm-edit-mode-label");
        dns_mode_label.add_css_class("nm-edit-dns-mode-label");
        dns_mode_row.append(dns_mode_label);
        wifi_edit_dns_auto_switch = new Gtk.Switch();
        wifi_edit_dns_auto_switch.add_css_class("nm-switch");
        wifi_edit_dns_auto_switch.add_css_class("nm-edit-field-control");
        wifi_edit_dns_auto_switch.add_css_class("nm-edit-mode-switch");
        wifi_edit_dns_auto_switch.add_css_class("nm-edit-dns-mode-switch");
        wifi_edit_dns_auto_switch.set_valign(Gtk.Align.CENTER);
        wifi_edit_dns_auto_switch.set_active(true);
        wifi_edit_dns_auto_switch.notify["active"].connect(() => {
            sync_wifi_edit_gateway_dns_sensitivity();
        });
        dns_mode_row.append(wifi_edit_dns_auto_switch);
        form.append(dns_mode_row);

        wifi_edit_ipv4_dns_entry = new Gtk.Entry();
        wifi_edit_ipv4_dns_entry.set_placeholder_text("1.1.1.1, 8.8.8.8");
        wifi_edit_ipv4_dns_entry.add_css_class("nm-edit-field-control");
        wifi_edit_ipv4_dns_entry.add_css_class("nm-edit-field-entry");
        wifi_edit_ipv4_dns_entry.add_css_class("nm-edit-dns-entry");
        form.append(wifi_edit_ipv4_dns_entry);

        sync_wifi_edit_gateway_dns_sensitivity();

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        actions.add_css_class("nm-edit-actions");
        actions.add_css_class("nm-edit-wifi-actions");

        var save_btn = new Gtk.Button.with_label("Apply");
        save_btn.add_css_class("nm-button");
        save_btn.add_css_class("suggested-action");
        save_btn.clicked.connect(() => {
            apply_wifi_edit();
        });
        actions.append(save_btn);

        form.append(actions);
        page.append(form);
        return page;
    }

    private string get_band_label(uint32 frequency_mhz) {
        if (frequency_mhz >= 2400 && frequency_mhz < 2500) {
            return "2.4 GHz";
        }
        if (frequency_mhz >= 5000 && frequency_mhz < 6000) {
            return "5 GHz";
        }
        return "";
    }

    private Gtk.ListBoxRow build_wifi_row(WifiNetwork net) {
        var row = new Gtk.ListBoxRow();
        row.add_css_class("nm-wifi-row");
        if (net.connected) {
            row.add_css_class("connected");
        }

        var row_root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        row_root.add_css_class("nm-row-root");

        var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
        content.add_css_class("nm-row-content");

        var signal_icon = new Gtk.Image.from_icon_name(resolve_wifi_row_icon_name(net));
        signal_icon.set_pixel_size(16);
        signal_icon.add_css_class("nm-signal-icon");
        signal_icon.add_css_class("nm-wifi-icon");
        if (net.is_secured) {
            signal_icon.add_css_class("nm-signal-icon-secured");
        }
        content.append(signal_icon);

        var info = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
        info.set_hexpand(true);
        info.add_css_class("nm-row-info");
        var ssid_lbl = new Gtk.Label(net.ssid);
        ssid_lbl.set_xalign(0.0f);
        ssid_lbl.add_css_class("nm-ssid-label");
        info.append(ssid_lbl);

        string subtitle = "%s (%u%%)".printf(net.signal_label, net.signal);
        if (show_frequency && net.frequency_mhz > 0) {
            subtitle += " • %u MHz".printf(net.frequency_mhz);
        }
        if (show_band && net.frequency_mhz > 0) {
            string band = get_band_label(net.frequency_mhz);
            if (band != "") {
                subtitle += " • %s".printf(band);
            }
        }
        if (show_bssid && net.bssid != "") {
            subtitle += " • %s".printf(net.bssid);
        }

        var sub = new Gtk.Label(subtitle);
        sub.set_xalign(0.0f);
        sub.add_css_class("nm-sub-label");
        info.append(sub);
        content.append(info);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        actions.add_css_class("nm-row-actions");
        actions.set_valign(Gtk.Align.CENTER);

        var details_btn = new Gtk.Button();
        details_btn.add_css_class("nm-button");
        details_btn.add_css_class("nm-menu-button");
        details_btn.add_css_class("nm-details-open-button");
        details_btn.add_css_class("nm-row-icon-button");
        details_btn.set_valign(Gtk.Align.CENTER);
        details_btn.set_tooltip_text("Details");
        var details_icon = new Gtk.Image.from_icon_name("document-properties-symbolic");
        details_icon.add_css_class("nm-details-open-icon");
        details_icon.add_css_class("nm-details-button-icon");
        details_btn.set_child(details_icon);
        details_btn.clicked.connect(() => {
            open_wifi_details(net);
        });

        if (net.saved) {
            var forget = new Gtk.Button.with_label("Forget");
            forget.add_css_class("nm-button");
            forget.add_css_class("nm-action-button");
            forget.add_css_class("nm-row-action-button");
            forget.set_valign(Gtk.Align.CENTER);
            forget.clicked.connect(() => {
                string error_message;
                if (!nm.forget_network(net.ssid, out error_message)) {
                    show_error("Forget failed: " + error_message);
                }
                refresh_after_action(true);
            });
            actions.append(forget);
        }

        bool is_connecting = pending_wifi_connect.contains(net.ssid);
        string action_label = is_connecting ? "Connecting..." : (net.connected ? "Disconnect" : "Connect");
        var action = new Gtk.Button.with_label(action_label);
        action.add_css_class("nm-button");
        action.add_css_class(net.connected && !is_connecting ? "nm-disconnect-button" : "nm-connect-button");
        action.add_css_class("nm-row-action-button");
        action.set_valign(Gtk.Align.CENTER);
        action.set_sensitive(!is_connecting);

        var prompt_label = new Gtk.Label("Password for %s".printf(net.ssid));
        prompt_label.set_xalign(0.0f);
        prompt_label.set_hexpand(true);
        prompt_label.add_css_class("nm-form-label");
        prompt_label.add_css_class("nm-inline-password-label");

        var prompt_entry = new Gtk.Entry();
        prompt_entry.set_hexpand(true);
        prompt_entry.set_visibility(false);
        prompt_entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
        prompt_entry.set_placeholder_text("Wi-Fi password");
        prompt_entry.add_css_class("nm-password-entry");
        prompt_entry.add_css_class("nm-inline-password-entry");

        var prompt_cancel = new Gtk.Button.with_label("Cancel");
        prompt_cancel.add_css_class("nm-button");
        prompt_cancel.add_css_class("nm-inline-password-cancel");

        var prompt_connect = new Gtk.Button.with_label("Connect");
        prompt_connect.add_css_class("nm-button");
        prompt_connect.add_css_class("suggested-action");
        prompt_connect.add_css_class("nm-inline-password-connect");

        var prompt_actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        prompt_actions.add_css_class("nm-inline-password-actions");
        prompt_actions.set_halign(Gtk.Align.END);
        prompt_actions.append(prompt_cancel);
        prompt_actions.append(prompt_connect);

        var prompt_inner = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        prompt_inner.add_css_class("nm-inline-password");
        prompt_inner.append(prompt_label);
        prompt_inner.append(prompt_entry);
        prompt_inner.append(prompt_actions);

        var prompt_revealer = new Gtk.Revealer();
        prompt_revealer.add_css_class("nm-inline-password-revealer");
        prompt_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN);
        prompt_revealer.set_transition_duration(220);
        prompt_revealer.set_reveal_child(false);
        prompt_revealer.set_child(prompt_inner);

        prompt_cancel.clicked.connect(() => {
            hide_wifi_password_prompt(prompt_revealer, prompt_entry, null);
        });

        prompt_connect.clicked.connect(() => {
            hide_wifi_password_prompt(prompt_revealer, prompt_entry, prompt_entry.get_text());
            connect_wifi_with_optional_password(net, prompt_entry.get_text());
        });

        prompt_entry.activate.connect(() => {
            hide_wifi_password_prompt(prompt_revealer, prompt_entry, prompt_entry.get_text());
            connect_wifi_with_optional_password(net, prompt_entry.get_text());
        });

        action.clicked.connect(() => {
            if (net.connected) {
                pending_wifi_connect.remove(net.ssid);
                pending_wifi_seen_connecting.remove(net.ssid);
                string error_message;
                if (!nm.disconnect_wifi(net, out error_message)) {
                    show_error("Disconnect failed: " + error_message);
                }
                refresh_after_action(false);
                return;
            }

            if (net.is_secured && !net.saved) {
                show_wifi_password_prompt(prompt_revealer, prompt_entry);
            } else {
                connect_wifi_with_optional_password(net, null);
            }
        });
        actions.append(action);
        actions.append(details_btn);
        content.append(actions);

        row_root.append(content);
        row_root.append(prompt_revealer);
        row.set_child(row_root);
        return row;
    }

    private void refresh_wifi() {
        debug_log("Refreshing Wi-Fi list");
        string current_view = wifi_stack.get_visible_child_name();
        hide_active_wifi_password_prompt();
        refresh_switch_states();
        var networks = nm.get_wifi_networks();
        var devices = nm.get_devices();

        foreach (var net in networks) {
            if (!pending_wifi_connect.contains(net.ssid)) {
                continue;
            }

            if (net.connected) {
                pending_wifi_connect.remove(net.ssid);
                pending_wifi_seen_connecting.remove(net.ssid);
                continue;
            }

            NetworkDevice? matched_device = null;
            foreach (var dev in devices) {
                if (dev.is_wifi && dev.device_path == net.device_path) {
                    matched_device = dev;
                    break;
                }
            }

            if (matched_device == null) {
                continue;
            }

            bool is_connecting_state = matched_device.state >= 40
                && matched_device.state < NM_DEVICE_STATE_ACTIVATED;
            if (is_connecting_state) {
                pending_wifi_seen_connecting.insert(net.ssid, true);
                continue;
            }

            if (pending_wifi_seen_connecting.contains(net.ssid)) {
                pending_wifi_connect.remove(net.ssid);
                pending_wifi_seen_connecting.remove(net.ssid);
            }
        }

        clear_listbox(wifi_listbox);
        foreach (var net in networks) {
            wifi_listbox.append(build_wifi_row(net));
        }

        if (current_view == "details" || current_view == "edit") {
            if (selected_wifi_network != null) {
                WifiNetwork? updated = null;
                foreach (var net in networks) {
                    if (net.ssid == selected_wifi_network.ssid) {
                        updated = net;
                        break;
                    }
                }

                if (updated != null) {
                    selected_wifi_network = updated;
                    if (current_view == "details") {
                        populate_wifi_details(updated);
                    }
                    wifi_stack.set_visible_child_name(current_view);
                } else {
                    selected_wifi_network = null;
                    wifi_stack.set_visible_child_name(networks.length() > 0 ? "list" : "empty");
                }
            } else {
                wifi_stack.set_visible_child_name(networks.length() > 0 ? "list" : "empty");
            }
        } else {
            wifi_stack.set_visible_child_name(networks.length() > 0 ? "list" : "empty");
        }

        if (networks.length() > 0) {
            WifiNetwork? connected = null;
            foreach (var net in networks) {
                if (net.connected) {
                    connected = net;
                    break;
                }
            }

            if (connected != null) {
                status_label.set_text("Wi-Fi · %s (%u%%)".printf(connected.ssid, connected.signal));
                status_icon.set_from_icon_name(connected.signal_icon_name);
            } else {
                status_label.set_text("Wi-Fi available (%u networks)".printf(networks.length()));
                status_icon.set_from_icon_name("network-wireless-signal-good-symbolic");
            }
        } else {
            status_label.set_text("No Wi-Fi networks found");
            status_icon.set_from_icon_name("network-wireless-offline-symbolic");
        }

        debug_log("Rendered %u Wi-Fi rows".printf(networks.length()));
    }

    private void connect_wifi_with_optional_password(WifiNetwork net, string? password) {
        if (!net.connected) {
            pending_wifi_connect.insert(net.ssid, true);
            pending_wifi_seen_connecting.remove(net.ssid);
        }

        string error_message;
        if (!nm.connect_wifi(net, password, out error_message)) {
            pending_wifi_connect.remove(net.ssid);
            pending_wifi_seen_connecting.remove(net.ssid);
            show_error("Connect failed: " + error_message);
            return;
        }

        if (close_on_connect) {
            this.close();
            return;
        }

        refresh_after_action(true);

        string pending_ssid = net.ssid;
        Timeout.add(20000, () => {
            if (pending_wifi_connect.contains(pending_ssid)) {
                pending_wifi_connect.remove(pending_ssid);
                pending_wifi_seen_connecting.remove(pending_ssid);
                refresh_wifi();
            }
            return false;
        });
    }

    private Gtk.Widget build_ethernet_page() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-ethernet");

        var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        toolbar.set_margin_start(12);
        toolbar.set_margin_end(8);
        toolbar.set_margin_top(8);
        toolbar.set_margin_bottom(8);
        toolbar.add_css_class("nm-toolbar");

        var title = new Gtk.Label("Ethernet");
        title.set_xalign(0.0f);
        title.set_hexpand(true);
        title.add_css_class("nm-section-title");
        toolbar.append(title);

        var refresh_btn = new Gtk.Button();
        refresh_btn.add_css_class("nm-button");
        refresh_btn.add_css_class("nm-icon-button");
        var refresh_icon = new Gtk.Image.from_icon_name("view-refresh-symbolic");
        refresh_icon.set_pixel_size(16);
        refresh_icon.add_css_class("nm-toolbar-icon");
        refresh_icon.add_css_class("nm-refresh-icon");
        refresh_icon.add_css_class("nm-ethernet-refresh-icon");
        refresh_btn.set_child(refresh_icon);
        refresh_btn.clicked.connect(() => {
            refresh_ethernet();
        });
        toolbar.append(refresh_btn);

        page.append(toolbar);
        var toolbar_sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        toolbar_sep.add_css_class("nm-separator");
        page.append(toolbar_sep);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");

        ethernet_listbox = new Gtk.ListBox();
        ethernet_listbox.set_selection_mode(Gtk.SelectionMode.NONE);
        ethernet_listbox.add_css_class("nm-list");

        var ethernet_placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        ethernet_placeholder.set_halign(Gtk.Align.CENTER);
        ethernet_placeholder.set_valign(Gtk.Align.CENTER);
        ethernet_placeholder.add_css_class("nm-empty-state");
        var eth_icon = new Gtk.Image.from_icon_name("network-wired-symbolic");
        eth_icon.set_pixel_size(24);
        eth_icon.add_css_class("nm-placeholder-icon");
        eth_icon.add_css_class("nm-ethernet-placeholder-icon");
        var eth_lbl = new Gtk.Label("No Ethernet devices found");
        eth_lbl.add_css_class("nm-placeholder-label");
        ethernet_placeholder.append(eth_icon);
        ethernet_placeholder.append(eth_lbl);

        scroll.set_child(ethernet_listbox);

        ethernet_stack = new Gtk.Stack();
        ethernet_stack.set_vexpand(true);
        ethernet_stack.add_css_class("nm-content-stack");
        ethernet_stack.add_named(scroll, "list");
        ethernet_stack.add_named(ethernet_placeholder, "empty");
        ethernet_stack.set_visible_child_name("empty");

        page.append(ethernet_stack);
        return page;
    }

    private Gtk.ListBoxRow build_ethernet_row(NetworkDevice dev) {
        var row = new Gtk.ListBoxRow();
        row.add_css_class("nm-device-row");
        if (dev.is_connected) {
            row.add_css_class("connected");
        }

        var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
        content.set_margin_start(12);
        content.set_margin_end(8);
        content.set_margin_top(8);
        content.set_margin_bottom(8);

        var icon = new Gtk.Image.from_icon_name("network-wired-symbolic");
        icon.set_pixel_size(16);
        icon.add_css_class("nm-signal-icon");
        icon.add_css_class("nm-ethernet-icon");
        content.append(icon);

        var info = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
        info.set_hexpand(true);
        var name_lbl = new Gtk.Label(dev.name);
        name_lbl.set_xalign(0.0f);
        name_lbl.add_css_class("nm-ssid-label");
        info.append(name_lbl);

        string subtitle = dev.state_label;
        if (dev.connection != "") {
            subtitle = "%s (%s)".printf(dev.state_label, dev.connection);
        }
        var sub = new Gtk.Label(subtitle);
        sub.set_xalign(0.0f);
        sub.add_css_class("nm-sub-label");
        info.append(sub);
        content.append(info);

        var action = new Gtk.Button.with_label("Disconnect");
        action.add_css_class("nm-button");
        action.add_css_class("nm-disconnect-button");
        action.add_css_class("nm-row-action-button");
        action.set_sensitive(dev.is_connected);
        action.clicked.connect(() => {
            string error_message;
            if (!nm.disconnect_device(dev.name, out error_message)) {
                show_error("Ethernet disconnect failed: " + error_message);
            }
            refresh_after_action(false);
        });
        content.append(action);

        row.set_child(content);
        return row;
    }

    private void refresh_ethernet() {
        var devices = nm.get_devices();
        uint ethernet_count = 0;
        clear_listbox(ethernet_listbox);

        foreach (var dev in devices) {
            if (dev.is_ethernet) {
                ethernet_listbox.append(build_ethernet_row(dev));
                ethernet_count++;
            }
        }

        ethernet_stack.set_visible_child_name(ethernet_count > 0 ? "list" : "empty");
    }

    private Gtk.Widget build_vpn_page() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-vpn");

        var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        toolbar.set_margin_start(12);
        toolbar.set_margin_end(8);
        toolbar.set_margin_top(8);
        toolbar.set_margin_bottom(8);
        toolbar.add_css_class("nm-toolbar");

        var title = new Gtk.Label("VPN");
        title.set_xalign(0.0f);
        title.set_hexpand(true);
        title.add_css_class("nm-section-title");
        toolbar.append(title);

        var refresh_btn = new Gtk.Button();
        refresh_btn.add_css_class("nm-button");
        refresh_btn.add_css_class("nm-icon-button");
        var refresh_icon = new Gtk.Image.from_icon_name("view-refresh-symbolic");
        refresh_icon.set_pixel_size(16);
        refresh_icon.add_css_class("nm-toolbar-icon");
        refresh_icon.add_css_class("nm-refresh-icon");
        refresh_icon.add_css_class("nm-vpn-refresh-icon");
        refresh_btn.set_child(refresh_icon);
        refresh_btn.clicked.connect(() => {
            refresh_vpn();
        });
        toolbar.append(refresh_btn);

        page.append(toolbar);
        var toolbar_sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        toolbar_sep.add_css_class("nm-separator");
        page.append(toolbar_sep);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");

        vpn_listbox = new Gtk.ListBox();
        vpn_listbox.set_selection_mode(Gtk.SelectionMode.NONE);
        vpn_listbox.add_css_class("nm-list");

        var vpn_placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        vpn_placeholder.set_halign(Gtk.Align.CENTER);
        vpn_placeholder.set_valign(Gtk.Align.CENTER);
        vpn_placeholder.add_css_class("nm-empty-state");
        var vpn_icon = new Gtk.Image.from_icon_name("network-vpn-symbolic");
        vpn_icon.set_pixel_size(24);
        vpn_icon.add_css_class("nm-placeholder-icon");
        vpn_icon.add_css_class("nm-vpn-placeholder-icon");
        var vpn_lbl = new Gtk.Label("No VPN profiles found");
        vpn_lbl.add_css_class("nm-placeholder-label");
        vpn_placeholder.append(vpn_icon);
        vpn_placeholder.append(vpn_lbl);

        scroll.set_child(vpn_listbox);

        vpn_stack = new Gtk.Stack();
        vpn_stack.set_vexpand(true);
        vpn_stack.add_css_class("nm-content-stack");
        vpn_stack.add_named(scroll, "list");
        vpn_stack.add_named(vpn_placeholder, "empty");
        vpn_stack.set_visible_child_name("empty");

        page.append(vpn_stack);
        return page;
    }

    private Gtk.ListBoxRow build_vpn_row(VpnConnection conn) {
        var row = new Gtk.ListBoxRow();
        row.add_css_class("nm-device-row");
        if (conn.is_connected) {
            row.add_css_class("connected");
        }

        var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
        content.set_margin_start(12);
        content.set_margin_end(8);
        content.set_margin_top(8);
        content.set_margin_bottom(8);

        var icon = new Gtk.Image.from_icon_name("network-vpn-symbolic");
        icon.set_pixel_size(16);
        icon.add_css_class("nm-signal-icon");
        icon.add_css_class("nm-vpn-icon");
        content.append(icon);

        var info = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
        info.set_hexpand(true);
        var name_lbl = new Gtk.Label(conn.name);
        name_lbl.set_xalign(0.0f);
        name_lbl.add_css_class("nm-ssid-label");
        info.append(name_lbl);

        var sub = new Gtk.Label(conn.vpn_type);
        sub.set_xalign(0.0f);
        sub.add_css_class("nm-sub-label");
        info.append(sub);
        content.append(info);

        var action = new Gtk.Button.with_label(conn.is_connected ? "Disconnect" : "Connect");
        action.add_css_class("nm-button");
        action.add_css_class(conn.is_connected ? "nm-disconnect-button" : "nm-connect-button");
        action.add_css_class("nm-row-action-button");
        action.clicked.connect(() => {
            string error_message;
            bool ok;
            if (conn.is_connected) {
                ok = nm.disconnect_vpn(conn.name, out error_message);
                if (!ok) {
                    show_error("VPN disconnect failed: " + error_message);
                }
            } else {
                ok = nm.connect_vpn(conn.name, out error_message);
                if (!ok) {
                    show_error("VPN connect failed: " + error_message);
                }
            }
            refresh_after_action(false);
        });
        content.append(action);

        row.set_child(content);
        return row;
    }

    private void refresh_vpn() {
        var connections = nm.get_vpn_connections();
        clear_listbox(vpn_listbox);

        foreach (var conn in connections) {
            vpn_listbox.append(build_vpn_row(conn));
        }

        vpn_stack.set_visible_child_name(connections.length() > 0 ? "list" : "empty");
    }

    private void refresh_all() {
        refresh_wifi();
        refresh_ethernet();
        refresh_vpn();
    }

    private void refresh_after_action(bool request_wifi_scan) {
        string error_message;

        if (request_wifi_scan) {
            if (!nm.scan_wifi(out error_message)) {
                debug_log("Could not request Wi-Fi scan: " + error_message);
            }
        }

        refresh_all();

        // NetworkManager state transitions are async; refresh again shortly after actions.
        Timeout.add(650, () => {
            if (request_wifi_scan) {
                string delayed_scan_error;
                if (!nm.scan_wifi(out delayed_scan_error)) {
                    debug_log("Could not request delayed Wi-Fi scan: " + delayed_scan_error);
                }
            }
            refresh_all();
            return false;
        });

        Timeout.add(1800, () => {
            refresh_all();
            return false;
        });
    }

    private void refresh_switch_states() {
        bool wifi_enabled;
        bool net_enabled;
        string error_message;

        updating_switches = true;

        if (nm.get_wifi_enabled(out wifi_enabled, out error_message)) {
            wifi_switch.set_active(wifi_enabled);
        } else {
            debug_log("Could not read WirelessEnabled: " + error_message);
        }

        if (nm.get_networking_enabled(out net_enabled, out error_message)) {
            networking_switch.set_active(net_enabled);
        } else {
            debug_log("Could not read NetworkingEnabled: " + error_message);
        }

        updating_switches = false;
    }

    private void refresh_after_toggle(bool scan_wifi) {
        refresh_after_action(scan_wifi);
    }

    private void on_wifi_switch_changed() {
        if (updating_switches) {
            return;
        }

        string error_message;
        bool enabled = wifi_switch.get_active();
        if (!nm.set_wifi_enabled(enabled, out error_message)) {
            show_error("Could not toggle Wi-Fi: " + error_message);
            refresh_switch_states();
            return;
        }

        refresh_after_toggle(enabled);
    }

    private void on_networking_switch_changed() {
        if (updating_switches) {
            return;
        }

        string error_message;
        bool enabled = networking_switch.get_active();
        if (!nm.set_networking_enabled(enabled, out error_message)) {
            show_error("Could not toggle networking: " + error_message);
            refresh_switch_states();
            return;
        }

        refresh_after_toggle(enabled);
    }

    private void show_wifi_password_prompt(Gtk.Revealer revealer, Gtk.Entry entry) {
        if (active_wifi_password_revealer != null && active_wifi_password_revealer != revealer) {
            active_wifi_password_revealer.set_reveal_child(false);
        }

        if (active_wifi_password_entry != null && active_wifi_password_entry != entry) {
            active_wifi_password_entry.set_text("");
        }

        active_wifi_password_revealer = revealer;
        active_wifi_password_entry = entry;
        entry.set_text("");
        set_popup_text_input_mode(true);
        revealer.set_reveal_child(true);
        entry.grab_focus();
    }

    private void hide_wifi_password_prompt(Gtk.Revealer revealer, Gtk.Entry entry, string? value) {
        revealer.set_reveal_child(false);
        if (value == null) {
            entry.set_text("");
        }

        if (active_wifi_password_revealer == revealer) {
            active_wifi_password_revealer = null;
            active_wifi_password_entry = null;
            set_popup_text_input_mode(false);
        }
    }

    private void hide_active_wifi_password_prompt() {
        if (active_wifi_password_revealer != null) {
            active_wifi_password_revealer.set_reveal_child(false);
        }
        if (active_wifi_password_entry != null) {
            active_wifi_password_entry.set_text("");
        }
        active_wifi_password_revealer = null;
        active_wifi_password_entry = null;
        set_popup_text_input_mode(false);
    }

    private void show_error(string message) {
        var dialog = new Gtk.AlertDialog("Network Error");
        dialog.set_message("Network Error");
        dialog.set_detail(message);
        dialog.set_modal(true);
        dialog.show(this);
    }

    private void build_ui() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        root.add_css_class("nm-root");
        set_child(root);

        root.append(build_status_bar());
        var status_sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        status_sep.add_css_class("nm-separator");
        root.append(status_sep);

        var notebook = new Gtk.Notebook();
        notebook.set_show_border(false);
        notebook.add_css_class("nm-notebook");

        var wifi_tab = new Gtk.Label("Wi-Fi");
        wifi_tab.add_css_class("nm-tab-label");
        notebook.append_page(build_wifi_page(), wifi_tab);

        var eth_tab = new Gtk.Label("Ethernet");
        eth_tab.add_css_class("nm-tab-label");
        notebook.append_page(build_ethernet_page(), eth_tab);

        var vpn_tab = new Gtk.Label("VPN");
        vpn_tab.add_css_class("nm-tab-label");
        notebook.append_page(build_vpn_page(), vpn_tab);

        root.append(notebook);
    }
}
