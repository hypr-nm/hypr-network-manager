using GLib;
using Gtk;

public class MainWindowWifiDetailsEditController : Object {
    public static void populate_wifi_details(
        NetworkManagerClientVala nm,
        WifiNetwork net,
        HashTable<string, bool> active_wifi_connections,
        Gtk.Label wifi_details_title,
        Gtk.Box wifi_details_basic_rows,
        Gtk.Box wifi_details_advanced_rows,
        Gtk.Box wifi_details_ip_rows,
        Gtk.Box wifi_details_action_row,
        Gtk.Button wifi_details_forget_button,
        Gtk.Button wifi_details_edit_button,
        MainWindowLogCallback log_debug
    ) {
        wifi_details_title.set_text(net.ssid);
        bool is_connected_now = active_wifi_connections.contains(net.ssid);
        bool can_manage_saved_profile = net.saved;
        wifi_details_action_row.set_visible(can_manage_saved_profile);
        wifi_details_forget_button.set_visible(can_manage_saved_profile);
        wifi_details_edit_button.set_visible(can_manage_saved_profile);

        MainWindowHelpers.clear_box(wifi_details_basic_rows);
        MainWindowHelpers.clear_box(wifi_details_advanced_rows);
        MainWindowHelpers.clear_box(wifi_details_ip_rows);

        wifi_details_basic_rows.append(
            MainWindowHelpers.build_details_row(
                "Connection Status",
                is_connected_now ? "Connected" : "Not connected"
            )
        );
        wifi_details_basic_rows.append(
            MainWindowHelpers.build_details_row("Signal Strength", "%u%%".printf(net.signal))
        );
        wifi_details_basic_rows.append(
            MainWindowHelpers.build_details_row("Bars", MainWindowHelpers.get_signal_bars(net.signal))
        );
        wifi_details_basic_rows.append(
            MainWindowHelpers.build_details_row("Security", net.is_secured ? "Secured" : "Open")
        );
        wifi_details_basic_rows.append(
            MainWindowHelpers.build_details_row("Saved Profile", net.saved ? "Yes" : "No")
        );

        string band = MainWindowHelpers.get_band_label(net.frequency_mhz);
        int channel = MainWindowHelpers.get_channel_from_frequency(net.frequency_mhz);
        wifi_details_advanced_rows.append(
            MainWindowHelpers.build_details_row(
                "Frequency",
                net.frequency_mhz > 0 ? "%.1f GHz".printf((double) net.frequency_mhz / 1000.0) : "n/a"
            )
        );
        wifi_details_advanced_rows.append(
            MainWindowHelpers.build_details_row("Channel", channel > 0 ? "%d".printf(channel) : "n/a")
        );
        wifi_details_advanced_rows.append(
            MainWindowHelpers.build_details_row("Band", band != "" ? band : "n/a")
        );
        wifi_details_advanced_rows.append(
            MainWindowHelpers.build_details_row("BSSID", net.bssid != "" ? net.bssid : "n/a")
        );
        wifi_details_advanced_rows.append(
            MainWindowHelpers.build_details_row(
                "Max bitrate",
                net.max_bitrate_kbps > 0
                    ? "%.1f Mbps".printf((double) net.max_bitrate_kbps / 1000.0)
                    : "n/a"
            )
        );
        wifi_details_advanced_rows.append(
            MainWindowHelpers.build_details_row("Mode", MainWindowHelpers.get_mode_label(net.mode))
        );

        NetworkIpSettings ip_settings;
        string ip_error;
        bool ip_ok = nm.get_wifi_network_ip_settings(net, out ip_settings, out ip_error);
        if (!ip_ok && ip_error != "") {
            log_debug("Could not read IP settings for details page: " + ip_error);
        }

        wifi_details_ip_rows.append(
            MainWindowHelpers.build_details_row(
                "Configured IPv4 Method",
                MainWindowHelpers.get_ipv4_method_label(ip_settings.ipv4_method)
            )
        );
        wifi_details_ip_rows.append(
            MainWindowHelpers.build_details_row(
                "Configured IPv4 Address",
                MainWindowHelpers.format_ip_with_prefix(
                    ip_settings.configured_address,
                    ip_settings.configured_prefix
                )
            )
        );
        wifi_details_ip_rows.append(
            MainWindowHelpers.build_details_row(
                "Configured Gateway",
                ip_settings.configured_gateway.strip() != "" ? ip_settings.configured_gateway : "n/a"
            )
        );
        wifi_details_ip_rows.append(
            MainWindowHelpers.build_details_row(
                "Configured DNS",
                ip_settings.configured_dns.strip() != "" ? ip_settings.configured_dns : "n/a"
            )
        );
        wifi_details_ip_rows.append(
            MainWindowHelpers.build_details_row(
                "Current IPv4 Address",
                MainWindowHelpers.format_ip_with_prefix(ip_settings.current_address, ip_settings.current_prefix)
            )
        );
        wifi_details_ip_rows.append(
            MainWindowHelpers.build_details_row(
                "Current Gateway",
                ip_settings.current_gateway.strip() != "" ? ip_settings.current_gateway : "n/a"
            )
        );
        wifi_details_ip_rows.append(
            MainWindowHelpers.build_details_row(
                "Current DNS",
                ip_settings.current_dns.strip() != "" ? ip_settings.current_dns : "n/a"
            )
        );
    }

    public static void open_wifi_edit(
        NetworkManagerClientVala nm,
        WifiNetwork net,
        Gtk.Label wifi_edit_title,
        Gtk.Entry wifi_edit_password_entry,
        Gtk.Label wifi_edit_note,
        Gtk.DropDown wifi_edit_ipv4_method_dropdown,
        Gtk.Entry wifi_edit_ipv4_address_entry,
        Gtk.Entry wifi_edit_ipv4_prefix_entry,
        Gtk.Switch wifi_edit_gateway_auto_switch,
        Gtk.Entry wifi_edit_ipv4_gateway_entry,
        Gtk.Switch wifi_edit_dns_auto_switch,
        Gtk.Entry wifi_edit_ipv4_dns_entry,
        Gtk.Stack wifi_stack,
        MainWindowActionCallback sync_sensitivity,
        MainWindowActionCallback enable_popup_text_input,
        MainWindowLogCallback log_debug
    ) {
        wifi_edit_title.set_text("Edit: %s".printf(net.ssid));
        wifi_edit_password_entry.set_text("");

        if (net.is_secured) {
            wifi_edit_note.set_text(
                "Leave password empty to keep current credentials.\n"
                + "IPv4 settings can be changed below (DHCP or manual)."
            );
        } else {
            wifi_edit_note.set_text("Open network. Password is not required.");
        }

        NetworkIpSettings ip_settings;
        string ip_error;
        if (nm.get_wifi_network_ip_settings(net, out ip_settings, out ip_error)) {
            wifi_edit_ipv4_method_dropdown.set_selected(
                MainWindowHelpers.get_ipv4_method_dropdown_index(ip_settings.ipv4_method)
            );
            wifi_edit_ipv4_address_entry.set_text(ip_settings.configured_address);
            wifi_edit_ipv4_prefix_entry.set_text(
                ip_settings.configured_prefix > 0 ? "%u".printf(ip_settings.configured_prefix) : ""
            );
            wifi_edit_gateway_auto_switch.set_active(ip_settings.gateway_auto);
            wifi_edit_ipv4_gateway_entry.set_text(ip_settings.configured_gateway);
            wifi_edit_dns_auto_switch.set_active(ip_settings.dns_auto);
            wifi_edit_ipv4_dns_entry.set_text(ip_settings.configured_dns);
        } else {
            log_debug("Could not load current IP settings for edit: " + ip_error);
            wifi_edit_ipv4_method_dropdown.set_selected(0);
            wifi_edit_ipv4_address_entry.set_text("");
            wifi_edit_ipv4_prefix_entry.set_text("");
            wifi_edit_gateway_auto_switch.set_active(true);
            wifi_edit_ipv4_gateway_entry.set_text("");
            wifi_edit_dns_auto_switch.set_active(true);
            wifi_edit_ipv4_dns_entry.set_text("");
        }

        sync_sensitivity();

        wifi_stack.set_visible_child_name("edit");
        enable_popup_text_input();
        wifi_edit_password_entry.grab_focus();
    }

    public static bool apply_wifi_edit(
        NetworkManagerClientVala nm,
        WifiNetwork net,
        Gtk.Entry wifi_edit_password_entry,
        Gtk.DropDown wifi_edit_ipv4_method_dropdown,
        Gtk.Entry wifi_edit_ipv4_address_entry,
        Gtk.Switch wifi_edit_gateway_auto_switch,
        Gtk.Entry wifi_edit_ipv4_gateway_entry,
        Gtk.Switch wifi_edit_dns_auto_switch,
        Gtk.Entry wifi_edit_ipv4_dns_entry,
        Gtk.Entry wifi_edit_ipv4_prefix_entry,
        HashTable<string, bool> pending_wifi_connect,
        HashTable<string, bool> pending_wifi_seen_connecting,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowActionCallback on_open_details,
        MainWindowActionCallback disable_popup_text_input
    ) {
        string password = wifi_edit_password_entry.get_text().strip();

        string method = MainWindowWifiEditUtils.get_selected_ipv4_method(wifi_edit_ipv4_method_dropdown);
        string ipv4_address = wifi_edit_ipv4_address_entry.get_text().strip();
        bool gateway_auto = wifi_edit_gateway_auto_switch.get_active();
        string ipv4_gateway = wifi_edit_ipv4_gateway_entry.get_text().strip();
        bool dns_auto = wifi_edit_dns_auto_switch.get_active();
        string dns_csv = wifi_edit_ipv4_dns_entry.get_text().strip();

        uint32 ipv4_prefix;
        string prefix_error;
        if (!MainWindowWifiEditUtils.try_parse_prefix(
            wifi_edit_ipv4_prefix_entry.get_text(),
            out ipv4_prefix,
            out prefix_error
        )) {
            on_error(prefix_error);
            return false;
        }

        if (method == "manual") {
            if (ipv4_address == "") {
                on_error("Manual IPv4 requires an address.");
                return false;
            }
            if (ipv4_prefix == 0) {
                on_error("Manual IPv4 requires a prefix between 1 and 32.");
                return false;
            }
        }

        if (!gateway_auto && ipv4_gateway == "") {
            on_error("Manual gateway is enabled; please provide a gateway address.");
            return false;
        }

        string[] dns_servers = MainWindowWifiEditUtils.parse_dns_csv(dns_csv);
        if (!dns_auto && dns_servers.length == 0) {
            on_error("Manual DNS is enabled; provide at least one DNS server.");
            return false;
        }

        string error_message;
        if (!nm.update_wifi_network_settings(
            net,
            password,
            method,
            ipv4_address,
            ipv4_prefix,
            gateway_auto,
            ipv4_gateway,
            dns_auto,
            dns_servers,
            out error_message
        )) {
            on_error("Apply failed: " + error_message);
            return false;
        }

        if (net.connected) {
            string disconnect_error;
            if (!nm.disconnect_wifi(net, out disconnect_error)) {
                on_error("Disconnect before reconnect failed: " + disconnect_error);
                return false;
            }

            Timeout.add(750, () => {
                pending_wifi_connect.insert(net.ssid, true);
                pending_wifi_seen_connecting.remove(net.ssid);
                string reconnect_error;
                if (!nm.connect_wifi(net, null, out reconnect_error)) {
                    pending_wifi_connect.remove(net.ssid);
                    pending_wifi_seen_connecting.remove(net.ssid);
                    on_error("Reconnect after edit failed: " + reconnect_error);
                }
                on_refresh_after_action(true);
                return false;
            });
        } else {
            on_refresh_after_action(method != "disabled");
        }

        on_open_details();
        disable_popup_text_input();
        return true;
    }
}