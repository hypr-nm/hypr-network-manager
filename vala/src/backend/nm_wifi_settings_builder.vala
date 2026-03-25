using GLib;

public class NmWifiSettingsBuilder : Object {
    private static bool apply_manual_dns(
        VariantDict ipv4_dict,
        Variant? existing_ipv4,
        string[] ipv4_dns_servers,
        out string error_message
    ) {
        error_message = "";

        Variant? existing_dns_data = existing_ipv4 != null
            ? existing_ipv4.lookup_value("dns-data", null)
            : null;
        bool dns_data_uses_dict_items = existing_dns_data != null
            && existing_dns_data.is_of_type(new VariantType("aa{sv}"));

        var dns_data_strings_builder = new VariantBuilder(new VariantType("as"));
        var dns_data_dict_builder = new VariantBuilder(new VariantType("aa{sv}"));
        var dns_legacy_builder = new VariantBuilder(new VariantType("au"));

        foreach (string dns in ipv4_dns_servers) {
            string dns_ip = dns.strip();
            if (dns_ip == "") {
                continue;
            }

            uint32 dns_legacy;
            if (!NmClientUtils.parse_ipv4_to_uint32(dns_ip, out dns_legacy)) {
                error_message = "Invalid DNS server IPv4 address: " + dns_ip;
                return false;
            }

            if (dns_data_uses_dict_items) {
                var dns_data_item = new VariantBuilder(new VariantType("a{sv}"));
                dns_data_item.add("{sv}", "address", new Variant.string(dns_ip));
                dns_data_dict_builder.add_value(dns_data_item.end());
            } else {
                dns_data_strings_builder.add("s", dns_ip);
            }

            dns_legacy_builder.add("u", dns_legacy);
        }

        if (dns_data_uses_dict_items) {
            ipv4_dict.insert_value("dns-data", dns_data_dict_builder.end());
        } else {
            ipv4_dict.insert_value("dns-data", dns_data_strings_builder.end());
        }
        ipv4_dict.insert_value("dns", dns_legacy_builder.end());
        return true;
    }

    public static bool build_updated_ipv4_section(
        Variant all_settings,
        string method,
        string address,
        uint32 ipv4_prefix,
        bool gateway_auto,
        string gateway,
        bool dns_auto,
        string[] ipv4_dns_servers,
        out Variant updated_ipv4,
        out string error_message
    ) {
        error_message = "";

        Variant? existing_ipv4 = all_settings.lookup_value("ipv4", new VariantType("a{sv}"));
        Variant base_ipv4 = existing_ipv4 != null
            ? existing_ipv4
            : new VariantBuilder(new VariantType("a{sv}")).end();
        var ipv4_dict = new VariantDict(base_ipv4);

        ipv4_dict.insert_value("method", new Variant.string(method));
        ipv4_dict.insert_value("ignore-auto-routes", new Variant.boolean(!gateway_auto));
        ipv4_dict.insert_value("ignore-auto-dns", new Variant.boolean(!dns_auto));

        uint32 gateway_legacy = 0;
        if (!gateway_auto && !NmClientUtils.parse_ipv4_to_uint32(gateway, out gateway_legacy)) {
            error_message = "Invalid IPv4 gateway address.";
            updated_ipv4 = new VariantBuilder(new VariantType("a{sv}")).end();
            return false;
        }

        if (method == "manual") {
            uint32 address_legacy;
            if (!NmClientUtils.parse_ipv4_to_uint32(address, out address_legacy)) {
                error_message = "Invalid IPv4 address for manual mode.";
                updated_ipv4 = new VariantBuilder(new VariantType("a{sv}")).end();
                return false;
            }

            var addresses = new VariantBuilder(new VariantType("aa{sv}"));
            var addr_entry = new VariantBuilder(new VariantType("a{sv}"));
            addr_entry.add("{sv}", "address", new Variant.string(address));
            addr_entry.add("{sv}", "prefix", new Variant.uint32(ipv4_prefix));
            addresses.add_value(addr_entry.end());
            ipv4_dict.insert_value("address-data", addresses.end());

            // Keep legacy key for older NetworkManager versions.
            var legacy_addresses = new VariantBuilder(new VariantType("aau"));
            var legacy_addr_entry = new VariantBuilder(new VariantType("au"));
            legacy_addr_entry.add("u", address_legacy);
            legacy_addr_entry.add("u", ipv4_prefix);
            legacy_addr_entry.add("u", gateway_legacy);
            legacy_addresses.add_value(legacy_addr_entry.end());
            ipv4_dict.insert_value("addresses", legacy_addresses.end());
        } else {
            ipv4_dict.remove("address-data");
            ipv4_dict.remove("addresses");
        }

        if (!gateway_auto) {
            ipv4_dict.insert_value("gateway", new Variant.string(gateway));
        } else {
            ipv4_dict.remove("gateway");
        }

        if (!dns_auto) {
            if (!apply_manual_dns(ipv4_dict, existing_ipv4, ipv4_dns_servers, out error_message)) {
                updated_ipv4 = new VariantBuilder(new VariantType("a{sv}")).end();
                return false;
            }
        } else {
            ipv4_dict.remove("dns-data");
            ipv4_dict.remove("dns");
        }

        updated_ipv4 = ipv4_dict.end();
        return true;
    }

    public static Variant build_updated_connection_settings(
        Variant all_settings,
        Variant updated_ipv4,
        bool network_is_secured,
        string password
    ) {
        Variant? updated_sec = null;
        if (network_is_secured && password.strip() != "") {
            Variant? existing_sec = all_settings.lookup_value(
                "802-11-wireless-security",
                new VariantType("a{sv}")
            );
            Variant base_sec = existing_sec != null
                ? existing_sec
                : new VariantBuilder(new VariantType("a{sv}")).end();
            var sec_dict = new VariantDict(base_sec);
            sec_dict.insert_value("psk", new Variant.string(password.strip()));
            updated_sec = sec_dict.end();
        }

        var top_builder = new VariantBuilder(new VariantType("a{sa{sv}}"));
        bool has_ipv4 = false;
        bool has_sec = false;

        for (int i = 0; i < all_settings.n_children(); i++) {
            Variant entry = all_settings.get_child_value(i);
            string section_name = entry.get_child_value(0).get_string();
            Variant section_value = entry.get_child_value(1);

            if (section_name == "ipv4") {
                top_builder.add("{s@a{sv}}", "ipv4", updated_ipv4);
                has_ipv4 = true;
                continue;
            }

            if (section_name == "802-11-wireless-security" && updated_sec != null) {
                top_builder.add("{s@a{sv}}", "802-11-wireless-security", updated_sec);
                has_sec = true;
                continue;
            }

            top_builder.add("{s@a{sv}}", section_name, section_value);
        }

        if (!has_ipv4) {
            top_builder.add("{s@a{sv}}", "ipv4", updated_ipv4);
        }
        if (updated_sec != null && !has_sec) {
            top_builder.add("{s@a{sv}}", "802-11-wireless-security", updated_sec);
        }

        return top_builder.end();
    }
}