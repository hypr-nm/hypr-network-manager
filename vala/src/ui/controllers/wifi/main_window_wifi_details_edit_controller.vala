/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using Constants;
using GLib;

public class MainWindowWifiDetailsEditController : Object {
    private HyprNetworkManager.Backend.IWifiClient nm;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;
    private const uint WIFI_RECONNECT_CHECK_INTERVAL_MS = 300;
    private const uint WIFI_RECONNECT_MAX_WAIT_MS = 10000;

    private uint[] timeout_source_ids = {};
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private Cancellable? details_request_cancellable = null;
    private Cancellable? edit_request_cancellable = null;
    private Cancellable? action_request_cancellable = null;

    public signal void details_loaded (
        WifiNetwork network,
        NetworkIpSettings settings,
        bool is_connected
    );
    public signal void edit_settings_loaded (
        WifiNetwork network,
        NetworkIpSettings settings
    );
    public signal void edit_succeeded (
        WifiNetwork network,
        bool close_after_apply
    );
    public signal void edit_failed (string message);

    public MainWindowWifiDetailsEditController (
        HyprNetworkManager.Backend.IWifiClient nm,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        this.nm = nm;
        this.host = host;
        this.state_context = state_context;
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

    private bool is_cancelled_error (Error error) {
        return error is IOError.CANCELLED;
    }

    private void invalidate_ui_state () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_request (ref details_request_cancellable);
        cancel_request (ref edit_request_cancellable);
        cancel_action_request ();
        cancel_all_timeout_sources ();
    }

    private void cancel_request (ref Cancellable? request) {
        if (request != null) {
            request.cancel ();
            request = null;
        }
    }

    private void cancel_details_request () {
        cancel_request (ref details_request_cancellable);
    }

    private void cancel_edit_request () {
        cancel_request (ref edit_request_cancellable);
    }

    private void cancel_action_request () {
        if (action_request_cancellable != null) {
            action_request_cancellable.cancel ();
            action_request_cancellable = null;
        }
    }

    private void cancel_all_timeout_sources () {
        foreach (uint source_id in timeout_source_ids) {
            Source.remove (source_id);
        }
        timeout_source_ids = {};
    }

    private void track_timeout_source (uint source_id) {
        if (source_id != 0) {
            timeout_source_ids += source_id;
        }
    }

    private void untrack_timeout_source (uint source_id) {
        uint[] remaining = {};
        foreach (uint id in timeout_source_ids) {
            if (id != source_id) {
                remaining += id;
            }
        }
        timeout_source_ids = remaining;
    }

    private bool is_wifi_device_fully_disconnected (NetworkDevice device) {
        return !device.is_connected && !device.is_connecting;
    }

    private void reconnect_after_disconnect_with_retry (
        WifiNetwork network,
        uint epoch,
        uint waited_ms,
        Cancellable request_cancellable
    ) {
        string network_key = network.network_key;
        if (!is_ui_epoch_valid (epoch)) {
            return;
        }

        nm.get_devices.begin (request_cancellable, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            bool ready_to_reconnect = true;
            try {
                foreach (var device in nm.get_devices.end (res)) {
                    if (device.is_wifi && device.device_path == network.device_path) {
                        ready_to_reconnect = is_wifi_device_fully_disconnected (device);
                        break;
                    }
                }
            } catch (Error e) {
                if (is_cancelled_error (e)) {
                    return;
                }
                ready_to_reconnect = false;
            }

            if (ready_to_reconnect) {
                nm.connect_wifi.begin (
                    network,
                    null,
                    network.autoconnect,
                    request_cancellable,
                    (obj2, res2) => {
                        try {
                            nm.connect_wifi.end (res2);
                            if (!is_ui_epoch_valid (epoch)) {
                                return;
                            }
                            host.refresh_after_action (true);
                        } catch (Error e) {
                            if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                                return;
                            }
                            state_context.clear_wifi_connecting (network_key);
                            edit_failed (_("Reconnect after edit failed: %s").printf (e.message));
                            host.refresh_after_action (false);
                        }
                    }
                );
                return;
            }

            if (waited_ms >= WIFI_RECONNECT_MAX_WAIT_MS) {
                state_context.clear_wifi_connecting (network_key);
                edit_failed (_("Reconnect after edit timed out while waiting for disconnect to complete."));
                host.refresh_after_action (false);
                return;
            }

            uint next_waited_ms = waited_ms + WIFI_RECONNECT_CHECK_INTERVAL_MS;
            uint timeout_id = 0;
            timeout_id = Timeout.add (WIFI_RECONNECT_CHECK_INTERVAL_MS, () => {
                untrack_timeout_source (timeout_id);
                reconnect_after_disconnect_with_retry (
                    network,
                    epoch,
                    next_waited_ms,
                    request_cancellable
                );
                return false;
            });
            track_timeout_source (timeout_id);
        });
    }

    public bool is_connected (WifiNetwork network) {
        return network.connected;
    }

    public bool is_pending (WifiNetwork network) {
        return state_context.pending_wifi_connect.contains (network.network_key);
    }

    public void load_details (WifiNetwork network) {
        uint epoch = capture_ui_epoch ();
        cancel_details_request ();
        details_request_cancellable = new Cancellable ();
        var request = details_request_cancellable;
        bool connected = is_connected (network);

        nm.get_wifi_network_ip_settings.begin (network, request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch) || details_request_cancellable != request) {
                return;
            }
            var settings = nm.get_wifi_network_ip_settings.end (res);
            details_request_cancellable = null;
            details_loaded (network, settings, connected);
        });
    }

    public void load_edit_settings (WifiNetwork network) {
        uint epoch = capture_ui_epoch ();
        cancel_edit_request ();
        edit_request_cancellable = new Cancellable ();
        var request = edit_request_cancellable;

        nm.get_wifi_network_ip_settings.begin (network, request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch) || edit_request_cancellable != request) {
                return;
            }
            var settings = nm.get_wifi_network_ip_settings.end (res);
            edit_request_cancellable = null;
            edit_settings_loaded (network, settings);
        });
    }

    public void apply_edit (
        WifiNetwork network,
        WifiNetworkUpdateRequest request,
        bool close_after_apply,
        bool request_wifi_scan
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_action_request ();
        action_request_cancellable = new Cancellable ();
        var action_request = action_request_cancellable;
        string network_key = network.network_key;

        state_context.clear_wifi_error (network_key);

        nm.update_wifi_network_settings.begin (network, request, action_request, (obj, res) => {
            try {
                nm.update_wifi_network_settings.end (res);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                    return;
                }
                edit_failed (_("Apply failed: %s").printf (e.message));
                return;
            }

            if (!is_ui_epoch_valid (epoch)) {
                return;
            }
            edit_succeeded (network, close_after_apply);

            if (!network.connected) {
                host.refresh_after_action (request_wifi_scan);
                return;
            }

            nm.disconnect_wifi.begin (network, action_request, (obj2, res2) => {
                try {
                    nm.disconnect_wifi.end (res2);
                } catch (Error e) {
                    if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                        return;
                    }
                    edit_failed (_("Disconnect before reconnect failed: %s").printf (e.message));
                    return;
                }

                state_context.clear_all_wifi_errors ();
                state_context.mark_wifi_connecting (network_key, network.device_path);
                state_context.pending_wifi_seen_connecting.remove (network_key);
                reconnect_after_disconnect_with_retry (network, epoch, 0, action_request);
            });
        });
    }
}
