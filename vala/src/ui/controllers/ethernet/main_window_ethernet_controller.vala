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

public class MainWindowEthernetController : Object {
    private HyprNetworkManager.Backend.IEthernetClient nm;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;
    private MainWindowEthernetConnectionController connection_controller;
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private Cancellable? refresh_cancellable = null;
    private bool refresh_shows_progress = false;
    private Cancellable? details_cancellable = null;
    private Cancellable? edit_cancellable = null;

    public signal void refresh_started ();
    public signal void refresh_finished ();
    public signal void devices_loaded (NetworkDevice[] devices);
    public signal void details_loaded (
        NetworkDevice device,
        NetworkIpSettings settings
    );
    public signal void edit_settings_loaded (
        NetworkDevice device,
        NetworkIpSettings settings
    );
    public signal void edit_succeeded (
        NetworkDevice device,
        bool profile_edit_mode
    );
    public signal void edit_failed (string message);
    public signal void profile_edit_requested (NetworkDevice device);
    public signal void profile_edit_completed ();

    public MainWindowEthernetController (
        HyprNetworkManager.Backend.IEthernetClient nm,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        this.nm = nm;
        this.host = host;
        this.state_context = state_context;
        connection_controller = new MainWindowEthernetConnectionController (nm, host, state_context);
        connection_controller.refresh_requested.connect (() => {
            refresh (false);
        });
    }

    public void on_page_leave () {
        invalidate_ui_state ();
        connection_controller.on_page_leave ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        invalidate_ui_state ();
        connection_controller.dispose_controller ();
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
        cancel_refresh_request ();
        cancel_request (ref details_cancellable);
        cancel_request (ref edit_cancellable);
    }

    private void cancel_request (ref Cancellable? request) {
        if (request != null) {
            request.cancel ();
            request = null;
        }
    }

    private void cancel_refresh_request () {
        if (refresh_cancellable != null) {
            refresh_cancellable.cancel ();
            refresh_cancellable = null;
        }
        if (refresh_shows_progress) {
            refresh_shows_progress = false;
            refresh_finished ();
        }
    }

    public bool is_action_pending (NetworkDevice device) {
        return connection_controller.pending_action.contains (device.name);
    }

    public bool has_saved_profile (NetworkDevice device) {
        return connection_controller.has_saved_profile (device);
    }

    public bool can_connect_with_profile (NetworkDevice device) {
        return connection_controller.can_connect_with_profile (device);
    }

    public string? error_for_device (NetworkDevice device) {
        return state_context.ethernet_errors.lookup (device.name);
    }

    public void trigger_toggle (NetworkDevice device) {
        connection_controller.trigger_toggle (device);
    }

    public void open_profile_edit (NetworkDevice device) {
        profile_edit_requested (device);
    }

    public void refresh (bool show_progress = true) {
        if (!show_progress && refresh_cancellable != null) {
            return;
        }
        uint epoch = capture_ui_epoch ();
        cancel_refresh_request ();
        refresh_cancellable = new Cancellable ();
        var request = refresh_cancellable;
        refresh_shows_progress = show_progress;
        if (show_progress) {
            refresh_started ();
        }

        nm.get_devices.begin (request, (obj, res) => {
            try {
                var devices = nm.get_devices.end (res);
                if (!is_ui_epoch_valid (epoch) || refresh_cancellable != request) {
                    return;
                }
                refresh_cancellable = null;

                var ethernet_devices = new List<NetworkDevice> ();
                foreach (var device in devices) {
                    if (!device.is_ethernet) {
                        continue;
                    }

                    if (connection_controller.pending_action.contains (device.name)
                        && connection_controller.pending_target_connected.contains (device.name)) {
                        bool target_connected = connection_controller.pending_target_connected.get (device.name);
                        if (device.is_connected == target_connected) {
                            connection_controller.pending_action.remove (device.name);
                            connection_controller.pending_target_connected.remove (device.name);
                        }
                    }
                    ethernet_devices.append (device);
                }

                var result = new NetworkDevice[ethernet_devices.length ()];
                int index = 0;
                foreach (var device in ethernet_devices) {
                    result[index++] = device;
                }
                devices_loaded (result);
                if (refresh_shows_progress) {
                    refresh_shows_progress = false;
                    refresh_finished ();
                }
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || refresh_cancellable != request
                    || e is IOError.CANCELLED) {
                    return;
                }
                refresh_cancellable = null;
                if (refresh_shows_progress) {
                    refresh_shows_progress = false;
                    refresh_finished ();
                }
                host.show_error (_("Ethernet refresh failed: %s").printf (e.message));
            }
        });
    }

    public void load_details (NetworkDevice device) {
        uint epoch = capture_ui_epoch ();
        cancel_request (ref details_cancellable);
        details_cancellable = new Cancellable ();
        var request = details_cancellable;

        nm.get_ethernet_device_ip_settings.begin (device, request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch) || details_cancellable != request) {
                return;
            }
            var settings = nm.get_ethernet_device_ip_settings.end (res);
            details_cancellable = null;
            details_loaded (device, settings);
        });
    }

    public void load_edit_settings (NetworkDevice device) {
        uint epoch = capture_ui_epoch ();
        cancel_request (ref edit_cancellable);
        edit_cancellable = new Cancellable ();
        var request = edit_cancellable;

        nm.get_ethernet_device_ip_settings.begin (device, request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch) || edit_cancellable != request) {
                return;
            }
            var settings = nm.get_ethernet_device_ip_settings.end (res);
            edit_cancellable = null;
            edit_settings_loaded (device, settings);
        });
    }

    public void apply_edit (
        NetworkDevice device,
        NetworkIpUpdateRequest request,
        bool profile_edit_mode
    ) {
        uint epoch = capture_ui_epoch ();
        state_context.clear_ethernet_error (device.name);

        nm.update_ethernet_device_settings.begin (device, request, null, (obj, res) => {
            try {
                nm.update_ethernet_device_settings.end (res);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                edit_failed (_("Apply failed: %s").printf (e.message));
                return;
            }

            if (!device.is_connected) {
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                complete_edit (device, profile_edit_mode);
                return;
            }

            nm.disconnect_device.begin (device.name, null, (obj2, res2) => {
                try {
                    nm.disconnect_device.end (res2);
                } catch (Error e) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    edit_failed (_("Disconnect before reconnect failed: %s").printf (e.message));
                    return;
                }

                nm.connect_ethernet_device.begin (device, null, (obj3, res3) => {
                    string? reconnect_error = null;
                    try {
                        nm.connect_ethernet_device.end (res3);
                    } catch (Error e) {
                        reconnect_error = e.message;
                    }

                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    connection_controller.track_pending_action (device, true);
                    if (reconnect_error != null) {
                        edit_failed (_("Reconnect after edit failed: %s").printf (reconnect_error));
                    }
                    complete_edit (device, profile_edit_mode);
                });
            });
        });
    }

    private void complete_edit (NetworkDevice device, bool profile_edit_mode) {
        host.refresh_after_action (false);
        edit_succeeded (device, profile_edit_mode);
        if (profile_edit_mode) {
            profile_edit_completed ();
        }
    }
}
