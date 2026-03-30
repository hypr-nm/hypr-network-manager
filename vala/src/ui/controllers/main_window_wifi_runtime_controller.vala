public class MainWindowWifiRuntimeController : Object {
    private bool is_disposed = false;
    private bool updating_switches = false;
    private uint switch_refresh_epoch = 1;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};
    private Cancellable? wifi_refresh_cancellable = null;
    private Cancellable? add_network_cancellable = null;
    private Cancellable? saved_profiles_cancellable = null;
    private Cancellable? saved_profile_settings_cancellable = null;
    private Cancellable? saved_profile_update_cancellable = null;
    private HashTable<string, WifiNetwork> active_wifi_by_device;
    private bool wifi_refresh_in_flight = false;
    private bool wifi_refresh_queued = false;
    private MainWindowWifiDetailsEditController details_edit_controller;
    private MainWindowWifiRowReconciler row_reconciler;

    public MainWindowWifiRuntimeController () {
        active_wifi_by_device = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        details_edit_controller = new MainWindowWifiDetailsEditController ();
        row_reconciler = new MainWindowWifiRowReconciler ();
    }

    public void on_page_leave () {
        cancel_add_network_request ();
        cancel_saved_profile_requests ();
        cancel_wifi_refresh ();
        details_edit_controller.on_page_leave ();
        invalidate_ui_state ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        cancel_add_network_request ();
        cancel_saved_profile_requests ();
        cancel_wifi_refresh ();
        details_edit_controller.dispose_controller ();
        invalidate_ui_state ();
    }

    private bool is_cancelled_error (Error e) {
        return e is IOError.CANCELLED;
    }

    private void cancel_add_network_request () {
        if (add_network_cancellable != null) {
            add_network_cancellable.cancel ();
            add_network_cancellable = null;
        }
    }

    private void cancel_saved_profiles_request () {
        if (saved_profiles_cancellable != null) {
            saved_profiles_cancellable.cancel ();
            saved_profiles_cancellable = null;
        }
    }

    private void cancel_saved_profile_settings_request () {
        if (saved_profile_settings_cancellable != null) {
            saved_profile_settings_cancellable.cancel ();
            saved_profile_settings_cancellable = null;
        }
    }

    private void cancel_saved_profile_update_request () {
        if (saved_profile_update_cancellable != null) {
            saved_profile_update_cancellable.cancel ();
            saved_profile_update_cancellable = null;
        }
    }

    private void cancel_saved_profile_requests () {
        cancel_saved_profiles_request ();
        cancel_saved_profile_settings_request ();
        cancel_saved_profile_update_request ();
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
        row_reconciler.reset ();
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

                row_reconciler.reconcile (
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

    public void sync_add_network_sensitivity (
        Gtk.DropDown? wifi_add_security_dropdown,
        Gtk.Entry? wifi_add_password_entry,
        Gtk.Button? wifi_add_connect_button = null
    ) {
        if (wifi_add_security_dropdown == null || wifi_add_password_entry == null) {
            return;
        }

        HiddenWifiSecurityMode mode = HiddenWifiSecurityModeUtils.from_dropdown_index (
            wifi_add_security_dropdown.get_selected ()
        );
        bool secured = HiddenWifiSecurityModeUtils.requires_password (mode);
        wifi_add_password_entry.set_sensitive (secured);
        if (!secured) {
            wifi_add_password_entry.set_text ("");
        }

        if (wifi_add_connect_button != null) {
            bool can_connect = HiddenWifiSecurityModeUtils.is_password_valid_for_mode (
                mode,
                wifi_add_password_entry.get_text ()
            );
            wifi_add_connect_button.set_sensitive (can_connect);
        }
    }

    public void open_add_network (
        Gtk.Stack wifi_stack,
        Gtk.Entry wifi_add_ssid_entry,
        Gtk.DropDown wifi_add_security_dropdown,
        Gtk.Entry wifi_add_password_entry,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        cancel_add_network_request ();
        wifi_add_ssid_entry.set_text ("");
        wifi_add_security_dropdown.set_selected (
            HiddenWifiSecurityModeUtils.to_dropdown_index (HiddenWifiSecurityMode.WPA_PSK)
        );
        wifi_add_password_entry.set_text ("");
        sync_add_network_sensitivity (
            wifi_add_security_dropdown,
            wifi_add_password_entry
        );

        wifi_stack.set_visible_child_name ("add");
        on_set_popup_text_input_mode (true);
        wifi_add_ssid_entry.grab_focus ();
    }

    public void apply_add_network (
        NetworkManagerClient nm,
        Gtk.Stack wifi_stack,
        Gtk.Entry wifi_add_ssid_entry,
        Gtk.DropDown wifi_add_security_dropdown,
        Gtk.Entry wifi_add_password_entry,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        string ssid = wifi_add_ssid_entry.get_text ().strip ();
        HiddenWifiSecurityMode security_mode = HiddenWifiSecurityModeUtils.from_dropdown_index (
            wifi_add_security_dropdown.get_selected ()
        );
        string password = wifi_add_password_entry.get_text ().strip ();

        if (ssid == "") {
            on_error ("SSID is required.");
            return;
        }

        if (!HiddenWifiSecurityModeUtils.is_password_valid_for_mode (security_mode, password)) {
            on_error (
                "Password must be at least %d characters for the selected security mode.".printf (
                    HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH
                )
            );
            return;
        }

        uint epoch = capture_ui_epoch ();
        cancel_add_network_request ();
        add_network_cancellable = new Cancellable ();
        var add_request = add_network_cancellable;

        nm.connect_hidden_wifi.begin (ssid, security_mode, password, add_request, (obj, res) => {
            try {
                nm.connect_hidden_wifi.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                on_refresh_after_action (true);
                wifi_stack.set_visible_child_name ("list");
                on_set_popup_text_input_mode (false);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                    return;
                }
                on_error ("Add hidden network failed: " + e.message);
            }
        });
    }

    public void forget_wifi_network (
        NetworkManagerClient nm,
        WifiNetwork net,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        uint epoch = capture_ui_epoch ();
        string profile_uuid = net.saved_connection_uuid.strip ();
        string network_key = net.network_key;

        nm.forget_network.begin (profile_uuid, network_key, null, (obj, res) => {
            try {
                nm.forget_network.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                on_refresh_after_action (true);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                    return;
                }
                on_error ("Forget failed: " + e.message);
            }
        });
    }

    public void disconnect_wifi_network (
        NetworkManagerClient nm,
        WifiNetwork net,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        uint epoch = capture_ui_epoch ();
        string wifi_key = net.network_key;
        pending_wifi_connect.remove (wifi_key);
        pending_wifi_seen_connecting.remove (wifi_key);

        nm.disconnect_wifi.begin (net, null, (obj, res) => {
            try {
                nm.disconnect_wifi.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                on_refresh_after_action (false);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                    return;
                }
                on_error ("Disconnect failed: " + e.message);
                on_refresh_after_action (false);
            }
        });
    }

    public void set_wifi_network_autoconnect (
        NetworkManagerClient nm,
        WifiNetwork net,
        bool enabled,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_refresh_wifi
    ) {
        uint epoch = capture_ui_epoch ();
        nm.set_wifi_network_autoconnect.begin (net, enabled, 10, null, (obj, res) => {
            try {
                nm.set_wifi_network_autoconnect.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                on_refresh_after_action (false);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                    return;
                }
                on_error ("Could not update auto-connect: " + e.message);
                on_refresh_wifi ();
            }
        });
    }

    public void refresh_saved_wifi_profiles (
        NetworkManagerClient nm,
        MainWindowWifiSavedPage page,
        MainWindowErrorCallback on_error
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_saved_profiles_request ();
        saved_profiles_cancellable = new Cancellable ();
        var list_request = saved_profiles_cancellable;

        nm.get_saved_wifi_profiles.begin (list_request, (obj, res) => {
            try {
                var saved_profiles = nm.get_saved_wifi_profiles.end (res);
                if (!is_ui_epoch_valid (epoch) || saved_profiles_cancellable != list_request) {
                    return;
                }
                page.set_networks (saved_profiles);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)
                    || saved_profiles_cancellable != list_request
                    || is_cancelled_error (e)) {
                    return;
                }
                on_error ("Could not load saved networks: " + e.message);
            }
        });
    }

    public void load_saved_wifi_profile_settings (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        MainWindowWifiSavedEditPage page,
        MainWindowActionCallback on_sync_sensitivity,
        MainWindowErrorCallback on_error
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_saved_profile_settings_request ();
        saved_profile_settings_cancellable = new Cancellable ();
        var settings_request = saved_profile_settings_cancellable;

        nm.get_saved_wifi_profile_settings.begin (profile, settings_request, (obj, res) => {
            try {
                var settings = nm.get_saved_wifi_profile_settings.end (res);
                if (!is_ui_epoch_valid (epoch) || saved_profile_settings_cancellable != settings_request) {
                    return;
                }

                page.profile_name_entry.set_text (settings.profile_name);
                page.ssid_entry.set_text (settings.ssid);
                page.bssid_entry.set_text (settings.bssid);
                page.set_selected_security_mode_key (settings.security_mode);
                page.autoconnect_check.set_active (settings.autoconnect);
                page.all_users_check.set_active (settings.available_to_all_users);
                page.password_entry.set_text (settings.configured_password);

                page.ipv4_method_dropdown.set_selected (
                    MainWindowHelpers.get_ipv4_method_dropdown_index (settings.ipv4_method)
                );
                page.ipv4_address_entry.set_text (settings.configured_address);
                page.ipv4_prefix_entry.set_text (
                    settings.configured_prefix > 0 ? "%u".printf (settings.configured_prefix) : ""
                );
                page.ipv4_gateway_entry.set_text (settings.configured_gateway);
                page.dns_auto_switch.set_active (settings.dns_auto);
                page.ipv4_dns_entry.set_text (settings.configured_dns);

                page.ipv6_method_dropdown.set_selected (
                    MainWindowHelpers.get_ipv6_method_dropdown_index (settings.ipv6_method)
                );
                page.ipv6_address_entry.set_text (settings.configured_ipv6_address);
                page.ipv6_prefix_entry.set_text (
                    settings.configured_ipv6_prefix > 0 ? "%u".printf (settings.configured_ipv6_prefix) : ""
                );
                page.ipv6_gateway_entry.set_text (settings.configured_ipv6_gateway);
                page.ipv6_dns_auto_switch.set_active (settings.ipv6_dns_auto);
                page.ipv6_dns_entry.set_text (settings.configured_ipv6_dns);

                on_sync_sensitivity ();
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)
                    || saved_profile_settings_cancellable != settings_request
                    || is_cancelled_error (e)) {
                    return;
                }
                on_error ("Could not load saved profile settings: " + e.message);
            }
        });
    }

    public void apply_saved_wifi_profile_updates (
        NetworkManagerClient nm,
        WifiSavedProfile profile,
        WifiSavedProfileUpdateRequest profile_request,
        WifiNetworkUpdateRequest network_request,
        MainWindowErrorCallback on_error,
        MainWindowActionCallback on_success
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_saved_profile_update_request ();
        saved_profile_update_cancellable = new Cancellable ();
        var update_request = saved_profile_update_cancellable;

        nm.update_saved_wifi_profile_settings.begin (profile, profile_request, update_request, (obj, res) => {
            try {
                nm.update_saved_wifi_profile_settings.end (res);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)
                    || saved_profile_update_cancellable != update_request
                    || is_cancelled_error (e)) {
                    return;
                }
                on_error ("Save profile failed: " + e.message);
                return;
            }

            nm.update_saved_wifi_profile_network_settings.begin (
                profile,
                network_request,
                update_request,
                (obj2, res2) => {
                    try {
                        nm.update_saved_wifi_profile_network_settings.end (res2);
                        if (!is_ui_epoch_valid (epoch)
                            || saved_profile_update_cancellable != update_request) {
                            return;
                        }
                        on_success ();
                    } catch (Error e) {
                        if (!is_ui_epoch_valid (epoch)
                            || saved_profile_update_cancellable != update_request
                            || is_cancelled_error (e)) {
                            return;
                        }
                        on_error ("Save network settings failed: " + e.message);
                    }
                }
            );
        });
    }

    public void populate_wifi_details (
        NetworkManagerClient nm,
        WifiNetwork net,
        HashTable<string, bool> active_wifi_connections,
        MainWindowWifiDetailsPage page,
        MainWindowLogCallback log_debug
    ) {
        details_edit_controller.populate_wifi_details (
            nm,
            net,
            active_wifi_connections,
            page,
            log_debug
        );
    }

    public void open_wifi_edit (
        NetworkManagerClient nm,
        WifiNetwork net,
        MainWindowWifiEditPage page,
        Gtk.Stack wifi_stack,
        MainWindowActionCallback sync_sensitivity,
        MainWindowActionCallback enable_popup_text_input,
        MainWindowLogCallback log_debug
    ) {
        details_edit_controller.open_wifi_edit (
            nm,
            net,
            page,
            wifi_stack,
            sync_sensitivity,
            enable_popup_text_input,
            log_debug
        );
    }

    public bool apply_wifi_edit (
        NetworkManagerClient nm,
        WifiNetwork net,
        MainWindowWifiEditPage page,
        bool close_after_apply,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_open_details,
        MainWindowActionCallback disable_popup_text_input
    ) {
        return details_edit_controller.apply_wifi_edit (
            nm,
            net,
            page,
            close_after_apply,
            pending_wifi_connect,
            pending_wifi_seen_connecting,
            on_error,
            on_refresh_after_action,
            on_open_details,
            disable_popup_text_input
        );
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
