public class MainWindowWifiSavedProfilesController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private Cancellable? saved_profiles_cancellable = null;
    private Cancellable? saved_profile_settings_cancellable = null;
    private Cancellable? saved_profile_update_cancellable = null;
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;

    public signal void saved_profile_update_succeeded ();

    public MainWindowWifiSavedProfilesController (NetworkManagerRebuild.UI.Interfaces.IWindowHost host) {
        this.host = host;
    }

    public void on_page_leave () {
        cancel_saved_profile_requests ();
        invalidate_ui_state ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        cancel_saved_profile_requests ();
        invalidate_ui_state ();
    }

    private uint capture_ui_epoch () {
        return ui_epoch;
    }

    private bool is_ui_epoch_valid (uint epoch) {
        return !is_disposed && epoch == ui_epoch;
    }

    private void invalidate_ui_state () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
    }

    private bool is_cancelled_error (Error e) {
        return e is IOError.CANCELLED;
    }

    private void cancel_saved_profiles_request () {
        if (saved_profiles_cancellable != null) {
            saved_profiles_cancellable.cancel ();
            saved_profiles_cancellable = null;
        }
    }

    private void cancel_saved_profile_settings_request () {
        if (saved_profile_settings_cancellable != null) {
            saved_profile_settings_cancellable.cancel ();
            saved_profile_settings_cancellable = null;
        }
    }

    private void cancel_saved_profile_update_request () {
        if (saved_profile_update_cancellable != null) {
            saved_profile_update_cancellable.cancel ();
            saved_profile_update_cancellable = null;
        }
    }

    private void cancel_saved_profile_requests () {
        cancel_saved_profiles_request ();
        cancel_saved_profile_settings_request ();
        cancel_saved_profile_update_request ();
    }

    public void refresh_saved_wifi_profiles (
        NetworkManagerClient nm,
        MainWindowProfilesPage page
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_saved_profiles_request ();
        saved_profiles_cancellable = new Cancellable ();
        var list_request = saved_profiles_cancellable;

        nm.get_saved_wifi_profiles.begin (list_request, (obj, res) => {
            try {
                var saved_profiles = nm.get_saved_wifi_profiles.end (res);
                if (!is_ui_epoch_valid (epoch) || saved_profiles_cancellable != list_request) {
                    return;
                }
                page.set_wifi_networks (saved_profiles);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)
                    || saved_profiles_cancellable != list_request
                    || is_cancelled_error (e)) {
                    return;
                }
                host.show_error ("Could not load saved networks: " + e.message);
            }
        });
    }

    public void load_saved_wifi_profile_settings (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        MainWindowWifiSavedEditPage page
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_saved_profile_settings_request ();
        saved_profile_settings_cancellable = new Cancellable ();
        var settings_request = saved_profile_settings_cancellable;

        nm.get_saved_wifi_profile_settings.begin (profile, settings_request, (obj, res) => {
            try {
                var settings = nm.get_saved_wifi_profile_settings.end (res);
                if (!is_ui_epoch_valid (epoch) || saved_profile_settings_cancellable != settings_request) {
                    return;
                }

                MainWindowWifiSavedProfileFormUtils.apply_settings_to_edit_page (page, settings);
                MainWindowWifiSavedProfileFormUtils.sync_saved_edit_dns_sensitivity (page);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)
                    || saved_profile_settings_cancellable != settings_request
                    || is_cancelled_error (e)) {
                    return;
                }
                host.show_error ("Could not load saved profile settings: " + e.message);
            }
        });
    }

    public void apply_saved_wifi_profile_updates (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        WifiSavedProfileUpdateRequest profile_request,
        WifiNetworkUpdateRequest network_request
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_saved_profile_update_request ();
        saved_profile_update_cancellable = new Cancellable ();
        var update_request = saved_profile_update_cancellable;

        nm.update_saved_wifi_profile_settings.begin (profile, profile_request, update_request, (obj, res) => {
            try {
                nm.update_saved_wifi_profile_settings.end (res);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)
                    || saved_profile_update_cancellable != update_request
                    || is_cancelled_error (e)) {
                    return;
                }
                host.show_error ("Save profile failed: " + e.message);
                return;
            }

            nm.update_saved_wifi_profile_network_settings.begin (
                profile,
                network_request,
                update_request,
                (obj2, res2) => {
                    try {
                        nm.update_saved_wifi_profile_network_settings.end (res2);
                        if (!is_ui_epoch_valid (epoch)
                            || saved_profile_update_cancellable != update_request) {
                            return;
                        }
                        saved_profile_update_succeeded ();
                    } catch (Error e) {
                        if (!is_ui_epoch_valid (epoch)
                            || saved_profile_update_cancellable != update_request
                            || is_cancelled_error (e)) {
                            return;
                        }
                        host.show_error ("Save network settings failed: " + e.message);
                    }
                }
            );
        });
    }
}
