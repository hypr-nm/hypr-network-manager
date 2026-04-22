public class MainWindowWifiRefreshController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private Cancellable? wifi_refresh_cancellable = null;
    public HashTable<string, WifiNetwork> active_wifi_by_device;
    private bool wifi_refresh_in_flight = false;
    private bool wifi_refresh_queued = false;
    private MainWindowWifiRowReconciler row_reconciler;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;

    public MainWindowWifiRefreshController (HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context) {
        this.host = host;
        this.state_context = state_context;
        active_wifi_by_device = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        row_reconciler = new MainWindowWifiRowReconciler (host, state_context);
    }

    public void on_page_leave () {
        cancel_wifi_refresh ();
        invalidate_ui_state ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        cancel_wifi_refresh ();
        invalidate_ui_state ();
    }

    private void cancel_wifi_refresh () {
        if (wifi_refresh_cancellable != null) {
            wifi_refresh_cancellable.cancel ();
            wifi_refresh_cancellable = null;
        }
        wifi_refresh_in_flight = false;
        wifi_refresh_queued = false;
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
        row_reconciler.reset ();
        active_wifi_by_device.remove_all ();
    }

    public void refresh_wifi (
        NetworkManagerClient nm,
        Gtk.Stack wifi_stack,
        Gtk.ListBox wifi_listbox,
        Gtk.Label status_label,
        Gtk.Image status_icon,
        string? active_wifi_password_row_id,
        bool has_active_wifi_password_prompt,
        IMainWindowWifiRowProvider row_provider
    ) {
        if (wifi_refresh_in_flight) {
            wifi_refresh_queued = true;
            return;
        }

        wifi_refresh_in_flight = true;
        uint epoch = capture_ui_epoch ();
        host.debug_log ("Refreshing Wi-Fi list");

        var request_cancellable = new Cancellable ();
        wifi_refresh_cancellable = request_cancellable;

        nm.get_wifi_refresh_data.begin (request_cancellable, (obj, res) => {
            try {
                var refresh_data = nm.get_wifi_refresh_data.end (res);
                if (wifi_refresh_cancellable != request_cancellable) {
                    return;
                }

                WifiNetwork[] networks = refresh_data.networks;
                NetworkDevice[] devices = refresh_data.devices;

                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }

                string? primary_connected_ssid = null;

                var wifi_device_states = new HashTable<string, uint> (str_hash, str_equal);
                foreach (var dev in devices) {
                    if (!dev.is_wifi) {
                        continue;
                    }
                    wifi_device_states.insert (dev.device_path, dev.state);
                }

                var current_network_keys = new HashTable<string, bool> (str_hash, str_equal);
                var old_active = new HashTable<string, bool> (str_hash, str_equal);
                foreach (var k in state_context.active_wifi_connections.get_keys ()) {
                    old_active.insert (k, true);
                }

                state_context.active_wifi_connections.remove_all ();
                active_wifi_by_device.remove_all ();

                foreach (var net in networks) {
                    current_network_keys.insert (net.network_key, true);
                    if (!net.connected) {
                        continue;
                    }

                    uint? device_state = wifi_device_states.lookup (net.device_path);
                    bool is_fully_activated = device_state != null
                        && device_state == NM_DEVICE_STATE_ACTIVATED;
                    if (!is_fully_activated) {
                        continue;
                    }

                    state_context.active_wifi_connections.insert (net.network_key, true);
                    if (!old_active.contains (net.network_key)) {
                        state_context.clear_all_wifi_errors ();
                    }

                    if (!active_wifi_by_device.contains (net.device_path)) {
                        active_wifi_by_device.insert (net.device_path, net);
                    }
                    if (primary_connected_ssid == null) {
                        primary_connected_ssid = net.ssid;
                    }
                }

                var keys_to_remove = new List<string> ();
                foreach (var err_key in state_context.wifi_errors.get_keys ()) {
                    if (!current_network_keys.contains (err_key)) {
                        keys_to_remove.append (err_key);
                    }
                }
                foreach (var stale_key in keys_to_remove) {
                    state_context.clear_wifi_error (stale_key);
                }

                foreach (var net in networks) {
                    string net_key = net.network_key;
                    if (!state_context.pending_wifi_connect.contains (net_key)) {
                        continue;
                    }

                    if (state_context.active_wifi_connections.contains (net_key)) {
                        bool was_pending = state_context.pending_wifi_connect.contains (net_key);
                        state_context.pending_wifi_connect.remove (net_key);
                        state_context.pending_wifi_seen_connecting.remove (net_key);
                        if (was_pending) {
                            state_context.clear_all_wifi_errors ();
                        }
                        continue;
                    }

                    NetworkDevice? matched_device = null;
                    foreach (var dev in devices) {
                        if (dev.is_wifi && dev.device_path == net.device_path) {
                            matched_device = dev;
                            break;
                        }
                    }

                    if (matched_device == null) {
                        continue;
                    }

                    bool is_connecting_state = matched_device.state >= 40
                        && matched_device.state < NM_DEVICE_STATE_ACTIVATED;
                    if (is_connecting_state) {
                        state_context.pending_wifi_seen_connecting.insert (net_key, true);
                        continue;
                    }

                    bool activated_on_other_network = matched_device.state == NM_DEVICE_STATE_ACTIVATED
                        && !state_context.active_wifi_connections.contains (net_key);
                    if (activated_on_other_network || matched_device.state == NM_DEVICE_STATE_FAILED) {
                        state_context.pending_wifi_connect.remove (net_key);
                        state_context.pending_wifi_seen_connecting.remove (net_key);
                        state_context.mark_wifi_error (net_key, "Connection failed or interrupted.");
                        continue;
                    }

                    if (state_context.pending_wifi_seen_connecting.contains (net_key)
                        && matched_device.state <= NM_DEVICE_STATE_DISCONNECTED) {
                        state_context.pending_wifi_connect.remove (net_key);
                        state_context.pending_wifi_seen_connecting.remove (net_key);
                        state_context.mark_wifi_error (net_key, "Connection failed.");
                    }
                }

                row_reconciler.reconcile (
                    wifi_listbox,
                    networks,
                    active_wifi_password_row_id,
                    has_active_wifi_password_prompt,
                    row_provider
                );

                string current_actual_view = wifi_stack.get_visible_child_name ();
                if (current_actual_view == "details" || current_actual_view == "edit" || current_actual_view == "add" ||
                    current_actual_view == "saved" || current_actual_view == "saved-edit" ||
                    current_actual_view == "wifi-disabled" || current_actual_view == "flight-mode") {
                    // Leave the stack on the current user-facing page
                } else {
                    wifi_stack.set_visible_child_name (networks.length > 0 ? "list" : "empty");
                }

                if (networks.length > 0) {
                    WifiNetwork? connected = null;
                    if (primary_connected_ssid != null) {
                        foreach (var net in networks) {
                            if (net.ssid == primary_connected_ssid) {
                                connected = net;
                                break;
                            }
                        }
                    }

                    if (connected != null) {
                        status_label.set_text ("Wi-Fi · %s (%u%%)".printf (connected.ssid, connected.signal));
                        status_icon.set_from_icon_name (connected.signal_icon_name);
                    } else if (primary_connected_ssid != null) {
                        status_label.set_text ("Wi-Fi · %s".printf (primary_connected_ssid));
                        status_icon.set_from_icon_name ("network-wireless-signal-good-symbolic");
                    } else {
                        status_label.set_text ("Wi-Fi available (%u networks)".printf (networks.length));
                        status_icon.set_from_icon_name ("network-wireless-signal-good-symbolic");
                    }
                } else {
                    status_label.set_text ("No Wi-Fi networks found");
                    status_icon.set_from_icon_name ("network-wireless-offline-symbolic");
                }

                host.debug_log ("Rendered %u Wi-Fi rows".printf (networks.length));
            } catch (Error e) {
                if (e is IOError.CANCELLED || !is_ui_epoch_valid (epoch)) {
                    return;
                }
                host.debug_log ("Wi-Fi refresh failed: " + e.message);
            } finally {
                if (wifi_refresh_cancellable == request_cancellable) {
                    wifi_refresh_cancellable = null;
                }
                wifi_refresh_in_flight = false;

                if (wifi_refresh_queued && is_ui_epoch_valid (epoch)) {
                    wifi_refresh_queued = false;
                }
            }
        });
    }
}
