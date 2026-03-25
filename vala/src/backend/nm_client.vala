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
            DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
        );
        var boxed = result.get_child_value(0);
        return boxed.get_variant();
    }

    private static string decode_ssid(Variant v) {
        return NmClientUtils.decode_ssid(v);
    }

    private HashTable<string, bool> get_saved_ssids() {
        var saved = new HashTable<string, bool>(str_hash, str_equal);

        try {
            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
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

    private HashTable<string, string> get_unique_saved_ssid_uuids() {
        var unique = new HashTable<string, string>(str_hash, str_equal);
        var duplicates = new HashTable<string, bool>(str_hash, str_equal);

        try {
            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
                var all_settings = settings_res.get_child_value(0);

                Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
                Variant? wifi_group = all_settings.lookup_value("802-11-wireless", new VariantType("a{sv}"));
                if (conn_group == null || wifi_group == null) {
                    continue;
                }

                Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
                Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
                Variant? ssid_v = wifi_group.lookup_value("ssid", new VariantType("ay"));
                if (type_v == null
                    || type_v.get_string() != "802-11-wireless"
                    || uuid_v == null
                    || ssid_v == null) {
                    continue;
                }

                string ssid = decode_ssid(ssid_v);
                if (ssid == "") {
                    continue;
                }

                if (duplicates.contains(ssid)) {
                    continue;
                }

                if (unique.contains(ssid)) {
                    unique.remove(ssid);
                    duplicates.insert(ssid, true);
                    continue;
                }

                unique.insert(ssid, uuid_v.get_string());
            }
        } catch (Error e) {
            debug_log("could not build saved ssid uuid index: " + e.message);
        }

        return unique;
    }

    private string? find_connection_by_uuid(string uuid) {
        try {
            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
                var all_settings = settings_res.get_child_value(0);

                Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
                if (conn_group == null) {
                    continue;
                }

                Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
                if (uuid_v != null && uuid_v.get_string() == uuid) {
                    return conn_path;
                }
            }
        } catch (Error e) {
            debug_log("could not resolve connection by uuid: " + e.message);
        }

        return null;
    }

    private string? find_connection_by_ssid(string ssid, out bool ambiguous) {
        ambiguous = false;
        string? match = null;

        try {
            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
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
                    if (match != null) {
                        ambiguous = true;
                        return null;
                    }
                    match = conn_path;
                }
            }
        } catch (Error e) {
            debug_log("could not resolve saved connection: " + e.message);
        }

        return match;
    }

    private string? find_connection_by_name(string name, out bool ambiguous) {
        ambiguous = false;
        string? match = null;

        try {
            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
                var all_settings = settings_res.get_child_value(0);

                Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
                if (conn_group == null) {
                    continue;
                }

                Variant? id_v = conn_group.lookup_value("id", new VariantType("s"));
                if (id_v != null && id_v.get_string() == name) {
                    if (match != null) {
                        ambiguous = true;
                        return null;
                    }
                    match = conn_path;
                }
            }
        } catch (Error e) {
            debug_log("could not resolve connection by name: " + e.message);
        }

        return match;
    }

    private static Variant make_ssid_variant(string ssid) {
        return NmClientUtils.make_ssid_variant(ssid);
    }

    private static string normalize_ipv4_method(string value) {
        return NmClientUtils.normalize_ipv4_method(value);
    }

    private static string extract_dns_list_string(Variant dns_variant) {
        return NmClientUtils.extract_dns_list_string(dns_variant);
    }

    private static void fill_configured_ipv4_from_settings(Variant all_settings, NetworkIpSettings out_ip) {
        NmClientUtils.fill_configured_ipv4_from_settings(all_settings, out_ip);
    }

    private void fill_runtime_ipv4_for_device(
        string device_path,
        bool device_connected,
        NetworkIpSettings out_ip
    ) {
        if (!device_connected) {
            return;
        }

        try {
            string active_conn_path = get_prop(device_path, NM_DEVICE_IFACE, "ActiveConnection").get_string();
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

    private void fill_runtime_ipv4_for_wifi(WifiNetwork network, NetworkIpSettings out_ip) {
        fill_runtime_ipv4_for_device(network.device_path, network.connected, out_ip);
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
                string? conn_path = null;
                if (network.saved_connection_uuid.strip() != "") {
                    conn_path = find_connection_by_uuid(network.saved_connection_uuid);
                }
                if (conn_path == null) {
                    bool ssid_ambiguous = false;
                    conn_path = find_connection_by_ssid(network.ssid, out ssid_ambiguous);
                    if (ssid_ambiguous) {
                        error_message = "Multiple saved profiles share this SSID. Select a specific profile by UUID.";
                        fill_runtime_ipv4_for_wifi(network, ip_settings);
                        return false;
                    }
                }
                if (conn_path == null) {
                    error_message = "Saved connection not found.";
                    fill_runtime_ipv4_for_wifi(network, ip_settings);
                    return false;
                }

                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
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

    public bool update_wifi_network_settings(
        WifiNetwork network,
        string password,
        string ipv4_method,
        string ipv4_address,
        uint32 ipv4_prefix,
        bool gateway_auto,
        string ipv4_gateway,
        bool dns_auto,
        string[] ipv4_dns_servers,
        out string error_message
    ) {
        error_message = "";

        try {
            string? conn_path = null;
            if (network.saved_connection_uuid.strip() != "") {
                conn_path = find_connection_by_uuid(network.saved_connection_uuid);
            }
            if (conn_path == null) {
                bool ssid_ambiguous = false;
                conn_path = find_connection_by_ssid(network.ssid, out ssid_ambiguous);
                if (ssid_ambiguous) {
                    error_message = "Multiple saved profiles share this SSID. Refusing ambiguous update.";
                    return false;
                }
            }
            if (conn_path == null) {
                error_message = "No saved connection found for this network.";
                return false;
            }

            string method = normalize_ipv4_method(ipv4_method);
            string address = ipv4_address.strip();
            string gateway = ipv4_gateway.strip();

            if (!gateway_auto && gateway == "") {
                error_message = "Manual gateway requires a gateway address.";
                return false;
            }

            if (!gateway_auto && method == "disabled") {
                error_message = "Manual gateway is not supported when IPv4 method is Disabled.";
                return false;
            }

            if (!dns_auto && ipv4_dns_servers.length == 0) {
                error_message = "Manual DNS requires at least one DNS server.";
                return false;
            }

            if (method == "manual") {
                if (address == "") {
                    error_message = "Manual IPv4 requires an address.";
                    return false;
                }
                if (ipv4_prefix == 0 || ipv4_prefix > 32) {
                    error_message = "Manual IPv4 prefix must be between 1 and 32.";
                    return false;
                }
            }

            var conn = make_proxy(conn_path, NM_CONN_IFACE);
            var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var all_settings = settings_res.get_child_value(0);

            Variant updated_ipv4;
            if (!NmWifiSettingsBuilder.build_updated_ipv4_section(
                all_settings,
                method,
                address,
                ipv4_prefix,
                gateway_auto,
                gateway,
                dns_auto,
                ipv4_dns_servers,
                out updated_ipv4,
                out error_message
            )) {
                return false;
            }

            Variant updated_settings = NmWifiSettingsBuilder.build_updated_connection_settings(
                all_settings,
                updated_ipv4,
                network.is_secured,
                password
            );

            conn.call_sync(
                "Update",
                new Variant("(@a{sa{sv}})", updated_settings),
                DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
            );
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool get_ethernet_device_ip_settings(
        NetworkDevice device,
        out NetworkIpSettings ip_settings,
        out string error_message
    ) {
        error_message = "";
        ip_settings = new NetworkIpSettings();

        if (device.connection.strip() != "") {
            try {
                string? conn_path = null;
                if (device.connection_uuid.strip() != "") {
                    conn_path = find_connection_by_uuid(device.connection_uuid);
                }
                if (conn_path == null) {
                    bool name_ambiguous = false;
                    conn_path = find_connection_by_name(device.connection, out name_ambiguous);
                    if (name_ambiguous) {
                        error_message = "Multiple Ethernet profiles share this name. Select by UUID.";
                    }
                }
                if (conn_path != null) {
                    var conn = make_proxy(conn_path, NM_CONN_IFACE);
                    var settings_res = conn.call_sync(
                        "GetSettings",
                        null,
                        DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
                    );
                    var all_settings = settings_res.get_child_value(0);
                    fill_configured_ipv4_from_settings(all_settings, ip_settings);
                }
            } catch (Error e) {
                error_message = e.message;
            }
        }

        fill_runtime_ipv4_for_device(device.device_path, device.is_connected, ip_settings);
        return true;
    }

    public bool update_ethernet_device_settings(
        NetworkDevice device,
        string ipv4_method,
        string ipv4_address,
        uint32 ipv4_prefix,
        bool gateway_auto,
        string ipv4_gateway,
        bool dns_auto,
        string[] ipv4_dns_servers,
        out string error_message
    ) {
        error_message = "";

        if (device.connection.strip() == "") {
            error_message = "No Ethernet profile is available for this interface.";
            return false;
        }

        try {
            string? conn_path = null;
            if (device.connection_uuid.strip() != "") {
                conn_path = find_connection_by_uuid(device.connection_uuid);
            }
            if (conn_path == null) {
                bool name_ambiguous = false;
                conn_path = find_connection_by_name(device.connection, out name_ambiguous);
                if (name_ambiguous) {
                    error_message = "Multiple Ethernet profiles share this name. Refusing ambiguous update.";
                    return false;
                }
            }
            if (conn_path == null) {
                error_message = "No saved Ethernet profile found.";
                return false;
            }

            string method = normalize_ipv4_method(ipv4_method);
            string address = ipv4_address.strip();
            string gateway = ipv4_gateway.strip();

            if (!gateway_auto && gateway == "") {
                error_message = "Manual gateway requires a gateway address.";
                return false;
            }

            if (!gateway_auto && method == "disabled") {
                error_message = "Manual gateway is not supported when IPv4 method is Disabled.";
                return false;
            }

            if (!dns_auto && ipv4_dns_servers.length == 0) {
                error_message = "Manual DNS requires at least one DNS server.";
                return false;
            }

            if (method == "manual") {
                if (address == "") {
                    error_message = "Manual IPv4 requires an address.";
                    return false;
                }
                if (ipv4_prefix == 0 || ipv4_prefix > 32) {
                    error_message = "Manual IPv4 prefix must be between 1 and 32.";
                    return false;
                }
            }

            var conn = make_proxy(conn_path, NM_CONN_IFACE);
            var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var all_settings = settings_res.get_child_value(0);

            Variant updated_ipv4;
            if (!NmWifiSettingsBuilder.build_updated_ipv4_section(
                all_settings,
                method,
                address,
                ipv4_prefix,
                gateway_auto,
                gateway,
                dns_auto,
                ipv4_dns_servers,
                out updated_ipv4,
                out error_message
            )) {
                return false;
            }

            Variant updated_settings = NmWifiSettingsBuilder.build_updated_connection_settings(
                all_settings,
                updated_ipv4,
                false,
                ""
            );

            conn.call_sync(
                "Update",
                new Variant("(@a{sa{sv}})", updated_settings),
                DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
            );
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool connect_ethernet_device(NetworkDevice device, out string error_message) {
        error_message = "";

        if (device.connection.strip() == "") {
            error_message = "No saved Ethernet profile available for this interface.";
            return false;
        }

        if (device.connection_uuid.strip() != "") {
            return activate_connection_by_uuid(device.connection_uuid, out error_message);
        }

        return activate_connection(device.connection, out error_message);
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
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
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
                string conn_uuid = "";
                string ac_path = get_prop(dev_path, NM_DEVICE_IFACE, "ActiveConnection").get_string();
                if (ac_path != "/") {
                    try {
                        conn_name = get_prop(ac_path, NM_ACTIVE_CONN_IFACE, "Id").get_string();
                        conn_uuid = get_prop(ac_path, NM_ACTIVE_CONN_IFACE, "Uuid").get_string();
                    } catch (Error e) {
                        debug_log("Could not read active connection id: " + e.message);
                    }
                }

                if (conn_name == "" && dev_type == NM_DEVICE_TYPE_ETHERNET) {
                    try {
                        Variant available_connections = get_prop(
                            dev_path,
                            NM_DEVICE_IFACE,
                            "AvailableConnections"
                        );
                        for (int j = 0; j < available_connections.n_children(); j++) {
                            string conn_path = available_connections.get_child_value(j).get_string();
                            var conn = make_proxy(conn_path, NM_CONN_IFACE);
                            var settings_res = conn.call_sync(
                                "GetSettings",
                                null,
                                DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
                            );
                            var all_settings = settings_res.get_child_value(0);

                            Variant? conn_group = all_settings.lookup_value(
                                "connection",
                                new VariantType("a{sv}")
                            );
                            if (conn_group == null) {
                                continue;
                            }

                            Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
                            if (type_v == null || type_v.get_string() != "802-3-ethernet") {
                                continue;
                            }

                            Variant? id_v = conn_group.lookup_value("id", new VariantType("s"));
                            Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
                            if (id_v != null && id_v.get_string() != "") {
                                conn_name = id_v.get_string();
                                conn_uuid = uuid_v != null ? uuid_v.get_string() : "";
                                break;
                            }
                        }
                    } catch (Error e) {
                        debug_log("Could not read available Ethernet profiles: " + e.message);
                    }
                }

                devices_out.append(new NetworkDevice() {
                    name = iface,
                    device_path = dev_path,
                    device_type = dev_type,
                    state = state,
                    connection = conn_name,
                    connection_uuid = conn_uuid
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
                DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
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
                DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
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
        var by_ssid = new HashTable<string, WifiNetwork>(str_hash, str_equal);
        var saved_ssids = get_saved_ssids();
        var unique_saved_ssid_uuids = get_unique_saved_ssid_uuids();

        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var devices = devices_res.get_child_value(0);

            for (int i = 0; i < devices.n_children(); i++) {
                string dev_path = devices.get_child_value(i).get_string();
                uint32 dev_type = get_prop(dev_path, NM_DEVICE_IFACE, "DeviceType").get_uint32();
                if (dev_type != NM_DEVICE_TYPE_WIFI) {
                    continue;
                }

                string active_ap_path = get_prop(dev_path, NM_WIRELESS_IFACE, "ActiveAccessPoint").get_string();

                var wifi = make_proxy(dev_path, NM_WIRELESS_IFACE);
                var aps_res = wifi.call_sync("GetAccessPoints", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
                var aps = aps_res.get_child_value(0);

                for (int j = 0; j < aps.n_children(); j++) {
                    string ap_path = aps.get_child_value(j).get_string();

                    string ssid = decode_ssid(get_prop(ap_path, NM_AP_IFACE, "Ssid"));
                    if (ssid == "") {
                        ssid = get_prop(ap_path, NM_AP_IFACE, "HwAddress").get_string();
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
                    bool is_connected = (ap_path == active_ap_path);

                    WifiNetwork? existing = by_ssid.get(ssid);
                    if (existing != null) {
                        bool prefer_candidate = false;

                        if (is_connected && !existing.connected) {
                            prefer_candidate = true;
                        } else if (is_connected == existing.connected && signal > existing.signal) {
                            prefer_candidate = true;
                        }

                        if (!prefer_candidate) {
                            continue;
                        }

                        existing.signal = signal;
                        existing.connected = is_connected;
                        existing.is_secured = is_secured;
                        existing.saved = saved_ssids.contains(ssid);
                        existing.saved_connection_uuid = unique_saved_ssid_uuids.contains(ssid)
                            ? unique_saved_ssid_uuids.get(ssid)
                            : "";
                        existing.device_path = dev_path;
                        existing.ap_path = ap_path;
                        existing.bssid = bssid;
                        existing.frequency_mhz = frequency;
                        existing.max_bitrate_kbps = max_bitrate;
                        existing.mode = mode;
                        existing.flags = flags;
                        existing.wpa_flags = wpa_flags;
                        existing.rsn_flags = rsn_flags;
                        continue;
                    }

                    var network = new WifiNetwork() {
                        ssid = ssid,
                        saved_connection_uuid = unique_saved_ssid_uuids.contains(ssid)
                            ? unique_saved_ssid_uuids.get(ssid)
                            : "",
                        signal = signal,
                        connected = is_connected,
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
                    };
                    by_ssid.insert(ssid, network);
                    networks.append(network);
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
            string? conn_path = null;
            if (network.saved_connection_uuid.strip() != "") {
                conn_path = find_connection_by_uuid(network.saved_connection_uuid);
            }
            if (conn_path == null) {
                bool ssid_ambiguous = false;
                conn_path = find_connection_by_ssid(network.ssid, out ssid_ambiguous);
                if (ssid_ambiguous) {
                    error_message = "Multiple saved profiles share this SSID. Refusing ambiguous connect.";
                    return false;
                }
            }
            if (conn_path == null) {
                error_message = "No saved profile found for SSID.";
                return false;
            }

            var nm = make_proxy(NM_PATH, NM_IFACE);
            nm.call_sync(
                "ActivateConnection",
                new Variant("(ooo)", conn_path, network.device_path, network.ap_path),
                DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
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
                DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
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
            dev.call_sync("Disconnect", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    public bool forget_network(string ssid_or_name, out string error_message) {
        error_message = "";

        try {
            string? conn_path = find_connection_by_uuid(ssid_or_name);

            bool ssid_ambiguous = false;
            bool name_ambiguous = false;
            if (conn_path == null) {
                conn_path = find_connection_by_ssid(ssid_or_name, out ssid_ambiguous);
            }
            if (conn_path == null) {
                conn_path = find_connection_by_name(ssid_or_name, out name_ambiguous);
            }

            if (conn_path == null) {
                if (ssid_ambiguous || name_ambiguous) {
                    error_message = "Multiple profiles match this identifier. Use UUID to avoid ambiguity.";
                    return false;
                }
                error_message = "No saved connection found.";
                return false;
            }

            var conn = make_proxy(conn_path, NM_CONN_IFACE);
            conn.call_sync("Delete", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
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
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var devices = devices_res.get_child_value(0);

            for (int i = 0; i < devices.n_children(); i++) {
                string dev_path = devices.get_child_value(i).get_string();
                string iface = get_prop(dev_path, NM_DEVICE_IFACE, "Interface").get_string();
                if (iface != interface_name) {
                    continue;
                }

                var dev = make_proxy(dev_path, NM_DEVICE_IFACE);
                dev.call_sync("Disconnect", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
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
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
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
            bool ambiguous = false;
            string? conn_path = find_connection_by_name(name, out ambiguous);
            if (ambiguous) {
                error_message = "Multiple connections share this name. Use UUID to activate a specific profile.";
                return false;
            }
            if (conn_path == null) {
                error_message = "Connection not found.";
                return false;
            }
            nm.call_sync(
                "ActivateConnection",
                new Variant("(ooo)", conn_path, "/", "/"),
                DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
            );
            return true;
        } catch (Error e) {
            error_message = e.message;
            return false;
        }
    }

    private bool activate_connection_by_uuid(string uuid, out string error_message) {
        error_message = "";
        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            string? conn_path = find_connection_by_uuid(uuid);
            if (conn_path == null) {
                error_message = "Connection UUID not found.";
                return false;
            }
            nm.call_sync(
                "ActivateConnection",
                new Variant("(ooo)", conn_path, "/", "/"),
                DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
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
                    DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
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
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
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
                    DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null
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
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
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

        uint signal = 100;
        if (active_wifi != null) {
            var wifi_nets = get_wifi_networks();
            foreach (var net in wifi_nets) {
                if (net.connected) {
                    signal = net.signal;
                    break;
                }
            }
        }

        string text;
        string alt;
        string tooltip;
        string klass;
        NmStatusFormatter.pick_status_fields(
            networking_on,
            wifi_on,
            active_wifi,
            active_eth,
            signal,
            out text,
            out alt,
            out tooltip,
            out klass
        );

        return NmStatusFormatter.build_status_json(text, alt, tooltip, klass);
    }
}
