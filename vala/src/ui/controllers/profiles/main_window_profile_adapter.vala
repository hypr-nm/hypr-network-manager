using GLib;
using Gtk;

public class MainWindowProfileAdapter : Object {
    private NetworkManagerClient nm;
    private MainWindowWifiController wifi_controller;
    private Gtk.Stack profiles_stack;
    private MainWindowProfilesPage profiles_page;
    private MainWindowWifiSavedEditPage wifi_saved_edit_page;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;

    private WifiSavedProfile? selected_profile = null;

    public MainWindowProfileAdapter (
        NetworkManagerClient nm,
        MainWindowWifiController wifi_controller,
        Gtk.Stack profiles_stack,
        MainWindowProfilesPage profiles_page,
        MainWindowWifiSavedEditPage wifi_saved_edit_page,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        this.nm = nm;
        this.wifi_controller = wifi_controller;
        this.profiles_stack = profiles_stack;
        this.profiles_page = profiles_page;
        this.wifi_saved_edit_page = wifi_saved_edit_page;
        this.host = host;
        this.state_context = state_context;

        wifi_controller.saved_profile_update_succeeded.connect (() => {
            host.refresh_after_action (false);
            host.set_popup_text_input_mode (false);
            profiles_stack.set_visible_child_name ("list");
        });
    }

    public void refresh_saved_networks () {
        wifi_controller.refresh_saved_wifi_profiles (
            nm,
            profiles_page
        );
    }

    public void open_saved_edit (WifiSavedProfile profile) {
        selected_profile = profile;

        string title_name = MainWindowHelpers.safe_text (profile.profile_name).strip ();
        if (title_name == "") {
            title_name = MainWindowHelpers.safe_text (profile.ssid).strip ();
        }
        wifi_saved_edit_page.title_label.set_text ("Saved Profile: %s".printf (title_name));
        host.set_popup_text_input_mode (true);
        profiles_stack.set_visible_child_name ("edit");

        wifi_controller.load_saved_wifi_profile_settings (
            nm,
            profile,
            wifi_saved_edit_page
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
            }
        );
    }

    public void on_saved_edit_back () {
        host.set_popup_text_input_mode (false);
        profiles_stack.set_visible_child_name ("list");
    }

    public bool apply_saved_edit () {
        if (selected_profile == null) {
            return false;
        }

        WifiSavedProfileUpdateRequest profile_request;
        WifiNetworkUpdateRequest network_request;
        string error_message;
        if (!wifi_saved_edit_page.build_update_requests (
            out profile_request,
            out network_request,
            out error_message
        )) {
            host.show_error (error_message);
            return false;
        }

        var profile = selected_profile;
        wifi_controller.apply_saved_wifi_profile_updates (
            nm,
            profile,
            profile_request,
            network_request
        );

        return true;
    }
}