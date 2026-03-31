using GLib;
using Gtk;

public class MainWindowProfileAdapter : Object {
    private NetworkManagerClient nm;
    private MainWindowWifiController wifi_controller;
    private Gtk.Stack wifi_stack;
    private MainWindowProfilesPage profiles_page;
    private MainWindowWifiSavedEditPage wifi_saved_edit_page;

    private MainWindowErrorCallback on_error;
    private MainWindowRefreshActionCallback on_refresh_after_action;
    private MainWindowBoolCallback on_set_popup_text_input_mode;

    private WifiSavedProfile? selected_profile = null;

    public MainWindowProfileAdapter (
        NetworkManagerClient nm,
        MainWindowWifiController wifi_controller,
        Gtk.Stack wifi_stack,
        MainWindowProfilesPage profiles_page,
        MainWindowWifiSavedEditPage wifi_saved_edit_page,
        owned MainWindowErrorCallback on_error,
        owned MainWindowRefreshActionCallback on_refresh_after_action,
        owned MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        this.nm = nm;
        this.wifi_controller = wifi_controller;
        this.wifi_stack = wifi_stack;
        this.profiles_page = profiles_page;
        this.wifi_saved_edit_page = wifi_saved_edit_page;
        this.on_error = (owned) on_error;
        this.on_refresh_after_action = (owned) on_refresh_after_action;
        this.on_set_popup_text_input_mode = (owned) on_set_popup_text_input_mode;
    }

    private void sync_gateway_dns_sensitivity () {
        wifi_controller.sync_edit_gateway_dns_sensitivity (
            wifi_saved_edit_page.ipv4_method_dropdown,
            wifi_saved_edit_page.ipv4_gateway_entry,
            wifi_saved_edit_page.ipv4_dns_entry,
            wifi_saved_edit_page.dns_auto_switch,
            wifi_saved_edit_page.ipv6_method_dropdown,
            wifi_saved_edit_page.ipv6_gateway_entry,
            wifi_saved_edit_page.ipv6_dns_entry,
            wifi_saved_edit_page.ipv6_dns_auto_switch
        );
    }

    public void on_sync_sensitivity_requested () {
        sync_gateway_dns_sensitivity ();
    }

    public void refresh_saved_networks () {
        wifi_controller.refresh_saved_wifi_profiles (
            nm,
            profiles_page,
            (message) => {
                on_error (message);
            }
        );
    }

    public void open_saved_edit (WifiSavedProfile profile) {
        selected_profile = profile;

        string title_name = MainWindowHelpers.safe_text (profile.profile_name).strip ();
        if (title_name == "") {
            title_name = MainWindowHelpers.safe_text (profile.ssid).strip ();
        }
        wifi_saved_edit_page.title_label.set_text ("Saved Profile: %s".printf (title_name));
        on_set_popup_text_input_mode (true);
        wifi_stack.set_visible_child_name ("saved-edit");

        wifi_controller.load_saved_wifi_profile_settings (
            nm,
            profile,
            wifi_saved_edit_page,
            () => {
                sync_gateway_dns_sensitivity ();
            },
            (message) => {
                on_error (message);
            }
        );
    }

    public void delete_profile (WifiSavedProfile profile) {
        wifi_controller.forget_wifi_network (
            nm,
            new WifiNetwork () {
                saved_connection_uuid = profile.saved_connection_uuid,
                ssid = profile.ssid,
                device_path = profile.device_path,
                ap_path = "saved:" + profile.saved_connection_uuid,
                saved = true
            },
            (message) => {
                on_error (message.replace ("Forget", "Delete"));
            },
            (request_wifi_scan) => {
                on_refresh_after_action (request_wifi_scan);
            }
        );
    }

    public void on_saved_edit_back () {
        on_set_popup_text_input_mode (false);
        wifi_stack.set_visible_child_name ("saved");
    }

    public bool apply_saved_edit () {
        if (selected_profile == null) {
            return false;
        }

        WifiSavedProfileUpdateRequest profile_request;
        WifiNetworkUpdateRequest network_request;
        string error_message;
        if (!MainWindowWifiSavedProfileFormUtils.build_update_requests (
            wifi_saved_edit_page,
            out profile_request,
            out network_request,
            out error_message
        )) {
            on_error (error_message);
            return false;
        }

        var profile = selected_profile;
        wifi_controller.apply_saved_wifi_profile_updates (
            nm,
            profile,
            profile_request,
            network_request,
            (message) => {
                on_error (message);
            },
            () => {
                on_refresh_after_action (false);
                on_set_popup_text_input_mode (false);
                wifi_stack.set_visible_child_name ("saved");
            }
        );

        return true;
    }
}
