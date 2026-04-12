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
using NetworkManagerRebuild.UI.Interfaces;
using NetworkManagerRebuild.Models;

public class MainWindow : Gtk.ApplicationWindow, IWindowHost {
    private const int MIN_WINDOW_WIDTH = 480;
    private const int MIN_WINDOW_HEIGHT = 680;

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
    private NetworkManagerClient nm;
    private Gtk.Widget status_bar;
    private Gtk.Widget status_separator;
    private Gtk.Label status_label;
    private Gtk.Image status_icon;
    private Gtk.Switch networking_switch;
    private Gtk.Switch wifi_switch;
    private Gtk.ListBox wifi_listbox;
    private Gtk.Stack wifi_stack;
    private NetworkManagerRebuild.UI.Views.EthernetSectionView ethernet_section;
    private WifiNetwork? selected_wifi_network = null;
    private MainWindowProfileAdapter? wifi_saved_flow = null;
    private MainWindowWifiDetailsPage wifi_details_page;
    private MainWindowWifiEditPage wifi_edit_page;
    private MainWindowProfilesPage profiles_page;
    private MainWindowProfilesDetailsPage profiles_details_page;
    private MainWindowWifiSavedEditPage wifi_saved_edit_page;
    private Gtk.Stack profiles_stack;
    private WifiSavedProfile? selected_saved_wifi_profile = null;
    private NetworkDevice? selected_saved_ethernet_profile = null;
    private Gtk.Entry wifi_add_ssid_entry;
    private Gtk.DropDown wifi_add_security_dropdown;
    private Gtk.Entry wifi_add_password_entry;
    private Gtk.Revealer? active_wifi_password_revealer = null;
    private Gtk.Entry? active_wifi_password_entry = null;
    private string? active_wifi_password_row_id = null;
    private MainWindowWifiController wifi_controller;
    private MainWindowRefreshCoordinator refresh_coordinator;
    private MainWindowEthernetController ethernet_controller;
    private MainWindowVpnController vpn_controller;
    private NetworkManagerRebuild.UI.Views.VpnSectionView vpn_section;
    private Gtk.Stack content_stack;
    private Gtk.Notebook notebook;
    private HashTable<string, bool> pending_wifi_connect;
    private HashTable<string, bool> pending_wifi_seen_connecting;
    private HashTable<string, bool> active_wifi_connections;
    private Gtk.EventControllerKey key_controller;
    private bool layer_shell_active = false;
    private NetworkStateContext state_context;
    private NetworkManagerRebuild.UI.Views.AppContentNavigationManager nav_manager;

    public MainWindow (
        Gtk.Application app,
        AppConfig config
    ) throws Error {
        Object (application: app, title: "Network Manager");
        this.state_context = new NetworkStateContext();
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

        set_default_size (effective_width, effective_height);
        set_size_request (MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT);
        set_resizable (false);
        set_opacity (MainWindowUiMetrics.WINDOW_OPACITY);
        add_css_class ("nm-window");
        nm = new NetworkManagerClient ();
        wifi_controller = new MainWindowWifiController (this, state_context);
        ethernet_controller = new MainWindowEthernetController (
            nm,
            this,
            state_context
        );
        vpn_controller = new MainWindowVpnController (
            nm,
            this,
            state_context
        );
        refresh_coordinator = new MainWindowRefreshCoordinator (
            nm,
            wifi_controller,
            refresh_interval_seconds,
            () => {
                refresh_all ();
            },
            (message) => {
                debug_log (message);
            }
        );
        pending_wifi_connect = new HashTable<string, bool> (str_hash, str_equal);
        pending_wifi_seen_connecting = new HashTable<string, bool> (str_hash, str_equal);
        active_wifi_connections = new HashTable<string, bool> (str_hash, str_equal);

        layer_shell_active = configure_layer_shell ();
        if (!layer_shell_active) {
            configure_regular_window_fallback ();
        }
        log_info ("gui", "window_init: starting");
        build_ui ();
        configure_key_handling ();
        refresh_all ();
        refresh_coordinator.start ();

        this.map.connect (() => {
            refresh_coordinator.start ();
        });

        this.unmap.connect (() => {
            refresh_coordinator.stop ();
        });

        log_info ("gui", "window_init: completed");
    }

    public void debug_log (string message) {
        log_debug ("gui", message);
    }

    private bool configure_layer_shell () {
        GtkLayerShell.Layer layer_mode = parse_layer_mode (shell_layer);

        if (!GtkLayerShell.is_supported ()) {
            log_warn (
                "gui",
                "layer_shell_init: unsupported in current session; outcome=using regular window"
            );
            return false;
        }

        GtkLayerShell.init_for_window (this);
        if (!GtkLayerShell.is_layer_window (this)) {
            log_error (
                "gui",
                "layer_shell_init: failed to create layer surface; outcome=using regular window"
            );
            return false;
        }

        GtkLayerShell.set_namespace (this, "hypr-network-manager");
        GtkLayerShell.set_layer (this, layer_mode);

        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, anchor_top);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, anchor_right);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, anchor_bottom);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, anchor_left);
        GtkLayerShell.set_margin (this, GtkLayerShell.Edge.TOP, shell_margin_top);
        GtkLayerShell.set_margin (this, GtkLayerShell.Edge.RIGHT, shell_margin_right);
        GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, shell_margin_bottom);
        GtkLayerShell.set_margin (this, GtkLayerShell.Edge.LEFT, shell_margin_left);

        GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.ON_DEMAND);
        GtkLayerShell.auto_exclusive_zone_enable (this);
        return true;
    }

    private void configure_regular_window_fallback () {
        log_warn (
            "gui",
            "layer_shell_fallback: enabled; outcome=placement/exclusive-zone constraints disabled"
        );

        // Keep the fallback window above most windows to mimic popup behavior.
        this.set_modal (true);
    }

    private GtkLayerShell.Layer parse_layer_mode (string value) {
        switch (value.strip ().down ()) {
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

    private void configure_key_handling () {
        key_controller = new Gtk.EventControllerKey ();
        key_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
        ((Gtk.Widget) this).add_controller (key_controller);
        key_controller.key_pressed.connect (key_press_event_cb);
    }

    private bool key_press_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
        // Keep text entry usable (for Wi-Fi password prompts), but still allow Esc to close.
        if (get_focus () is Gtk.Editable) {
            if (Gdk.keyval_name (keyval) == "Escape") {
                this.close ();
                return true;
            }
            return false;
        }

        switch (Gdk.keyval_name (keyval)) {
        case "Escape":
            this.close ();
            return true;
        default:
            break;
        }

        return false;
    }

    public void set_popup_text_input_mode (bool enabled) {
        if (!layer_shell_active) {
            return;
        }

        if (enabled) {
            GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.ON_DEMAND);
            return;
        }

        bool keep_input_for_wifi_edit = wifi_stack != null
            && wifi_stack.get_visible_child_name () == "edit";
        bool keep_input_for_saved_wifi_edit = wifi_stack != null
            && wifi_stack.get_visible_child_name () == "saved-edit";
        bool keep_input_for_wifi_add = wifi_stack != null
            && wifi_stack.get_visible_child_name () == "add";
        bool keep_input_for_inline_prompt = active_wifi_password_revealer != null
            && active_wifi_password_revealer.get_reveal_child ();

        if (keep_input_for_wifi_edit || keep_input_for_saved_wifi_edit || keep_input_for_wifi_add ||
            keep_input_for_inline_prompt) {
            GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.ON_DEMAND);
            return;
        }

        GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.NONE);
    }

    private Gtk.Widget build_status_bar () {
        var view = new NetworkManagerRebuild.UI.Views.StatusBarView ();
        status_icon = view.status_icon;
        status_label = view.status_label;
        networking_switch = view.networking_switch;
        
        view.networking_switch_toggled.connect (() => {
            on_networking_switch_changed ();
        });

        return view.root_widget;
    }

    private Gtk.Widget build_wifi_page () {
        var page = MainWindowWifiPageBuilder.build_page (
            out wifi_switch,
            out wifi_listbox,
            out wifi_stack,
            build_wifi_details_page (),
            build_wifi_edit_page (),
            build_wifi_add_page (),
            refresh_wifi,
            () => {
                wifi_controller.open_add_network (
                    wifi_stack,
                    wifi_add_ssid_entry,
                    wifi_add_security_dropdown,
                    wifi_add_password_entry
                );
            },
            () => {
                on_wifi_switch_changed ();
            }
        );

        wifi_saved_flow = new MainWindowProfileAdapter (
            nm,
            wifi_controller,
            profiles_stack,
            profiles_page,
            wifi_saved_edit_page,
            this,
            this.state_context
        );

        return page;
    }

    private void submit_add_hidden_network () {
        wifi_controller.apply_add_network (
            nm,
            wifi_stack,
            wifi_add_ssid_entry,
            wifi_add_security_dropdown,
            wifi_add_password_entry
        );
    }


    private void update_main_chrome_visibility (bool focus_mode) {
        if (status_bar != null) {
            status_bar.set_visible (!focus_mode);
        }
        if (status_separator != null) {
            status_separator.set_visible (!focus_mode);
        }
        if (notebook != null) {
            notebook.set_show_tabs (!focus_mode);
        }
    }

    private string resolve_wifi_row_icon_name (WifiNetwork net) {
        return MainWindowHelpers.resolve_wifi_row_icon_name (net);
    }

    private void sync_wifi_edit_gateway_dns_sensitivity () {
        if (wifi_edit_page == null) return;
        wifi_controller.sync_edit_gateway_dns_sensitivity (
            wifi_edit_page.ipv4_method_dropdown,
            wifi_edit_page.ipv4_gateway_entry,
            wifi_edit_page.ipv4_dns_entry,
            wifi_edit_page.dns_auto_switch,
            wifi_edit_page.ipv6_method_dropdown,
            wifi_edit_page.ipv6_gateway_entry,
            wifi_edit_page.ipv6_dns_entry,
            wifi_edit_page.ipv6_dns_auto_switch
        );
    }

    private void populate_wifi_details (WifiNetwork net) {
        wifi_controller.populate_details (
            nm,
            net,
            wifi_details_page
        );
    }

    private void open_wifi_details (WifiNetwork net) {
        wifi_controller.open_details (
            ref selected_wifi_network,
            net,
            wifi_stack,
            (wifi_net) => {
                populate_wifi_details (wifi_net);
            }
        );
    }

    private void open_wifi_edit (WifiNetwork net) {
        wifi_controller.open_edit (
            ref selected_wifi_network,
            nm,
            net,
            wifi_edit_page,
            wifi_stack,
            sync_wifi_edit_gateway_dns_sensitivity
        );
    }

    private bool apply_wifi_edit (bool close_after_apply) {
        return wifi_controller.apply_edit (
            ref selected_wifi_network,
            nm,
            wifi_edit_page,
            close_after_apply,
            () => {
                if (selected_wifi_network != null) {
                    open_wifi_details (selected_wifi_network);
                }
            }
        );
    }

    private void forget_wifi_network (WifiNetwork net, MainWindowActionCallback? on_done = null) {
        wifi_controller.forget_wifi_network (
            nm,
            net
        );
        if (on_done != null) {
            on_done ();
        }
    }

    private void disconnect_wifi_network (WifiNetwork net) {
        wifi_controller.disconnect_wifi_network (
            nm,
            net
        );
    }

    private Gtk.Widget build_wifi_details_page () {
        wifi_details_page = new MainWindowWifiDetailsPage ();

        wifi_details_page.back.connect (() => {
            selected_wifi_network = null;
            set_popup_text_input_mode (false);
            wifi_stack.set_visible_child_name ("list");
        });

        wifi_details_page.forget.connect (() => {
            if (selected_wifi_network == null) return;
            forget_wifi_network (selected_wifi_network, () => {
                wifi_stack.set_visible_child_name ("list");
            });
        });

        wifi_details_page.edit.connect (() => {
            if (selected_wifi_network != null) {
                open_wifi_edit (selected_wifi_network);
            }
        });

        return wifi_details_page;
    }

    private Gtk.Widget build_wifi_edit_page () {
        wifi_edit_page = new MainWindowWifiEditPage ();

        wifi_edit_page.back.connect (() => {
            set_popup_text_input_mode (false);
            if (selected_wifi_network != null) {
                open_wifi_details (selected_wifi_network);
            } else {
                wifi_stack.set_visible_child_name ("list");
            }
        });

        wifi_edit_page.apply.connect (() => {
            apply_wifi_edit (false);
        });

        wifi_edit_page.ok.connect (() => {
            apply_wifi_edit (true);
        });

        wifi_edit_page.sync_sensitivity.connect (sync_wifi_edit_gateway_dns_sensitivity);

        return wifi_edit_page;
    }

    private Gtk.Widget build_wifi_add_page () {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_ROW);
        page.add_css_class ("nm-page");
        page.add_css_class ("nm-page-shell-inset");
        MainWindowCssClassResolver.add_best_class (page, {"nm-page-shell-inset", "nm-page"});
        MainWindowCssClassResolver.add_hook_and_best_class (
            page,
            "nm-page-wifi-add",
            {"nm-page-network-edit", "nm-page"}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button (() => {
            set_popup_text_input_mode (false);
            wifi_stack.set_visible_child_name ("list");
        });
        header.append (back_btn);

        var title = new Gtk.Label ("Add Hidden Network");
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class ("nm-section-title");
        header.append (title);
        page.append (header);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        MainWindowCssClassResolver.add_best_class (form, {"nm-edit-network-form", "nm-edit-form"});
        form.add_css_class ("nm-details-scroll-body-inset");

        var note = new Gtk.Label ("Manually add a hidden Wi-Fi network.");
        note.set_xalign (0.0f);
        note.set_wrap (true);
        MainWindowCssClassResolver.add_best_class (note, {"nm-edit-note", "nm-sub-label"});
        form.append (note);

        var ssid_label = new Gtk.Label ("SSID");
        ssid_label.set_xalign (0.0f);
        MainWindowCssClassResolver.add_best_class (ssid_label, {"nm-edit-field-label", "nm-form-label"});
        form.append (ssid_label);

        wifi_add_ssid_entry = new Gtk.Entry ();
        wifi_add_ssid_entry.set_placeholder_text ("Network name");
        MainWindowCssClassResolver.add_best_class (
            wifi_add_ssid_entry,
            {"nm-edit-field-entry", "nm-edit-field-control"}
        );
        form.append (wifi_add_ssid_entry);

        var security_label = new Gtk.Label ("Security");
        security_label.set_xalign (0.0f);
        MainWindowCssClassResolver.add_best_class (security_label, {"nm-edit-field-label", "nm-form-label"});
        form.append (security_label);

        var security_list = new Gtk.StringList (null);
        foreach (string label in HiddenWifiSecurityModeUtils.get_dropdown_labels ()) {
            security_list.append (label);
        }
        wifi_add_security_dropdown = new Gtk.DropDown (security_list, null);
        MainWindowCssClassResolver.add_best_class (
            wifi_add_security_dropdown,
            {"nm-edit-dropdown", "nm-edit-field-control"}
        );
        wifi_add_security_dropdown.set_selected (
            HiddenWifiSecurityModeUtils.to_dropdown_index (HiddenWifiSecurityMode.WPA_PSK)
        );

        var save_btn = new Gtk.Button.with_label ("Connect");
        save_btn.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (save_btn, {"suggested-action", "nm-button"});

        wifi_add_security_dropdown.notify["selected"].connect (() => {
            wifi_controller.sync_add_network_sensitivity (
                wifi_add_security_dropdown,
                wifi_add_password_entry,
                save_btn
            );
        });
        form.append (wifi_add_security_dropdown);

        var password_label = new Gtk.Label ("Password");
        password_label.set_xalign (0.0f);
        MainWindowCssClassResolver.add_best_class (
            password_label,
            {"nm-edit-field-label", "nm-form-label"}
        );
        form.append (password_label);

        wifi_add_password_entry = new Gtk.Entry ();
        wifi_add_password_entry.set_visibility (false);
        wifi_add_password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        wifi_add_password_entry.set_placeholder_text (
            "Network password (min %d chars)".printf (HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH)
        );
        MainWindowCssClassResolver.add_best_class (
            wifi_add_password_entry,
            {"nm-edit-field-entry", "nm-edit-field-control", "nm-password-entry"}
        );
        wifi_add_password_entry.changed.connect (() => {
            wifi_controller.sync_add_network_sensitivity (
                wifi_add_security_dropdown,
                wifi_add_password_entry,
                save_btn
            );
        });
        wifi_add_password_entry.activate.connect (() => {
            if (!save_btn.get_sensitive ()) {
                return;
            }
            submit_add_hidden_network ();
        });
        form.append (wifi_add_password_entry);

        wifi_controller.sync_add_network_sensitivity (
            wifi_add_security_dropdown,
            wifi_add_password_entry,
            save_btn
        );

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        actions.add_css_class ("nm-edit-actions");

        save_btn.clicked.connect (submit_add_hidden_network);
        actions.append (save_btn);

        form.append (actions);

        page.append (form);
        return page;
    }

    private void sync_saved_wifi_edit_gateway_dns_sensitivity () {
        if (wifi_saved_flow == null) {
            return;
        }
        wifi_saved_flow.on_sync_sensitivity_requested ();
    }

    private Gtk.Widget build_profiles_root_page () {
        profiles_page = new MainWindowProfilesPage ();
        profiles_details_page = new MainWindowProfilesDetailsPage ();
        wifi_saved_edit_page = new MainWindowWifiSavedEditPage ();

        profiles_stack = new Gtk.Stack ();
        profiles_stack.set_vexpand (true);
        profiles_stack.add_css_class ("nm-content-stack");
        profiles_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        profiles_stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);
        profiles_stack.add_named (profiles_page, "list");
        profiles_stack.add_named (profiles_details_page, "details");
        profiles_stack.add_named (wifi_saved_edit_page, "edit");
        profiles_stack.set_visible_child_name ("list");

        wire_profiles_page_signals ();
        wire_profiles_details_page_signals ();
        wire_profiles_edit_page_signals ();

        return profiles_stack;
    }

    private void wire_profiles_page_signals () {
        profiles_page.back.connect (() => {
            content_stack.set_visible_child_name ("main");
            wifi_stack.set_visible_child_name ("list");
            set_popup_text_input_mode (false);
        });

        profiles_page.refresh.connect (refresh_saved_profiles);

        profiles_page.open_profile.connect (open_saved_wifi_profile_details);

        profiles_page.delete_profile.connect ((net) => {
            if (wifi_saved_flow != null) {
                wifi_saved_flow.delete_profile (net);
            }
        });

        profiles_page.open_ethernet_profile.connect (open_saved_ethernet_profile_details);
    }

    private void wire_profiles_details_page_signals () {
        profiles_details_page.back.connect (() => {
            profiles_stack.set_visible_child_name ("list");
            profiles_page.restore_scroll_position ();
        });

        profiles_details_page.edit.connect (() => {
            if (selected_saved_wifi_profile != null) {
                open_saved_wifi_edit (selected_saved_wifi_profile);
                return;
            }

            if (selected_saved_ethernet_profile != null) {
                var selected_dev = selected_saved_ethernet_profile;
                notebook.set_current_page (1);
                content_stack.set_visible_child_name ("main");
                ethernet_controller.open_profile_edit (selected_dev, () => {
                    content_stack.set_visible_child_name ("profiles");
                    profiles_stack.set_visible_child_name ("list");
                    profiles_page.restore_scroll_position ();
                    set_popup_text_input_mode (false);
                });
            }
        });

        profiles_details_page.delete_profile.connect (() => {
            if (selected_saved_wifi_profile != null && wifi_saved_flow != null) {
                var selected_profile = selected_saved_wifi_profile;
                wifi_saved_flow.delete_profile (selected_profile);
                profiles_stack.set_visible_child_name ("list");
                profiles_page.restore_scroll_position ();
            }
        });
    }

    private void wire_profiles_edit_page_signals () {
        wifi_saved_edit_page.back.connect (() => {
            if (wifi_saved_flow != null) {
                wifi_saved_flow.on_saved_edit_back ();
            }
            profiles_page.restore_scroll_position ();
        });

        wifi_saved_edit_page.save.connect (() => {
            apply_saved_wifi_edit ();
        });

        wifi_saved_edit_page.sync_sensitivity.connect (() => {
            sync_saved_wifi_edit_gateway_dns_sensitivity ();
        });
    }

    private bool has_ethernet_profile (NetworkDevice dev) {
        return nm.has_ethernet_profile_for_device (dev);
    }

    private void refresh_saved_ethernet_profiles () {
        if (profiles_page == null) {
            return;
        }

        nm.get_devices.begin (null, (obj, res) => {
            try {
                var devices = nm.get_devices.end (res);
                var ethernet_profiles = new List<NetworkDevice> ();
                foreach (var dev in devices) {
                    if (!dev.is_ethernet || !has_ethernet_profile (dev)) {
                        continue;
                    }
                    ethernet_profiles.append (dev);
                }

                var ethernet_profiles_arr = new NetworkDevice[ethernet_profiles.length ()];
                int idx = 0;
                foreach (var dev in ethernet_profiles) {
                    ethernet_profiles_arr[idx++] = dev;
                }
                profiles_page.set_ethernet_profiles (ethernet_profiles_arr);
            } catch (Error e) {
                show_error ("Could not load ethernet profiles: " + e.message);
            }
        });
    }

    private void refresh_saved_networks () {
        if (wifi_saved_flow != null) {
            wifi_saved_flow.refresh_saved_networks ();
        }
    }

    private void refresh_saved_profiles () {
        refresh_saved_networks ();
        refresh_saved_ethernet_profiles ();
    }

    private void open_profiles_page (bool focus_ethernet_section = false) {
        content_stack.set_visible_child_name ("profiles");
        selected_saved_wifi_profile = null;
        selected_saved_ethernet_profile = null;
        refresh_saved_profiles ();
        profiles_stack.set_visible_child_name ("list");
        if (focus_ethernet_section) {
            profiles_page.focus_ethernet_section ();
        } else {
            profiles_page.focus_wifi_section ();
        }
    }

    private void open_saved_wifi_edit (WifiSavedProfile profile) {
        if (wifi_saved_flow != null) {
            wifi_saved_flow.open_saved_edit (profile);
        }
    }

    private void open_saved_wifi_profile_details (WifiSavedProfile profile) {
        selected_saved_wifi_profile = profile;
        selected_saved_ethernet_profile = null;
        profiles_page.remember_scroll_position ();
        profiles_details_page.set_wifi_profile (profile);
        profiles_stack.set_visible_child_name ("details");
        load_saved_wifi_profile_details_settings (profile);
    }

    private void open_saved_ethernet_profile_details (NetworkDevice device) {
        selected_saved_wifi_profile = null;
        selected_saved_ethernet_profile = device;
        profiles_page.remember_scroll_position ();
        profiles_details_page.set_ethernet_profile (device);
        profiles_stack.set_visible_child_name ("details");
        load_saved_ethernet_profile_ip_settings (device);
    }

    private void load_saved_wifi_profile_details_settings (WifiSavedProfile profile) {
        nm.get_saved_wifi_profile_settings.begin (profile, null, (obj, res) => {
            try {
                var settings = nm.get_saved_wifi_profile_settings.end (res);
                if (selected_saved_wifi_profile == null
                    || selected_saved_wifi_profile.saved_connection_uuid != profile.saved_connection_uuid) {
                    return;
                }
                profiles_details_page.apply_wifi_ip_settings (settings);
            } catch (Error e) {
                show_error ("Could not load saved profile settings: " + e.message);
            }
        });
    }

    private void load_saved_ethernet_profile_ip_settings (NetworkDevice device) {
        nm.get_ethernet_device_configured_ip_settings.begin (device, null, (obj, res) => {
            var ip_settings = nm.get_ethernet_device_configured_ip_settings.end (res);
            if (selected_saved_ethernet_profile == null
                || (selected_saved_ethernet_profile.device_path != device.device_path
                    && selected_saved_ethernet_profile.name != device.name)) {
                return;
            }
            profiles_details_page.apply_ethernet_ip_settings (ip_settings);
        });
    }

    private bool apply_saved_wifi_edit () {
        if (wifi_saved_flow == null) {
            return false;
        }
        return wifi_saved_flow.apply_saved_edit ();
    }

    private Gtk.ListBoxRow build_wifi_row (WifiNetwork net) {
        var nm_client = nm;
        var wifi_controller_ref = wifi_controller;
        uint pending_timeout_ms = pending_wifi_connect_timeout_ms;
        bool should_close_on_connect = close_on_connect;
        string net_key = net.network_key;
        bool is_connected_now = active_wifi_connections.contains (net_key);
        bool is_connecting = pending_wifi_connect.contains (net_key);

        return wifi_controller.build_row (
            net,
            is_connected_now,
            is_connecting,
            show_frequency,
            show_band,
            show_bssid,
            resolve_wifi_row_icon_name (net),
            (wifi_net) => {
                open_wifi_details (wifi_net);
            },
            (wifi_net) => {
                forget_wifi_network (wifi_net);
            },
            (wifi_net) => {
                disconnect_wifi_network (wifi_net);
            },
            (wifi_net, password, hidden_ssid) => {
                wifi_controller_ref.connect_with_optional_password (
                    nm_client,
                    wifi_net,
                    password,
                    hidden_ssid,
                    pending_timeout_ms,
                    should_close_on_connect,
                    () => {
                        refresh_wifi ();
                    }
                );
            },
            (wifi_net, enabled) => {
                wifi_controller_ref.set_wifi_network_autoconnect (
                    nm_client,
                    wifi_net,
                    enabled,
                    () => {
                        refresh_wifi ();
                    }
                );
            },
            (revealer, entry) => {
                active_wifi_password_row_id = get_wifi_row_id (net);
                show_wifi_password_prompt (revealer, entry);
            },
            (revealer, entry, value) => {
                hide_wifi_password_prompt (revealer, entry, value);
            }
        );
    }

    private string get_wifi_row_id (WifiNetwork net) {
        return "%s|%s".printf (net.device_path, net.ap_path);
    }

    private void refresh_wifi () {
        bool has_active_prompt_open = active_wifi_password_revealer != null
            && active_wifi_password_revealer.get_reveal_child ();

        wifi_controller.refresh (
            nm,
            wifi_stack,
            wifi_listbox,
            status_label,
            status_icon,
            active_wifi_password_row_id,
            has_active_prompt_open,
            () => {
                hide_active_wifi_password_prompt ();
            },
            () => {
                refresh_switch_states ();
            },
            (net) => {
                return build_wifi_row (net);
            }
        );
    }

    private void refresh_ethernet_section () {
        ethernet_controller.refresh ();
    }

    private void refresh_vpn_section () {
        vpn_controller.refresh ();
    }

    public void refresh_all () {
        refresh_wifi ();
        refresh_saved_profiles ();
        refresh_ethernet_section ();
        refresh_vpn_section ();
    }

    public void prepare_for_presentation () {
        reset_ui_state ();
        refresh_all ();
        refresh_switch_states ();
    }

    private void reset_ui_state () {
        if (content_stack != null) {
            content_stack.set_visible_child_name ("main");
        }
        if (wifi_stack != null) {
            wifi_stack.set_visible_child_name ("list");
        }
        if (ethernet_section != null && ethernet_section.stack != null) {
            ethernet_section.stack.set_visible_child_name ("list");
        }
        if (profiles_stack != null) {
            profiles_stack.set_visible_child_name ("list");
        }
        if (vpn_section != null && vpn_section.stack != null) {
            vpn_section.stack.set_visible_child_name ("list");
        }
        if (notebook != null) {
            notebook.set_current_page (0);
        }

        hide_active_wifi_password_prompt ();

        if (wifi_listbox != null) {
            for (Gtk.Widget? child = wifi_listbox.get_first_child (); child != null; child = child.get_next_sibling ()) {
                var row = child as Gtk.ListBoxRow;
                if (row != null && row.get_data<bool> ("nm-actions-expanded")) {
                    var revealer = row.get_data<Gtk.Revealer> ("actions-revealer");
                    if (revealer != null) {
                        revealer.set_reveal_child (false);
                    }
                    var expand_hint = row.get_data<Gtk.Image> ("expand-hint");
                    if (expand_hint != null) {
                        MainWindowIconResources.set_expand_indicator_icon (expand_hint, false);
                    }
                    row.set_data<bool> ("nm-actions-expanded", false);
                }
            }
        }
    }

    public void refresh_after_action (bool request_wifi_scan) {
        refresh_coordinator.refresh_after_action (request_wifi_scan);
    }

    public void close_window () {
        this.close ();
    }

    private void refresh_switch_states () {
        refresh_coordinator.refresh_switch_states (wifi_switch, networking_switch);
    }

    private void on_wifi_switch_changed () {
        wifi_controller.on_wifi_switch_changed (
            nm,
            wifi_switch,
            () => {
                refresh_switch_states ();
            }
        );
    }

    private void on_networking_switch_changed () {
        wifi_controller.on_networking_switch_changed (
            nm,
            networking_switch,
            () => {
                refresh_switch_states ();
            }
        );
    }

    private void show_wifi_password_prompt (Gtk.Revealer revealer, Gtk.Entry entry) {
        wifi_controller.show_wifi_password_prompt (
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry
        );
    }

    private void hide_wifi_password_prompt (Gtk.Revealer revealer, Gtk.Entry entry, string? value) {
        wifi_controller.hide_wifi_password_prompt (
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry,
            value
        );

        if (active_wifi_password_revealer == null) {
            active_wifi_password_row_id = null;
        }
    }

    private void hide_active_wifi_password_prompt () {
        wifi_controller.hide_active_wifi_password_prompt (
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry
        );
        active_wifi_password_row_id = null;
    }

    public void show_error (string message) {
        var dialog = new Gtk.AlertDialog ("Network Error");
        dialog.set_message ("Network Error");
        dialog.set_detail (message);
        dialog.set_modal (true);
        dialog.show (this);
    }

    private void build_ui () {
        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        root.add_css_class ("nm-root");
        set_child (root);

        status_bar = build_status_bar ();
        root.append (status_bar);
        status_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        status_separator.add_css_class ("nm-separator");
        root.append (status_separator);

        content_stack = new Gtk.Stack ();
        notebook = new Gtk.Notebook ();

        var profiles_root_page = build_profiles_root_page ();

        var wifi_tab = new Gtk.Label ("Wi-Fi");
        wifi_tab.add_css_class ("nm-tab-label");
        notebook.append_page (build_wifi_page (), wifi_tab);

        var eth_tab = new Gtk.Label ("Ethernet");
        eth_tab.add_css_class ("nm-tab-label");
        ethernet_section = new NetworkManagerRebuild.UI.Views.EthernetSectionView (ethernet_controller);
        notebook.append_page (
            ethernet_section.widget,
            eth_tab
        );

        var vpn_tab = new Gtk.Label ("VPN");
        vpn_tab.add_css_class ("nm-tab-label");
        vpn_section = new NetworkManagerRebuild.UI.Views.VpnSectionView (vpn_controller);
        notebook.append_page (
            vpn_section.widget,
            vpn_tab
        );

        content_stack.add_named (notebook, "main");
        content_stack.add_named (profiles_root_page, "profiles");

        nav_manager = new NetworkManagerRebuild.UI.Views.AppContentNavigationManager (
            content_stack,
            notebook,
            wifi_stack,
            ethernet_section.stack,
            vpn_section.stack
        );

        nav_manager.page_changed.connect ((page_num) => {
            if (page_num != 0) {
                wifi_controller.on_page_leave ();
            }
            if (page_num != 1) {
                ethernet_controller.on_page_leave ();
            }
            if (page_num != 2) {
                vpn_controller.on_page_leave ();
            }
        });

        nav_manager.focus_mode_changed.connect ((focus_mode) => {
            update_main_chrome_visibility (focus_mode);
        });

        content_stack.set_visible_child_name ("main");

        var tabs_menu_popover = new Gtk.Popover ();
        tabs_menu_popover.add_css_class ("nm-tabs-menu-popover");
        tabs_menu_popover.set_has_arrow (false);
        tabs_menu_popover.set_position (Gtk.PositionType.BOTTOM);
        // Bias the popover inward so it stays inside the right window edge.
        tabs_menu_popover.set_offset (
            MainWindowUiMetrics.TABS_POPOVER_OFFSET_X,
            MainWindowUiMetrics.TABS_POPOVER_OFFSET_Y
        );
        var tabs_menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
        MainWindowCssClassResolver.add_best_class (
            tabs_menu_box,
            {"nm-popover-list-inset", "nm-row-content-inset"}
        );
        MainWindowCssClassResolver.add_best_class (
            tabs_menu_box,
            {"nm-tabs-menu-list", "nm-list"}
        );

        var saved_profiles_item = new Gtk.Button.with_label ("Saved Profiles");
        saved_profiles_item.add_css_class ("nm-tabs-menu-item");
        saved_profiles_item.clicked.connect (() => {
            tabs_menu_popover.popdown ();
            open_profiles_page (false);
        });
        tabs_menu_box.append (saved_profiles_item);

        tabs_menu_popover.set_child (tabs_menu_box);

        var tabs_menu_button = new Gtk.MenuButton ();
        tabs_menu_button.add_css_class ("nm-tabs-menu-button");
        tabs_menu_button.set_tooltip_text ("Profiles");
        tabs_menu_button.set_popover (tabs_menu_popover);
        var tabs_menu_icon = new Gtk.Image.from_icon_name ("view-more-symbolic");
        MainWindowCssClassResolver.add_best_class (
            tabs_menu_icon,
            {"nm-tabs-menu-icon", "nm-toolbar-icon"}
        );
        tabs_menu_button.set_child (tabs_menu_icon);

        notebook.set_action_widget (tabs_menu_button, Gtk.PackType.END);

        root.append (content_stack);

        update_main_chrome_visibility (nav_manager.is_focus_mode_active ());
    }

    private void dispose_lifecycle_owners () {
        refresh_coordinator.stop ();
        wifi_controller.dispose_controller ();
        ethernet_controller.dispose_controller ();
        vpn_controller.dispose_controller ();
    }

    ~MainWindow () {
        dispose_lifecycle_owners ();
    }
}
