using GLib;

public class NetworkManagerClientVala : Object {
    private bool debug_enabled;

    public NetworkManagerClientVala(bool debug_enabled) {
        this.debug_enabled = debug_enabled;
    }

    private void debug_log(string message) {
        if (debug_enabled) {
            stderr.printf("[hypr-nm] %s\n", message);
        }
    }

    private DBusProxy make_proxy(string object_path, string iface) throws Error {
        return new DBusProxy.for_bus_sync(
            BusType.SYSTEM,
            DBusProxyFlags.NONE,
            null,
            NM_SERVICE,
            object_path,
            iface,
            null
        );
    }

    private Variant get_prop(string object_path, string iface, string prop) throws Error {
        var proxy = make_proxy(object_path, DBUS_PROPS_IFACE);
        var result = proxy.call_sync(
            "Get",
            new Variant("(ss)", iface, prop),
            DBusCallFlags.NONE,
            -1,
            null
        );
        var boxed = result.get_child_value(0);
        return boxed.get_variant();
    }

    private static string decode_ssid(Variant v) {
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

    private HashTable<string, bool> get_saved_ssids() {
        var saved = new HashTable<string, bool>(str_hash, str_equal);

        try {
            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, -1, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, -1, null);
                var all_settings = settings_res.get_child_value(0);

                Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
                Variant? wifi_group = all_settings.lookup_value("802-11-wireless", new VariantType("a{sv}"));
                if (conn_group == null || wifi_group == null) {
                    continue;
                }

                Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
                if (type_v == null || type_v.get_string() != "802-11-wireless") {
                    continue;
                }

                Variant? ssid_v = wifi_group.lookup_value("ssid", new VariantType("ay"));
                if (ssid_v == null) {
                    continue;
                }

                string ssid = decode_ssid(ssid_v);
                if (ssid != "") {
                    saved.insert(ssid, true);
                }
            }
        } catch (Error e) {
            debug_log("could not load saved ssids: " + e.message);
        }

        return saved;
    }

    private string? find_connection_by_ssid(string ssid) {
        try {
            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, -1, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, -1, null);
                var all_settings = settings_res.get_child_value(0);

                Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
                Variant? wifi_group = all_settings.lookup_value("802-11-wireless", new VariantType("a{sv}"));
                if (conn_group == null || wifi_group == null) {
                    continue;
                }

                Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
                if (type_v == null || type_v.get_string() != "802-11-wireless") {
                    continue;
                }

                Variant? ssid_v = wifi_group.lookup_value("ssid", new VariantType("ay"));
                if (ssid_v == null) {
                    continue;
                }

                if (decode_ssid(ssid_v) == ssid) {
                    return conn_path;
                }
            }
        } catch (Error e) {
            debug_log("could not resolve saved connection: " + e.message);
        }

        return null;
    }

    private string? find_connection_by_name(string name) {
        try {
            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, -1, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, -1, null);
                var all_settings = settings_res.get_child_value(0);

                Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
                if (conn_group == null) {
                    continue;
                }

                Variant? id_v = conn_group.lookup_value("id", new VariantType("s"));
                if (id_v != null && id_v.get_string() == name) {
                    return conn_path;
                }
            }
        } catch (Error e) {
            debug_log("could not resolve connection by name: " + e.message);
        }

        return null;
    }

    private static Variant make_ssid_variant(string ssid) {
        var ssid_bytes = new VariantBuilder(new VariantType("ay"));
        for (int i = 0; i < ssid.length; i++) {
            ssid_bytes.add("y", (uint8) ssid[i]);
        }
        return ssid_bytes.end();
    }

    private static string normalize_ipv4_method(string value) {
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

    private static string join_string_variant_list(Variant list_variant) {
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

    private static string extract_dns_list_string(Variant dns_variant) {
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

    private static void fill_configured_ipv4_from_settings(Variant all_settings, NetworkIpSettings out_ip) {
        Variant? ipv4_group = all_settings.lookup_value("ipv4", new VariantType("a{sv}"));
        if (ipv4_group == null) {
            out_ip.ipv4_method = "auto";
            return;
        }

        Variant? method_v = ipv4_group.lookup_value("method", new VariantType("s"));
        if (method_v != null) {
            out_ip.ipv4_method = normalize_ipv4_method(method_v.get_string());
        }

        Variant? gateway_v = ipv4_group.lookup_value("gateway", new VariantType("s"));
        if (gateway_v != null) {
            out_ip.configured_gateway = gateway_v.get_string();
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

    private void fill_runtime_ipv4_for_wifi(WifiNetwork network, NetworkIpSettings out_ip) {
        if (!network.connected) {
            return;
        }

        try {
            string active_conn_path = get_prop(network.device_path, NM_DEVICE_IFACE, "ActiveConnection").get_string();
            if (active_conn_path == "/") {
                return;
            }

            string ip4_config_path = get_prop(active_conn_path, NM_ACTIVE_CONN_IFACE, "Ip4Config").get_string();
            if (ip4_config_path == "/") {
                return;
            }

            Variant address_data = get_prop(ip4_config_path, NM_IP4_CONFIG_IFACE, "AddressData");
            if (address_data.n_children() > 0) {
                Variant first_addr = address_data.get_child_value(0);
                Variant? addr_v = first_addr.lookup_value("address", new VariantType("s"));
                Variant? prefix_v = first_addr.lookup_value("prefix", new VariantType("u"));
                if (addr_v != null) {
                    out_ip.current_address = addr_v.get_string();
                }
                if (prefix_v != null) {
                    out_ip.current_prefix = prefix_v.get_uint32();
                }
            }

            try {
                out_ip.current_gateway = get_prop(ip4_config_path, NM_IP4_CONFIG_IFACE, "Gateway").get_string();
            } catch (Error gateway_err) {
                debug_log("could not read runtime IPv4 gateway: " + gateway_err.message);
            }

            try {
                Variant dns_data = get_prop(ip4_config_path, NM_IP4_CONFIG_IFACE, "NameserverData");
                out_ip.current_dns = extract_dns_list_string(dns_data);
            } catch (Error dns_err) {
                debug_log("could not read runtime IPv4 DNS: " + dns_err.message);
            }
        } catch (Error e) {
            debug_log("could not read runtime IPv4 details: " + e.message);
        }
    }

    public bool get_wifi_network_ip_settings(
        WifiNetwork network,
        out NetworkIpSettings ip_settings,
        out string error_message
    ) {
        error_message = "";
        ip_settings = new NetworkIpSettings();

        if (network.saved) {
            try {
                string? conn_path = find_connection_by_ssid(network.ssid);
                if (conn_path == null) {
                    error_message = "Saved connection not found.";
                    fill_runtime_ipv4_for_wifi(network, ip_settings);
                    return false;
                }

                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, -1, null);
                var all_settings = settings_res.get_child_value(0);
                fill_configured_ipv4_from_settings(all_settings, ip_settings);
            } catch (Error e) {
                error_message = e.message;
                fill_runtime_ipv4_for_wifi(network, ip_settings);
                return false;
            }
        }

        fill_runtime_ipv4_for_wifi(network, ip_settings);
        return true;
    }

    private static string json_escape(string value) {
        string out = value.replace("\\", "\\\\");
        out = out.replace("\"", "\\\"");
        out = out.replace("\n", "\\n");
        out = out.replace("\r", "\\r");
        out = out.replace("\t", "\\t");
        return out;
    }

    public bool is_networking_enabled(out string error_message) {
        error_message = "";

        try {
            bool enabled = get_prop(NM_PATH, NM_IFACE, "NetworkingEnabled").get_boolean();
            debug_log("networking enabled: %s".printf(enabled.to_string()));
            return enabled;
        } catch (Error e) {
            error_message = e.message;
            debug_log("failed to read NetworkingEnabled: " + e.message);
            return false;
        }
    }

    public List<NetworkDevice> get_devices() {
        var devices_out = new List<NetworkDevice>();

        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, -1, null);
            var devices = devices_res.get_child_value(0);

            for (int i = 0; i < devices.n_children(); i++) {
                string dev_path = devices.get_child_value(i).get_string();
                string iface = get_prop(dev_path, NM_DEVICE_IFACE, "Interface").get_string();
                if (iface == "" || iface == "lo") {
                    continue;
                }

                uint32 dev_type = get_prop(dev_path, NM_DEVICE_IFACE, "DeviceType").get_uint32();
                uint32 state = get_prop(dev_path, NM_DEVICE_IFACE, "State").get_uint32();

                string conn_name = "";
                string ac_path = get_prop(dev_path, NM_DEVICE_IFACE, "ActiveConnection").get_string();
                if (ac_path != "/") {
                    try {
                        conn_name = get_prop(ac_path, NM_ACTIVE_CONN_IFACE, "Id").get_string();
                    } catch (Error e) {
                        debug_log("Could not read active connection id: " + e.message);
                    }
                }

                devices_out.append(new NetworkDevice() {
                    name = iface,
                    device_type = dev_type,
                    state = state,
                    connection = conn_name
                });
            }
        } catch (Error e) {
            debug_log("get_devices failed: " + e.message);
        }

        return devices_out;
    }

    public bool get_wifi_enabled(out bool enabled, out string error_message) {
        enabled = false;
        error_message = "";

        try {
            enabled = get_prop(NM_PATH, NM_IFACE, "WirelessEnabled").get_boolean();
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool get_networking_enabled(out bool enabled, out string error_message) {
        enabled = false;
        error_message = "";

        try {
            enabled = get_prop(NM_PATH, NM_IFACE, "NetworkingEnabled").get_boolean();
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    private bool set_nm_bool_property(string prop_name, bool value, out string error_message) {
        error_message = "";
        try {
            var proxy = make_proxy(NM_PATH, DBUS_PROPS_IFACE);
            proxy.call_sync(
                "Set",
                new Variant("(ssv)", NM_IFACE, prop_name, new Variant.boolean(value)),
                DBusCallFlags.NONE,
                -1,
                null
            );
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool set_wifi_enabled(bool enabled, out string error_message) {
        return set_nm_bool_property("WirelessEnabled", enabled, out error_message);
    }

    public bool set_networking_enabled(bool enabled, out string error_message) {
        error_message = "";
        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            nm.call_sync(
                "Enable",
                new Variant("(b)", enabled),
                DBusCallFlags.NONE,
                -1,
                null
            );
            return true;
        } catch (Error e) {
            debug_log("Enable() failed, falling back to NetworkingEnabled property: " + e.message);
            return set_nm_bool_property("NetworkingEnabled", enabled, out error_message);
        }
    }

    public bool toggle_wifi(out bool enabled_after_toggle, out string error_message) {
        enabled_after_toggle = false;
        error_message = "";

        bool current;
        if (!get_wifi_enabled(out current, out error_message)) {
            return false;
        }

        enabled_after_toggle = !current;
        if (!set_wifi_enabled(enabled_after_toggle, out error_message)) {
            return false;
        }
        return true;
    }

    public List<WifiNetwork> get_wifi_networks() {
        var networks = new List<WifiNetwork>();
        var seen = new HashTable<string, bool>(str_hash, str_equal);
        var saved_ssids = get_saved_ssids();

        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, -1, null);
            var devices = devices_res.get_child_value(0);

            for (int i = 0; i < devices.n_children(); i++) {
                string dev_path = devices.get_child_value(i).get_string();
                uint32 dev_type = get_prop(dev_path, NM_DEVICE_IFACE, "DeviceType").get_uint32();
                if (dev_type != NM_DEVICE_TYPE_WIFI) {
                    continue;
                }

                string active_ap_path = get_prop(dev_path, NM_WIRELESS_IFACE, "ActiveAccessPoint").get_string();

                var wifi = make_proxy(dev_path, NM_WIRELESS_IFACE);
                var aps_res = wifi.call_sync("GetAccessPoints", null, DBusCallFlags.NONE, -1, null);
                var aps = aps_res.get_child_value(0);

                for (int j = 0; j < aps.n_children(); j++) {
                    string ap_path = aps.get_child_value(j).get_string();

                    string ssid = decode_ssid(get_prop(ap_path, NM_AP_IFACE, "Ssid"));
                    if (ssid == "") {
                        ssid = get_prop(ap_path, NM_AP_IFACE, "HwAddress").get_string();
                    }
                    if (seen.contains(ssid)) {
                        continue;
                    }

                    uint8 signal = get_prop(ap_path, NM_AP_IFACE, "Strength").get_byte();
                    uint32 flags = get_prop(ap_path, NM_AP_IFACE, "Flags").get_uint32();
                    uint32 wpa_flags = get_prop(ap_path, NM_AP_IFACE, "WpaFlags").get_uint32();
                    uint32 rsn_flags = get_prop(ap_path, NM_AP_IFACE, "RsnFlags").get_uint32();
                    string bssid = get_prop(ap_path, NM_AP_IFACE, "HwAddress").get_string();
                    uint32 frequency = get_prop(ap_path, NM_AP_IFACE, "Frequency").get_uint32();
                    uint32 max_bitrate = get_prop(ap_path, NM_AP_IFACE, "MaxBitrate").get_uint32();
                    uint32 mode = get_prop(ap_path, NM_AP_IFACE, "Mode").get_uint32();
                    bool is_secured = ((flags & 0x1) != 0) || wpa_flags != 0 || rsn_flags != 0;

                    seen.insert(ssid, true);
                    networks.append(new WifiNetwork() {
                        ssid = ssid,
                        signal = signal,
                        connected = (ap_path == active_ap_path),
                        is_secured = is_secured,
                        saved = saved_ssids.contains(ssid),
                        device_path = dev_path,
                        ap_path = ap_path,
                        bssid = bssid,
                        frequency_mhz = frequency,
                        max_bitrate_kbps = max_bitrate,
                        mode = mode,
                        flags = flags,
                        wpa_flags = wpa_flags,
                        rsn_flags = rsn_flags
                    });
                }
            }
        } catch (Error e) {
            debug_log("get_wifi_networks failed: " + e.message);
        }

        networks.sort((a, b) => {
            if (a.connected != b.connected) {
                return a.connected ? -1 : 1;
            }
            return (int) b.signal - (int) a.signal;
        });

        debug_log("discovered %u wifi networks".printf(networks.length()));
        return networks;
    }

    public bool connect_saved_wifi(WifiNetwork network, out string error_message) {
        error_message = "";

        try {
            string? conn_path = find_connection_by_ssid(network.ssid);
            if (conn_path == null) {
                error_message = "No saved profile found for SSID.";
                return false;
            }

            var nm = make_proxy(NM_PATH, NM_IFACE);
            nm.call_sync(
                "ActivateConnection",
                new Variant("(ooo)", conn_path, network.device_path, network.ap_path),
                DBusCallFlags.NONE,
                -1,
                null
            );
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool connect_wifi(WifiNetwork network, string? password, out string error_message) {
        error_message = "";

        if (network.saved) {
            return connect_saved_wifi(network, out error_message);
        }

        if (password == null) {
            password = "";
        }

        return connect_wifi_with_password(network, password, out error_message);
    }

    public bool connect_wifi_with_password(
        WifiNetwork network,
        string password,
        out string error_message
    ) {
        error_message = "";

        try {
            if (network.is_secured && password.strip() == "") {
                error_message = "Password is required for secured networks.";
                return false;
            }

            var nm = make_proxy(NM_PATH, NM_IFACE);

            var conn = new VariantBuilder(new VariantType("a{sa{sv}}"));

            var conn_section = new VariantBuilder(new VariantType("a{sv}"));
            conn_section.add("{sv}", "id", new Variant.string(network.ssid));
            conn_section.add("{sv}", "type", new Variant.string("802-11-wireless"));
            conn_section.add("{sv}", "uuid", new Variant.string(Uuid.string_random()));
            conn_section.add("{sv}", "autoconnect", new Variant.boolean(true));
            conn.add("{s@a{sv}}", "connection", conn_section.end());

            var wifi_section = new VariantBuilder(new VariantType("a{sv}"));
            wifi_section.add("{sv}", "ssid", make_ssid_variant(network.ssid));
            conn.add("{s@a{sv}}", "802-11-wireless", wifi_section.end());

            if (network.is_secured) {
                var sec = new VariantBuilder(new VariantType("a{sv}"));
                sec.add("{sv}", "key-mgmt", new Variant.string("wpa-psk"));
                sec.add("{sv}", "psk", new Variant.string(password));
                conn.add("{s@a{sv}}", "802-11-wireless-security", sec.end());
            }

            nm.call_sync(
                "AddAndActivateConnection",
                new Variant("(@a{sa{sv}}oo)", conn.end(), network.device_path, network.ap_path),
                DBusCallFlags.NONE,
                -1,
                null
            );
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool disconnect_wifi(WifiNetwork network, out string error_message) {
        error_message = "";

        try {
            var dev = make_proxy(network.device_path, NM_DEVICE_IFACE);
            dev.call_sync("Disconnect", null, DBusCallFlags.NONE, -1, null);
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool forget_network(string ssid_or_name, out string error_message) {
        error_message = "";

        try {
            string? conn_path = find_connection_by_ssid(ssid_or_name);
            if (conn_path == null) {
                conn_path = find_connection_by_name(ssid_or_name);
            }

            if (conn_path == null) {
                error_message = "No saved connection found.";
                return false;
            }

            var conn = make_proxy(conn_path, NM_CONN_IFACE);
            conn.call_sync("Delete", null, DBusCallFlags.NONE, -1, null);
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool disconnect_device(string interface_name, out string error_message) {
        error_message = "";

        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, -1, null);
            var devices = devices_res.get_child_value(0);

            for (int i = 0; i < devices.n_children(); i++) {
                string dev_path = devices.get_child_value(i).get_string();
                string iface = get_prop(dev_path, NM_DEVICE_IFACE, "Interface").get_string();
                if (iface != interface_name) {
                    continue;
                }

                var dev = make_proxy(dev_path, NM_DEVICE_IFACE);
                dev.call_sync("Disconnect", null, DBusCallFlags.NONE, -1, null);
                return true;
            }

            error_message = "Device not found.";
            return false;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public List<VpnConnection> get_vpn_connections() {
        var vpns = new List<VpnConnection>();

        try {
            var active_map = new HashTable<string, string>(str_hash, str_equal);
            var active_conns = get_prop(NM_PATH, NM_IFACE, "ActiveConnections");
            for (int i = 0; i < active_conns.n_children(); i++) {
                string ac_path = active_conns.get_child_value(i).get_string();
                try {
                    string id = get_prop(ac_path, NM_ACTIVE_CONN_IFACE, "Id").get_string();
                    active_map.insert(id, "activated");
                } catch (Error e) {
                    debug_log("Could not read active VPN id: " + e.message);
                }
            }

            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, -1, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, -1, null);
                var all_settings = settings_res.get_child_value(0);

                Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
                if (conn_group == null) {
                    continue;
                }
                Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
                if (type_v == null || type_v.get_string() != "vpn") {
                    continue;
                }

                Variant? id_v = conn_group.lookup_value("id", new VariantType("s"));
                string name = id_v != null ? id_v.get_string() : "VPN";

                Variant? vpn_group = all_settings.lookup_value("vpn", new VariantType("a{sv}"));
                string vpn_type = "vpn";
                if (vpn_group != null) {
                    Variant? svc_v = vpn_group.lookup_value("service-type", new VariantType("s"));
                    if (svc_v != null) {
                        string svc = svc_v.get_string();
                        var parts = svc.split(".");
                        if (parts.length > 0) {
                            vpn_type = parts[parts.length - 1];
                        }
                    }
                }

                vpns.append(new VpnConnection() {
                    name = name,
                    state = active_map.contains(name) ? "activated" : "deactivated",
                    vpn_type = vpn_type
                });
            }
        } catch (Error e) {
            debug_log("get_vpn_connections failed: " + e.message);
        }

        return vpns;
    }

    private bool activate_connection(string name, out string error_message) {
        error_message = "";
        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            string? conn_path = find_connection_by_name(name);
            if (conn_path == null) {
                error_message = "Connection not found.";
                return false;
            }
            nm.call_sync(
                "ActivateConnection",
                new Variant("(ooo)", conn_path, "/", "/"),
                DBusCallFlags.NONE,
                -1,
                null
            );
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    private bool deactivate_connection(string name, out string error_message) {
        error_message = "";
        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            var active_conns = get_prop(NM_PATH, NM_IFACE, "ActiveConnections");
            for (int i = 0; i < active_conns.n_children(); i++) {
                string ac_path = active_conns.get_child_value(i).get_string();
                string id = get_prop(ac_path, NM_ACTIVE_CONN_IFACE, "Id").get_string();
                if (id != name) {
                    continue;
                }

                nm.call_sync(
                    "DeactivateConnection",
                    new Variant("(o)", ac_path),
                    DBusCallFlags.NONE,
                    -1,
                    null
                );
                return true;
            }

            error_message = "Active connection not found.";
            return false;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool connect_vpn(string name, out string error_message) {
        return activate_connection(name, out error_message);
    }

    public bool disconnect_vpn(string name, out string error_message) {
        return deactivate_connection(name, out error_message);
    }

    public bool scan_wifi(out string error_message) {
        error_message = "";

        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, -1, null);
            var devices = devices_res.get_child_value(0);

            uint scanned = 0;
            for (int i = 0; i < devices.n_children(); i++) {
                string dev_path = devices.get_child_value(i).get_string();
                uint32 dev_type = get_prop(dev_path, NM_DEVICE_IFACE, "DeviceType").get_uint32();
                if (dev_type != NM_DEVICE_TYPE_WIFI) {
                    continue;
                }

                var wifi = make_proxy(dev_path, NM_WIRELESS_IFACE);
                var options = new VariantBuilder(new VariantType("a{sv}"));
                wifi.call_sync(
                    "RequestScan",
                    new Variant("(@a{sv})", options.end()),
                    DBusCallFlags.NONE,
                    -1,
                    null
                );
                scanned++;
            }

            debug_log("requested scan on %u wifi device(s)".printf(scanned));
            return true;
        } catch (Error e) {
            error_message = e.message;
            debug_log("scan_wifi failed: " + e.message);
            return false;
        }
    }

    public List<string> get_device_paths() {
        var paths = new List<string>();

        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, -1, null);
            var devices = devices_res.get_child_value(0);

            for (int i = 0; i < devices.n_children(); i++) {
                paths.append(devices.get_child_value(i).get_string());
            }
            debug_log("found %u devices".printf(paths.length()));
        } catch (Error e) {
            debug_log("GetDevices failed: " + e.message);
        }

        return paths;
    }

    public string get_status_json() {
        bool networking_on;
        bool wifi_on;
        string error_message;
        if (!get_networking_enabled(out networking_on, out error_message)) {
            networking_on = false;
        }
        if (!get_wifi_enabled(out wifi_on, out error_message)) {
            wifi_on = false;
        }

        var devices = get_devices();
        NetworkDevice? active_wifi = null;
        NetworkDevice? active_eth = null;
        foreach (var dev in devices) {
            if (dev.is_wifi && dev.is_connected) {
                active_wifi = dev;
            } else if (dev.is_ethernet && dev.is_connected) {
                active_eth = dev;
            }
        }

        string text;
        string alt;
        string tooltip;
        string klass;

        if (!networking_on) {
            text = "NET-OFF";
            alt = "Offline";
            tooltip = "Networking is disabled";
            klass = "offline";
        } else if (active_eth != null) {
            text = "ETH";
            alt = active_eth.connection != "" ? active_eth.connection : "Ethernet";
            tooltip = "Ethernet: " + active_eth.name;
            klass = "ethernet";
        } else if (active_wifi != null) {
            uint signal = 100;
            var wifi_nets = get_wifi_networks();
            foreach (var net in wifi_nets) {
                if (net.connected) {
                    signal = net.signal;
                    break;
                }
            }

            text = "WIFI";
            alt = active_wifi.connection != "" ? active_wifi.connection : "WiFi";
            tooltip = "WiFi: " + alt + " (" + signal.to_string() + "%)\\nDevice: " + active_wifi.name;
            klass = "wifi";
        } else if (!wifi_on) {
            text = "WIFI-OFF";
            alt = "WiFi Off";
            tooltip = "WiFi is disabled";
            klass = "wifi-off";
        } else {
            text = "DISCONNECTED";
            alt = "Disconnected";
            tooltip = "Not connected to any network";
            klass = "disconnected";
        }

        return "{\"text\":\"%s\",\"alt\":\"%s\",\"tooltip\":\"%s\",\"class\":\"%s\"}".printf(
            json_escape(text),
            json_escape(alt),
            json_escape(tooltip),
            json_escape(klass)
        );
    }
}
