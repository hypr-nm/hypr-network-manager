using GLib;

public class NmClientUtils : Object {
    public static string decode_ssid(Variant v) {
        var bytes = v.get_data_as_bytes();
        if (bytes == null) {
            return "";
        }

        unowned uint8[] raw = bytes.get_data();
        if (raw.length == 0) {
            return "";
        }

        var out = new StringBuilder();
        foreach (uint8 b in raw) {
            if (b == 0) {
                continue;
            }
            if (b >= 32 && b <= 126) {
                out.append_c((char) b);
            } else {
                out.append_printf("\\x%02X", b);
            }
        }
        return out.str;
    }

    public static Variant make_ssid_variant(string ssid) {
        var ssid_bytes = new VariantBuilder(new VariantType("ay"));
        for (int i = 0; i < ssid.length; i++) {
            ssid_bytes.add("y", (uint8) ssid[i]);
        }
        return ssid_bytes.end();
    }

    public static string normalize_ipv4_method(string value) {
        string method = value.strip().down();
        switch (method) {
        case "manual":
        case "disabled":
        case "auto":
            return method;
        default:
            return "auto";
        }
    }

    public static string join_string_variant_list(Variant list_variant) {
        var out = new StringBuilder();
        for (int i = 0; i < list_variant.n_children(); i++) {
            Variant child = list_variant.get_child_value(i);
            if (!child.is_of_type(new VariantType("s"))) {
                continue;
            }

            string value = child.get_string();
            if (value == "") {
                continue;
            }
            if (out.len > 0) {
                out.append(", ");
            }
            out.append(value);
        }
        return out.str;
    }

    public static string extract_dns_list_string(Variant dns_variant) {
        if (dns_variant.is_of_type(new VariantType("as"))) {
            return join_string_variant_list(dns_variant);
        }

        if (dns_variant.is_of_type(new VariantType("aa{sv}"))) {
            var out = new StringBuilder();
            for (int i = 0; i < dns_variant.n_children(); i++) {
                Variant item = dns_variant.get_child_value(i);
                Variant? addr_v = item.lookup_value("address", new VariantType("s"));
                if (addr_v == null) {
                    continue;
                }

                string addr = addr_v.get_string();
                if (addr == "") {
                    continue;
                }

                if (out.len > 0) {
                    out.append(", ");
                }
                out.append(addr);
            }
            return out.str;
        }

        return "";
    }

    public static bool parse_ipv4_to_uint32(string ip_text, out uint32 value) {
        value = 0;
        string ip = ip_text.strip();
        string[] octets = ip.split(".");
        if (octets.length != 4) {
            return false;
        }

        uint[] parts = {0, 0, 0, 0};
        for (int i = 0; i < 4; i++) {
            uint parsed;
            if (!uint.try_parse(octets[i], out parsed) || parsed > 255) {
                return false;
            }
            parts[i] = parsed;
        }

        // NetworkManager legacy `u32` IPv4 values are interpreted in host order
        // over D-Bus, so pack octets least-significant first.
        value = (uint32) parts[0]
            | ((uint32) parts[1] << 8)
            | ((uint32) parts[2] << 16)
            | ((uint32) parts[3] << 24);
        return true;
    }

    public static string format_ipv4_from_uint32(uint32 value) {
        uint32 o1 = value & 0xFF;
        uint32 o2 = (value >> 8) & 0xFF;
        uint32 o3 = (value >> 16) & 0xFF;
        uint32 o4 = (value >> 24) & 0xFF;
        return "%u.%u.%u.%u".printf(o1, o2, o3, o4);
    }

    public static void fill_configured_ipv4_from_settings(
        Variant all_settings,
        NetworkIpSettings out_ip
    ) {
        Variant? ipv4_group = all_settings.lookup_value("ipv4", new VariantType("a{sv}"));
        if (ipv4_group == null) {
            out_ip.ipv4_method = "auto";
            out_ip.gateway_auto = true;
            out_ip.dns_auto = true;
            return;
        }

        Variant? method_v = ipv4_group.lookup_value("method", new VariantType("s"));
        if (method_v != null) {
            out_ip.ipv4_method = normalize_ipv4_method(method_v.get_string());
        }

        Variant? ignore_routes_v = ipv4_group.lookup_value("ignore-auto-routes", new VariantType("b"));
        if (ignore_routes_v != null) {
            out_ip.gateway_auto = !ignore_routes_v.get_boolean();
        }

        Variant? ignore_dns_v = ipv4_group.lookup_value("ignore-auto-dns", new VariantType("b"));
        if (ignore_dns_v != null) {
            out_ip.dns_auto = !ignore_dns_v.get_boolean();
        }

        Variant? gateway_v = ipv4_group.lookup_value("gateway", new VariantType("s"));
        if (gateway_v != null) {
            out_ip.configured_gateway = gateway_v.get_string();
        }

        if (out_ip.configured_gateway.strip() == "") {
            Variant? route_data_v = ipv4_group.lookup_value("route-data", new VariantType("aa{sv}"));
            if (route_data_v != null) {
                for (int i = 0; i < route_data_v.n_children(); i++) {
                    Variant route = route_data_v.get_child_value(i);
                    Variant? dest_v = route.lookup_value("dest", new VariantType("s"));
                    Variant? prefix_v = route.lookup_value("prefix", new VariantType("u"));
                    Variant? hop_v = route.lookup_value("next-hop", new VariantType("s"));
                    if (dest_v == null || prefix_v == null || hop_v == null) {
                        continue;
                    }

                    string dest = dest_v.get_string();
                    uint32 prefix = prefix_v.get_uint32();
                    if ((dest == "0.0.0.0" || dest == "") && prefix == 0) {
                        out_ip.configured_gateway = hop_v.get_string();
                        break;
                    }
                }
            }
        }

        if (out_ip.configured_gateway.strip() == "") {
            Variant? routes_v = ipv4_group.lookup_value("routes", new VariantType("aau"));
            if (routes_v != null) {
                for (int i = 0; i < routes_v.n_children(); i++) {
                    Variant route = routes_v.get_child_value(i);
                    if (route.n_children() < 3) {
                        continue;
                    }

                    uint32 dest_legacy = route.get_child_value(0).get_uint32();
                    uint32 prefix_legacy = route.get_child_value(1).get_uint32();
                    if (dest_legacy == 0 && prefix_legacy == 0) {
                        uint32 hop_legacy = route.get_child_value(2).get_uint32();
                        out_ip.configured_gateway = format_ipv4_from_uint32(hop_legacy);
                        break;
                    }
                }
            }
        }

        Variant? dns_data_v = ipv4_group.lookup_value("dns-data", null);
        if (dns_data_v != null) {
            out_ip.configured_dns = extract_dns_list_string(dns_data_v);
        }

        Variant? address_data_v = ipv4_group.lookup_value("address-data", new VariantType("aa{sv}"));
        if (address_data_v == null || address_data_v.n_children() == 0) {
            return;
        }

        Variant first_addr = address_data_v.get_child_value(0);
        Variant? addr_v = first_addr.lookup_value("address", new VariantType("s"));
        Variant? prefix_v = first_addr.lookup_value("prefix", new VariantType("u"));
        if (addr_v != null) {
            out_ip.configured_address = addr_v.get_string();
        }
        if (prefix_v != null) {
            out_ip.configured_prefix = prefix_v.get_uint32();
        }
    }

}