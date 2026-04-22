using GLib;
using Gtk;
using HyprNetworkManager.UI.Interfaces;

public class MainWindowFlightModeController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private bool updating = false;
    private NetworkManagerClient nm;
    private IWindowHost host;

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

    public void refresh_flight_mode_state (
        Gtk.Button flight_mode_button
    ) {
        uint epoch = capture_ui_epoch ();
        updating = true;

        nm.get_networking_enabled_dbus.begin (null, (obj, res) => {
            try {
                bool net_enabled = nm.get_networking_enabled_dbus.end (res);
                if (is_ui_epoch_valid (epoch)) {
                    // Flight mode is active if networking is disabled
                    bool flight_mode_active = !net_enabled;
                    flight_mode_button.set_label (
                        flight_mode_active ? "Turn off flight mode" : "Turn on flight mode"
                    );
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

    public void toggle_flight_mode (
        Gtk.Button flight_mode_button
    ) {
        if (updating) {
            return;
        }

        uint epoch = capture_ui_epoch ();
        
        // We fetch the current state to be sure
        nm.get_networking_enabled_dbus.begin (null, (obj, res) => {
            bool current_net_enabled = true;
            try {
                current_net_enabled = nm.get_networking_enabled_dbus.end (res);
            } catch (Error e) {
                host.debug_log ("Flight mode toggle: failed to fetch current state: " + e.message);
                // Fallback to button label
                current_net_enabled = flight_mode_button.get_label () == "Turn on flight mode";
            }

            // If net is enabled, flight mode is OFF. Clicking toggle should Turn ON flight mode (disable net).
            bool target_net_enabled = !current_net_enabled;

            nm.set_networking_enabled.begin (target_net_enabled, null, (obj2, res2) => {
                try {
                    nm.set_networking_enabled.end (res2);
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }

                    // Update UI immediately
                    bool new_flight_mode_active = !target_net_enabled;
                    flight_mode_button.set_label (
                        new_flight_mode_active ? "Turn off flight mode" : "Turn on flight mode"
                    );

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
