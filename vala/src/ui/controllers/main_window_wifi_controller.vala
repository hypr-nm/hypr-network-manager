using GLib;
using Gtk;

public class MainWindowWifiController : Object {
    private MainWindowWifiRuntimeController runtime_controller;
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;
    private NetworkManagerRebuild.Models.NetworkStateContext state_context;

    public MainWindowWifiController (NetworkManagerRebuild.UI.Interfaces.IWindowHost host, NetworkManagerRebuild.Models.NetworkStateContext state_context) {
        this.host = host;
        this.state_context = state_context;
        runtime_controller = new MainWindowWifiRuntimeController (host, state_context);
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
        Gtk.Entry wifi_add_password_entry
    ) {
        runtime_controller.open_add_network (
            wifi_stack,
            wifi_add_ssid_entry,
            wifi_add_security_dropdown,
            wifi_add_password_entry
        );
    }

    public void apply_add_network (
        NetworkManagerClient nm,
        Gtk.Stack wifi_stack,
        Gtk.Entry wifi_add_ssid_entry,
        Gtk.DropDown wifi_add_security_dropdown,
        Gtk.Entry wifi_add_password_entry
    ) {
        runtime_controller.apply_add_network (
            nm,
            wifi_stack,
            wifi_add_ssid_entry,
            wifi_add_security_dropdown,
            wifi_add_password_entry
        );
    }

    public void populate_details (
        NetworkManagerClient nm,
        WifiNetwork net,
        MainWindowWifiDetailsPage page
    ) {
        runtime_controller.populate_wifi_details (
            nm,
            net,
            page
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
        MainWindowActionCallback on_sync_gateway_dns_sensitivity
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
            on_sync_gateway_dns_sensitivity
        );
    }

    public bool apply_edit (
        ref WifiNetwork? selected_wifi_network,
        NetworkManagerClient nm,
        MainWindowWifiEditPage page,
        bool close_after_apply,
        MainWindowActionCallback on_open_details
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
            on_open_details,
            on_open_details
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
        string? active_wifi_password_row_id,
        bool has_active_wifi_password_prompt,
        MainWindowActionCallback on_hide_active_wifi_password_prompt,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowWifiRowBuildCallback on_build_wifi_row
    ) {
        runtime_controller.refresh_wifi (
            nm,
            wifi_stack,
            wifi_listbox,
            status_label,
            status_icon,
            active_wifi_password_row_id,
            has_active_wifi_password_prompt,
            on_hide_active_wifi_password_prompt,
            on_refresh_switch_states,
            on_build_wifi_row
        );
    }

    public void connect_with_optional_password (
        NetworkManagerClient nm,
        WifiNetwork net,
        string? password,
        string? hidden_ssid,
        uint pending_wifi_connect_timeout_ms,
        bool close_on_connect,
        MainWindowActionCallback on_refresh_wifi
    ) {
        runtime_controller.connect_wifi_with_optional_password (
            nm,
            net,
            password,
            hidden_ssid,
            pending_wifi_connect_timeout_ms,
            close_on_connect,
            on_refresh_wifi
        );
    }

    public void refresh_after_action (
        NetworkManagerClient nm,
        bool request_wifi_scan,
        MainWindowActionCallback on_refresh_all
    ) {
        runtime_controller.refresh_after_action (
            nm,
            request_wifi_scan,
            on_refresh_all
        );
    }

    public void refresh_switch_states (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        Gtk.Switch networking_switch
    ) {
        runtime_controller.refresh_switch_states (
            nm,
            wifi_switch,
            networking_switch
        );
    }

    public void on_wifi_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        MainWindowActionCallback on_refresh_switch_states
    ) {
        runtime_controller.on_wifi_switch_changed (
            nm,
            wifi_switch,
            on_refresh_switch_states
        );
    }

    public void on_networking_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch networking_switch,
        MainWindowActionCallback on_refresh_switch_states
    ) {
        runtime_controller.on_networking_switch_changed (
            nm,
            networking_switch,
            on_refresh_switch_states
        );
    }

    public void show_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry
    ) {
        runtime_controller.show_wifi_password_prompt (
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry
        );
    }

    public void hide_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        string? value
    ) {
        runtime_controller.hide_wifi_password_prompt (
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry,
            value
        );
    }

    public void hide_active_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry
    ) {
        runtime_controller.hide_active_wifi_password_prompt (
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry
        );
    }

    public void forget_wifi_network (
        NetworkManagerClient nm,
        WifiNetwork net
    ) {
        runtime_controller.forget_wifi_network (
            nm,
            net
        );
    }

    public void disconnect_wifi_network (
        NetworkManagerClient nm,
        WifiNetwork net
    ) {
        runtime_controller.disconnect_wifi_network (
            nm,
            net
        );
    }

    public void set_wifi_network_autoconnect (
        NetworkManagerClient nm,
        WifiNetwork net,
        bool enabled,
        MainWindowActionCallback on_refresh_wifi
    ) {
        runtime_controller.set_wifi_network_autoconnect (
            nm,
            net,
            enabled,
            on_refresh_wifi
        );
    }

    public void refresh_saved_wifi_profiles (
        NetworkManagerClient nm,
        MainWindowProfilesPage page
    ) {
        runtime_controller.refresh_saved_wifi_profiles (nm, page);
    }

    public void load_saved_wifi_profile_settings (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        MainWindowWifiSavedEditPage page,
        MainWindowActionCallback on_sync_sensitivity
    ) {
        runtime_controller.load_saved_wifi_profile_settings (
            nm,
            profile,
            page,
            on_sync_sensitivity
        );
    }

    public void apply_saved_wifi_profile_updates (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        WifiSavedProfileUpdateRequest profile_request,
        WifiNetworkUpdateRequest network_request,
        MainWindowActionCallback on_success
    ) {
        runtime_controller.apply_saved_wifi_profile_updates (
            nm,
            profile,
            profile_request,
            network_request,
            on_success
        );
    }
}
