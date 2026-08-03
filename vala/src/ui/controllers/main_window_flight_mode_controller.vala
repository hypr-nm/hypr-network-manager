/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Constants;
using GLib;
using HyprNetworkManager.UI.Interfaces;

public class MainWindowFlightModeController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private bool updating = false;
    private HyprNetworkManager.Backend.INetworkManagerClient nm;
    private IWindowHost host;

    public signal void flight_mode_state_changed (bool is_flight_mode);

    public MainWindowFlightModeController (
        HyprNetworkManager.Backend.INetworkManagerClient nm,
        IWindowHost host
    ) {
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
