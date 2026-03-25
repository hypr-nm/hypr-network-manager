public class MainWindowWifiRuntimeController : Object {
    public static void refresh_wifi(
        NetworkManagerClientVala nm,
        Gtk.Stack wifi_stack,
        Gtk.ListBox wifi_listbox,
        Gtk.Label status_label,
        Gtk.Image status_icon,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        ref WifiNetwork? selected_wifi_network,
        MainWindowActionCallback on_hide_active_wifi_password_prompt,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowWifiRowBuildCallback on_build_wifi_row,
        MainWindowWifiNetworkCallback on_populate_wifi_details,
        MainWindowLogCallback on_log
    ) {
        on_log("Refreshing Wi-Fi list");
        string current_view = wifi_stack.get_visible_child_name();
        on_hide_active_wifi_password_prompt();
        on_refresh_switch_states();

        MainWindowAsyncExecutor.run(() => {
            var networks = nm.get_wifi_networks();
            var devices = nm.get_devices();

            MainWindowAsyncExecutor.dispatch(() => {
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
                        wifi_stack.set_visible_child_name(networks.length() > 0 ? "list" : "empty");
                    }

                    if (networks.length() > 0) {
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
                            status_label.set_text("Wi-Fi available (%u networks)".printf(networks.length()));
                            status_icon.set_from_icon_name("network-wireless-signal-good-symbolic");
                        }
                    } else {
                        status_label.set_text("No Wi-Fi networks found");
                        status_icon.set_from_icon_name("network-wireless-offline-symbolic");
                    }

                    on_log("Rendered %u Wi-Fi rows".printf(networks.length()));
                });
        },
        (message) => {
            on_log("Failed to spawn Wi-Fi refresh thread: " + message);
        });
    }

    public static void connect_wifi_with_optional_password(
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
        if (!active_wifi_connections.contains(net.ssid)) {
            pending_wifi_connect.insert(net.ssid, true);
            pending_wifi_seen_connecting.remove(net.ssid);
        }

        MainWindowAsyncExecutor.run(() => {
            string error_message;
            bool ok = nm.connect_wifi(net, password, out error_message);

            MainWindowAsyncExecutor.dispatch(() => {
                    if (!ok) {
                        pending_wifi_connect.remove(net.ssid);
                        pending_wifi_seen_connecting.remove(net.ssid);
                        on_error("Connect failed: " + error_message);
                        return;
                    }

                    if (close_on_connect) {
                        on_close_window();
                        return;
                    }

                    on_refresh_after_action(true);

                    string pending_ssid = net.ssid;
                    Timeout.add(20000, () => {
                        if (pending_wifi_connect.contains(pending_ssid)) {
                            pending_wifi_connect.remove(pending_ssid);
                            pending_wifi_seen_connecting.remove(pending_ssid);
                            on_refresh_wifi();
                        }
                        return false;
                    });
                });
        },
        (message) => {
            pending_wifi_connect.remove(net.ssid);
            pending_wifi_seen_connecting.remove(net.ssid);
            on_error("Connect failed: " + message);
        });
    }

    public static void refresh_after_action(
        NetworkManagerClientVala nm,
        bool request_wifi_scan,
        MainWindowActionCallback on_refresh_all,
        MainWindowLogCallback on_log
    ) {
        if (request_wifi_scan) {
            MainWindowAsyncExecutor.run(() => {
                string error_message;
                if (!nm.scan_wifi(out error_message)) {
                    MainWindowAsyncExecutor.dispatch(() => {
                        on_log("Could not request Wi-Fi scan: " + error_message);
                    });
                }
            },
            (message) => {
                on_log("Could not spawn Wi-Fi scan thread: " + message);
            });
        }

        on_refresh_all();

        // NetworkManager state transitions are async; refresh again shortly after actions.
        Timeout.add(650, () => {
            if (request_wifi_scan) {
                MainWindowAsyncExecutor.run(() => {
                    string delayed_scan_error;
                    if (!nm.scan_wifi(out delayed_scan_error)) {
                        MainWindowAsyncExecutor.dispatch(() => {
                            on_log("Could not request delayed Wi-Fi scan: " + delayed_scan_error);
                        });
                    }
                },
                (message) => {
                    on_log("Could not spawn delayed Wi-Fi scan thread: " + message);
                });
            }
            on_refresh_all();
            return false;
        });

        Timeout.add(1800, () => {
            on_refresh_all();
            return false;
        });
    }

    public static void show_wifi_password_prompt(
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

    public static void hide_wifi_password_prompt(
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

    public static void hide_active_wifi_password_prompt(
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

    public static void refresh_switch_states(
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

    public static void on_wifi_switch_changed(
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

        bool enabled = wifi_switch.get_active();
        MainWindowAsyncExecutor.run(() => {
            string error_message;
            bool ok = nm.set_wifi_enabled(enabled, out error_message);

            MainWindowAsyncExecutor.dispatch(() => {
                    if (!ok) {
                        on_error("Could not toggle Wi-Fi: " + error_message);
                        on_refresh_switch_states();
                        return;
                    }

                    on_refresh_after_action(enabled);
                });
        },
        (message) => {
            on_error("Could not toggle Wi-Fi: " + message);
            on_refresh_switch_states();
        });
    }

    public static void on_networking_switch_changed(
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

        bool enabled = networking_switch.get_active();
        MainWindowAsyncExecutor.run(() => {
            string error_message;
            bool ok = nm.set_networking_enabled(enabled, out error_message);

            MainWindowAsyncExecutor.dispatch(() => {
                    if (!ok) {
                        on_error("Could not toggle networking: " + error_message);
                        on_refresh_switch_states();
                        return;
                    }

                    on_refresh_after_action(enabled);
                });
        },
        (message) => {
            on_error("Could not toggle networking: " + message);
            on_refresh_switch_states();
        });
    }
}
