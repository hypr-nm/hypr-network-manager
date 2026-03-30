public class MainWindowWifiRuntimeController : Object {
    private bool is_disposed = false;
    private bool updating_switches = false;
    private uint switch_refresh_epoch = 1;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};
    private Cancellable? wifi_refresh_cancellable = null;
    private HashTable<string, string> wifi_row_signatures;
    private HashTable<string, WifiNetwork> active_wifi_by_device;
    private string[] wifi_row_order = {};
    private bool wifi_refresh_in_flight = false;
    private bool wifi_refresh_queued = false;

    public MainWindowWifiRuntimeController () {
        wifi_row_signatures = new HashTable<string, string> (str_hash, str_equal);
        active_wifi_by_device = new HashTable<string, WifiNetwork> (str_hash, str_equal);
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
        switch_refresh_epoch++;
        if (switch_refresh_epoch == 0) {
            switch_refresh_epoch = 1;
        }
        updating_switches = false;
        cancel_all_timeout_sources ();
        wifi_row_order = {};
        wifi_row_signatures.remove_all ();
        active_wifi_by_device.remove_all ();
    }

    public bool is_updating_switches () {
        return updating_switches;
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

    private string get_wifi_row_id (WifiNetwork net) {
        return "%s|%s".printf (net.device_path, net.ap_path);
    }

    private string build_wifi_row_signature (
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting
    ) {
        int connected_flag = is_connected_now ? 1 : 0;
        int connecting_flag = is_connecting ? 1 : 0;
        int secured_flag = net.is_secured ? 1 : 0;
        int saved_flag = net.saved ? 1 : 0;
        return "%s|%s|%s|%u|%d|%d|%d|%d|%s|%u|%u|%u|%u|%u|%u|%u|%s|%s".printf (
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

    private bool contains_value (string[] values, string candidate) {
        foreach (var value in values) {
            if (value == candidate) {
                return true;
            }
        }
        return false;
    }

    private void reconcile_wifi_rows (
        Gtk.ListBox wifi_listbox,
        WifiNetwork[] networks,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        string? active_wifi_password_row_id,
        bool has_active_wifi_password_prompt,
        MainWindowActionCallback on_hide_active_wifi_password_prompt,
        MainWindowWifiRowBuildCallback on_build_wifi_row
    ) {
        var visible_rows_by_id = new HashTable<string, Gtk.ListBoxRow> (str_hash, str_equal);
        for (Gtk.Widget? child = wifi_listbox.get_first_child (); child != null; child = child.get_next_sibling ()) {
            var existing_row = child as Gtk.ListBoxRow;
            if (existing_row == null) {
                continue;
            }

            string? existing_row_id = (string?) existing_row.get_data<string> ("nm-row-id");
            if (existing_row_id == null || existing_row_id == "") {
                continue;
            }

            if (!visible_rows_by_id.contains (existing_row_id)) {
                visible_rows_by_id.insert (existing_row_id, existing_row);
            }
        }

        var networks_by_row_id = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        string[] scan_order = {};

        foreach (var net in networks) {
            if (net.ap_path.has_prefix ("saved:")) {
                continue;
            }
            string row_id = get_wifi_row_id (net);
            networks_by_row_id.insert (row_id, net);
            scan_order += row_id;
        }

        bool has_active_prompt_id = has_active_wifi_password_prompt
            && active_wifi_password_row_id != null
            && active_wifi_password_row_id != "";
        bool active_prompt_row_still_present = has_active_prompt_id
            && networks_by_row_id.contains (active_wifi_password_row_id);

        if (has_active_prompt_id && !active_prompt_row_still_present) {
            on_hide_active_wifi_password_prompt ();
        }

        bool keep_stable_order = has_active_prompt_id && active_prompt_row_still_present;
        string[] ordered_row_ids = {};
        if (keep_stable_order) {
            foreach (var existing_id in wifi_row_order) {
                if (networks_by_row_id.contains (existing_id)) {
                    ordered_row_ids += existing_id;
                }
            }
            foreach (var scan_row_id in scan_order) {
                if (!contains_value (ordered_row_ids, scan_row_id)) {
                    ordered_row_ids += scan_row_id;
                }
            }
        } else {
            ordered_row_ids = scan_order;
        }

        foreach (var existing_id in visible_rows_by_id.get_keys ()) {
            if (networks_by_row_id.contains (existing_id)) {
                continue;
            }

            var stale_row = visible_rows_by_id.lookup (existing_id);
            if (stale_row != null && stale_row.get_parent () == wifi_listbox) {
                wifi_listbox.remove (stale_row);
            }
            wifi_row_signatures.remove (existing_id);
        }

        int index = 0;
        foreach (var row_id in ordered_row_ids) {
            var net = networks_by_row_id.lookup (row_id);
            string net_key = net.network_key;
            bool is_connected_now = active_wifi_connections.contains (net_key);
            bool is_connecting = pending_wifi_connect.contains (net_key);
            string new_signature = build_wifi_row_signature (net, is_connected_now, is_connecting);

            var row = visible_rows_by_id.lookup (row_id);
            string? existing_signature = wifi_row_signatures.lookup (row_id);
            bool preserve_prompt_row = active_prompt_row_still_present
                && active_wifi_password_row_id == row_id;
            bool needs_rebuild = row == null || (!preserve_prompt_row && existing_signature != new_signature);

            if (needs_rebuild) {
                bool was_expanded = false;
                if (row != null) {
                    was_expanded = row.get_data<bool> ("nm-actions-expanded");
                }

                var rebuilt_row = on_build_wifi_row (net);
                rebuilt_row.set_data<string> ("nm-row-id", row_id);

                if (was_expanded) {
                    for (Gtk.Widget? child = rebuilt_row.get_first_child ();
                     child != null; child = child.get_next_sibling ()) {
                        var box = child as Gtk.Box;
                        if (box != null) {
                            for (Gtk.Widget? bchild = box.get_first_child ();
                             bchild != null; bchild = bchild.get_next_sibling ()) {
                                var rev = bchild as Gtk.Revealer;
                                if (rev != null && rev.has_css_class ("nm-row-actions-revealer")) {
                                    rev.set_reveal_child (true);
                                    rebuilt_row.set_data<bool> ("nm-actions-expanded", true);
                                    break;
                                }
                            }
                            break;
                        }
                    }
                }

                if (row != null && row.get_parent () == wifi_listbox) {
                    wifi_listbox.remove (row);
                }
                row = rebuilt_row;
                visible_rows_by_id.insert (row_id, row);
                wifi_row_signatures.insert (row_id, new_signature);
            }

            var current_row = wifi_listbox.get_row_at_index (index);
            if (current_row != row) {
                if (row.get_parent () == wifi_listbox) {
                    wifi_listbox.remove (row);
                }
                wifi_listbox.insert (row, index);
            }

            if (!preserve_prompt_row) {
                wifi_row_signatures.insert (row_id, new_signature);
            }

            index++;
        }

        wifi_row_order = ordered_row_ids;
    }

    public void refresh_wifi (
        NetworkManagerClient nm,
        Gtk.Stack wifi_stack,
        Gtk.ListBox wifi_listbox,
        Gtk.Label status_label,
        Gtk.Image status_icon,
        HashTable<string, bool> active_wifi_connections,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        string? active_wifi_password_row_id,
        bool has_active_wifi_password_prompt,
        MainWindowActionCallback on_hide_active_wifi_password_prompt,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowWifiRowBuildCallback on_build_wifi_row,
        MainWindowLogCallback on_log
    ) {
        if (wifi_refresh_in_flight) {
            wifi_refresh_queued = true;
            return;
        }

        wifi_refresh_in_flight = true;
        uint epoch = capture_ui_epoch ();
        on_log ("Refreshing Wi-Fi list");
        string current_view = wifi_stack.get_visible_child_name ();
        on_refresh_switch_states ();

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

                active_wifi_connections.remove_all ();
                active_wifi_by_device.remove_all ();
                foreach (var net in networks) {
                    if (!net.connected) {
                        continue;
                    }

                    uint? device_state = wifi_device_states.lookup (net.device_path);
                    bool is_fully_activated = device_state != null
                        && device_state == NM_DEVICE_STATE_ACTIVATED;
                    if (!is_fully_activated) {
                        continue;
                    }

                    active_wifi_connections.insert (net.network_key, true);
                    if (!active_wifi_by_device.contains (net.device_path)) {
                        active_wifi_by_device.insert (net.device_path, net);
                    }
                    if (primary_connected_ssid == null) {
                        primary_connected_ssid = net.ssid;
                    }
                }

                foreach (var net in networks) {
                    string net_key = net.network_key;
                    if (!pending_wifi_connect.contains (net_key)) {
                        continue;
                    }

                    if (active_wifi_connections.contains (net_key)) {
                        pending_wifi_connect.remove (net_key);
                        pending_wifi_seen_connecting.remove (net_key);
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
                        pending_wifi_seen_connecting.insert (net_key, true);
                        continue;
                    }

                    bool activated_on_other_network = matched_device.state == NM_DEVICE_STATE_ACTIVATED
                        && !active_wifi_connections.contains (net_key);
                    if (activated_on_other_network || matched_device.state == NM_DEVICE_STATE_FAILED) {
                        pending_wifi_connect.remove (net_key);
                        pending_wifi_seen_connecting.remove (net_key);
                        continue;
                    }

                    if (pending_wifi_seen_connecting.contains (net_key)
                        && matched_device.state <= NM_DEVICE_STATE_DISCONNECTED) {
                        pending_wifi_connect.remove (net_key);
                        pending_wifi_seen_connecting.remove (net_key);
                    }
                }

                reconcile_wifi_rows (
                    wifi_listbox,
                    networks,
                    active_wifi_connections,
                    pending_wifi_connect,
                    active_wifi_password_row_id,
                    has_active_wifi_password_prompt,
                    on_hide_active_wifi_password_prompt,
                    on_build_wifi_row
                );

                if (current_view == "details" || current_view == "edit" || current_view == "add" ||
                    current_view == "saved" || current_view == "saved-edit") {
                    // Avoid touching ref parameters from async callbacks.
                    wifi_stack.set_visible_child_name (current_view);
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

                on_log ("Rendered %u Wi-Fi rows".printf (networks.length));
            } catch (Error e) {
                if (e is IOError.CANCELLED || !is_ui_epoch_valid (epoch)) {
                    return;
                }
                on_log ("Wi-Fi refresh failed: " + e.message);
            } finally {
                if (wifi_refresh_cancellable == request_cancellable) {
                    wifi_refresh_cancellable = null;
                }
                wifi_refresh_in_flight = false;

                if (wifi_refresh_queued && is_ui_epoch_valid (epoch)) {
                    // Coalesce repeated refresh requests during in-flight work.
                    // A subsequent timer/signal-triggered refresh will pick up the latest state.
                    wifi_refresh_queued = false;
                }
            }
        });
    }

    public void connect_wifi_with_optional_password (
        NetworkManagerClient nm,
        WifiNetwork net,
        string? password,
        string? hidden_ssid,
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
        uint epoch = capture_ui_epoch ();

        string net_key = net.network_key;
        WifiNetwork? fallback_network = active_wifi_by_device.lookup (net.device_path);
        bool can_fallback_reconnect = fallback_network != null
            && fallback_network.network_key != net_key;

        if (!active_wifi_connections.contains (net_key)) {
            pending_wifi_connect.insert (net_key, true);
            pending_wifi_seen_connecting.remove (net_key);
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
                // Force hidden connect flow to use entered SSID rather than reusing
                // an unrelated saved profile that may have been matched to placeholder rows.
                saved_connection_uuid = "",
                signal = net.signal,
                connected = net.connected,
                is_secured = net.is_secured,
                is_hidden = net.is_hidden,
                saved = false,
                autoconnect = net.autoconnect,
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

        nm.connect_wifi.begin (connect_target, password, null, (obj, res) => {
            try {
                nm.connect_wifi.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }

                if (close_on_connect) {
                    on_close_window ();
                    return;
                }

                on_refresh_after_action (true);

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

                    if (pending_wifi_connect.contains (pending_ssid)) {
                        pending_wifi_connect.remove (pending_ssid);
                        pending_wifi_seen_connecting.remove (pending_ssid);
                        on_refresh_wifi ();
                    }
                    return false;
                });
                track_timeout_source (timeout_id);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                pending_wifi_connect.remove (net_key);
                pending_wifi_seen_connecting.remove (net_key);
                string connect_error_message = e.message;

                if (can_fallback_reconnect) {
                    string fallback_key = fallback_network.network_key;
                    pending_wifi_connect.insert (fallback_key, true);
                    pending_wifi_seen_connecting.remove (fallback_key);

                    nm.connect_wifi.begin (fallback_network, null, null, (obj2, res2) => {
                        try {
                            nm.connect_wifi.end (res2);
                            if (!is_ui_epoch_valid (epoch)) {
                                return;
                            }
                            on_refresh_after_action (true);
                        } catch (Error fallback_error) {
                            if (!is_ui_epoch_valid (epoch)) {
                                return;
                            }
                            pending_wifi_connect.remove (fallback_key);
                            pending_wifi_seen_connecting.remove (fallback_key);
                            on_error (
                                "Connect failed: %s. Reconnect to previous network failed: %s"
                                    .printf (connect_error_message, fallback_error.message)
                            );
                            on_refresh_wifi ();
                        }
                    });
                    return;
                }

                on_error ("Connect failed: " + connect_error_message);
                on_refresh_wifi ();
            }
        });
    }

    public void refresh_after_action (
        NetworkManagerClient nm,
        bool request_wifi_scan,
        MainWindowActionCallback on_refresh_all,
        MainWindowLogCallback on_log
    ) {
        uint epoch = capture_ui_epoch ();

        if (request_wifi_scan) {
            nm.scan_wifi.begin (null, (obj, res) => {
                try {
                    nm.scan_wifi.end (res);
                } catch (Error e) {
                    string message = e.message;
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    on_log ("Could not request Wi-Fi scan: " + message);
                }
            });
        }

        if (!is_ui_epoch_valid (epoch)) {
            return;
        }
        on_refresh_all ();

        // NetworkManager state transitions are async; refresh again shortly after actions.
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
                        on_log ("Could not request delayed Wi-Fi scan: " + message);
                    }
                });
            }
            on_refresh_all ();
            return false;
        });
        track_timeout_source (quick_refresh_id);

        uint followup_refresh_id = 0;
        followup_refresh_id = Timeout.add (1800, () => {
            untrack_timeout_source (followup_refresh_id);
            if (!is_ui_epoch_valid (epoch)) {
                return false;
            }
            on_refresh_all ();
            return false;
        });
        track_timeout_source (followup_refresh_id);
    }

    public void show_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        if (active_wifi_password_revealer != null && active_wifi_password_revealer != revealer) {
            active_wifi_password_revealer.set_reveal_child (false);
        }

        if (active_wifi_password_entry != null && active_wifi_password_entry != entry) {
            active_wifi_password_entry.set_text ("");
        }

        active_wifi_password_revealer = revealer;
        active_wifi_password_entry = entry;
        entry.set_text ("");
        entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        on_set_popup_text_input_mode (true);
        revealer.set_reveal_child (true);
        entry.grab_focus ();
    }

    public void hide_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        string? value,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        revealer.set_reveal_child (false);
        if (value == null) {
            entry.set_text ("");
        }

        if (active_wifi_password_revealer == revealer) {
            active_wifi_password_revealer = null;
            active_wifi_password_entry = null;
            on_set_popup_text_input_mode (false);
        }
    }

    public void hide_active_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        if (active_wifi_password_revealer != null) {
            active_wifi_password_revealer.set_reveal_child (false);
        }
        if (active_wifi_password_entry != null) {
            active_wifi_password_entry.set_text ("");
        }
        active_wifi_password_revealer = null;
        active_wifi_password_entry = null;
        on_set_popup_text_input_mode (false);
    }

    public void refresh_switch_states (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        Gtk.Switch networking_switch,
        MainWindowLogCallback on_log
    ) {
        uint epoch = capture_ui_epoch ();
        uint refresh_epoch = switch_refresh_epoch + 1;
        if (refresh_epoch == 0) {
            refresh_epoch = 1;
        }
        switch_refresh_epoch = refresh_epoch;
        updating_switches = true;

        nm.get_wifi_enabled_dbus.begin (null, (obj, wifi_res) => {
            try {
                bool wifi_enabled = nm.get_wifi_enabled_dbus.end (wifi_res);
                if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                    wifi_switch.set_active (wifi_enabled);
                }
            } catch (Error e) {
                if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                    on_log ("Could not read WirelessEnabled: " + e.message);
                }
            }

            nm.get_networking_enabled_dbus.begin (null, (obj2, net_res) => {
                try {
                    bool net_enabled = nm.get_networking_enabled_dbus.end (net_res);
                    if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                        networking_switch.set_active (net_enabled);
                    }
                } catch (Error e) {
                    if (is_ui_epoch_valid (epoch) && switch_refresh_epoch == refresh_epoch) {
                        on_log ("Could not read NetworkingEnabled: " + e.message);
                    }
                } finally {
                    if (switch_refresh_epoch == refresh_epoch) {
                        updating_switches = false;
                    }
                }
            });
        });
    }

    public void on_wifi_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch wifi_switch,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        if (updating_switches) {
            return;
        }

        uint epoch = capture_ui_epoch ();
        bool enabled = wifi_switch.get_active ();

        nm.set_wifi_enabled.begin (enabled, null, (obj, res) => {
            try {
                nm.set_wifi_enabled.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                on_refresh_after_action (enabled);
            } catch (Error e) {
                string message = e.message;
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                    on_error ("Could not toggle Wi-Fi: " + message);
                on_refresh_switch_states ();
            }
        });
    }

    public void on_networking_switch_changed (
        NetworkManagerClient nm,
        Gtk.Switch networking_switch,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_refresh_switch_states,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        if (updating_switches) {
            return;
        }

        uint epoch = capture_ui_epoch ();
        bool enabled = networking_switch.get_active ();

        nm.set_networking_enabled.begin (enabled, null, (obj, res) => {
            try {
                nm.set_networking_enabled.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                on_refresh_after_action (enabled);
            } catch (Error e) {
                string message = e.message;
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                    on_error ("Could not toggle networking: " + message);
                on_refresh_switch_states ();
            }
        });
    }
}
