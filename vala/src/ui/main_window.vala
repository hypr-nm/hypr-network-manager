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
using HyprNetworkManager.UI.Utils;
using HyprNetworkManager.UI.Widgets;
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
    private Gtk.Box root_container;
    private TransientSurfaceTracker transient_surface_tracker;
    private MainWindowDismissHandler dismiss_handler;
    private bool layer_shell_active = false;
    public GtkLayerShell.Layer current_layer_mode { get; private set; }
    private NetworkStateContext state_context;
    private HyprNetworkManager.UI.Views.AppContentNavigationManager nav_manager;

    private Gtk.Label global_error_label;
    private Gtk.Revealer global_error_revealer;
    private bool flight_mode_active = false;
    private MainWindowTabsMenu? tabs_menu;

    public MainWindow (
        Gtk.Application app,
        AppConfig config
    ) throws Error {
        Object (application: app, title: _("Network Manager"));
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

        layer_shell_active = MainWindowLayerShellConfigurator.configure (this, config_context);
        if (!layer_shell_active) {
            MainWindowLayerShellConfigurator.configure_fallback (this);
        }
        this.current_layer_mode = MainWindowLayerShellConfigurator.parse_layer_mode (config_context.shell_layer);

        transient_surface_tracker = new TransientSurfaceTracker (this, layer_shell_active);
        dismiss_handler = new MainWindowDismissHandler (this, transient_surface_tracker);

        log_info ("gui", "window_init: starting");
        build_ui ();
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

    public void set_popup_text_input_mode (bool enabled) {
        transient_surface_tracker.apply_keyboard_mode ();
    }

    public HyprNetworkManager.UI.Widgets.TrackedDropDown create_tracked_dropdown (
        owned Gtk.StringList model
    ) {
        return new HyprNetworkManager.UI.Widgets.TrackedDropDown (transient_surface_tracker, model);
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
        if (tabs_menu != null) {
            tabs_menu.popdown ();
        }
        transient_surface_tracker.reset (root_container);
        dismiss_handler.reset_state ();

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

        if (tabs_menu != null) {
            flight_mode_controller.refresh_flight_mode_state ();
        }
    }

    private void update_refresh_button_availability () {
        if (wifi_section != null) {
            bool wifi_enabled = wifi_section.wifi_switch.get_active ();
            bool wifi_refresh_enabled = wifi_enabled && !flight_mode_active;
            string wifi_tooltip = "Refresh Wi-Fi networks";

            if (flight_mode_active) {
                wifi_tooltip = "Refresh unavailable while flight mode is on";
            } else if (!wifi_enabled) {
                wifi_tooltip = "Refresh unavailable while Wi-Fi is off";
            }

            wifi_section.wifi_switch.set_sensitive (!flight_mode_active);

            wifi_section.set_refresh_button_enabled (wifi_refresh_enabled, wifi_tooltip);
            wifi_section.add_button.set_sensitive (wifi_refresh_enabled);
            wifi_section.set_availability_placeholder (wifi_enabled, flight_mode_active);
        }

        if (ethernet_section != null) {
            bool ethernet_refresh_enabled = !flight_mode_active;
            string ethernet_tooltip = ethernet_refresh_enabled
                ? "Refresh Ethernet devices"
                : "Refresh unavailable while flight mode is on";

            ethernet_section.set_refresh_button_enabled (ethernet_refresh_enabled, ethernet_tooltip);
            ethernet_section.set_flight_mode_placeholder (flight_mode_active);
        }
    }

    private void on_flight_mode_clicked () {
        flight_mode_controller.request_flight_mode_toggle (!flight_mode_active);
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
        root_container = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        root_container.add_css_class (MainWindowCssClasses.ROOT);
        set_child (root_container);
        dismiss_handler.set_root_container (root_container);
        return root_container;
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
        wifi_section.wifi_switch.notify["active"].connect (() => {
            update_refresh_button_availability ();
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

        ethernet_section = new HyprNetworkManager.UI.Views.EthernetSectionView (
            ethernet_controller,
            this
        );
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
            if (tabs_menu != null) {
                tabs_menu.popdown ();
            }
        });

        nav_manager.focus_mode_changed.connect ((focus_mode) => {
            update_main_chrome_visibility (focus_mode);
        });

        content_stack.set_visible_child_name ("main");
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

        tabs_menu = new MainWindowTabsMenu (transient_surface_tracker);
        tabs_menu.saved_profiles_clicked.connect (() => {
            profiles_section.open_profiles_page (false);
        });
        tabs_menu.flight_mode_clicked.connect (on_flight_mode_clicked);
        tabs_menu.popover_mapped.connect (refresh_switch_states);

        notebook.set_action_widget (tabs_menu, Gtk.PackType.END);

        root.append (content_stack);

        flight_mode_controller.flight_mode_state_changed.connect ((is_flight_mode) => {
            flight_mode_active = is_flight_mode;
            if (tabs_menu != null) {
                tabs_menu.set_flight_mode_label (is_flight_mode ? "Turn off flight mode" : "Turn on flight mode");
            }
            update_refresh_button_availability ();
        });

        update_refresh_button_availability ();
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
