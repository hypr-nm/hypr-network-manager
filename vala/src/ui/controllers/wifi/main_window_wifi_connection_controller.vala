public class MainWindowWifiConnectionController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;
    private MainWindowWifiRefreshController refresh_controller;

    public MainWindowWifiConnectionController (HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context,
            MainWindowWifiRefreshController refresh_controller) {
        this.host = host;
        this.state_context = state_context;
        this.refresh_controller = refresh_controller;
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
        cancel_all_timeout_sources ();
    }

    private void track_timeout_source (uint source_id) {
        if (source_id == 0) {
            return;
        }
        timeout_source_ids += source_id;
    }

    private void untrack_timeout_source (uint source_id) {
        if (source_id == 0 || timeout_source_ids.length == 0) {
            return;
        }

        uint[] remaining = {};
        foreach (uint id in timeout_source_ids) {
            if (id != source_id) {
                remaining += id;
            }
        }
        timeout_source_ids = remaining;
    }

    private void cancel_all_timeout_sources () {
        if (timeout_source_ids.length == 0) {
            return;
        }

        foreach (uint source_id in timeout_source_ids) {
            Source.remove (source_id);
        }
        timeout_source_ids = {};
    }

    private bool is_cancelled_error (Error e) {
        return e is IOError.CANCELLED;
    }

    public void connect_wifi_with_optional_password (
        NetworkManagerClient nm,
        WifiNetwork net,
        string? password,
        string? hidden_ssid,
        bool autoconnect,
        uint pending_wifi_connect_timeout_ms,
        bool close_on_connect
    ) {
        uint epoch = capture_ui_epoch ();

        string net_key = net.network_key;
        WifiNetwork? fallback_network = refresh_controller.active_wifi_by_device.lookup (net.device_path);
        bool can_fallback_reconnect = fallback_network != null
            && fallback_network.network_key != net_key;

        state_context.clear_all_wifi_errors ();

        if (!state_context.active_wifi_connections.contains (net_key)) {
            state_context.mark_wifi_connecting (net_key);
            state_context.pending_wifi_seen_connecting.remove (net_key);
        }

        WifiNetwork connect_target = net;
        if (hidden_ssid != null && hidden_ssid.strip () != "") {
            string resolved_hidden_ssid = hidden_ssid.strip ();
            log_debug (
                "gui",
                "hidden_connect_input: row_ssid='%s' entered_ssid='%s' saved=%s uuid=%s"
                    .printf (
                        redact_ssid (net.ssid),
                        redact_ssid (resolved_hidden_ssid),
                        net.saved ? "true" : "false",
                        redact_uuid (net.saved_connection_uuid)
                    )
            );

            connect_target = new WifiNetwork () {
                ssid = resolved_hidden_ssid,
                saved_connection_uuid = "",
                signal = net.signal,
                connected = net.connected,
                is_secured = net.is_secured,
                is_hidden = net.is_hidden,
                saved = false,
                autoconnect = autoconnect,
                device_path = net.device_path,
                ap_path = net.ap_path,
                bssid = net.bssid,
                frequency_mhz = net.frequency_mhz,
                max_bitrate_kbps = net.max_bitrate_kbps,
                mode = net.mode,
                flags = net.flags,
                wpa_flags = net.wpa_flags,
                rsn_flags = net.rsn_flags
            };
        }

        nm.connect_wifi.begin (connect_target, password, autoconnect, null, (obj, res) => {
            try {
                nm.connect_wifi.end (res);
                state_context.clear_all_wifi_errors ();
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }

                if (close_on_connect) {
                    host.close_window ();
                    return;
                }

                refresh_after_action (nm, true, epoch);

                string pending_ssid = net_key;
                uint effective_timeout_ms = pending_wifi_connect_timeout_ms >= 1000
                    ? pending_wifi_connect_timeout_ms
                    : 1000;
                uint timeout_id = 0;
                timeout_id = Timeout.add (effective_timeout_ms, () => {
                    untrack_timeout_source (timeout_id);
                    if (!is_ui_epoch_valid (epoch)) {
                        return false;
                    }

                    if (state_context.pending_wifi_connect.contains (pending_ssid)) {
                        state_context.pending_wifi_connect.remove (pending_ssid);
                        state_context.pending_wifi_seen_connecting.remove (pending_ssid);
                        state_context.mark_wifi_error (pending_ssid, "Connection timed out.");
                        host.refresh_all ();
                    }
                    return false;
                });
                track_timeout_source (timeout_id);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                state_context.pending_wifi_connect.remove (net_key);
                state_context.pending_wifi_seen_connecting.remove (net_key);
                string connect_error_message = e.message;

                if (can_fallback_reconnect) {
                    string fallback_key = fallback_network.network_key;
                    host.show_wifi_error (net_key, "Connect failed: " + connect_error_message);
                    state_context.mark_wifi_connecting (fallback_key);
                    state_context.pending_wifi_seen_connecting.remove (fallback_key);

                    nm.connect_wifi.begin (
                        fallback_network,
                        null,
                        fallback_network.autoconnect,
                        null,
                        (obj2, res2) => {
                        try {
                            nm.connect_wifi.end (res2);
                            state_context.clear_all_wifi_errors ();
                            if (!is_ui_epoch_valid (epoch)) {
                                return;
                            }
                            refresh_after_action (nm, true, epoch);
                        } catch (Error fallback_error) {
                            if (!is_ui_epoch_valid (epoch)) {
                                return;
                            }
                            state_context.pending_wifi_connect.remove (fallback_key);
                            state_context.pending_wifi_seen_connecting.remove (fallback_key);
                            host.show_wifi_error (
                                fallback_key,
                                "Connect failed: %s. Reconnect to previous network failed: %s"
                                    .printf (connect_error_message, fallback_error.message)
                            );
                            host.refresh_all ();
                        }
                    });
                    return;
                }

                host.show_wifi_error (net_key, "Connect failed: " + connect_error_message);
                host.refresh_all ();
            }
        });
    }

    public void forget_wifi_network (
        NetworkManagerClient nm,
        WifiNetwork net
    ) {
        uint epoch = capture_ui_epoch ();
        string profile_uuid = net.saved_connection_uuid.strip ();
        string network_key = net.network_key;

        state_context.clear_wifi_error (network_key);

        nm.forget_network.begin (profile_uuid, network_key, null, (obj, res) => {
            try {
                nm.forget_network.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                refresh_after_action (nm, true, epoch);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                    return;
                }
                host.show_wifi_error (network_key, "Forget failed: " + e.message);
            }
            });
            }

            public void disconnect_wifi_network (
            NetworkManagerClient nm,
            WifiNetwork net
            ) {
            uint epoch = capture_ui_epoch ();
            string wifi_key = net.network_key;

            state_context.pending_wifi_connect.remove (wifi_key);
            state_context.pending_wifi_seen_connecting.remove (wifi_key);
            state_context.clear_wifi_error (wifi_key);

            nm.disconnect_wifi.begin (net, null, (obj, res) => {
            try {
                nm.disconnect_wifi.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                refresh_after_action (nm, false, epoch);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                    return;
                }
                host.show_wifi_error (wifi_key, "Disconnect failed: " + e.message);
                refresh_after_action (nm, false, epoch);
            }
            });
            }

            public void set_wifi_network_autoconnect (
            NetworkManagerClient nm,
            WifiNetwork net,
            bool enabled
            ) {
            uint epoch = capture_ui_epoch ();
            string wifi_key = net.network_key;
            state_context.clear_wifi_error (wifi_key);

            nm.set_wifi_network_autoconnect.begin (net, enabled, 10, null, (obj, res) => {
            try {
                nm.set_wifi_network_autoconnect.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                refresh_after_action (nm, false, epoch);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                    return;
                }
                host.show_wifi_error (wifi_key, "Could not update auto-connect: " + e.message);
                host.refresh_all ();
            }
        });
    }

    public void refresh_after_action (
        NetworkManagerClient nm,
        bool request_wifi_scan,
        uint? active_epoch = null
    ) {
        uint epoch = active_epoch != null ? active_epoch : capture_ui_epoch ();

        if (request_wifi_scan) {
            nm.scan_wifi.begin (null, (obj, res) => {
                try {
                    nm.scan_wifi.end (res);
                } catch (Error e) {
                    string message = e.message;
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    host.debug_log ("Could not request Wi-Fi scan: " + message);
                }
            });
        }

        if (!is_ui_epoch_valid (epoch)) {
            return;
        }
        host.refresh_all ();

        uint quick_refresh_id = 0;
        quick_refresh_id = Timeout.add (650, () => {
            untrack_timeout_source (quick_refresh_id);
            if (!is_ui_epoch_valid (epoch)) {
                return false;
            }

            if (request_wifi_scan) {
                nm.scan_wifi.begin (null, (obj, res) => {
                    try {
                        nm.scan_wifi.end (res);
                    } catch (Error e) {
                        string message = e.message;
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        host.debug_log ("Could not request delayed Wi-Fi scan: " + message);
                    }
                });
            }
            host.refresh_all ();
            return false;
        });
        track_timeout_source (quick_refresh_id);

        uint followup_refresh_id = 0;
        followup_refresh_id = Timeout.add (1800, () => {
            untrack_timeout_source (followup_refresh_id);
            if (!is_ui_epoch_valid (epoch)) {
                return false;
            }
            host.refresh_all ();
            return false;
        });
        track_timeout_source (followup_refresh_id);
    }
}
