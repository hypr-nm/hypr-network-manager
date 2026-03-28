using GLib;
using Gtk;

public class MainWindowWifiController : Object {
    private MainWindowWifiRuntimeController runtime_controller;
    private MainWindowWifiDetailsEditController details_edit_controller;

    public MainWindowWifiController() {
        runtime_controller = new MainWindowWifiRuntimeController();
        details_edit_controller = new MainWindowWifiDetailsEditController();
    }

    public void on_page_leave() {
        runtime_controller.on_page_leave();
        details_edit_controller.on_page_leave();
    }

    public void dispose_controller() {
        runtime_controller.dispose_controller();
        details_edit_controller.dispose_controller();
    }

    public void sync_edit_gateway_dns_sensitivity(
        Gtk.DropDown? wifi_edit_ipv4_method_dropdown,
        Gtk.Entry? wifi_edit_ipv4_gateway_entry,
        Gtk.Switch? wifi_edit_gateway_auto_switch,
        Gtk.Entry? wifi_edit_ipv4_dns_entry,
        Gtk.Switch? wifi_edit_dns_auto_switch,
        Gtk.DropDown? wifi_edit_ipv6_method_dropdown,
        Gtk.Entry? wifi_edit_ipv6_gateway_entry,
        Gtk.Switch? wifi_edit_ipv6_gateway_auto_switch
    ) {
        if (wifi_edit_ipv4_method_dropdown != null && wifi_edit_ipv4_method_dropdown.get_selected() == 2) {
            if (wifi_edit_gateway_auto_switch != null) {
                wifi_edit_gateway_auto_switch.set_active(true);
            }
            if (wifi_edit_dns_auto_switch != null) {
                wifi_edit_dns_auto_switch.set_active(true);
            }
        }

        if (wifi_edit_ipv6_method_dropdown != null) {
            uint selected = wifi_edit_ipv6_method_dropdown.get_selected();
            if (selected == 2 || selected == 3) {
                if (wifi_edit_ipv6_gateway_auto_switch != null) {
                    wifi_edit_ipv6_gateway_auto_switch.set_active(true);
                }
            }
        }

        if (wifi_edit_ipv4_gateway_entry != null && wifi_edit_gateway_auto_switch != null) {
            wifi_edit_ipv4_gateway_entry.set_sensitive(!wifi_edit_gateway_auto_switch.get_active());
        }

        if (wifi_edit_ipv4_dns_entry != null && wifi_edit_dns_auto_switch != null) {
            wifi_edit_ipv4_dns_entry.set_sensitive(!wifi_edit_dns_auto_switch.get_active());
        }

        if (wifi_edit_ipv6_gateway_entry != null && wifi_edit_ipv6_gateway_auto_switch != null) {
            wifi_edit_ipv6_gateway_entry.set_sensitive(!wifi_edit_ipv6_gateway_auto_switch.get_active());
        }
    }

    public void sync_add_network_sensitivity(
        Gtk.DropDown? wifi_add_security_dropdown,
        Gtk.Entry? wifi_add_password_entry,
        Gtk.Button? wifi_add_connect_button = null
    ) {
        if (wifi_add_security_dropdown == null || wifi_add_password_entry == null) {
            return;
        }

        HiddenWifiSecurityMode mode = HiddenWifiSecurityModeUtils.from_dropdown_index(
            wifi_add_security_dropdown.get_selected()
        );
        bool secured = HiddenWifiSecurityModeUtils.requires_password(mode);
        wifi_add_password_entry.set_sensitive(secured);
        if (!secured) {
            wifi_add_password_entry.set_text("");
        }

        if (wifi_add_connect_button != null) {
            bool can_connect = HiddenWifiSecurityModeUtils.is_password_valid_for_mode(
                mode,
                wifi_add_password_entry.get_text()
            );
            wifi_add_connect_button.set_sensitive(can_connect);
        }
    }

    public void open_add_network(
        Gtk.Stack wifi_stack,
        Gtk.Entry wifi_add_ssid_entry,
        Gtk.DropDown wifi_add_security_dropdown,
        Gtk.Entry wifi_add_password_entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        wifi_add_ssid_entry.set_text("");
        wifi_add_security_dropdown.set_selected(
            HiddenWifiSecurityModeUtils.to_dropdown_index(HiddenWifiSecurityMode.WPA_PSK)
        );
        wifi_add_password_entry.set_text("");
        sync_add_network_sensitivity(
            wifi_add_security_dropdown,
            wifi_add_password_entry
        );

        wifi_stack.set_visible_child_name("add");
        on_set_popup_text_input_mode(true);
        wifi_add_ssid_entry.grab_focus();
    }

    public void apply_add_network(
        NetworkManagerClient nm,
        Gtk.Stack wifi_stack,
        Gtk.Entry wifi_add_ssid_entry,
        Gtk.DropDown wifi_add_security_dropdown,
        Gtk.Entry wifi_add_password_entry,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        string ssid = wifi_add_ssid_entry.get_text().strip();
        HiddenWifiSecurityMode security_mode = HiddenWifiSecurityModeUtils.from_dropdown_index(
            wifi_add_security_dropdown.get_selected()
        );
        string password = wifi_add_password_entry.get_text().strip();

        if (ssid == "") {
            on_error("SSID is required.");
            return;
        }

        if (!HiddenWifiSecurityModeUtils.is_password_valid_for_mode(security_mode, password)) {
            on_error(
                "Password must be at least %d characters for the selected security mode.".printf(
                    HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH
                )
            );
            return;
        }

        nm.connect_hidden_wifi.begin(ssid, security_mode, password, null, (obj, res) => {
            try {
                nm.connect_hidden_wifi.end(res);
                on_refresh_after_action(true);
                wifi_stack.set_visible_child_name("list");
                on_set_popup_text_input_mode(false);
            } catch (Error e) {
                on_error("Add hidden network failed: " + e.message);
            }
        });
    }

    public void populate_details(
        NetworkManagerClient nm,
        WifiNetwork net,
        HashTable<string, bool> active_wifi_connections,
        MainWindowWifiDetailsPage page,
        MainWindowLogCallback on_log
    ) {
        details_edit_controller.populate_wifi_details(
            nm,
            net,
            active_wifi_connections,
            page,
            on_log
        );
    }

    public void open_details(
        ref WifiNetwork? selected_wifi_network,
        WifiNetwork net,
        Gtk.Stack wifi_stack,
        MainWindowWifiNetworkCallback on_populate_details
    ) {
        selected_wifi_network = net;
        on_populate_details(net);
        wifi_stack.set_visible_child_name("details");
    }

    public void open_edit(
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
        details_edit_controller.open_wifi_edit(
            nm,
            net,
            page,
            wifi_stack,
            on_sync_gateway_dns_sensitivity,
            on_set_popup_text_input_mode,
            on_log
        );
    }

    public bool apply_edit(
        ref WifiNetwork? selected_wifi_network,
        NetworkManagerClient nm,
        MainWindowWifiEditPage page,
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
        return details_edit_controller.apply_wifi_edit(
            nm,
            net,
            page,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            on_error,
            on_refresh_after_action,
            on_open_details,
            on_set_popup_text_input_mode_disabled
        );
    }

    public Gtk.ListBoxRow build_row(
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
        owned MainWindowPasswordPromptShowCallback on_show_password_prompt,
        owned MainWindowPasswordPromptHideCallback on_hide_password_prompt
    ) {
        return MainWindowWifiRowBuilder.build_row(
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
            (owned) on_show_password_prompt,
            (owned) on_hide_password_prompt
        );
    }

    public void refresh(
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
        owned MainWindowActionCallback on_hide_active_wifi_password_prompt,
        owned MainWindowActionCallback on_refresh_switch_states,
        owned MainWindowWifiRowBuildCallback on_build_wifi_row,
        owned MainWindowLogCallback on_log
    ) {
        runtime_controller.refresh_wifi(
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
            (owned) on_hide_active_wifi_password_prompt,
            (owned) on_refresh_switch_states,
            (owned) on_build_wifi_row,
            (owned) on_log
        );
    }

    public void connect_with_optional_password(
        NetworkManagerClient nm,
        WifiNetwork net,
        string? password,
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
        runtime_controller.connect_wifi_with_optional_password(
            nm,
            net,
            password,
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

    public void refresh_after_action(
        NetworkManagerClient nm,
        bool request_wifi_scan,
        MainWindowActionCallback on_refresh_all,
        MainWindowLogCallback on_log
    ) {
        runtime_controller.refresh_after_action(
            nm,
            request_wifi_scan,
            on_refresh_all,
            on_log
        );
    }

    public void refresh_switch_states(
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        Gtk.Switch networking_switch,
        MainWindowLogCallback on_log
    ) {
        runtime_controller.refresh_switch_states(
            nm,
            wifi_switch,
            networking_switch,
            on_log
        );
    }

    public void on_wifi_switch_changed(
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        runtime_controller.on_wifi_switch_changed(
            nm,
            wifi_switch,
            on_error,
            on_refresh_switch_states,
            on_refresh_after_action
        );
    }

    public void on_networking_switch_changed(
        NetworkManagerClient nm,
        Gtk.Switch networking_switch,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        runtime_controller.on_networking_switch_changed(
            nm,
            networking_switch,
            on_error,
            on_refresh_switch_states,
            on_refresh_after_action
        );
    }

    public void show_wifi_password_prompt(
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        runtime_controller.show_wifi_password_prompt(
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry,
            on_set_popup_text_input_mode
        );
    }

    public void hide_wifi_password_prompt(
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        string? value,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        runtime_controller.hide_wifi_password_prompt(
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            revealer,
            entry,
            value,
            on_set_popup_text_input_mode
        );
    }

    public void hide_active_wifi_password_prompt(
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        runtime_controller.hide_active_wifi_password_prompt(
            ref active_wifi_password_revealer,
            ref active_wifi_password_entry,
            on_set_popup_text_input_mode
        );
    }
}
