using GLib;

namespace MainWindowWifiSavedProfileFormUtils {
    public void sync_saved_edit_dns_sensitivity (MainWindowWifiSavedEditPage page) {
        bool ipv4_disabled = page.ipv4_method_dropdown.get_selected () == 2;
        if (ipv4_disabled) {
            page.dns_auto_switch.set_active (true);
        }

        uint ipv6_selected = page.ipv6_method_dropdown.get_selected ();
        bool ipv6_disabled_or_ignore = ipv6_selected == 2 || ipv6_selected == 3;
        if (ipv6_disabled_or_ignore) {
            page.ipv6_dns_auto_switch.set_active (true);
        }

        page.ipv4_dns_entry.set_sensitive (!page.dns_auto_switch.get_active ());
        page.ipv6_dns_entry.set_sensitive (!page.ipv6_dns_auto_switch.get_active ());
    }

    public void apply_settings_to_edit_page (
        MainWindowWifiSavedEditPage page,
        WifiSavedProfileSettings settings
    ) {
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
    }

    public bool build_update_requests (
        MainWindowWifiSavedEditPage page,
        out WifiSavedProfileUpdateRequest profile_request,
        out WifiNetworkUpdateRequest network_request,
        out string error_message
    ) {
        error_message = "";

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
        if (!MainWindowWifiEditUtils.try_parse_prefix (
            page.ipv4_prefix_entry.get_text (),
            out ipv4_prefix,
            out error_message
        )) {
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        uint32 ipv6_prefix;
        if (!MainWindowWifiEditUtils.try_parse_ipv6_prefix (
            page.ipv6_prefix_entry.get_text (),
            out ipv6_prefix,
            out error_message
        )) {
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        if (method == "manual") {
            if (ipv4_address == "") {
                error_message = "Manual IPv4 requires an address.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
            if (ipv4_prefix == 0) {
                error_message = "Manual IPv4 requires a prefix between 1 and 32.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
            if (ipv4_gateway == "") {
                error_message = "Manual IPv4 requires a gateway address.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
        }

        string[] dns_servers = MainWindowWifiEditUtils.parse_dns_csv (dns_csv);
        if (!dns_auto && dns_servers.length == 0) {
            error_message = "Manual DNS is enabled; provide at least one DNS server.";
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        if (method6 == "manual") {
            if (ipv6_address == "") {
                error_message = "Manual IPv6 requires an address.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
            if (ipv6_prefix == 0) {
                error_message = "Manual IPv6 requires a prefix between 1 and 128.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
            if (ipv6_gateway == "") {
                error_message = "Manual IPv6 requires a gateway address.";
                profile_request = new WifiSavedProfileUpdateRequest ();
                network_request = new WifiNetworkUpdateRequest ();
                return false;
            }
        }

        string[] ipv6_dns_servers = MainWindowWifiEditUtils.parse_dns_csv (ipv6_dns_csv);
        if (!ipv6_dns_auto && ipv6_dns_servers.length == 0) {
            error_message = "Manual IPv6 DNS is enabled; provide at least one DNS server.";
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        profile_request = new WifiSavedProfileUpdateRequest () {
            profile_name = page.profile_name_entry.get_text ().strip (),
            ssid = page.ssid_entry.get_text ().strip (),
            bssid = page.bssid_entry.get_text ().strip (),
            security_mode = page.get_selected_security_mode_key (),
            autoconnect = page.autoconnect_check.get_active (),
            available_to_all_users = page.all_users_check.get_active ()
        };

        network_request = new WifiNetworkUpdateRequest () {
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

        return true;
    }
}
