public class MainWindowWifiSwitchController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private bool updating_switches = false;
    private uint switch_refresh_epoch = 1;
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;

    public MainWindowWifiSwitchController (NetworkManagerRebuild.UI.Interfaces.IWindowHost host) {
        this.host = host;
    }

    public void on_page_leave () {
        invalidate_ui_state ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
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
        switch_refresh_epoch++;
        if (switch_refresh_epoch == 0) {
            switch_refresh_epoch = 1;
        }
        updating_switches = false;
    }

    public bool is_updating_switches () {
        return updating_switches;
    }

    public void refresh_switch_states (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        Gtk.Switch networking_switch
    ) {
        uint epoch = capture_ui_epoch ();
        uint refresh_epoch = switch_refresh_epoch + 1;
        if (refresh_epoch == 0) {
            refresh_epoch = 1;
        }
        switch_refresh_epoch = refresh_epoch;
        updating_switches = true;

        nm.get_wifi_enabled_dbus.begin (null, (obj, wifi_res) => {
            try {
                bool wifi_enabled = nm.get_wifi_enabled_dbus.end (wifi_res);
                if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                    wifi_switch.set_active (wifi_enabled);
                }
            } catch (Error e) {
                if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                    host.debug_log ("Could not read WirelessEnabled: " + e.message);
                }
            }

            nm.get_networking_enabled_dbus.begin (null, (obj2, net_res) => {
                try {
                    bool net_enabled = nm.get_networking_enabled_dbus.end (net_res);
                    if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                        networking_switch.set_active (net_enabled);
                    }
                } catch (Error e) {
                    if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                        host.debug_log ("Could not read NetworkingEnabled: " + e.message);
                    }
                } finally {
                    if (switch_refresh_epoch == refresh_epoch) {
                        updating_switches = false;
                    }
                }
            });
        });
    }

    public void on_wifi_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch
    ) {
        if (updating_switches) {
            return;
        }

        uint epoch = capture_ui_epoch ();
        bool enabled = wifi_switch.get_active ();

        nm.set_wifi_enabled.begin (enabled, null, (obj, res) => {
            try {
                nm.set_wifi_enabled.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                host.refresh_after_action (enabled);
            } catch (Error e) {
                string message = e.message;
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                host.show_error ("Could not toggle Wi-Fi: " + message);
                host.refresh_switch_states ();
            }
        });
    }

    public void on_networking_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch networking_switch
    ) {
        if (updating_switches) {
            return;
        }

        uint epoch = capture_ui_epoch ();
        bool enabled = networking_switch.get_active ();

        nm.set_networking_enabled.begin (enabled, null, (obj, res) => {
            try {
                nm.set_networking_enabled.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                host.refresh_after_action (enabled);
            } catch (Error e) {
                string message = e.message;
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                host.show_error ("Could not toggle networking: " + message);
                host.refresh_switch_states ();
            }
        });
    }
}
