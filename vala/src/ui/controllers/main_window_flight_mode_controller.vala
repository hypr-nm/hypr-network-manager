using GLib;
using HyprNetworkManager.UI.Interfaces;

public class MainWindowFlightModeController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private bool updating = false;
    private NetworkManagerClient nm;
    private IWindowHost host;

    public signal void flight_mode_state_changed (bool is_flight_mode);

    public MainWindowFlightModeController (NetworkManagerClient nm, IWindowHost host) {
        this.nm = nm;
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
        updating = false;
    }

    public void refresh_flight_mode_state () {
        uint epoch = capture_ui_epoch ();
        updating = true;

        nm.get_networking_enabled_dbus.begin (null, (obj, res) => {
            try {
                bool net_enabled = nm.get_networking_enabled_dbus.end (res);
                if (is_ui_epoch_valid (epoch)) {
                    // Flight mode is active if networking is disabled
                    flight_mode_state_changed (!net_enabled);
                }
            } catch (Error e) {
                if (is_ui_epoch_valid (epoch)) {
                    host.debug_log ("Could not read NetworkingEnabled: " + e.message);
                }
            } finally {
                updating = false;
            }
        });
    }

    public void request_flight_mode_toggle (bool current_flight_mode_active) {
        if (updating) {
            return;
        }

        uint epoch = capture_ui_epoch ();

        nm.get_networking_enabled_dbus.begin (null, (obj, res) => {
            bool current_net_enabled = !current_flight_mode_active;
            try {
                current_net_enabled = nm.get_networking_enabled_dbus.end (res);
            } catch (Error e) {
                host.debug_log ("Flight mode toggle: failed to fetch current state: " + e.message);
            }

            bool target_net_enabled = !current_net_enabled;

            nm.set_networking_enabled.begin (target_net_enabled, null, (obj2, res2) => {
                try {
                    nm.set_networking_enabled.end (res2);
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }

                    flight_mode_state_changed (!target_net_enabled);
                    host.refresh_after_action (target_net_enabled);
                } catch (Error e) {
                    if (is_ui_epoch_valid (epoch)) {
                        host.show_error ("Could not toggle flight mode: " + e.message);
                        host.refresh_switch_states ();
                    }
                }
            });
        });
    }
}
