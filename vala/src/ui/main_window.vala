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
    private MainWindowEthernetController ethernet_controller;
    private Gtk.ListBox vpn_listbox;
    private Gtk.Stack vpn_stack;
    private HashTable<string, bool> pending_wifi_connect;
    private HashTable<string, bool> pending_wifi_seen_connecting;
    private HashTable<string, bool> active_wifi_connections;
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
        ethernet_controller = new MainWindowEthernetController(
            nm,
            (message) => {
                show_error(message);
            },
            (request_wifi_scan) => {
                refresh_after_action(request_wifi_scan);
            },
            (enabled) => {
                set_popup_text_input_mode(enabled);
            }
        );
        pending_wifi_connect = new HashTable<string, bool>(str_hash, str_equal);
        pending_wifi_seen_connecting = new HashTable<string, bool>(str_hash, str_equal);
        active_wifi_connections = new HashTable<string, bool>(str_hash, str_equal);

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
        return MainWindowWifiPageBuilder.build_page(
            out wifi_switch,
            out wifi_listbox,
            out wifi_stack,
            build_wifi_details_page(),
            build_wifi_edit_page(),
            () => {
                refresh_wifi();
            },
            () => {
                on_wifi_switch_changed();
            }
        );
    }

    private string resolve_wifi_row_icon_name(WifiNetwork net) {
        return MainWindowHelpers.resolve_wifi_row_icon_name(net);
    }

    private void sync_wifi_edit_gateway_dns_sensitivity() {
        MainWindowWifiController.sync_edit_gateway_dns_sensitivity(
            wifi_edit_ipv4_gateway_entry,
            wifi_edit_gateway_auto_switch,
            wifi_edit_ipv4_dns_entry,
            wifi_edit_dns_auto_switch
        );
    }

    private void populate_wifi_details(WifiNetwork net) {
        MainWindowWifiController.populate_details(
            nm,
            net,
            active_wifi_connections,
            wifi_details_title,
            wifi_details_basic_rows,
            wifi_details_advanced_rows,
            wifi_details_ip_rows,
            wifi_details_action_row,
            wifi_details_forget_button,
            wifi_details_edit_button,
            (message) => {
                debug_log(message);
            }
        );
    }

    private void open_wifi_details(WifiNetwork net) {
        MainWindowWifiController.open_details(
            ref selected_wifi_network,
            net,
            wifi_stack,
            (wifi_net) => {
                populate_wifi_details(wifi_net);
            }
        );
    }

    private void open_wifi_edit(WifiNetwork net) {
        MainWindowWifiController.open_edit(
            ref selected_wifi_network,
            nm,
            net,
            wifi_edit_title,
            wifi_edit_password_entry,
            wifi_edit_note,
            wifi_edit_ipv4_method_dropdown,
            wifi_edit_ipv4_address_entry,
            wifi_edit_ipv4_prefix_entry,
            wifi_edit_gateway_auto_switch,
            wifi_edit_ipv4_gateway_entry,
            wifi_edit_dns_auto_switch,
            wifi_edit_ipv4_dns_entry,
            wifi_stack,
            () => {
                sync_wifi_edit_gateway_dns_sensitivity();
            },
            () => {
                set_popup_text_input_mode(true);
            },
            (message) => {
                debug_log(message);
            }
        );
    }

    private bool apply_wifi_edit() {
        return MainWindowWifiController.apply_edit(
            ref selected_wifi_network,
            nm,
            wifi_edit_password_entry,
            wifi_edit_ipv4_method_dropdown,
            wifi_edit_ipv4_address_entry,
            wifi_edit_gateway_auto_switch,
            wifi_edit_ipv4_gateway_entry,
            wifi_edit_dns_auto_switch,
            wifi_edit_ipv4_dns_entry,
            wifi_edit_ipv4_prefix_entry,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            (message) => {
                show_error(message);
            },
            (request_wifi_scan) => {
                refresh_after_action(request_wifi_scan);
            },
            () => {
                if (selected_wifi_network != null) {
                    open_wifi_details(selected_wifi_network);
                }
            },
            () => {
                set_popup_text_input_mode(false);
            }
        );
    }

    private Gtk.Widget build_wifi_details_page() {
        return MainWindowWifiController.build_details_page(
            out wifi_details_title,
            out wifi_details_basic_rows,
            out wifi_details_advanced_rows,
            out wifi_details_ip_rows,
            out wifi_details_action_row,
            out wifi_details_forget_button,
            out wifi_details_edit_button,
            () => {
                set_popup_text_input_mode(false);
                wifi_stack.set_visible_child_name("list");
            },
            () => {
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
            },
            () => {
                if (selected_wifi_network != null) {
                    open_wifi_edit(selected_wifi_network);
                }
            }
        );
    }

    private Gtk.Widget build_wifi_edit_page() {
        return MainWindowWifiController.build_edit_page(
            out wifi_edit_title,
            out wifi_edit_password_entry,
            out wifi_edit_note,
            out wifi_edit_ipv4_method_dropdown,
            out wifi_edit_ipv4_address_entry,
            out wifi_edit_gateway_auto_switch,
            out wifi_edit_ipv4_prefix_entry,
            out wifi_edit_dns_auto_switch,
            out wifi_edit_ipv4_gateway_entry,
            out wifi_edit_ipv4_dns_entry,
            () => {
                set_popup_text_input_mode(false);
                if (selected_wifi_network != null) {
                    open_wifi_details(selected_wifi_network);
                } else {
                    wifi_stack.set_visible_child_name("list");
                }
            },
            () => {
                apply_wifi_edit();
            },
            () => {
                sync_wifi_edit_gateway_dns_sensitivity();
            }
        );
    }

    private Gtk.ListBoxRow build_wifi_row(WifiNetwork net) {
        bool is_connected_now = active_wifi_connections.contains(net.ssid);
        bool is_connecting = pending_wifi_connect.contains(net.ssid);

        return MainWindowWifiController.build_row(
            net,
            is_connected_now,
            is_connecting,
            show_frequency,
            show_band,
            show_bssid,
            resolve_wifi_row_icon_name(net),
            (wifi_net) => {
                open_wifi_details(wifi_net);
            },
            (wifi_net) => {
                string error_message;
                if (!nm.forget_network(wifi_net.ssid, out error_message)) {
                    show_error("Forget failed: " + error_message);
                }
                refresh_after_action(true);
            },
            (wifi_net) => {
                pending_wifi_connect.remove(wifi_net.ssid);
                pending_wifi_seen_connecting.remove(wifi_net.ssid);
                string error_message;
                if (!nm.disconnect_wifi(wifi_net, out error_message)) {
                    show_error("Disconnect failed: " + error_message);
                }
                refresh_after_action(false);
            },
            (wifi_net, password) => {
                connect_wifi_with_optional_password(wifi_net, password);
            },
            (revealer, entry) => {
                show_wifi_password_prompt(revealer, entry);
            },
            (revealer, entry, value) => {
                hide_wifi_password_prompt(revealer, entry, value);
            }
        );
    }

    private void refresh_wifi() {
        MainWindowWifiController.refresh(
            nm,
            wifi_stack,
            wifi_listbox,
            status_label,
            status_icon,
            active_wifi_connections,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            ref selected_wifi_network,
            () => {
                hide_active_wifi_password_prompt();
            },
            () => {
                refresh_switch_states();
            },
            (net) => {
                return build_wifi_row(net);
            },
            (net) => {
                populate_wifi_details(net);
            },
            (message) => {
                debug_log(message);
            }
        );
    }

    private void connect_wifi_with_optional_password(WifiNetwork net, string? password) {
        MainWindowWifiController.connect_with_optional_password(
            nm,
            net,
            password,
            active_wifi_connections,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            close_on_connect,
            () => {
                this.close();
            },
            (request_wifi_scan) => {
                refresh_after_action(request_wifi_scan);
            },
            () => {
                refresh_wifi();
            },
            (message) => {
                show_error(message);
            }
        );
    }

    private void on_network_section_error(string message) {
        show_error(message);
    }

    private void on_network_section_refresh_after_action(bool request_wifi_scan) {
        refresh_after_action(request_wifi_scan);
    }

    private void refresh_ethernet_section() {
        ethernet_controller.refresh();
    }

    private void refresh_vpn_section() {
        MainWindowVpnController.refresh(
            vpn_listbox,
            vpn_stack,
            nm,
            on_network_section_error,
            on_network_section_refresh_after_action
        );
    }

    private void refresh_all() {
        refresh_wifi();
        refresh_ethernet_section();
        refresh_vpn_section();
    }

    private void refresh_after_action(bool request_wifi_scan) {
        MainWindowWifiRuntimeController.refresh_after_action(
            nm,
            request_wifi_scan,
            () => {
                refresh_all();
            },
            (message) => {
                debug_log(message);
            }
        );
    }

    private void refresh_switch_states() {
        MainWindowWifiRuntimeController.refresh_switch_states(
            nm,
            wifi_switch,
            networking_switch,
            ref updating_switches,
            (message) => {
                debug_log(message);
            }
        );
    }

    private void on_wifi_switch_changed() {
        MainWindowWifiRuntimeController.on_wifi_switch_changed(
            nm,
            wifi_switch,
            updating_switches,
            (message) => {
                show_error(message);
            },
            () => {
                refresh_switch_states();
            },
            (request_wifi_scan) => {
                refresh_after_action(request_wifi_scan);
            }
        );
    }

    private void on_networking_switch_changed() {
        MainWindowWifiRuntimeController.on_networking_switch_changed(
            nm,
            networking_switch,
            updating_switches,
            (message) => {
                show_error(message);
            },
            () => {
                refresh_switch_states();
            },
            (request_wifi_scan) => {
                refresh_after_action(request_wifi_scan);
            }
        );
    }

    private void show_wifi_password_prompt(Gtk.Revealer revealer, Gtk.Entry entry) {
        MainWindowWifiRuntimeController.show_wifi_password_prompt(
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry,
            (enabled) => {
                set_popup_text_input_mode(enabled);
            }
        );
    }

    private void hide_wifi_password_prompt(Gtk.Revealer revealer, Gtk.Entry entry, string? value) {
        MainWindowWifiRuntimeController.hide_wifi_password_prompt(
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry,
            value,
            (enabled) => {
                set_popup_text_input_mode(enabled);
            }
        );
    }

    private void hide_active_wifi_password_prompt() {
        MainWindowWifiRuntimeController.hide_active_wifi_password_prompt(
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            (enabled) => {
                set_popup_text_input_mode(enabled);
            }
        );
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
        notebook.append_page(
            ethernet_controller.build_page(),
            eth_tab
        );

        var vpn_tab = new Gtk.Label("VPN");
        vpn_tab.add_css_class("nm-tab-label");
        notebook.append_page(
            MainWindowVpnController.build_page(
                out vpn_listbox,
                out vpn_stack,
                () => {
                    refresh_vpn_section();
                }
            ),
            vpn_tab
        );

        root.append(notebook);
    }
}
