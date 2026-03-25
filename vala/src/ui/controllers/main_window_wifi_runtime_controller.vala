public class MainWindowWifiRuntimeController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};
    private Cancellable? wifi_refresh_cancellable = null;

    public MainWindowWifiRuntimeController() {
    }

    public void on_page_leave() {
        cancel_wifi_refresh();
        invalidate_ui_state();
    }

    public void dispose_controller() {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        cancel_wifi_refresh();
        invalidate_ui_state();
    }

    private void cancel_wifi_refresh() {
        if (wifi_refresh_cancellable != null) {
            wifi_refresh_cancellable.cancel();
            wifi_refresh_cancellable = null;
        }
    }

    private uint capture_ui_epoch() {
        return ui_epoch;
    }

    private bool is_ui_epoch_valid(uint epoch) {
        return !is_disposed && epoch == ui_epoch;
    }

    private void dispatch_ui(owned MainWindowActionCallback action, uint epoch) {
        if (!is_ui_epoch_valid(epoch)) {
            return;
        }
        action();
    }

    private void invalidate_ui_state() {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_all_timeout_sources();
    }

    private void track_timeout_source(uint source_id) {
        if (source_id == 0) {
            return;
        }
        timeout_source_ids += source_id;
    }

    private void untrack_timeout_source(uint source_id) {
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

    private void cancel_all_timeout_sources() {
        if (timeout_source_ids.length == 0) {
            return;
        }

        foreach (uint source_id in timeout_source_ids) {
            Source.remove(source_id);
        }
        timeout_source_ids = {};
    }

    public void refresh_wifi(
        NetworkManagerClientVala nm,
        Gtk.Stack wifi_stack,
        Gtk.ListBox wifi_listbox,
        Gtk.Label status_label,
        Gtk.Image status_icon,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        MainWindowActionCallback on_hide_active_wifi_password_prompt,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowWifiRowBuildCallback on_build_wifi_row,
        MainWindowLogCallback on_log
    ) {
        uint epoch = capture_ui_epoch();
        on_log("Refreshing Wi-Fi list");
        string current_view = wifi_stack.get_visible_child_name();
        on_hide_active_wifi_password_prompt();
        on_refresh_switch_states();

        cancel_wifi_refresh();
        var request_cancellable = new Cancellable();
        wifi_refresh_cancellable = request_cancellable;

        nm.get_wifi_refresh_data.begin(request_cancellable, (obj, res) => {
            try {
                var refresh_data = nm.get_wifi_refresh_data.end(res);
                if (wifi_refresh_cancellable != request_cancellable) {
                    return;
                }

                WifiNetwork[] networks = refresh_data.networks;
                NetworkDevice[] devices = refresh_data.devices;

                dispatch_ui(() => {
                    string? primary_connected_ssid = null;

                    active_wifi_connections.remove_all();
                    foreach (var dev in devices) {
                        if (!dev.is_wifi || !dev.is_connected || dev.connection == "") {
                            continue;
                        }
                        active_wifi_connections.insert(dev.connection, true);
                        if (primary_connected_ssid == null) {
                            primary_connected_ssid = dev.connection;
                        }
                    }

                    foreach (var net in networks) {
                        if (!pending_wifi_connect.contains(net.ssid)) {
                            continue;
                        }

                        if (active_wifi_connections.contains(net.ssid)) {
                            pending_wifi_connect.remove(net.ssid);
                            pending_wifi_seen_connecting.remove(net.ssid);
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
                            pending_wifi_seen_connecting.insert(net.ssid, true);
                            continue;
                        }

                        if (pending_wifi_seen_connecting.contains(net.ssid)) {
                            pending_wifi_connect.remove(net.ssid);
                            pending_wifi_seen_connecting.remove(net.ssid);
                        }
                    }

                    MainWindowHelpers.clear_listbox(wifi_listbox);
                    foreach (var net in networks) {
                        wifi_listbox.append(on_build_wifi_row(net));
                    }

                    if (current_view == "details" || current_view == "edit") {
                        // Avoid touching ref parameters from async callbacks.
                        wifi_stack.set_visible_child_name(current_view);
                    } else {
                        wifi_stack.set_visible_child_name(networks.length > 0 ? "list" : "empty");
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
                            status_label.set_text("Wi-Fi · %s (%u%%)".printf(connected.ssid, connected.signal));
                            status_icon.set_from_icon_name(connected.signal_icon_name);
                        } else if (primary_connected_ssid != null) {
                            status_label.set_text("Wi-Fi · %s".printf(primary_connected_ssid));
                            status_icon.set_from_icon_name("network-wireless-signal-good-symbolic");
                        } else {
                            status_label.set_text("Wi-Fi available (%u networks)".printf(networks.length));
                            status_icon.set_from_icon_name("network-wireless-signal-good-symbolic");
                        }
                    } else {
                        status_label.set_text("No Wi-Fi networks found");
                        status_icon.set_from_icon_name("network-wireless-offline-symbolic");
                    }

                    on_log("Rendered %u Wi-Fi rows".printf(networks.length));
                }, epoch);
            } catch (Error e) {
                if (e is IOError.CANCELLED || !is_ui_epoch_valid(epoch)) {
                    return;
                }
                on_log("Wi-Fi refresh failed: " + e.message);
            } finally {
                if (wifi_refresh_cancellable == request_cancellable) {
                    wifi_refresh_cancellable = null;
                }
            }
        });
    }

    public void connect_wifi_with_optional_password(
        NetworkManagerClientVala nm,
        WifiNetwork net,
        string? password,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        bool close_on_connect,
        MainWindowActionCallback on_close_window,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_refresh_wifi,
        MainWindowErrorCallback on_error
    ) {
        uint epoch = capture_ui_epoch();

        if (!active_wifi_connections.contains(net.ssid)) {
            pending_wifi_connect.insert(net.ssid, true);
            pending_wifi_seen_connecting.remove(net.ssid);
        }

        nm.connect_wifi.begin(net, password, null, (obj, res) => {
            try {
                nm.connect_wifi.end(res);
                dispatch_ui(() => {
                        if (close_on_connect) {
                            on_close_window();
                            return;
                        }

                        on_refresh_after_action(true);

                        string pending_ssid = net.ssid;
                        uint timeout_id = 0;
                        timeout_id = Timeout.add(20000, () => {
                            untrack_timeout_source(timeout_id);
                            if (!is_ui_epoch_valid(epoch)) {
                                return false;
                            }

                            if (pending_wifi_connect.contains(pending_ssid)) {
                                pending_wifi_connect.remove(pending_ssid);
                                pending_wifi_seen_connecting.remove(pending_ssid);
                                on_refresh_wifi();
                            }
                            return false;
                        });
                        track_timeout_source(timeout_id);
                    }, epoch);
            } catch (Error e) {
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                pending_wifi_connect.remove(net.ssid);
                pending_wifi_seen_connecting.remove(net.ssid);
                on_error("Connect failed: " + e.message);
            }
        });
    }

    public void refresh_after_action(
        NetworkManagerClientVala nm,
        bool request_wifi_scan,
        MainWindowActionCallback on_refresh_all,
        MainWindowLogCallback on_log
    ) {
        uint epoch = capture_ui_epoch();

        if (request_wifi_scan) {
            nm.scan_wifi.begin(null, (obj, res) => {
                try {
                    nm.scan_wifi.end(res);
                } catch (Error e) {
                    string message = e.message;
                    dispatch_ui(() => {
                        on_log("Could not request Wi-Fi scan: " + message);
                    }, epoch);
                }
            });
        }

        if (!is_ui_epoch_valid(epoch)) {
            return;
        }
        on_refresh_all();

        // NetworkManager state transitions are async; refresh again shortly after actions.
        uint quick_refresh_id = 0;
        quick_refresh_id = Timeout.add(650, () => {
            untrack_timeout_source(quick_refresh_id);
            if (!is_ui_epoch_valid(epoch)) {
                return false;
            }

            if (request_wifi_scan) {
                nm.scan_wifi.begin(null, (obj, res) => {
                    try {
                        nm.scan_wifi.end(res);
                    } catch (Error e) {
                        string message = e.message;
                        dispatch_ui(() => {
                            on_log("Could not request delayed Wi-Fi scan: " + message);
                        }, epoch);
                    }
                });
            }
            on_refresh_all();
            return false;
        });
        track_timeout_source(quick_refresh_id);

        uint followup_refresh_id = 0;
        followup_refresh_id = Timeout.add(1800, () => {
            untrack_timeout_source(followup_refresh_id);
            if (!is_ui_epoch_valid(epoch)) {
                return false;
            }
            on_refresh_all();
            return false;
        });
        track_timeout_source(followup_refresh_id);
    }

    public void show_wifi_password_prompt(
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        if (active_wifi_password_revealer != null && active_wifi_password_revealer != revealer) {
            active_wifi_password_revealer.set_reveal_child(false);
        }

        if (active_wifi_password_entry != null && active_wifi_password_entry != entry) {
            active_wifi_password_entry.set_text("");
        }

        active_wifi_password_revealer = revealer;
        active_wifi_password_entry = entry;
        entry.set_text("");
        on_set_popup_text_input_mode(true);
        revealer.set_reveal_child(true);
        entry.grab_focus();
    }

    public void hide_wifi_password_prompt(
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        string? value,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        revealer.set_reveal_child(false);
        if (value == null) {
            entry.set_text("");
        }

        if (active_wifi_password_revealer == revealer) {
            active_wifi_password_revealer = null;
            active_wifi_password_entry = null;
            on_set_popup_text_input_mode(false);
        }
    }

    public void hide_active_wifi_password_prompt(
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        if (active_wifi_password_revealer != null) {
            active_wifi_password_revealer.set_reveal_child(false);
        }
        if (active_wifi_password_entry != null) {
            active_wifi_password_entry.set_text("");
        }
        active_wifi_password_revealer = null;
        active_wifi_password_entry = null;
        on_set_popup_text_input_mode(false);
    }

    public void refresh_switch_states(
        NetworkManagerClientVala nm,
        Gtk.Switch wifi_switch,
        Gtk.Switch networking_switch,
        ref bool updating_switches,
        MainWindowLogCallback on_log
    ) {
        bool wifi_enabled;
        bool net_enabled;
        string error_message;

        updating_switches = true;

        if (nm.get_wifi_enabled(out wifi_enabled, out error_message)) {
            wifi_switch.set_active(wifi_enabled);
        } else {
            on_log("Could not read WirelessEnabled: " + error_message);
        }

        if (nm.get_networking_enabled(out net_enabled, out error_message)) {
            networking_switch.set_active(net_enabled);
        } else {
            on_log("Could not read NetworkingEnabled: " + error_message);
        }

        updating_switches = false;
    }

    public void on_wifi_switch_changed(
        NetworkManagerClientVala nm,
        Gtk.Switch wifi_switch,
        bool updating_switches,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        if (updating_switches) {
            return;
        }

        uint epoch = capture_ui_epoch();
        bool enabled = wifi_switch.get_active();

        nm.set_wifi_enabled.begin(enabled, null, (obj, res) => {
            try {
            nm.set_wifi_enabled.end(res);
                dispatch_ui(() => {
                        on_refresh_after_action(enabled);
                    }, epoch);
            } catch (Error e) {
                string message = e.message;
                dispatch_ui(() => {
                    on_error("Could not toggle Wi-Fi: " + message);
                        on_refresh_switch_states();
                    }, epoch);
            }
        });
    }

    public void on_networking_switch_changed(
        NetworkManagerClientVala nm,
        Gtk.Switch networking_switch,
        bool updating_switches,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        if (updating_switches) {
            return;
        }

        uint epoch = capture_ui_epoch();
        bool enabled = networking_switch.get_active();

        nm.set_networking_enabled.begin(enabled, null, (obj, res) => {
            try {
            nm.set_networking_enabled.end(res);
                dispatch_ui(() => {
                        on_refresh_after_action(enabled);
                    }, epoch);
            } catch (Error e) {
                string message = e.message;
                dispatch_ui(() => {
                    on_error("Could not toggle networking: " + message);
                        on_refresh_switch_states();
                    }, epoch);
            }
        });
    }
}
