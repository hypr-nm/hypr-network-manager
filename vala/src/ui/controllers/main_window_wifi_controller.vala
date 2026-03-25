using GLib;
using Gtk;

public class MainWindowWifiController : Object {
    public static void sync_edit_gateway_dns_sensitivity(
        Gtk.Entry wifi_edit_ipv4_gateway_entry,
        Gtk.Switch wifi_edit_gateway_auto_switch,
        Gtk.Entry wifi_edit_ipv4_dns_entry,
        Gtk.Switch wifi_edit_dns_auto_switch
    ) {
        if (wifi_edit_ipv4_gateway_entry != null && wifi_edit_gateway_auto_switch != null) {
            wifi_edit_ipv4_gateway_entry.set_sensitive(!wifi_edit_gateway_auto_switch.get_active());
        }

        if (wifi_edit_ipv4_dns_entry != null && wifi_edit_dns_auto_switch != null) {
            wifi_edit_ipv4_dns_entry.set_sensitive(!wifi_edit_dns_auto_switch.get_active());
        }
    }

    public static void populate_details(
        NetworkManagerClientVala nm,
        WifiNetwork net,
        HashTable<string, bool> active_wifi_connections,
        Gtk.Label wifi_details_title,
        Gtk.Box wifi_details_basic_rows,
        Gtk.Box wifi_details_advanced_rows,
        Gtk.Box wifi_details_ip_rows,
        Gtk.Box wifi_details_action_row,
        Gtk.Button wifi_details_forget_button,
        Gtk.Button wifi_details_edit_button,
        MainWindowLogCallback on_log
    ) {
        MainWindowWifiDetailsEditController.populate_wifi_details(
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
            on_log
        );
    }

    public static void open_details(
        ref WifiNetwork? selected_wifi_network,
        WifiNetwork net,
        Gtk.Stack wifi_stack,
        MainWindowWifiNetworkCallback on_populate_details
    ) {
        selected_wifi_network = net;
        on_populate_details(net);
        wifi_stack.set_visible_child_name("details");
    }

    public static void open_edit(
        ref WifiNetwork? selected_wifi_network,
        NetworkManagerClientVala nm,
        WifiNetwork net,
        Gtk.Label wifi_edit_title,
        Gtk.Entry wifi_edit_password_entry,
        Gtk.Label wifi_edit_note,
        Gtk.DropDown wifi_edit_ipv4_method_dropdown,
        Gtk.Entry wifi_edit_ipv4_address_entry,
        Gtk.Entry wifi_edit_ipv4_prefix_entry,
        Gtk.Switch wifi_edit_gateway_auto_switch,
        Gtk.Entry wifi_edit_ipv4_gateway_entry,
        Gtk.Switch wifi_edit_dns_auto_switch,
        Gtk.Entry wifi_edit_ipv4_dns_entry,
        Gtk.Stack wifi_stack,
        MainWindowActionCallback on_sync_gateway_dns_sensitivity,
        MainWindowActionCallback on_set_popup_text_input_mode,
        MainWindowLogCallback on_log
    ) {
        if (!net.saved) {
            return;
        }

        selected_wifi_network = net;
        MainWindowWifiDetailsEditController.open_wifi_edit(
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
            on_sync_gateway_dns_sensitivity,
            on_set_popup_text_input_mode,
            on_log
        );
    }

    public static bool apply_edit(
        ref WifiNetwork? selected_wifi_network,
        NetworkManagerClientVala nm,
        Gtk.Entry wifi_edit_password_entry,
        Gtk.DropDown wifi_edit_ipv4_method_dropdown,
        Gtk.Entry wifi_edit_ipv4_address_entry,
        Gtk.Switch wifi_edit_gateway_auto_switch,
        Gtk.Entry wifi_edit_ipv4_gateway_entry,
        Gtk.Switch wifi_edit_dns_auto_switch,
        Gtk.Entry wifi_edit_ipv4_dns_entry,
        Gtk.Entry wifi_edit_ipv4_prefix_entry,
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
        return MainWindowWifiDetailsEditController.apply_wifi_edit(
            nm,
            net,
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
            on_error,
            on_refresh_after_action,
            on_open_details,
            on_set_popup_text_input_mode_disabled
        );
    }

    public static Gtk.Widget build_details_page(
        out Gtk.Label wifi_details_title,
        out Gtk.Box wifi_details_basic_rows,
        out Gtk.Box wifi_details_advanced_rows,
        out Gtk.Box wifi_details_ip_rows,
        out Gtk.Box wifi_details_action_row,
        out Gtk.Button wifi_details_forget_button,
        out Gtk.Button wifi_details_edit_button,
        MainWindowActionCallback on_back,
        MainWindowActionCallback on_forget,
        MainWindowActionCallback on_edit
    ) {
        return MainWindowWifiDetailsPagesBuilder.build_details_page(
            out wifi_details_title,
            out wifi_details_basic_rows,
            out wifi_details_advanced_rows,
            out wifi_details_ip_rows,
            out wifi_details_action_row,
            out wifi_details_forget_button,
            out wifi_details_edit_button,
            on_back,
            on_forget,
            on_edit
        );
    }

    public static Gtk.Widget build_edit_page(
        out Gtk.Label wifi_edit_title,
        out Gtk.Entry wifi_edit_password_entry,
        out Gtk.Label wifi_edit_note,
        out Gtk.DropDown wifi_edit_ipv4_method_dropdown,
        out Gtk.Entry wifi_edit_ipv4_address_entry,
        out Gtk.Switch wifi_edit_gateway_auto_switch,
        out Gtk.Entry wifi_edit_ipv4_prefix_entry,
        out Gtk.Switch wifi_edit_dns_auto_switch,
        out Gtk.Entry wifi_edit_ipv4_gateway_entry,
        out Gtk.Entry wifi_edit_ipv4_dns_entry,
        MainWindowActionCallback on_back,
        MainWindowActionCallback on_apply,
        MainWindowActionCallback on_sync_gateway_dns_sensitivity
    ) {
        return MainWindowWifiDetailsPagesBuilder.build_edit_page(
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
            on_back,
            on_apply,
            on_sync_gateway_dns_sensitivity
        );
    }

    public static Gtk.ListBoxRow build_row(
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting,
        bool show_frequency,
        bool show_band,
        bool show_bssid,
        string wifi_row_icon_name,
        MainWindowWifiNetworkCallback on_open_details,
        MainWindowWifiNetworkCallback on_forget_saved_network,
        MainWindowWifiNetworkCallback on_disconnect,
        MainWindowWifiNetworkPasswordCallback on_connect,
        MainWindowPasswordPromptShowCallback on_show_password_prompt,
        MainWindowPasswordPromptHideCallback on_hide_password_prompt
    ) {
        return MainWindowWifiRowBuilder.build_row(
            net,
            is_connected_now,
            is_connecting,
            show_frequency,
            show_band,
            show_bssid,
            wifi_row_icon_name,
            on_open_details,
            on_forget_saved_network,
            on_disconnect,
            on_connect,
            on_show_password_prompt,
            on_hide_password_prompt
        );
    }

    public static void refresh(
        NetworkManagerClientVala nm,
        Gtk.Stack wifi_stack,
        Gtk.ListBox wifi_listbox,
        Gtk.Label status_label,
        Gtk.Image status_icon,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        ref WifiNetwork? selected_wifi_network,
        MainWindowActionCallback on_hide_active_wifi_password_prompt,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowWifiRowBuildCallback on_build_wifi_row,
        MainWindowWifiNetworkCallback on_populate_wifi_details,
        MainWindowLogCallback on_log
    ) {
        MainWindowWifiRuntimeController.refresh_wifi(
            nm,
            wifi_stack,
            wifi_listbox,
            status_label,
            status_icon,
            active_wifi_connections,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            ref selected_wifi_network,
            on_hide_active_wifi_password_prompt,
            on_refresh_switch_states,
            on_build_wifi_row,
            on_populate_wifi_details,
            on_log
        );
    }

    public static void connect_with_optional_password(
        NetworkManagerClientVala nm,
        WifiNetwork net,
        string? password,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        bool close_on_connect,
        MainWindowActionCallback on_close_window,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_refresh_wifi,
        MainWindowErrorCallback on_error
    ) {
        MainWindowWifiRuntimeController.connect_wifi_with_optional_password(
            nm,
            net,
            password,
            active_wifi_connections,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            close_on_connect,
            on_close_window,
            on_refresh_after_action,
            on_refresh_wifi,
            on_error
        );
    }
}
