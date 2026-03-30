using GLib;
using Gtk;

public class MainWindowWifiDetailsEditController : Object {
    private const uint WIFI_RECONNECT_CHECK_INTERVAL_MS = 300;
    private const uint WIFI_RECONNECT_MAX_WAIT_MS = 10000;

    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};

    public MainWindowWifiDetailsEditController () {
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

    private void cancel_all_timeout_sources () {
        if (timeout_source_ids.length == 0) {
            return;
        }

        foreach (uint source_id in timeout_source_ids) {
            Source.remove (source_id);
        }
        timeout_source_ids = {};
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

    private bool is_wifi_device_fully_disconnected (NetworkDevice dev) {
        if (dev.is_connected) {
            return false;
        }

        bool is_connecting = dev.state >= 40 && dev.state < NM_DEVICE_STATE_ACTIVATED;
        return !is_connecting;
    }

    private void reconnect_after_disconnect_with_retry (
        NetworkManagerClient nm,
        WifiNetwork net,
        bool close_after_apply,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_open_details,
        MainWindowActionCallback disable_popup_text_input,
        uint epoch,
        uint waited_ms
    ) {
        string net_key = net.network_key;

        if (!is_ui_epoch_valid (epoch)) {
            return;
        }

        nm.get_devices.begin (null, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            bool ready_to_reconnect = true;
            try {
                var devices = nm.get_devices.end (res);
                foreach (var dev in devices) {
                    if (!dev.is_wifi || dev.device_path != net.device_path) {
                        continue;
                    }

                    ready_to_reconnect = is_wifi_device_fully_disconnected (dev);
                    break;
                }
            } catch (Error e) {
                // Treat transient D-Bus/read errors as not-ready and retry until timeout.
                ready_to_reconnect = false;
            }

            if (ready_to_reconnect) {
                nm.connect_wifi.begin (net, null, null, (obj2, res2) => {
                    try {
                        nm.connect_wifi.end (res2);
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        if (close_after_apply) {
                            on_open_details ();
                            disable_popup_text_input ();
                        }
                        on_refresh_after_action (true);
                    } catch (Error e) {
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        pending_wifi_connect.remove (net_key);
                        pending_wifi_seen_connecting.remove (net_key);
                        on_error ("Reconnect after edit failed: " + e.message);
                        on_refresh_after_action (false);
                    }
                });
                return;
            }

            if (waited_ms >= WIFI_RECONNECT_MAX_WAIT_MS) {
                pending_wifi_connect.remove (net_key);
                pending_wifi_seen_connecting.remove (net_key);
                on_error (
                    "Reconnect after edit timed out while waiting for disconnect to complete."
                );
                on_refresh_after_action (false);
                return;
            }

            uint next_waited_ms = waited_ms + WIFI_RECONNECT_CHECK_INTERVAL_MS;
            uint timeout_id = 0;
            timeout_id = Timeout.add (WIFI_RECONNECT_CHECK_INTERVAL_MS, () => {
                untrack_timeout_source (timeout_id);
                reconnect_after_disconnect_with_retry (
                    nm,
                    net,
                    close_after_apply,
                    pending_wifi_connect,
                    pending_wifi_seen_connecting,
                    on_error,
                    on_refresh_after_action,
                    on_open_details,
                    disable_popup_text_input,
                    epoch,
                    next_waited_ms
                );
                return false;
            });
            track_timeout_source (timeout_id);
        });
    }

    public void populate_wifi_details (
        NetworkManagerClient nm,
        WifiNetwork net,
        HashTable<string, bool> active_wifi_connections,
        MainWindowWifiDetailsPage page,
        MainWindowLogCallback log_debug
    ) {
        uint epoch = capture_ui_epoch ();

        page.details_title.set_text (net.ssid);
        bool is_connected_now = active_wifi_connections.contains (net.network_key);
        bool can_manage_saved_profile = net.saved;
        page.action_row.set_visible (can_manage_saved_profile);
        page.forget_button.set_visible (can_manage_saved_profile);
        page.edit_button.set_visible (can_manage_saved_profile);

        MainWindowHelpers.clear_box (page.basic_rows);
        MainWindowHelpers.clear_box (page.advanced_rows);
        MainWindowHelpers.clear_box (page.ip_rows);

        page.basic_rows.append (
            MainWindowHelpers.build_details_row (
                "Connection Status",
                is_connected_now ? "Connected" : "Not connected"
            )
        );
        page.basic_rows.append (
            MainWindowHelpers.build_details_row ("Signal Strength", "%u%%".printf (net.signal))
        );
        page.basic_rows.append (
            MainWindowHelpers.build_details_row ("Bars", MainWindowHelpers.get_signal_bars (net.signal))
        );
        page.basic_rows.append (
            MainWindowHelpers.build_details_row ("Security", net.is_secured ? "Secured" : "Open")
        );
        page.basic_rows.append (
            MainWindowHelpers.build_details_row ("Saved Profile", net.saved ? "Yes" : "No")
        );

        string band = MainWindowHelpers.get_band_label (net.frequency_mhz);
        int channel = MainWindowHelpers.get_channel_from_frequency (net.frequency_mhz);
        page.advanced_rows.append (
            MainWindowHelpers.build_details_row (
                "Frequency",
                net.frequency_mhz > 0 ? "%.1f GHz".printf ((double) net.frequency_mhz / 1000.0) : "n/a"
            )
        );
        page.advanced_rows.append (
            MainWindowHelpers.build_details_row ("Channel", channel > 0 ? "%d".printf (channel) : "n/a")
        );
        page.advanced_rows.append (
            MainWindowHelpers.build_details_row ("Band", band != "" ? band : "n/a")
        );
        page.advanced_rows.append (
            MainWindowHelpers.build_details_row ("BSSID", net.bssid != "" ? net.bssid : "n/a")
        );
        page.advanced_rows.append (
            MainWindowHelpers.build_details_row (
                "Max bitrate",
                net.max_bitrate_kbps > 0
                    ? "%.1f Mbps".printf ((double) net.max_bitrate_kbps / 1000.0)
                    : "n/a"
            )
        );
        page.advanced_rows.append (
            MainWindowHelpers.build_details_row ("Mode", MainWindowHelpers.get_mode_label (net.mode))
        );

        page.ip_rows.append (
            MainWindowHelpers.build_details_row ("Loading", "Reading IP settings…")
        );

        nm.get_wifi_network_ip_settings.begin (net, null, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            if (page.details_title.get_text () != net.ssid) {
                return;
            }

            var ip_settings = nm.get_wifi_network_ip_settings.end (res);

            MainWindowHelpers.clear_box (page.ip_rows);
            page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv4 Method",
                    MainWindowHelpers.get_ipv4_method_label (ip_settings.ipv4_method)
                )
            );
            page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv4 Address",
                    MainWindowHelpers.format_ip_with_prefix (
                        ip_settings.configured_address,
                        ip_settings.configured_prefix
                    )
                )
            );
            page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured Gateway",
                    ip_settings.configured_gateway.strip () != "" ? ip_settings.configured_gateway : "n/a"
                )
            );
            page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured DNS",
                    ip_settings.configured_dns.strip () != "" ? ip_settings.configured_dns : "n/a"
                )
            );
            page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv6 Method",
                    MainWindowHelpers.get_ipv6_method_label (ip_settings.ipv6_method)
                )
            );
            page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv6 Address",
                    MainWindowHelpers.format_ip_with_prefix (
                        ip_settings.configured_ipv6_address,
                        ip_settings.configured_ipv6_prefix
                    )
                )
            );
            page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv6 Gateway",
                    ip_settings.configured_ipv6_gateway.strip () != ""
                        ? ip_settings.configured_ipv6_gateway
                        : "n/a"
                )
            );

            if (is_connected_now) {
                page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current IPv4 Address",
                        MainWindowHelpers.format_ip_with_prefix (
                            ip_settings.current_address,
                            ip_settings.current_prefix
                        )
                    )
                );
                page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current Gateway",
                        ip_settings.current_gateway.strip () != "" ? ip_settings.current_gateway : "n/a"
                    )
                );
                page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current DNS",
                        ip_settings.current_dns.strip () != "" ? ip_settings.current_dns : "n/a"
                    )
                );
                page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current IPv6 Address",
                        MainWindowHelpers.format_ip_with_prefix (
                            ip_settings.current_ipv6_address,
                            ip_settings.current_ipv6_prefix
                        )
                    )
                );
                page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current IPv6 Gateway",
                        ip_settings.current_ipv6_gateway.strip () != "" ? ip_settings.current_ipv6_gateway : "n/a"
                    )
                );
                page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current IPv6 DNS",
                        ip_settings.current_ipv6_dns.strip () != "" ? ip_settings.current_ipv6_dns : "n/a"
                    )
                );
            }
        });
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
        uint epoch = capture_ui_epoch ();

        page.edit_title.set_text ("Edit: %s".printf (net.ssid));
        page.password_entry.set_text ("");
        page.password_entry.set_visibility (false);

        if (net.is_secured) {
            page.note_label.set_text (
                "Current password is prefilled when available.\n"
                + "IPv4 and IPv6 settings can be changed below (auto/manual/disabled)."
            );
        } else {
            page.note_label.set_text ("Open network. Password is not required.");
        }

        wifi_stack.set_visible_child_name ("edit");
        enable_popup_text_input ();
        page.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        page.password_entry.grab_focus ();

        page.ipv4_method_dropdown.set_selected (0);
        page.ipv4_address_entry.set_text ("");
        page.ipv4_prefix_entry.set_text ("");
        page.ipv4_gateway_entry.set_text ("");
        page.dns_auto_switch.set_active (true);
        page.ipv4_dns_entry.set_text ("");
        page.ipv6_method_dropdown.set_selected (0);
        page.ipv6_address_entry.set_text ("");
        page.ipv6_prefix_entry.set_text ("");
        page.ipv6_gateway_entry.set_text ("");
        page.ipv6_dns_auto_switch.set_active (true);
        page.ipv6_dns_entry.set_text ("");
        sync_sensitivity ();

        nm.get_wifi_network_ip_settings.begin (net, null, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            if (page.edit_title.get_text () != "Edit: %s".printf (net.ssid)) {
                return;
            }

            var ip_settings = nm.get_wifi_network_ip_settings.end (res);

            page.ipv4_method_dropdown.set_selected (
                MainWindowHelpers.get_ipv4_method_dropdown_index (ip_settings.ipv4_method)
            );
            if (net.is_secured) {
                page.password_entry.set_text (ip_settings.configured_password);
            } else {
                page.password_entry.set_text ("");
            }
            page.ipv4_address_entry.set_text (ip_settings.configured_address);
            page.ipv4_prefix_entry.set_text (
                ip_settings.configured_prefix > 0 ? "%u".printf (ip_settings.configured_prefix) : ""
            );
            page.ipv4_gateway_entry.set_text (ip_settings.configured_gateway);
            page.dns_auto_switch.set_active (ip_settings.dns_auto);
            page.ipv4_dns_entry.set_text (ip_settings.configured_dns);
            page.ipv6_method_dropdown.set_selected (
                MainWindowHelpers.get_ipv6_method_dropdown_index (ip_settings.ipv6_method)
            );
            page.ipv6_address_entry.set_text (ip_settings.configured_ipv6_address);
            page.ipv6_prefix_entry.set_text (
                ip_settings.configured_ipv6_prefix > 0 ? "%u".printf (ip_settings.configured_ipv6_prefix) : ""
            );
            page.ipv6_gateway_entry.set_text (ip_settings.configured_ipv6_gateway);
            page.ipv6_dns_auto_switch.set_active (ip_settings.ipv6_dns_auto);
            page.ipv6_dns_entry.set_text (ip_settings.configured_ipv6_dns);
            sync_sensitivity ();
        });
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
        uint epoch = capture_ui_epoch ();
        string net_key = net.network_key;
        string password = page.password_entry.get_text ().strip ();

        string method = MainWindowWifiEditUtils.get_selected_ipv4_method (page.ipv4_method_dropdown);
        string ipv4_address = page.ipv4_address_entry.get_text ().strip ();
        string ipv4_gateway = page.ipv4_gateway_entry.get_text ().strip ();
        bool gateway_auto = method != "manual";
        bool dns_auto = page.dns_auto_switch.get_active ();
        string dns_csv = page.ipv4_dns_entry.get_text ().strip ();
        string method6 = MainWindowWifiEditUtils.get_selected_ipv6_method (page.ipv6_method_dropdown);
        string ipv6_address = page.ipv6_address_entry.get_text ().strip ();
        string ipv6_gateway = page.ipv6_gateway_entry.get_text ().strip ();
        bool ipv6_gateway_auto = method6 != "manual";
        bool ipv6_dns_auto = page.ipv6_dns_auto_switch.get_active ();
        string ipv6_dns_csv = page.ipv6_dns_entry.get_text ().strip ();

        if (method == "disabled") {
            dns_auto = true;
        }

        if (method6 == "disabled" || method6 == "ignore") {
            ipv6_dns_auto = true;
        }

        uint32 ipv4_prefix;
        string prefix_error;
        if (!MainWindowWifiEditUtils.try_parse_prefix (
            page.ipv4_prefix_entry.get_text (),
            out ipv4_prefix,
            out prefix_error
        )) {
            on_error (prefix_error);
            return false;
        }

        uint32 ipv6_prefix;
        string prefix6_error;
        if (!MainWindowWifiEditUtils.try_parse_ipv6_prefix (
            page.ipv6_prefix_entry.get_text (),
            out ipv6_prefix,
            out prefix6_error
        )) {
            on_error (prefix6_error);
            return false;
        }

        if (method == "manual") {
            if (ipv4_address == "") {
                on_error ("Manual IPv4 requires an address.");
                return false;
            }
            if (ipv4_prefix == 0) {
                on_error ("Manual IPv4 requires a prefix between 1 and 32.");
                return false;
            }
            if (ipv4_gateway == "") {
                on_error ("Manual IPv4 requires a gateway address.");
                return false;
            }
        }

        string[] dns_servers = MainWindowWifiEditUtils.parse_dns_csv (dns_csv);
        if (!dns_auto && dns_servers.length == 0) {
            on_error ("Manual DNS is enabled; provide at least one DNS server.");
            return false;
        }

        if (method6 == "manual") {
            if (ipv6_address == "") {
                on_error ("Manual IPv6 requires an address.");
                return false;
            }
            if (ipv6_prefix == 0) {
                on_error ("Manual IPv6 requires a prefix between 1 and 128.");
                return false;
            }
            if (ipv6_gateway == "") {
                on_error ("Manual IPv6 requires a gateway address.");
                return false;
            }
        }

        string[] ipv6_dns_servers = MainWindowWifiEditUtils.parse_dns_csv (ipv6_dns_csv);
        if (!ipv6_dns_auto && ipv6_dns_servers.length == 0) {
            on_error ("Manual IPv6 DNS is enabled; provide at least one DNS server.");
            return false;
        }

        var request = new WifiNetworkUpdateRequest () {
            password = password,
            ipv4_method = method,
            ipv4_address = ipv4_address,
            ipv4_prefix = ipv4_prefix,
            ipv4_gateway_auto = gateway_auto,
            ipv4_gateway = ipv4_gateway,
            ipv4_dns_auto = dns_auto,
            ipv4_dns_servers = dns_servers,
            ipv6_method = method6,
            ipv6_address = ipv6_address,
            ipv6_prefix = ipv6_prefix,
            ipv6_gateway_auto = ipv6_gateway_auto,
            ipv6_gateway = ipv6_gateway,
            ipv6_dns_auto = ipv6_dns_auto,
            ipv6_dns_servers = ipv6_dns_servers
        };

        nm.update_wifi_network_settings.begin (net, request, null, (obj, res) => {
                try {
                    nm.update_wifi_network_settings.end (res);
                } catch (Error e) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    on_error ("Apply failed: " + e.message);
                    return;
                }

                if (!net.connected) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    if (close_after_apply) {
                        on_open_details ();
                        disable_popup_text_input ();
                    }
                    on_refresh_after_action (method != "disabled");
                    return;
                }

                nm.disconnect_wifi.begin (net, null, (obj2, res2) => {
                    try {
                        nm.disconnect_wifi.end (res2);
                    } catch (Error e) {
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        on_error ("Disconnect before reconnect failed: " + e.message);
                        return;
                    }

                    pending_wifi_connect.insert (net_key, true);
                    pending_wifi_seen_connecting.remove (net_key);

                    reconnect_after_disconnect_with_retry (
                        nm,
                        net,
                        close_after_apply,
                        pending_wifi_connect,
                        pending_wifi_seen_connecting,
                        on_error,
                        on_refresh_after_action,
                        on_open_details,
                        disable_popup_text_input,
                        epoch,
                        0
                    );
                });
        });

        if (!is_ui_epoch_valid (epoch)) {
            return false;
        }
        return true;
    }
}
