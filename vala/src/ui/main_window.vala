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
    private const int MIN_WINDOW_HEIGHT = 680;

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
    private uint pending_wifi_connect_timeout_ms;
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
    private Gtk.DropDown wifi_edit_ipv6_method_dropdown;
    private Gtk.Entry wifi_edit_ipv6_address_entry;
    private Gtk.Switch wifi_edit_ipv6_gateway_auto_switch;
    private Gtk.Entry wifi_edit_ipv6_prefix_entry;
    private Gtk.Entry wifi_edit_ipv6_gateway_entry;
    private Gtk.Entry wifi_add_ssid_entry;
    private Gtk.DropDown wifi_add_security_dropdown;
    private Gtk.Entry wifi_add_password_entry;
    private Gtk.Revealer? active_wifi_password_revealer = null;
    private Gtk.Entry? active_wifi_password_entry = null;
    private string? active_wifi_password_row_id = null;
    private MainWindowWifiController wifi_controller;
    private MainWindowEthernetController ethernet_controller;
    private MainWindowVpnController vpn_controller;
    private Gtk.ListBox vpn_listbox;
    private Gtk.Stack vpn_stack;
    private HashTable<string, bool> pending_wifi_connect;
    private HashTable<string, bool> pending_wifi_seen_connecting;
    private HashTable<string, bool> active_wifi_connections;
    private bool updating_switches = false;
    private Gtk.EventControllerKey key_controller;
    private uint periodic_refresh_source_id = 0;
    private uint signal_refresh_source_id = 0;
    private ulong nm_events_changed_handler_id = 0;
    private bool nm_events_subscription_enabled = false;

    public MainWindow(
        Gtk.Application app,
        bool debug_enabled,
        AppConfig config
    ) {
        Object(application: app, title: "Network Manager");
        this.debug_enabled = debug_enabled;
        this.window_width = config.window_width;
        this.window_height = config.window_height;
        this.anchor_top = config.anchor_top;
        this.anchor_right = config.anchor_right;
        this.anchor_bottom = config.anchor_bottom;
        this.anchor_left = config.anchor_left;
        this.shell_margin_top = config.margin_top;
        this.shell_margin_right = config.margin_right;
        this.shell_margin_bottom = config.margin_bottom;
        this.shell_margin_left = config.margin_left;
        this.shell_layer = config.layer;
        this.refresh_interval_seconds = (uint) (config.scan_interval > 0 ? config.scan_interval : 30);
        this.pending_wifi_connect_timeout_ms = (uint) (
            config.pending_wifi_connect_timeout_ms > 0 ? config.pending_wifi_connect_timeout_ms : 45000
        );
        this.close_on_connect = config.close_on_connect;
        this.show_bssid = config.show_bssid;
        this.show_frequency = config.show_frequency;
        this.show_band = config.show_band;

        int effective_width = this.window_width < MIN_WINDOW_WIDTH ? MIN_WINDOW_WIDTH : this.window_width;
        int effective_height = this.window_height < MIN_WINDOW_HEIGHT ? MIN_WINDOW_HEIGHT : this.window_height;

        set_default_size(effective_width, effective_height);
        set_size_request(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT);
        set_resizable(false);
        set_opacity(1.0);
        add_css_class("nm-window");
        nm = new NetworkManagerClientVala(debug_enabled);
        wifi_controller = new MainWindowWifiController();
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
        vpn_controller = new MainWindowVpnController(
            nm,
            (message) => {
                show_error(message);
            },
            (request_wifi_scan) => {
                refresh_after_action(request_wifi_scan);
            }
        );
        pending_wifi_connect = new HashTable<string, bool>(str_hash, str_equal);
        pending_wifi_seen_connecting = new HashTable<string, bool>(str_hash, str_equal);
        active_wifi_connections = new HashTable<string, bool>(str_hash, str_equal);

        configure_layer_shell();
        build_ui();
        configure_key_handling();
        refresh_all();
        configure_nm_signal_refresh();
        periodic_refresh_source_id = Timeout.add_seconds(refresh_interval_seconds, () => {
            nm.scan_wifi.begin(null, (obj, res) => {
                try {
                    nm.scan_wifi.end(res);
                } catch (Error e) {
                    string message = e.message;
                    debug_log("Could not request periodic Wi-Fi scan: " + message);
                }
            });

            // Keep periodic polling as a fallback when D-Bus signal subscription is unavailable.
            if (!nm_events_subscription_enabled) {
                refresh_all();
            }
            return true;
        });

        this.close_request.connect(() => {
            dispose_lifecycle_owners();
            return false;
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

    private void schedule_signal_refresh() {
        if (signal_refresh_source_id != 0) {
            return;
        }

        signal_refresh_source_id = Timeout.add(200, () => {
            signal_refresh_source_id = 0;
            refresh_all();
            return false;
        });
    }

    private void configure_nm_signal_refresh() {
        string error_message;
        nm_events_subscription_enabled = nm.subscribe_network_events(out error_message);
        if (!nm_events_subscription_enabled) {
            debug_log("Could not subscribe to NM D-Bus signals, using polling fallback: " + error_message);
            return;
        }

        nm_events_changed_handler_id = nm.network_events_changed.connect(() => {
            schedule_signal_refresh();
        });

        debug_log("NetworkManager D-Bus signal refresh enabled");
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
        bool keep_input_for_wifi_add = wifi_stack != null
            && wifi_stack.get_visible_child_name() == "add";
        bool keep_input_for_inline_prompt = active_wifi_password_revealer != null
            && active_wifi_password_revealer.get_reveal_child();

        if (keep_input_for_wifi_edit || keep_input_for_wifi_add || keep_input_for_inline_prompt) {
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
            build_wifi_add_page(),
            () => {
                refresh_wifi();
            },
            () => {
                wifi_controller.open_add_network(
                    wifi_stack,
                    wifi_add_ssid_entry,
                    wifi_add_security_dropdown,
                    wifi_add_password_entry,
                    (enabled) => {
                        set_popup_text_input_mode(enabled);
                    }
                );
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
        if (wifi_edit_ipv4_method_dropdown == null
            || wifi_edit_ipv4_gateway_entry == null
            || wifi_edit_gateway_auto_switch == null
            || wifi_edit_ipv4_dns_entry == null
            || wifi_edit_dns_auto_switch == null
            || wifi_edit_ipv6_method_dropdown == null
            || wifi_edit_ipv6_gateway_entry == null
            || wifi_edit_ipv6_gateway_auto_switch == null) {
            return;
        }

        wifi_controller.sync_edit_gateway_dns_sensitivity(
            wifi_edit_ipv4_method_dropdown,
            wifi_edit_ipv4_gateway_entry,
            wifi_edit_gateway_auto_switch,
            wifi_edit_ipv4_dns_entry,
            wifi_edit_dns_auto_switch,
            wifi_edit_ipv6_method_dropdown,
            wifi_edit_ipv6_gateway_entry,
            wifi_edit_ipv6_gateway_auto_switch
        );
    }

    private void populate_wifi_details(WifiNetwork net) {
        wifi_controller.populate_details(
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
        wifi_controller.open_details(
            ref selected_wifi_network,
            net,
            wifi_stack,
            (wifi_net) => {
                populate_wifi_details(wifi_net);
            }
        );
    }

    private void open_wifi_edit(WifiNetwork net) {
        wifi_controller.open_edit(
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
            wifi_edit_ipv6_method_dropdown,
            wifi_edit_ipv6_address_entry,
            wifi_edit_ipv6_prefix_entry,
            wifi_edit_ipv6_gateway_auto_switch,
            wifi_edit_ipv6_gateway_entry,
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
        return wifi_controller.apply_edit(
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
            wifi_edit_ipv6_method_dropdown,
            wifi_edit_ipv6_address_entry,
            wifi_edit_ipv6_gateway_entry,
            wifi_edit_ipv6_gateway_auto_switch,
            wifi_edit_ipv6_prefix_entry,
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
        var nm_client = nm;
        return wifi_controller.build_details_page(
            out wifi_details_title,
            out wifi_details_basic_rows,
            out wifi_details_advanced_rows,
            out wifi_details_ip_rows,
            out wifi_details_action_row,
            out wifi_details_forget_button,
            out wifi_details_edit_button,
            () => {
                selected_wifi_network = null;
                set_popup_text_input_mode(false);
                wifi_stack.set_visible_child_name("list");
            },
            () => {
                if (selected_wifi_network == null) {
                    return;
                }

                string profile_uuid = selected_wifi_network.saved_connection_uuid.strip();
                string network_key = selected_wifi_network.network_key;

                nm_client.forget_network.begin(profile_uuid, network_key, null, (obj, res) => {
                    try {
                        nm_client.forget_network.end(res);
                        refresh_after_action(true);
                        wifi_stack.set_visible_child_name("list");
                    } catch (Error e) {
                        show_error("Forget failed: " + e.message);
                    }
                });
            },
            () => {
                if (selected_wifi_network != null) {
                    open_wifi_edit(selected_wifi_network);
                }
            }
        );
    }

    private Gtk.Widget build_wifi_edit_page() {
        return wifi_controller.build_edit_page(
            out wifi_edit_title,
            out wifi_edit_password_entry,
            out wifi_edit_note,
            out wifi_edit_ipv4_method_dropdown,
            out wifi_edit_ipv4_address_entry,
            out wifi_edit_gateway_auto_switch,
            out wifi_edit_ipv4_prefix_entry,
            out wifi_edit_ipv4_gateway_entry,
            out wifi_edit_dns_auto_switch,
            out wifi_edit_ipv4_dns_entry,
            out wifi_edit_ipv6_method_dropdown,
            out wifi_edit_ipv6_address_entry,
            out wifi_edit_ipv6_gateway_auto_switch,
            out wifi_edit_ipv6_prefix_entry,
            out wifi_edit_ipv6_gateway_entry,
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

    private Gtk.Widget build_wifi_add_page() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        page.set_margin_start(12);
        page.set_margin_end(12);
        page.set_margin_top(12);
        page.set_margin_bottom(12);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-wifi-add");
        page.add_css_class("nm-page-network-edit");

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var back_btn = MainWindowHelpers.build_back_button(() => {
            set_popup_text_input_mode(false);
            wifi_stack.set_visible_child_name("list");
        });
        header.append(back_btn);

        var title = new Gtk.Label("Add Hidden Network");
        title.set_xalign(0.0f);
        title.set_hexpand(true);
        title.add_css_class("nm-section-title");
        header.append(title);
        page.append(header);

        var form = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        form.add_css_class("nm-edit-form");
        form.add_css_class("nm-edit-network-form");

        var note = new Gtk.Label("Manually add a hidden Wi-Fi network.");
        note.set_xalign(0.0f);
        note.set_wrap(true);
        note.add_css_class("nm-sub-label");
        note.add_css_class("nm-edit-note");
        form.append(note);

        var ssid_label = new Gtk.Label("SSID");
        ssid_label.set_xalign(0.0f);
        ssid_label.add_css_class("nm-form-label");
        ssid_label.add_css_class("nm-edit-field-label");
        form.append(ssid_label);

        wifi_add_ssid_entry = new Gtk.Entry();
        wifi_add_ssid_entry.set_placeholder_text("Network name");
        wifi_add_ssid_entry.add_css_class("nm-edit-field-control");
        wifi_add_ssid_entry.add_css_class("nm-edit-field-entry");
        form.append(wifi_add_ssid_entry);

        var security_label = new Gtk.Label("Security");
        security_label.set_xalign(0.0f);
        security_label.add_css_class("nm-form-label");
        security_label.add_css_class("nm-edit-field-label");
        form.append(security_label);

        var security_list = new Gtk.StringList(null);
        foreach (string label in HiddenWifiSecurityModeUtils.get_dropdown_labels()) {
            security_list.append(label);
        }
        wifi_add_security_dropdown = new Gtk.DropDown(security_list, null);
        wifi_add_security_dropdown.add_css_class("nm-edit-field-control");
        wifi_add_security_dropdown.add_css_class("nm-edit-dropdown");
        wifi_add_security_dropdown.set_selected(
            HiddenWifiSecurityModeUtils.to_dropdown_index(HiddenWifiSecurityMode.WPA_PSK)
        );

        var save_btn = new Gtk.Button.with_label("Connect");
        save_btn.add_css_class("nm-button");
        save_btn.add_css_class("suggested-action");

        wifi_add_security_dropdown.notify["selected"].connect(() => {
            wifi_controller.sync_add_network_sensitivity(
                wifi_add_security_dropdown,
                wifi_add_password_entry,
                save_btn
            );
        });
        form.append(wifi_add_security_dropdown);

        var password_label = new Gtk.Label("Password");
        password_label.set_xalign(0.0f);
        password_label.add_css_class("nm-form-label");
        password_label.add_css_class("nm-edit-field-label");
        form.append(password_label);

        wifi_add_password_entry = new Gtk.Entry();
        wifi_add_password_entry.set_visibility(false);
        wifi_add_password_entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
        wifi_add_password_entry.set_placeholder_text(
            "Network password (min %d chars)".printf(HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH)
        );
        wifi_add_password_entry.add_css_class("nm-password-entry");
        wifi_add_password_entry.add_css_class("nm-edit-field-control");
        wifi_add_password_entry.add_css_class("nm-edit-field-entry");
        wifi_add_password_entry.changed.connect(() => {
            wifi_controller.sync_add_network_sensitivity(
                wifi_add_security_dropdown,
                wifi_add_password_entry,
                save_btn
            );
        });
        wifi_add_password_entry.activate.connect(() => {
            if (!save_btn.get_sensitive()) {
                return;
            }
            wifi_controller.apply_add_network(
                nm,
                wifi_stack,
                wifi_add_ssid_entry,
                wifi_add_security_dropdown,
                wifi_add_password_entry,
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
        });
        form.append(wifi_add_password_entry);

        wifi_controller.sync_add_network_sensitivity(
            wifi_add_security_dropdown,
            wifi_add_password_entry,
            save_btn
        );

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        actions.add_css_class("nm-edit-actions");

        save_btn.clicked.connect(() => {
            wifi_controller.apply_add_network(
                nm,
                wifi_stack,
                wifi_add_ssid_entry,
                wifi_add_security_dropdown,
                wifi_add_password_entry,
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
        });
        actions.append(save_btn);

        form.append(actions);

        page.append(form);
        return page;
    }

    private Gtk.ListBoxRow build_wifi_row(WifiNetwork net) {
        var nm_client = nm;
        var wifi_controller_ref = wifi_controller;
        var active_connections_ref = active_wifi_connections;
        var pending_connect_ref = pending_wifi_connect;
        var pending_seen_connecting_ref = pending_wifi_seen_connecting;
        uint pending_timeout_ms = pending_wifi_connect_timeout_ms;
        bool should_close_on_connect = close_on_connect;
        string net_key = net.network_key;
        bool is_connected_now = active_wifi_connections.contains(net_key);
        bool is_connecting = pending_wifi_connect.contains(net_key);

        return wifi_controller.build_row(
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
                string profile_uuid = wifi_net.saved_connection_uuid.strip();
                string network_key = wifi_net.network_key;

                nm_client.forget_network.begin(profile_uuid, network_key, null, (obj, res) => {
                    try {
                        nm_client.forget_network.end(res);
                        refresh_after_action(true);
                    } catch (Error e) {
                        show_error("Forget failed: " + e.message);
                    }
                });
            },
            (wifi_net) => {
                string wifi_key = wifi_net.network_key;
                pending_wifi_connect.remove(wifi_key);
                pending_wifi_seen_connecting.remove(wifi_key);
                nm_client.disconnect_wifi.begin(wifi_net, null, (obj, res) => {
                    try {
                        nm_client.disconnect_wifi.end(res);
                        refresh_after_action(false);
                    } catch (Error e) {
                        show_error("Disconnect failed: " + e.message);
                        refresh_after_action(false);
                    }
                });
            },
            (wifi_net, password) => {
                wifi_controller_ref.connect_with_optional_password(
                    nm_client,
                    wifi_net,
                    password,
                    active_connections_ref,
                    pending_connect_ref,
                    pending_seen_connecting_ref,
                    pending_timeout_ms,
                    should_close_on_connect,
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
            },
            (revealer, entry) => {
                active_wifi_password_row_id = get_wifi_row_id(net);
                show_wifi_password_prompt(revealer, entry);
            },
            (revealer, entry, value) => {
                hide_wifi_password_prompt(revealer, entry, value);
            }
        );
    }

    private string get_wifi_row_id(WifiNetwork net) {
        return "%s|%s".printf(net.device_path, net.ap_path);
    }

    private void refresh_wifi() {
        bool has_active_prompt_open = active_wifi_password_revealer != null
            && active_wifi_password_revealer.get_reveal_child();

        wifi_controller.refresh(
            nm,
            wifi_stack,
            wifi_listbox,
            status_label,
            status_icon,
            active_wifi_connections,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            active_wifi_password_row_id,
            has_active_prompt_open,
            () => {
                hide_active_wifi_password_prompt();
            },
            () => {
                refresh_switch_states();
            },
            (net) => {
                return build_wifi_row(net);
            },
            (message) => {
                debug_log(message);
            }
        );
    }

    private void connect_wifi_with_optional_password(WifiNetwork net, string? password) {
        wifi_controller.connect_with_optional_password(
            nm,
            net,
            password,
            active_wifi_connections,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            pending_wifi_connect_timeout_ms,
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

    private void refresh_ethernet_section() {
        ethernet_controller.refresh();
    }

    private void refresh_vpn_section() {
        vpn_controller.refresh();
    }

    private void refresh_all() {
        refresh_wifi();
        refresh_ethernet_section();
        refresh_vpn_section();
    }

    private void refresh_after_action(bool request_wifi_scan) {
        wifi_controller.refresh_after_action(
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
        wifi_controller.refresh_switch_states(
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
        wifi_controller.on_wifi_switch_changed(
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
        wifi_controller.on_networking_switch_changed(
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
        wifi_controller.show_wifi_password_prompt(
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
        wifi_controller.hide_wifi_password_prompt(
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry,
            value,
            (enabled) => {
                set_popup_text_input_mode(enabled);
            }
        );

        if (active_wifi_password_revealer == null) {
            active_wifi_password_row_id = null;
        }
    }

    private void hide_active_wifi_password_prompt() {
        wifi_controller.hide_active_wifi_password_prompt(
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            (enabled) => {
                set_popup_text_input_mode(enabled);
            }
        );
        active_wifi_password_row_id = null;
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
        notebook.switch_page.connect((page, page_num) => {
            if (page_num != 0) {
                wifi_controller.on_page_leave();
            }
            if (page_num != 1) {
                ethernet_controller.on_page_leave();
            }
            if (page_num != 2) {
                vpn_controller.on_page_leave();
            }
        });

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
            vpn_controller.build_page(
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

    private void dispose_lifecycle_owners() {
        if (signal_refresh_source_id != 0) {
            Source.remove(signal_refresh_source_id);
            signal_refresh_source_id = 0;
        }

        if (nm_events_changed_handler_id != 0) {
            SignalHandler.disconnect(nm, nm_events_changed_handler_id);
            nm_events_changed_handler_id = 0;
        }

        nm.unsubscribe_network_events();
        nm_events_subscription_enabled = false;

        if (periodic_refresh_source_id != 0) {
            Source.remove(periodic_refresh_source_id);
            periodic_refresh_source_id = 0;
        }
        wifi_controller.dispose_controller();
        ethernet_controller.dispose_controller();
        vpn_controller.dispose_controller();
    }

    ~MainWindow() {
        dispose_lifecycle_owners();
    }
}
