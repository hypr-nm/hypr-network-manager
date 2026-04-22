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
using HyprNetworkManager.UI.Interfaces;
using HyprNetworkManager.Models;

public class MainWindow : Gtk.ApplicationWindow, IWindowHost {
    private WindowConfigContext config_context;
    private NetworkManagerClient nm;
    private HyprNetworkManager.UI.Views.StatusBarView status_bar_view;
    private Gtk.Widget status_separator;
    private HyprNetworkManager.UI.Views.WifiSectionView wifi_section;
    private HyprNetworkManager.UI.Views.SavedProfilesView profiles_section;
    private HyprNetworkManager.UI.Views.EthernetSectionView ethernet_section;
    private MainWindowWifiController wifi_controller;
    private MainWindowRefreshCoordinator refresh_coordinator;
    private MainWindowEthernetController ethernet_controller;
    private MainWindowVpnController vpn_controller;
    private MainWindowFlightModeController flight_mode_controller;
    private HyprNetworkManager.UI.Views.VpnSectionView vpn_section;
    private Gtk.Stack content_stack;
    private Gtk.Notebook notebook;
    private Gtk.EventControllerKey key_controller;
    private bool layer_shell_active = false;
    private NetworkStateContext state_context;
    private HyprNetworkManager.UI.Views.AppContentNavigationManager nav_manager;

    private Gtk.Label global_error_label;
    private Gtk.Revealer global_error_revealer;
    private Gtk.Button flight_mode_button;

    public MainWindow (
        Gtk.Application app,
        AppConfig config
    ) throws Error {
        Object (application: app, title: "Network Manager");
        this.state_context = new NetworkStateContext ();
        this.config_context = new WindowConfigContext.from_app_config (config);

        int effective_width = config_context.window_width;
        int effective_height = config_context.window_height;

        set_default_size (effective_width, effective_height);
        set_size_request (WindowConfigContext.MIN_WINDOW_WIDTH, WindowConfigContext.MIN_WINDOW_HEIGHT);
        set_resizable (false);
        set_opacity (MainWindowUiMetrics.WINDOW_OPACITY);
        add_css_class (MainWindowCssClasses.WINDOW);
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
        flight_mode_controller = new MainWindowFlightModeController (nm, this);
        refresh_coordinator = new MainWindowRefreshCoordinator (
            nm,
            wifi_controller,
            config_context.refresh_interval_seconds,
            this
        );

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
        GtkLayerShell.Layer layer_mode = parse_layer_mode (config_context.shell_layer);

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

        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, config_context.anchor_top);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, config_context.anchor_right);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, config_context.anchor_bottom);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, config_context.anchor_left);
        GtkLayerShell.set_margin (this, GtkLayerShell.Edge.TOP, config_context.shell_margin_top);
        GtkLayerShell.set_margin (this, GtkLayerShell.Edge.RIGHT, config_context.shell_margin_right);
        GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, config_context.shell_margin_bottom);
        GtkLayerShell.set_margin (this, GtkLayerShell.Edge.LEFT, config_context.shell_margin_left);

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

        bool keep_input_for_wifi_edit = wifi_section != null && wifi_section.stack != null
            && wifi_section.stack.get_visible_child_name () == "edit";
        bool keep_input_for_saved_wifi_edit = profiles_section != null && profiles_section.stack != null
            && profiles_section.stack.get_visible_child_name () == "edit";
        bool keep_input_for_wifi_add = wifi_section != null && wifi_section.stack != null
            && wifi_section.stack.get_visible_child_name () == "add";
        bool keep_input_for_inline_prompt = wifi_section != null && wifi_section.active_wifi_password_revealer != null
            && wifi_section.active_wifi_password_revealer.get_reveal_child ();

        if (keep_input_for_wifi_edit || keep_input_for_saved_wifi_edit || keep_input_for_wifi_add ||
            keep_input_for_inline_prompt) {
            GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.ON_DEMAND);
            return;
        }

        GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.NONE);
    }

    private void update_main_chrome_visibility (bool focus_mode) {
        if (status_bar_view != null) {
            status_bar_view.root_widget.set_visible (!focus_mode);
        }
        if (status_separator != null) {
            status_separator.set_visible (!focus_mode);
        }
        if (notebook != null) {
            notebook.set_show_tabs (!focus_mode);
        }
    }

    private void refresh_wifi () {
        if (wifi_section != null) {
            wifi_section.perform_refresh ();
        }
    }

    private void refresh_ethernet_section () {
        ethernet_controller.refresh ();
    }

    private void refresh_vpn_section () {
        vpn_controller.refresh ();
    }

    public void refresh_all () {
        refresh_wifi ();
        if (profiles_section != null) {
            profiles_section.refresh_saved_profiles ();
        }
        refresh_ethernet_section ();
        refresh_vpn_section ();
        refresh_switch_states ();
    }

    public void prepare_for_presentation () {
        reset_ui_state ();
        refresh_all ();
        refresh_switch_states ();
    }

    private void reset_ui_state () {
        if (global_error_revealer != null) {
            global_error_revealer.set_reveal_child (false);
        }
        if (content_stack != null) {
            content_stack.set_visible_child_name ("main");
        }
        if (wifi_section != null) {
            wifi_section.reset_view_state ();
        }
        if (ethernet_section != null) {
            ethernet_section.reset_view_state ();
        }
        if (profiles_section != null) {
            profiles_section.reset_view_state ();
        }
        if (vpn_section != null) {
            vpn_section.reset_view_state ();
        }
        if (notebook != null) {
            notebook.set_current_page (0);
        }
    }

    public void refresh_after_action (bool request_wifi_scan) {
        refresh_coordinator.refresh_after_action (request_wifi_scan);
    }

    public void close_window () {
        this.close ();
    }

    public void hide_active_wifi_password_prompt () {
        if (wifi_section != null) {
            wifi_section.hide_active_wifi_password_prompt ();
        }
    }

    public void refresh_switch_states () {
        if (wifi_section == null || status_bar_view == null) {
            return;
        }

        refresh_coordinator.refresh_switch_states (
            wifi_section.wifi_switch
        );

        if (flight_mode_button != null) {
            flight_mode_controller.refresh_flight_mode_state ();
        }
    }

    private void on_flight_mode_clicked () {
        if (flight_mode_button == null) {
            return;
        }

        bool is_flight_mode = flight_mode_button.get_label () == "Turn off flight mode";
        flight_mode_controller.request_flight_mode_toggle (is_flight_mode);
    }

    public void show_error (string message) {
        if (message == null || message == "") {
            global_error_revealer.set_reveal_child (false);
            return;
        }
        global_error_label.set_text (message);
        global_error_revealer.set_reveal_child (true);

        // Auto-hide after 5 seconds
        Timeout.add (5000, () => {
            if (global_error_label.get_text () == message) {
                global_error_revealer.set_reveal_child (false);
            }
            return false;
        });
    }

    public void show_wifi_error (string net_key, string message) {
        state_context.mark_wifi_error (net_key, message);
        refresh_all ();
    }

    public void show_ethernet_error (string iface_name, string message) {
        state_context.mark_ethernet_error (iface_name, message);
        refresh_all ();
    }

    public void show_vpn_error (string vpn_name, string message) {
        state_context.mark_vpn_error (vpn_name, message);
        refresh_all ();
    }

    public void show_edit_page_error (string message) {
        if (wifi_section != null && wifi_section.stack.get_visible_child_name () == "edit") {
            wifi_section.show_edit_error (message);
        } else if (ethernet_section != null && ethernet_section.stack.get_visible_child_name () == "edit") {
            ethernet_section.show_edit_error (message);
        } else if (profiles_section != null && profiles_section.stack.get_visible_child_name () == "edit") {
            profiles_section.show_edit_error (message);
        }
    }

    public void show_add_page_error (string message) {
        if (wifi_section != null && wifi_section.stack.get_visible_child_name () == "add") {
            wifi_section.show_add_error (message);
        }
    }

    private Gtk.Box build_root_container () {
        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        root.add_css_class (MainWindowCssClasses.ROOT);
        set_child (root);
        return root;
    }

    private void build_status_chrome (Gtk.Box root) {
        status_bar_view = new HyprNetworkManager.UI.Views.StatusBarView ();
        root.append (status_bar_view.root_widget);

        status_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        status_separator.add_css_class (MainWindowCssClasses.SEPARATOR);
        root.append (status_separator);
    }

    private Gtk.Label build_tab_label (string text) {
        var tab = new Gtk.Label (text);
        tab.add_css_class (MainWindowCssClasses.TAB_LABEL);
        return tab;
    }

    private void build_sections_and_tabs () {
        wifi_section = new HyprNetworkManager.UI.Views.WifiSectionView (
            nm,
            wifi_controller,
            this,
            state_context,
            config_context,
            status_bar_view.status_label,
            status_bar_view.status_icon
        );
        wifi_section.refresh_requested.connect (() => {
            refresh_wifi ();
        });
        wifi_section.refresh_switch_states_requested.connect (() => {
            refresh_switch_states ();
        });

        profiles_section = new HyprNetworkManager.UI.Views.SavedProfilesView (
            nm,
            wifi_controller,
            ethernet_controller,
            this,
            state_context,
            content_stack,
            wifi_section.stack,
            notebook
        );
        profiles_section.refresh_requested.connect (() => {
            profiles_section.refresh_saved_profiles ();
        });

        ethernet_section = new HyprNetworkManager.UI.Views.EthernetSectionView (ethernet_controller);
        vpn_section = new HyprNetworkManager.UI.Views.VpnSectionView (vpn_controller);

        notebook.append_page (wifi_section.widget, build_tab_label ("Wi-Fi"));
        notebook.append_page (ethernet_section.widget, build_tab_label ("Ethernet"));
        notebook.append_page (vpn_section.widget, build_tab_label ("VPN"));

        content_stack.add_named (notebook, "main");
        content_stack.add_named (profiles_section.stack, "profiles");
    }

    private void build_navigation_manager () {
        nav_manager = new HyprNetworkManager.UI.Views.AppContentNavigationManager (
            content_stack,
            notebook,
            wifi_section.stack,
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
    }

    private Gtk.MenuButton build_tabs_menu_button () {
        var tabs_menu_popover = new Gtk.Popover ();
        tabs_menu_popover.add_css_class (MainWindowCssClasses.TABS_MENU_POPOVER);
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
            {MainWindowCssClasses.POPOVER_LIST_INSET, MainWindowCssClasses.ROW_CONTENT_INSET}
        );
        MainWindowCssClassResolver.add_best_class (
            tabs_menu_box,
            {MainWindowCssClasses.TABS_MENU_LIST, MainWindowCssClasses.LIST}
        );

        var saved_profiles_item = new Gtk.Button.with_label ("Saved Profiles");
        saved_profiles_item.add_css_class (MainWindowCssClasses.TABS_MENU_ITEM);
        saved_profiles_item.clicked.connect (() => {
            tabs_menu_popover.popdown ();
            profiles_section.open_profiles_page (false);
        });
        tabs_menu_box.append (saved_profiles_item);

        flight_mode_button = new Gtk.Button.with_label ("Turn on flight mode");
        flight_mode_button.add_css_class (MainWindowCssClasses.TABS_MENU_ITEM);
        flight_mode_button.clicked.connect (() => {
            tabs_menu_popover.popdown ();
            on_flight_mode_clicked ();
        });
        tabs_menu_box.append (flight_mode_button);

        tabs_menu_popover.map.connect (() => {
            refresh_switch_states ();
        });

        tabs_menu_popover.set_child (tabs_menu_box);

        var tabs_menu_button = new Gtk.MenuButton ();
        tabs_menu_button.add_css_class (MainWindowCssClasses.TABS_MENU_BUTTON);
        tabs_menu_button.set_tooltip_text ("Profiles");
        tabs_menu_button.set_popover (tabs_menu_popover);

        var tabs_menu_icon = new Gtk.Image.from_icon_name ("view-more-symbolic");
        MainWindowCssClassResolver.add_best_class (
            tabs_menu_icon,
            {MainWindowCssClasses.TABS_MENU_ICON, MainWindowCssClasses.TOOLBAR_ICON}
        );
        tabs_menu_button.set_child (tabs_menu_icon);

        return tabs_menu_button;
    }

    private void build_ui () {
        var root = build_root_container ();
        build_status_chrome (root);

        global_error_label = new Gtk.Label ("");
        global_error_label.set_xalign (0.0f);
        global_error_label.set_wrap (true);
        global_error_label.add_css_class (MainWindowCssClasses.ERROR_LABEL);
        global_error_label.add_css_class (MainWindowCssClasses.ROW_CONTENT_INSET);

        global_error_revealer = new Gtk.Revealer ();
        global_error_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        global_error_revealer.set_child (global_error_label);
        root.append (global_error_revealer);

        content_stack = new Gtk.Stack ();
        notebook = new Gtk.Notebook ();

        build_sections_and_tabs ();
        build_navigation_manager ();
        notebook.set_action_widget (build_tabs_menu_button (), Gtk.PackType.END);

        root.append (content_stack);

        flight_mode_controller.flight_mode_state_changed.connect ((is_flight_mode) => {
            if (flight_mode_button != null) {
                flight_mode_button.set_label (is_flight_mode ? "Turn off flight mode" : "Turn on flight mode");
            }
        });

        update_main_chrome_visibility (nav_manager.is_focus_mode_active ());
    }

    private void dispose_lifecycle_owners () {
        refresh_coordinator.stop ();
        wifi_controller.dispose_controller ();
        ethernet_controller.dispose_controller ();
        vpn_controller.dispose_controller ();
        flight_mode_controller.dispose_controller ();
    }

    ~MainWindow () {
        dispose_lifecycle_owners ();
    }
}
