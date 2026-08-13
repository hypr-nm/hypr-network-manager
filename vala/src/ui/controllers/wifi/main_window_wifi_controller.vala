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
using HyprNetworkManager.Backend;

public class MainWindowWifiController : Object {
    private IWifiClient nm;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;
    private MainWindowWifiConnectionController connection_controller;
    private MainWindowWifiDetailsEditController details_edit_controller;

    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private Cancellable? refresh_cancellable = null;
    private Cancellable? add_network_cancellable = null;
    private Cancellable? share_cancellable = null;
    private bool refresh_in_flight = false;
    private bool refresh_shows_progress = false;
    private bool refresh_queued = false;
    private bool queued_refresh_shows_progress = false;
    private bool queued_refresh_requests_scan = false;
    private bool updating_wifi_switch = false;
    private uint switch_refresh_epoch = 1;
    private uint share_operation_epoch = 1;
    private HashTable<string, WifiNetwork> active_wifi_by_device;

    public signal void refresh_started ();
    public signal void refresh_finished ();
    public signal void networks_loaded (
        WifiRefreshData data,
        string? primary_connected_ssid
    );
    public signal void wifi_switch_state_loaded (bool enabled);
    public signal void hidden_network_connected ();
    public signal void add_network_failed (string message);
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
    public signal void wifi_share_ready (string ssid, string qr_text);

    public MainWindowWifiController (
        IWifiClient nm,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        this.nm = nm;
        this.host = host;
        this.state_context = state_context;
        active_wifi_by_device = new HashTable<string, WifiNetwork> (str_hash, str_equal);

        connection_controller = new MainWindowWifiConnectionController (host, state_context);
        details_edit_controller = new MainWindowWifiDetailsEditController (nm, host, state_context);
        details_edit_controller.details_loaded.connect ((network, settings, connected) => {
            details_loaded (network, settings, connected);
        });
        details_edit_controller.edit_settings_loaded.connect ((network, settings) => {
            edit_settings_loaded (network, settings);
        });
        details_edit_controller.edit_succeeded.connect ((network, close_after_apply) => {
            edit_succeeded (network, close_after_apply);
        });
        details_edit_controller.edit_failed.connect ((message) => {
            edit_failed (message);
        });
    }

    public void on_page_leave () {
        cancel_refresh ();
        cancel_request (ref add_network_cancellable);
        cancel_share_request ();
        invalidate_ui_state ();
        connection_controller.on_page_leave ();
        details_edit_controller.on_page_leave ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        cancel_refresh ();
        cancel_request (ref add_network_cancellable);
        cancel_share_request ();
        invalidate_ui_state ();
        connection_controller.dispose_controller ();
        details_edit_controller.dispose_controller ();
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
        updating_wifi_switch = false;
        active_wifi_by_device.remove_all ();
    }

    private void cancel_request (ref Cancellable? request) {
        if (request != null) {
            request.cancel ();
            request = null;
        }
    }

    private void cancel_refresh () {
        bool was_in_flight = refresh_in_flight;
        bool was_showing_progress = refresh_shows_progress;
        cancel_request (ref refresh_cancellable);
        refresh_in_flight = false;
        refresh_shows_progress = false;
        refresh_queued = false;
        queued_refresh_shows_progress = false;
        queued_refresh_requests_scan = false;
        if (was_in_flight && was_showing_progress) {
            refresh_finished ();
        }
    }

    private async WifiRefreshData load_refresh_data (
        bool request_wifi_scan,
        Cancellable cancellable
    ) throws Error {
        if (request_wifi_scan) {
            try {
                yield nm.scan_wifi (cancellable);
            } catch (IOError.CANCELLED e) {
                throw e;
            } catch (Error e) {
                host.debug_log (
                    "Manual Wi-Fi scan failed; rendering cached results: " +
                    e.message);
            }
        }
        return yield nm.get_wifi_refresh_data (cancellable);
    }

    public void refresh (
        bool show_progress = true,
        bool request_wifi_scan = false
    ) {
        if (refresh_in_flight) {
            refresh_queued = true;
            queued_refresh_shows_progress = queued_refresh_shows_progress
                || show_progress;
            queued_refresh_requests_scan = queued_refresh_requests_scan
                || request_wifi_scan;
            return;
        }

        refresh_in_flight = true;
        refresh_shows_progress = show_progress;
        if (show_progress) {
            refresh_started ();
        }
        uint epoch = capture_ui_epoch ();
        host.debug_log (
            request_wifi_scan
                ? "Refreshing Wi-Fi list with a requested scan"
                : "Refreshing Wi-Fi list from current NetworkManager state");
        refresh_cancellable = new Cancellable ();
        var request = refresh_cancellable;

        load_refresh_data.begin (request_wifi_scan, request, (obj, res) => {
            try {
                var data = load_refresh_data.end (res);
                if (!is_ui_epoch_valid (epoch) || refresh_cancellable != request) {
                    return;
                }

                string? primary_connected_ssid = update_network_state (data.networks, data.devices);
                networks_loaded (data, primary_connected_ssid);
                host.debug_log ("Rendered %u Wi-Fi rows".printf (data.networks.length));
            } catch (Error e) {
                if (e is IOError.CANCELLED || !is_ui_epoch_valid (epoch)) {
                    return;
                }
                host.debug_log ("Wi-Fi refresh failed: " + e.message);
            } finally {
                if (refresh_cancellable == request) {
                    refresh_cancellable = null;
                    refresh_in_flight = false;
                    bool finished_showing_progress = refresh_shows_progress;
                    refresh_shows_progress = false;
                    if (finished_showing_progress) {
                        refresh_finished ();
                    }

                    bool run_queued_refresh = refresh_queued && is_ui_epoch_valid (epoch);
                    bool next_shows_progress = queued_refresh_shows_progress;
                    bool next_requests_scan = queued_refresh_requests_scan;
                    refresh_queued = false;
                    queued_refresh_shows_progress = false;
                    queued_refresh_requests_scan = false;
                    if (run_queued_refresh) {
                        refresh (next_shows_progress, next_requests_scan);
                    }
                }
            }
        });
    }

    private string? update_network_state (
        WifiNetwork[] networks,
        NetworkDevice[] devices
    ) {
        string? primary_connected_ssid = null;
        var device_states = new HashTable<string, DeviceState> (str_hash, str_equal);
        foreach (var device in devices) {
            if (device.is_wifi) {
                device_states.insert (device.device_path, device.state);
            }
        }

        var current_network_keys = new HashTable<string, bool> (str_hash, str_equal);
        var old_active = new HashTable<string, bool> (str_hash, str_equal);
        foreach (var key in state_context.active_wifi_connections.get_keys ()) {
            old_active.insert (key, true);
        }

        state_context.active_wifi_connections.remove_all ();
        active_wifi_by_device.remove_all ();

        foreach (var network in networks) {
            current_network_keys.insert (network.network_key, true);
            bool found_active_for_network = false;

            if (network.radio_candidates.length == 0) {
                DeviceState? state = device_states.lookup (network.device_path);
                if (network.connected && state != null && state == DeviceState.ACTIVATED) {
                    found_active_for_network = true;
                    active_wifi_by_device.insert (network.device_path, network);
                }
            } else {
                foreach (var candidate in network.radio_candidates) {
                    DeviceState? state = device_states.lookup (candidate.device_path);
                    if (!candidate.connected || state == null || state != DeviceState.ACTIVATED) {
                        continue;
                    }
                    found_active_for_network = true;
                    active_wifi_by_device.insert (candidate.device_path, candidate);
                }
            }

            if (found_active_for_network) {
                state_context.active_wifi_connections.insert (network.network_key, true);
                if (!old_active.contains (network.network_key)) {
                    state_context.clear_all_wifi_errors ();
                }
                if (primary_connected_ssid == null) {
                    primary_connected_ssid = network.ssid;
                }
            }
        }

        var stale_error_keys = new List<string> ();
        foreach (var key in state_context.wifi_errors.get_keys ()) {
            if (!current_network_keys.contains (key)) {
                stale_error_keys.append (key);
            }
        }
        foreach (var key in stale_error_keys) {
            state_context.clear_wifi_error (key);
        }

        foreach (var network in networks) {
            reconcile_pending_connection (network, devices);
        }
        return primary_connected_ssid;
    }

    private void reconcile_pending_connection (
        WifiNetwork network,
        NetworkDevice[] devices
    ) {
        string network_key = network.network_key;
        if (!state_context.pending_wifi_connect.contains (network_key)) {
            return;
        }
        string? pending_device_path = state_context.pending_wifi_device_paths.lookup (network_key);
        string target_device_path = pending_device_path != null && pending_device_path != ""
            ? pending_device_path
            : network.device_path;
        var target_candidate = network.candidate_for_device (target_device_path);

        NetworkDevice? matched_device = null;
        foreach (var device in devices) {
            if (device.is_wifi && device.device_path == target_device_path) {
                matched_device = device;
                break;
            }
        }
        if (matched_device == null) {
            return;
        }
        if (target_candidate != null
            && target_candidate.connected
            && matched_device.state == DeviceState.ACTIVATED) {
            state_context.clear_wifi_connecting (network_key);
            state_context.clear_all_wifi_errors ();
            return;
        }
        if (matched_device.is_connecting) {
            state_context.pending_wifi_seen_connecting.insert (network_key, true);
            return;
        }

        bool activated_elsewhere = matched_device.is_connected;
        if (activated_elsewhere || matched_device.state == DeviceState.FAILED) {
            state_context.clear_wifi_connecting (network_key);
            state_context.mark_wifi_error (network_key, _("Connection failed or interrupted."));
            return;
        }

        bool disconnected = matched_device.state == DeviceState.UNKNOWN
            || matched_device.state == DeviceState.UNMANAGED
            || matched_device.state == DeviceState.UNAVAILABLE
            || matched_device.state == DeviceState.DISCONNECTED;
        if (state_context.pending_wifi_seen_connecting.contains (network_key) && disconnected) {
            state_context.clear_wifi_connecting (network_key);
            state_context.mark_wifi_error (network_key, _("Connection failed."));
        }
    }

    public bool is_updating_wifi_switch () {
        return updating_wifi_switch;
    }

    public void refresh_switch_state () {
        uint epoch = capture_ui_epoch ();
        uint refresh_epoch = switch_refresh_epoch + 1;
        if (refresh_epoch == 0) {
            refresh_epoch = 1;
        }
        switch_refresh_epoch = refresh_epoch;
        updating_wifi_switch = true;

        nm.get_wifi_enabled_dbus.begin (null, (obj, res) => {
            try {
                bool enabled = nm.get_wifi_enabled_dbus.end (res);
                if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                    wifi_switch_state_loaded (enabled);
                }
            } catch (Error e) {
                if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                    host.debug_log ("Could not read WirelessEnabled: " + e.message);
                }
            } finally {
                if (switch_refresh_epoch == refresh_epoch) {
                    updating_wifi_switch = false;
                }
            }
        });
    }

    public void set_wifi_enabled (bool enabled) {
        if (updating_wifi_switch) {
            return;
        }
        uint epoch = capture_ui_epoch ();

        nm.set_wifi_enabled.begin (enabled, null, (obj, res) => {
            try {
                nm.set_wifi_enabled.end (res);
                if (is_ui_epoch_valid (epoch)) {
                    host.refresh_after_action (enabled);
                }
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                host.show_error (_("Could not toggle Wi-Fi: %s").printf (e.message));
                host.refresh_switch_states ();
            }
        });
    }

    public void connect_hidden_network (
        string ssid,
        HiddenWifiSecurityMode security_mode,
        string password,
        string device_path
    ) {
        string normalized_ssid = ssid.strip ();
        string normalized_password = password.strip ();
        string selected_device_path = device_path.strip ();
        if (normalized_ssid == "") {
            add_network_failed (_("SSID is required."));
            return;
        }
        if (selected_device_path == "") {
            add_network_failed (_("Select a Wi-Fi radio."));
            return;
        }
        if (!HiddenWifiSecurityModeUtils.is_password_valid_for_mode (security_mode, normalized_password)) {
            add_network_failed (HiddenWifiSecurityModeUtils.password_requirement_hint (security_mode));
            return;
        }

        uint epoch = capture_ui_epoch ();
        cancel_request (ref add_network_cancellable);
        add_network_cancellable = new Cancellable ();
        var request = add_network_cancellable;

        nm.connect_hidden_wifi.begin (
            normalized_ssid,
            security_mode,
            normalized_password,
            selected_device_path,
            request,
            (obj, res) => {
                try {
                    nm.connect_hidden_wifi.end (res);
                    if (!is_ui_epoch_valid (epoch) || add_network_cancellable != request) {
                        return;
                    }
                    add_network_cancellable = null;
                    connection_controller.refresh_after_action (nm, true);
                    hidden_network_connected ();
                } catch (Error e) {
                    if (!is_ui_epoch_valid (epoch) || e is IOError.CANCELLED) {
                        return;
                    }
                    add_network_cancellable = null;
                    add_network_failed (_("Add hidden network failed: %s").printf (e.message));
                }
            }
        );
    }

    public void load_details (WifiNetwork network) {
        cancel_share_request ();
        details_edit_controller.load_details (network);
    }

    public bool is_connected (WifiNetwork network) {
        return details_edit_controller.is_connected (network);
    }

    public bool is_pending (WifiNetwork network) {
        return details_edit_controller.is_pending (network);
    }

    public void load_edit_settings (WifiNetwork network) {
        details_edit_controller.load_edit_settings (network);
    }

    public void apply_edit (
        WifiNetwork network,
        WifiNetworkUpdateRequest request,
        bool close_after_apply,
        bool request_wifi_scan
    ) {
        details_edit_controller.apply_edit (
            network,
            request,
            close_after_apply,
            request_wifi_scan
        );
    }

    public void connect_with_optional_password (
        WifiNetwork network,
        string? password,
        string? hidden_ssid,
        bool autoconnect,
        uint pending_wifi_connect_timeout_ms,
        bool close_on_connect
    ) {
        WifiNetwork? fallback = active_wifi_by_device.lookup (network.device_path);
        connection_controller.connect_wifi_with_optional_password (
            nm,
            network,
            fallback,
            password,
            hidden_ssid,
            autoconnect,
            pending_wifi_connect_timeout_ms,
            close_on_connect
        );
    }

    public void refresh_after_action (bool request_wifi_scan) {
        connection_controller.refresh_after_action (nm, request_wifi_scan);
    }

    public void forget_wifi_network (WifiNetwork network) {
        connection_controller.forget_wifi_network (nm, network);
    }

    public void disconnect_wifi_network (WifiNetwork network) {
        connection_controller.disconnect_wifi_network (nm, network);
    }

    public void set_wifi_network_autoconnect (WifiNetwork network, bool enabled) {
        connection_controller.set_wifi_network_autoconnect (nm, network, enabled);
    }

    private void cancel_share_request () {
        share_operation_epoch++;
        if (share_operation_epoch == 0) {
            share_operation_epoch = 1;
        }
        cancel_request (ref share_cancellable);
    }

    public void open_wifi_share (WifiNetwork network) {
        cancel_share_request ();
        uint epoch = share_operation_epoch;
        share_cancellable = new Cancellable ();
        var request = share_cancellable;
        string share_uuid = network.saved_connection_uuid;
        string share_ssid = network.ssid;
        string share_network_key = network.network_key;
        bool share_secured = network.is_secured;
        bool share_hidden = network.is_hidden;

        nm.get_wifi_password.begin (share_uuid, request, (obj, res) => {
            if (epoch != share_operation_epoch || share_cancellable != request) {
                return;
            }

            string? read_failure = null;
            string? password = nm.get_wifi_password.end (res, out read_failure);
            share_cancellable = null;

            if (share_secured && (password == null || password == "")) {
                string message = read_failure != null
                    ? _("Could not read Wi-Fi password: %s").printf (read_failure)
                    : _("Cannot share: password is empty");
                host.show_wifi_error (share_network_key, message);
                return;
            }

            string qr_text = WifiQrBuilder.build (
                share_ssid,
                password ?? "",
                share_secured,
                share_hidden
            );
            wifi_share_ready (share_ssid, qr_text);
        });
    }
}
