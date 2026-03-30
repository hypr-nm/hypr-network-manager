using GLib;
using Gtk;

public class MainWindowWifiController : Object {
    private MainWindowWifiRuntimeController runtime_controller;

    public MainWindowWifiController () {
        runtime_controller = new MainWindowWifiRuntimeController ();
    }

    public void on_page_leave () {
        runtime_controller.on_page_leave ();
    }

    public void dispose_controller () {
        runtime_controller.dispose_controller ();
    }

    public void sync_edit_gateway_dns_sensitivity (
        Gtk.DropDown? wifi_edit_ipv4_method_dropdown,
        Gtk.Entry? wifi_edit_ipv4_gateway_entry,
        Gtk.Entry? wifi_edit_ipv4_dns_entry,
        Gtk.Switch? wifi_edit_dns_auto_switch,
        Gtk.DropDown? wifi_edit_ipv6_method_dropdown,
        Gtk.Entry? wifi_edit_ipv6_gateway_entry,
        Gtk.Entry? wifi_edit_ipv6_dns_entry,
        Gtk.Switch? wifi_edit_ipv6_dns_auto_switch
    ) {
        if (wifi_edit_ipv4_method_dropdown != null) {
            bool ipv4_disabled = wifi_edit_ipv4_method_dropdown.get_selected () == 2;
            if (ipv4_disabled) {
                if (wifi_edit_dns_auto_switch != null) {
                    wifi_edit_dns_auto_switch.set_active (true);
                }
            }
        }

        if (wifi_edit_ipv6_method_dropdown != null) {
            uint selected = wifi_edit_ipv6_method_dropdown.get_selected ();
            bool ipv6_disabled_or_ignore = selected == 2 || selected == 3;
            if (ipv6_disabled_or_ignore) {
                if (wifi_edit_ipv6_dns_auto_switch != null) {
                    wifi_edit_ipv6_dns_auto_switch.set_active (true);
                }
            }
        }

        if (wifi_edit_ipv4_dns_entry != null && wifi_edit_dns_auto_switch != null) {
            wifi_edit_ipv4_dns_entry.set_sensitive (!wifi_edit_dns_auto_switch.get_active ());
        }

        if (wifi_edit_ipv6_dns_entry != null && wifi_edit_ipv6_dns_auto_switch != null) {
            wifi_edit_ipv6_dns_entry.set_sensitive (!wifi_edit_ipv6_dns_auto_switch.get_active ());
        }
    }

    public void sync_add_network_sensitivity (
        Gtk.DropDown? wifi_add_security_dropdown,
        Gtk.Entry? wifi_add_password_entry,
        Gtk.Button? wifi_add_connect_button = null
    ) {
        runtime_controller.sync_add_network_sensitivity (
            wifi_add_security_dropdown,
            wifi_add_password_entry,
            wifi_add_connect_button
        );
    }

    public void open_add_network (
        Gtk.Stack wifi_stack,
        Gtk.Entry wifi_add_ssid_entry,
        Gtk.DropDown wifi_add_security_dropdown,
        Gtk.Entry wifi_add_password_entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        runtime_controller.open_add_network (
            wifi_stack,
            wifi_add_ssid_entry,
            wifi_add_security_dropdown,
            wifi_add_password_entry,
            on_set_popup_text_input_mode
        );
    }

    public void apply_add_network (
        NetworkManagerClient nm,
        Gtk.Stack wifi_stack,
        Gtk.Entry wifi_add_ssid_entry,
        Gtk.DropDown wifi_add_security_dropdown,
        Gtk.Entry wifi_add_password_entry,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        runtime_controller.apply_add_network (
            nm,
            wifi_stack,
            wifi_add_ssid_entry,
            wifi_add_security_dropdown,
            wifi_add_password_entry,
            on_error,
            on_refresh_after_action,
            on_set_popup_text_input_mode
        );
    }

    public void populate_details (
        NetworkManagerClient nm,
        WifiNetwork net,
        HashTable<string, bool> active_wifi_connections,
        MainWindowWifiDetailsPage page,
        MainWindowLogCallback on_log
    ) {
        runtime_controller.populate_wifi_details (
            nm,
            net,
            active_wifi_connections,
            page,
            on_log
        );
    }

    public void open_details (
        ref WifiNetwork? selected_wifi_network,
        WifiNetwork net,
        Gtk.Stack wifi_stack,
        MainWindowWifiNetworkCallback on_populate_details
    ) {
        selected_wifi_network = net;
        on_populate_details (net);
        wifi_stack.set_visible_child_name ("details");
    }

    public void open_edit (
        ref WifiNetwork? selected_wifi_network,
        NetworkManagerClient nm,
        WifiNetwork net,
        MainWindowWifiEditPage page,
        Gtk.Stack wifi_stack,
        MainWindowActionCallback on_sync_gateway_dns_sensitivity,
        MainWindowActionCallback on_set_popup_text_input_mode,
        MainWindowLogCallback on_log
    ) {
        if (!net.saved) {
            return;
        }

        selected_wifi_network = net;
        runtime_controller.open_wifi_edit (
            nm,
            net,
            page,
            wifi_stack,
            on_sync_gateway_dns_sensitivity,
            on_set_popup_text_input_mode,
            on_log
        );
    }

    public bool apply_edit (
        ref WifiNetwork? selected_wifi_network,
        NetworkManagerClient nm,
        MainWindowWifiEditPage page,
        bool close_after_apply,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_open_details,
        MainWindowActionCallback on_set_popup_text_input_mode_disabled
    ) {
        if (selected_wifi_network == null) {
            return false;
        }

        var net = selected_wifi_network;
        return runtime_controller.apply_wifi_edit (
            nm,
            net,
            page,
            close_after_apply,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            on_error,
            on_refresh_after_action,
            on_open_details,
            on_set_popup_text_input_mode_disabled
        );
    }

    public Gtk.ListBoxRow build_row (
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting,
        bool show_frequency,
        bool show_band,
        bool show_bssid,
        string wifi_row_icon_name,
        owned MainWindowWifiNetworkCallback on_open_details,
        owned MainWindowWifiNetworkCallback on_forget_saved_network,
        owned MainWindowWifiNetworkCallback on_disconnect,
        owned MainWindowWifiNetworkPasswordCallback on_connect,
        owned MainWindowWifiNetworkBoolCallback on_set_auto_connect,
        owned MainWindowPasswordPromptShowCallback on_show_password_prompt,
        owned MainWindowPasswordPromptHideCallback on_hide_password_prompt
    ) {
        return MainWindowWifiRowBuilder.build_row (
            net,
            is_connected_now,
            is_connecting,
            show_frequency,
            show_band,
            show_bssid,
            wifi_row_icon_name,
            (owned) on_open_details,
            (owned) on_forget_saved_network,
            (owned) on_disconnect,
            (owned) on_connect,
            (owned) on_set_auto_connect,
            (owned) on_show_password_prompt,
            (owned) on_hide_password_prompt
        );
    }

    public void refresh (
        NetworkManagerClient nm,
        Gtk.Stack wifi_stack,
        Gtk.ListBox wifi_listbox,
        Gtk.Label status_label,
        Gtk.Image status_icon,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        string? active_wifi_password_row_id,
        bool has_active_wifi_password_prompt,
        MainWindowActionCallback on_hide_active_wifi_password_prompt,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowWifiRowBuildCallback on_build_wifi_row,
        MainWindowLogCallback on_log
    ) {
        runtime_controller.refresh_wifi (
            nm,
            wifi_stack,
            wifi_listbox,
            status_label,
            status_icon,
            active_wifi_connections,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            active_wifi_password_row_id,
            has_active_wifi_password_prompt,
            on_hide_active_wifi_password_prompt,
            on_refresh_switch_states,
            on_build_wifi_row,
            on_log
        );
    }

    public void connect_with_optional_password (
        NetworkManagerClient nm,
        WifiNetwork net,
        string? password,
        string? hidden_ssid,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        uint pending_wifi_connect_timeout_ms,
        bool close_on_connect,
        MainWindowActionCallback on_close_window,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_refresh_wifi,
        MainWindowErrorCallback on_error
    ) {
        runtime_controller.connect_wifi_with_optional_password (
            nm,
            net,
            password,
            hidden_ssid,
            active_wifi_connections,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            pending_wifi_connect_timeout_ms,
            close_on_connect,
            on_close_window,
            on_refresh_after_action,
            on_refresh_wifi,
            on_error
        );
    }

    public void refresh_after_action (
        NetworkManagerClient nm,
        bool request_wifi_scan,
        MainWindowActionCallback on_refresh_all,
        MainWindowLogCallback on_log
    ) {
        runtime_controller.refresh_after_action (
            nm,
            request_wifi_scan,
            on_refresh_all,
            on_log
        );
    }

    public void refresh_switch_states (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        Gtk.Switch networking_switch,
        MainWindowLogCallback on_log
    ) {
        runtime_controller.refresh_switch_states (
            nm,
            wifi_switch,
            networking_switch,
            on_log
        );
    }

    public void on_wifi_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        runtime_controller.on_wifi_switch_changed (
            nm,
            wifi_switch,
            on_error,
            on_refresh_switch_states,
            on_refresh_after_action
        );
    }

    public void on_networking_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch networking_switch,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        runtime_controller.on_networking_switch_changed (
            nm,
            networking_switch,
            on_error,
            on_refresh_switch_states,
            on_refresh_after_action
        );
    }

    public void show_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        runtime_controller.show_wifi_password_prompt (
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry,
            on_set_popup_text_input_mode
        );
    }

    public void hide_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        string? value,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        runtime_controller.hide_wifi_password_prompt (
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry,
            value,
            on_set_popup_text_input_mode
        );
    }

    public void hide_active_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        runtime_controller.hide_active_wifi_password_prompt (
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            on_set_popup_text_input_mode
        );
    }

    public void forget_wifi_network (
        NetworkManagerClient nm,
        WifiNetwork net,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        runtime_controller.forget_wifi_network (nm, net, on_error, on_refresh_after_action);
    }

    public void disconnect_wifi_network (
        NetworkManagerClient nm,
        WifiNetwork net,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        runtime_controller.disconnect_wifi_network (
            nm,
            net,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            on_error,
            on_refresh_after_action
        );
    }

    public void set_wifi_network_autoconnect (
        NetworkManagerClient nm,
        WifiNetwork net,
        bool enabled,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_refresh_wifi
    ) {
        runtime_controller.set_wifi_network_autoconnect (
            nm,
            net,
            enabled,
            on_error,
            on_refresh_after_action,
            on_refresh_wifi
        );
    }

    public void refresh_saved_wifi_profiles (
        NetworkManagerClient nm,
        MainWindowWifiSavedPage page,
        MainWindowErrorCallback on_error
    ) {
        runtime_controller.refresh_saved_wifi_profiles (nm, page, on_error);
    }

    public void load_saved_wifi_profile_settings (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        MainWindowWifiSavedEditPage page,
        MainWindowActionCallback on_sync_sensitivity,
        MainWindowErrorCallback on_error
    ) {
        runtime_controller.load_saved_wifi_profile_settings (
            nm,
            profile,
            page,
            on_sync_sensitivity,
            on_error
        );
    }

    public void apply_saved_wifi_profile_updates (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        WifiSavedProfileUpdateRequest profile_request,
        WifiNetworkUpdateRequest network_request,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_success
    ) {
        runtime_controller.apply_saved_wifi_profile_updates (
            nm,
            profile,
            profile_request,
            network_request,
            on_error,
            on_success
        );
    }
}
