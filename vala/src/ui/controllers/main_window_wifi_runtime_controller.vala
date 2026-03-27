public class MainWindowWifiRuntimeController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};
    private Cancellable? wifi_refresh_cancellable = null;
    private HashTable<string, string> wifi_row_signatures;
    private string[] wifi_row_order = {};

    public MainWindowWifiRuntimeController() {
        wifi_row_signatures = new HashTable<string, string>(str_hash, str_equal);
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

    private void invalidate_ui_state() {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_all_timeout_sources();
        wifi_row_order = {};
        wifi_row_signatures.remove_all();
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

    private static string get_wifi_row_id(WifiNetwork net) {
        return "%s|%s".printf(net.device_path, net.ap_path);
    }

    private static string build_wifi_row_signature(
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting
    ) {
        int connected_flag = is_connected_now ? 1 : 0;
        int connecting_flag = is_connecting ? 1 : 0;
        int secured_flag = net.is_secured ? 1 : 0;
        int saved_flag = net.saved ? 1 : 0;
        return "%s|%s|%s|%u|%d|%d|%d|%d|%s|%u|%u|%u|%u|%u|%u|%u|%s|%s".printf(
            net.ssid,
            net.device_path,
            net.ap_path,
            net.signal,
            connected_flag,
            connecting_flag,
            secured_flag,
            saved_flag,
            net.saved_connection_uuid,
            net.frequency_mhz,
            net.max_bitrate_kbps,
            net.mode,
            net.flags,
            net.wpa_flags,
            net.rsn_flags,
            net.connected ? 1u : 0u,
            net.signal_label,
            net.signal_icon_name
        );
    }

    private static bool contains_value(string[] values, string candidate) {
        foreach (var value in values) {
            if (value == candidate) {
                return true;
            }
        }
        return false;
    }

    private void reconcile_wifi_rows(
        Gtk.ListBox wifi_listbox,
        WifiNetwork[] networks,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        string? active_wifi_password_row_id,
        bool has_active_wifi_password_prompt,
        MainWindowActionCallback on_hide_active_wifi_password_prompt,
        MainWindowWifiRowBuildCallback on_build_wifi_row
    ) {
        var visible_rows_by_id = new HashTable<string, Gtk.ListBoxRow>(str_hash, str_equal);
        for (Gtk.Widget? child = wifi_listbox.get_first_child(); child != null; child = child.get_next_sibling()) {
            var existing_row = child as Gtk.ListBoxRow;
            if (existing_row == null) {
                continue;
            }

            string? existing_row_id = (string?) existing_row.get_data<string>("nm-row-id");
            if (existing_row_id == null || existing_row_id == "") {
                continue;
            }

            if (!visible_rows_by_id.contains(existing_row_id)) {
                visible_rows_by_id.insert(existing_row_id, existing_row);
            }
        }

        var networks_by_row_id = new HashTable<string, WifiNetwork>(str_hash, str_equal);
        string[] scan_order = {};

        foreach (var net in networks) {
            string row_id = get_wifi_row_id(net);
            networks_by_row_id.insert(row_id, net);
            scan_order += row_id;
        }

        bool has_active_prompt_id = has_active_wifi_password_prompt
            && active_wifi_password_row_id != null
            && active_wifi_password_row_id != "";
        bool active_prompt_row_still_present = has_active_prompt_id
            && networks_by_row_id.contains(active_wifi_password_row_id);

        if (has_active_prompt_id && !active_prompt_row_still_present) {
            on_hide_active_wifi_password_prompt();
        }

        bool keep_stable_order = has_active_prompt_id && active_prompt_row_still_present;
        string[] ordered_row_ids = {};
        if (keep_stable_order) {
            foreach (var existing_id in wifi_row_order) {
                if (networks_by_row_id.contains(existing_id)) {
                    ordered_row_ids += existing_id;
                }
            }
            foreach (var scan_row_id in scan_order) {
                if (!contains_value(ordered_row_ids, scan_row_id)) {
                    ordered_row_ids += scan_row_id;
                }
            }
        } else {
            ordered_row_ids = scan_order;
        }

        foreach (var existing_id in visible_rows_by_id.get_keys()) {
            if (networks_by_row_id.contains(existing_id)) {
                continue;
            }

            var stale_row = visible_rows_by_id.lookup(existing_id);
            if (stale_row != null && stale_row.get_parent() == wifi_listbox) {
                wifi_listbox.remove(stale_row);
            }
            wifi_row_signatures.remove(existing_id);
        }

        int index = 0;
        foreach (var row_id in ordered_row_ids) {
            var net = networks_by_row_id.lookup(row_id);
            string net_key = net.network_key;
            bool is_connected_now = active_wifi_connections.contains(net_key);
            bool is_connecting = pending_wifi_connect.contains(net_key);
            string new_signature = build_wifi_row_signature(net, is_connected_now, is_connecting);

            var row = visible_rows_by_id.lookup(row_id);
            string? existing_signature = wifi_row_signatures.lookup(row_id);
            bool preserve_prompt_row = active_prompt_row_still_present
                && active_wifi_password_row_id == row_id;
            bool needs_rebuild = row == null || (!preserve_prompt_row && existing_signature != new_signature);

            if (needs_rebuild) {
                var rebuilt_row = on_build_wifi_row(net);
                rebuilt_row.set_data<string>("nm-row-id", row_id);
                if (row != null && row.get_parent() == wifi_listbox) {
                    wifi_listbox.remove(row);
                }
                row = rebuilt_row;
                visible_rows_by_id.insert(row_id, row);
                wifi_row_signatures.insert(row_id, new_signature);
            }

            var current_row = wifi_listbox.get_row_at_index(index);
            if (current_row != row) {
                if (row.get_parent() == wifi_listbox) {
                    wifi_listbox.remove(row);
                }
                wifi_listbox.insert(row, index);
            }

            if (!preserve_prompt_row) {
                wifi_row_signatures.insert(row_id, new_signature);
            }

            index++;
        }

        wifi_row_order = ordered_row_ids;
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
        string? active_wifi_password_row_id,
        bool has_active_wifi_password_prompt,
        owned MainWindowActionCallback on_hide_active_wifi_password_prompt,
        owned MainWindowActionCallback on_refresh_switch_states,
        owned MainWindowWifiRowBuildCallback on_build_wifi_row,
        owned MainWindowLogCallback on_log
    ) {
        uint epoch = capture_ui_epoch();
        on_log("Refreshing Wi-Fi list");
        string current_view = wifi_stack.get_visible_child_name();
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

                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }

                string? primary_connected_ssid = null;

                active_wifi_connections.remove_all();
                foreach (var net in networks) {
                    if (!net.connected) {
                        continue;
                    }
                    active_wifi_connections.insert(net.network_key, true);
                    if (primary_connected_ssid == null) {
                        primary_connected_ssid = net.ssid;
                    }
                }

                foreach (var net in networks) {
                    string net_key = net.network_key;
                    if (!pending_wifi_connect.contains(net_key)) {
                        continue;
                    }

                    if (active_wifi_connections.contains(net_key)) {
                        pending_wifi_connect.remove(net_key);
                        pending_wifi_seen_connecting.remove(net_key);
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
                        pending_wifi_seen_connecting.insert(net_key, true);
                        continue;
                    }

                    if (pending_wifi_seen_connecting.contains(net_key)
                        && matched_device.state <= NM_DEVICE_STATE_DISCONNECTED) {
                        pending_wifi_connect.remove(net_key);
                        pending_wifi_seen_connecting.remove(net_key);
                    }
                }

                reconcile_wifi_rows(
                    wifi_listbox,
                    networks,
                    active_wifi_connections,
                    pending_wifi_connect,
                    active_wifi_password_row_id,
                    has_active_wifi_password_prompt,
                    on_hide_active_wifi_password_prompt,
                    on_build_wifi_row
                );

                if (current_view == "details" || current_view == "edit" || current_view == "add") {
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
        uint pending_wifi_connect_timeout_ms,
        bool close_on_connect,
        MainWindowActionCallback on_close_window,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_refresh_wifi,
        MainWindowErrorCallback on_error
    ) {
        uint epoch = capture_ui_epoch();

        string net_key = net.network_key;
        if (!active_wifi_connections.contains(net_key)) {
            pending_wifi_connect.insert(net_key, true);
            pending_wifi_seen_connecting.remove(net_key);
        }

        nm.connect_wifi.begin(net, password, null, (obj, res) => {
            try {
                nm.connect_wifi.end(res);
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }

                if (close_on_connect) {
                    on_close_window();
                    return;
                }

                on_refresh_after_action(true);

                string pending_ssid = net_key;
                uint effective_timeout_ms = pending_wifi_connect_timeout_ms >= 1000
                    ? pending_wifi_connect_timeout_ms
                    : 1000;
                uint timeout_id = 0;
                timeout_id = Timeout.add(effective_timeout_ms, () => {
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
            } catch (Error e) {
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                pending_wifi_connect.remove(net_key);
                pending_wifi_seen_connecting.remove(net_key);
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
                    if (!is_ui_epoch_valid(epoch)) {
                        return;
                    }
                    on_log("Could not request Wi-Fi scan: " + message);
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
                        if (!is_ui_epoch_valid(epoch)) {
                            return;
                        }
                        on_log("Could not request delayed Wi-Fi scan: " + message);
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
        entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
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
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                on_refresh_after_action(enabled);
            } catch (Error e) {
                string message = e.message;
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                    on_error("Could not toggle Wi-Fi: " + message);
                on_refresh_switch_states();
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
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                on_refresh_after_action(enabled);
            } catch (Error e) {
                string message = e.message;
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                    on_error("Could not toggle networking: " + message);
                on_refresh_switch_states();
            }
        });
    }
}
