using GLib;
using Gtk;

public class MainWindowWifiController : Object {
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;
    private NetworkManagerRebuild.Models.NetworkStateContext state_context;

    private MainWindowWifiRefreshController refresh_controller;
    private MainWindowWifiConnectionController connection_controller;
    private MainWindowWifiHiddenNetworkController hidden_network_controller;
    private MainWindowWifiSavedProfilesController saved_profiles_controller;
    private MainWindowWifiSwitchController switch_controller;
    private MainWindowWifiPasswordUIController password_ui_controller;
    private MainWindowPasswordPromptManager prompt_manager;
    private MainWindowWifiDetailsEditController details_edit_controller;

    public signal void saved_profile_update_succeeded ();

    public MainWindowWifiController (NetworkManagerRebuild.UI.Interfaces.IWindowHost host, NetworkManagerRebuild.Models.NetworkStateContext state_context) {
        this.host = host;
        this.state_context = state_context;

        refresh_controller = new MainWindowWifiRefreshController (host, state_context);
        connection_controller = new MainWindowWifiConnectionController (host, state_context, refresh_controller);
        hidden_network_controller = new MainWindowWifiHiddenNetworkController (host, connection_controller);
        saved_profiles_controller = new MainWindowWifiSavedProfilesController (host);
        switch_controller = new MainWindowWifiSwitchController (host);
        password_ui_controller = new MainWindowWifiPasswordUIController (host);
        prompt_manager = new MainWindowPasswordPromptManager ();
        details_edit_controller = new MainWindowWifiDetailsEditController (host, state_context);

        saved_profiles_controller.saved_profile_update_succeeded.connect (() => {
            saved_profile_update_succeeded ();
        });
    }

    public void on_page_leave () {
        refresh_controller.on_page_leave ();
        connection_controller.on_page_leave ();
        hidden_network_controller.on_page_leave ();
        saved_profiles_controller.on_page_leave ();
        switch_controller.on_page_leave ();
        details_edit_controller.on_page_leave ();
    }

    public void dispose_controller () {
        refresh_controller.dispose_controller ();
        connection_controller.dispose_controller ();
        hidden_network_controller.dispose_controller ();
        saved_profiles_controller.dispose_controller ();
        switch_controller.dispose_controller ();
        details_edit_controller.dispose_controller ();
    }

    public void sync_add_network_sensitivity (
        Gtk.DropDown? wifi_add_security_dropdown,
        Gtk.Entry? wifi_add_password_entry,
        Gtk.Button? wifi_add_connect_button = null
    ) {
        hidden_network_controller.sync_add_network_sensitivity (
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
        hidden_network_controller.open_add_network (
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
        hidden_network_controller.apply_add_network (
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
        details_edit_controller.populate_wifi_details (
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
        Gtk.Stack wifi_stack
    ) {
        if (!net.saved) {
            return;
        }

        selected_wifi_network = net;
        details_edit_controller.open_wifi_edit (
            nm,
            net,
            page,
            wifi_stack
        );
    }

    public bool apply_edit (
        ref WifiNetwork? selected_wifi_network,
        NetworkManagerClient nm,
        MainWindowWifiEditPage page,
        Gtk.Stack wifi_stack,
        MainWindowWifiDetailsPage details_page,
        bool close_after_apply
    ) {
        if (selected_wifi_network == null) {
            return false;
        }

        var net = selected_wifi_network;
        return details_edit_controller.apply_wifi_edit (
            nm,
            net,
            page,
            wifi_stack,
            details_page,
            close_after_apply
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
        MainWindowWifiRowBuildCallback on_build_wifi_row
    ) {
        refresh_controller.refresh_wifi (
            nm,
            wifi_stack,
            wifi_listbox,
            status_label,
            status_icon,
            active_wifi_password_row_id,
            has_active_wifi_password_prompt,
            on_build_wifi_row
        );
    }

    public void connect_with_optional_password (
        NetworkManagerClient nm,
        WifiNetwork net,
        string? password,
        string? hidden_ssid,
        uint pending_wifi_connect_timeout_ms,
        bool close_on_connect
    ) {
        connection_controller.connect_wifi_with_optional_password (
            nm,
            net,
            password,
            hidden_ssid,
            pending_wifi_connect_timeout_ms,
            close_on_connect
        );
    }

    public void refresh_after_action (
        NetworkManagerClient nm,
        bool request_wifi_scan
    ) {
        connection_controller.refresh_after_action (
            nm,
            request_wifi_scan
        );
    }

    public void refresh_switch_states (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        Gtk.Switch networking_switch
    ) {
        switch_controller.refresh_switch_states (
            nm,
            wifi_switch,
            networking_switch
        );
    }

    public void on_wifi_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch
    ) {
        switch_controller.on_wifi_switch_changed (
            nm,
            wifi_switch
        );
    }

    public void on_networking_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch networking_switch
    ) {
        switch_controller.on_networking_switch_changed (
            nm,
            networking_switch
        );
    }

    public void show_wifi_password_prompt (
        Gtk.Revealer revealer,
        Gtk.Entry entry
    ) {
        prompt_manager.show_prompt (revealer, entry);
        password_ui_controller.set_popup_text_input_mode (true);
    }

    public void hide_wifi_password_prompt (
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        string? value
    ) {
        bool was_active = prompt_manager.hide_prompt (revealer, entry, value);
        if (was_active) {
            password_ui_controller.set_popup_text_input_mode (false);
        }
    }

    public void hide_active_wifi_password_prompt () {
        bool was_active = prompt_manager.hide_active_prompt ();
        if (was_active) {
            password_ui_controller.set_popup_text_input_mode (false);
        }
    }

    public void forget_wifi_network (
        NetworkManagerClient nm,
        WifiNetwork net
    ) {
        connection_controller.forget_wifi_network (
            nm,
            net
        );
    }

    public void disconnect_wifi_network (
        NetworkManagerClient nm,
        WifiNetwork net
    ) {
        connection_controller.disconnect_wifi_network (
            nm,
            net
        );
    }

    public void set_wifi_network_autoconnect (
        NetworkManagerClient nm,
        WifiNetwork net,
        bool enabled
    ) {
        connection_controller.set_wifi_network_autoconnect (
            nm,
            net,
            enabled
        );
    }

    public void refresh_saved_wifi_profiles (
        NetworkManagerClient nm,
        MainWindowProfilesPage page
    ) {
        saved_profiles_controller.refresh_saved_wifi_profiles (nm, page);
    }

    public void load_saved_wifi_profile_settings (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        MainWindowWifiSavedEditPage page
    ) {
        saved_profiles_controller.load_saved_wifi_profile_settings (
            nm,
            profile,
            page
        );
    }

    public void apply_saved_wifi_profile_updates (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        WifiSavedProfileUpdateRequest profile_request,
        WifiNetworkUpdateRequest network_request
    ) {
        saved_profiles_controller.apply_saved_wifi_profile_updates (
            nm,
            profile,
            profile_request,
            network_request
        );
    }
}
