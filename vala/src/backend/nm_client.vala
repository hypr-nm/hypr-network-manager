using GLib;

public class WifiRefreshData : Object {
    public WifiNetwork[] networks;
    public NetworkDevice[] devices;

    public WifiRefreshData(WifiNetwork[] networks_in, NetworkDevice[] devices_in) {
        networks = networks_in;
        devices = devices_in;
    }
}

public class WifiSavedProfileIndex : Object {
    public HashTable<string, bool> saved_ssids;
    public HashTable<string, string> unique_saved_ssid_uuids;
    public HashTable<string, string> ssid_to_conn_path;
    public HashTable<string, bool> ambiguous_ssids;

    public WifiSavedProfileIndex() {
        saved_ssids = new HashTable<string, bool>(str_hash, str_equal);
        unique_saved_ssid_uuids = new HashTable<string, string>(str_hash, str_equal);
        ssid_to_conn_path = new HashTable<string, string>(str_hash, str_equal);
        ambiguous_ssids = new HashTable<string, bool>(str_hash, str_equal);
    }
}

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

    private async Variant call_dbus(
        DBusProxy proxy,
        string method,
        Variant? parameters,
        Cancellable? cancellable = null
    ) throws Error {
        return yield proxy.call(
            method,
            parameters,
            DBusCallFlags.NONE,
            NM_DBUS_TIMEOUT_MS,
            cancellable
        );
    }

    private async Variant get_prop_dbus(
        string object_path,
        string iface,
        string prop,
        Cancellable? cancellable = null
    ) throws Error {
        var proxy = make_proxy(object_path, DBUS_PROPS_IFACE);
        var result = yield call_dbus(
            proxy,
            "Get",
            new Variant("(ss)", iface, prop),
            cancellable
        );
        var boxed = result.get_child_value(0);
        return boxed.get_variant();
    }

    private static string decode_ssid(Variant v) {
        return NmClientUtils.decode_ssid(v);
    }

    private void index_wifi_saved_profile(
        WifiSavedProfileIndex index,
        string conn_path,
        Variant all_settings
    ) {
        Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
        Variant? wifi_group = all_settings.lookup_value("802-11-wireless", new VariantType("a{sv}"));
        if (conn_group == null || wifi_group == null) {
            return;
        }

        Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
        Variant? ssid_v = wifi_group.lookup_value("ssid", new VariantType("ay"));
        if (type_v == null || type_v.get_string() != "802-11-wireless" || ssid_v == null) {
            return;
        }

        string ssid = decode_ssid(ssid_v);
        if (ssid == "") {
            return;
        }

        index.saved_ssids.insert(ssid, true);

        Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
        if (uuid_v != null) {
            if (index.ambiguous_ssids.contains(ssid)) {
                // Already ambiguous for UUID/path matching; keep suppressed.
            } else if (index.unique_saved_ssid_uuids.contains(ssid)) {
                index.unique_saved_ssid_uuids.remove(ssid);
                index.ambiguous_ssids.insert(ssid, true);
            } else {
                index.unique_saved_ssid_uuids.insert(ssid, uuid_v.get_string());
            }
        }

        if (index.ambiguous_ssids.contains(ssid)) {
            index.ssid_to_conn_path.remove(ssid);
            return;
        }

        if (index.ssid_to_conn_path.contains(ssid)) {
            index.ssid_to_conn_path.remove(ssid);
            index.ambiguous_ssids.insert(ssid, true);
            index.unique_saved_ssid_uuids.remove(ssid);
            return;
        }

        index.ssid_to_conn_path.insert(ssid, conn_path);
    }

    private WifiSavedProfileIndex build_wifi_saved_profile_index() {
        var index = new WifiSavedProfileIndex();

        try {
            var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
                var all_settings = settings_res.get_child_value(0);
                index_wifi_saved_profile(index, conn_path, all_settings);
            }
        } catch (Error e) {
            debug_log("could not build wifi saved profile index: " + e.message);
        }

        return index;
    }

    private async WifiSavedProfileIndex build_wifi_saved_profile_index_dbus(
        Cancellable? cancellable = null
    ) throws Error {
        var index = new WifiSavedProfileIndex();

        var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
        var list_res = yield call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string conn_path = conns.get_child_value(i).get_string();
            var conn = make_proxy(conn_path, NM_CONN_IFACE);
            var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
            var all_settings = settings_res.get_child_value(0);
            index_wifi_saved_profile(index, conn_path, all_settings);
        }

        return index;
    }

    private async List<WifiNetwork> get_wifi_networks_dbus(Cancellable? cancellable = null) throws Error {
        var networks = new List<WifiNetwork>();
        var by_ssid = new HashTable<string, WifiNetwork>(str_hash, str_equal);
        var saved_profile_index = yield build_wifi_saved_profile_index_dbus(cancellable);

        var nm = make_proxy(NM_PATH, NM_IFACE);
        var devices_res = yield call_dbus(nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value(0);

        for (int i = 0; i < devices.n_children(); i++) {
            string dev_path = devices.get_child_value(i).get_string();
            uint32 dev_type = (yield get_prop_dbus(
                dev_path,
                NM_DEVICE_IFACE,
                "DeviceType",
                cancellable
            )).get_uint32();
            if (dev_type != NM_DEVICE_TYPE_WIFI) {
                continue;
            }

            string active_ap_path = (yield get_prop_dbus(
                dev_path,
                NM_WIRELESS_IFACE,
                "ActiveAccessPoint",
                cancellable
            )).get_string();

            var wifi = make_proxy(dev_path, NM_WIRELESS_IFACE);
            var aps_res = yield call_dbus(wifi, "GetAccessPoints", null, cancellable);
            var aps = aps_res.get_child_value(0);

            for (int j = 0; j < aps.n_children(); j++) {
                string ap_path = aps.get_child_value(j).get_string();

                string ssid = decode_ssid(yield get_prop_dbus(ap_path, NM_AP_IFACE, "Ssid", cancellable));
                if (ssid == "") {
                    ssid = (yield get_prop_dbus(ap_path, NM_AP_IFACE, "HwAddress", cancellable)).get_string();
                }

                uint8 signal = (yield get_prop_dbus(ap_path, NM_AP_IFACE, "Strength", cancellable)).get_byte();
                uint32 flags = (yield get_prop_dbus(ap_path, NM_AP_IFACE, "Flags", cancellable)).get_uint32();
                uint32 wpa_flags = (yield get_prop_dbus(ap_path, NM_AP_IFACE, "WpaFlags", cancellable)).get_uint32();
                uint32 rsn_flags = (yield get_prop_dbus(ap_path, NM_AP_IFACE, "RsnFlags", cancellable)).get_uint32();
                string bssid = (yield get_prop_dbus(ap_path, NM_AP_IFACE, "HwAddress", cancellable)).get_string();
                uint32 frequency = (yield get_prop_dbus(ap_path, NM_AP_IFACE, "Frequency", cancellable)).get_uint32();
                uint32 max_bitrate = (yield get_prop_dbus(ap_path, NM_AP_IFACE, "MaxBitrate", cancellable)).get_uint32();
                uint32 mode = (yield get_prop_dbus(ap_path, NM_AP_IFACE, "Mode", cancellable)).get_uint32();
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
                    existing.saved = saved_profile_index.saved_ssids.contains(ssid);
                    existing.saved_connection_uuid = saved_profile_index.unique_saved_ssid_uuids.contains(ssid)
                        ? saved_profile_index.unique_saved_ssid_uuids.get(ssid)
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
                    saved_connection_uuid = saved_profile_index.unique_saved_ssid_uuids.contains(ssid)
                        ? saved_profile_index.unique_saved_ssid_uuids.get(ssid)
                        : "",
                    signal = signal,
                    connected = is_connected,
                    is_secured = is_secured,
                    saved = saved_profile_index.saved_ssids.contains(ssid),
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

        networks.sort((a, b) => {
            if (a.connected != b.connected) {
                return a.connected ? -1 : 1;
            }
            return (int) b.signal - (int) a.signal;
        });

        return networks;
    }

    private async List<NetworkDevice> get_devices_dbus(Cancellable? cancellable = null) throws Error {
        var devices_out = new List<NetworkDevice>();

        var nm = make_proxy(NM_PATH, NM_IFACE);
        var devices_res = yield call_dbus(nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value(0);

        for (int i = 0; i < devices.n_children(); i++) {
            string dev_path = devices.get_child_value(i).get_string();
            string iface = (yield get_prop_dbus(dev_path, NM_DEVICE_IFACE, "Interface", cancellable)).get_string();
            if (iface == "" || iface == "lo") {
                continue;
            }

            uint32 dev_type = (yield get_prop_dbus(dev_path, NM_DEVICE_IFACE, "DeviceType", cancellable)).get_uint32();
            uint32 state = (yield get_prop_dbus(dev_path, NM_DEVICE_IFACE, "State", cancellable)).get_uint32();

            string conn_name = "";
            string conn_uuid = "";
            string ac_path = (yield get_prop_dbus(
                dev_path,
                NM_DEVICE_IFACE,
                "ActiveConnection",
                cancellable
            )).get_string();
            if (ac_path != "/") {
                try {
                    conn_name = (yield get_prop_dbus(ac_path, NM_ACTIVE_CONN_IFACE, "Id", cancellable)).get_string();
                    conn_uuid = (yield get_prop_dbus(ac_path, NM_ACTIVE_CONN_IFACE, "Uuid", cancellable)).get_string();
                } catch (Error e) {
                    debug_log("Could not read active connection id: " + e.message);
                }
            }

            if (conn_name == "" && dev_type == NM_DEVICE_TYPE_ETHERNET) {
                try {
                    Variant available_connections = yield get_prop_dbus(
                        dev_path,
                        NM_DEVICE_IFACE,
                        "AvailableConnections",
                        cancellable
                    );
                    for (int j = 0; j < available_connections.n_children(); j++) {
                        string conn_path = available_connections.get_child_value(j).get_string();
                        var conn = make_proxy(conn_path, NM_CONN_IFACE);
                        var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
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

        return devices_out;
    }

    public async WifiRefreshData get_wifi_refresh_data(Cancellable? cancellable = null) throws Error {
        var networks_list = yield get_wifi_networks_dbus(cancellable);
        var devices_list = yield get_devices_dbus(cancellable);

        WifiNetwork[] networks = {};
        foreach (var net in networks_list) {
            networks += net;
        }

        NetworkDevice[] devices = {};
        foreach (var dev in devices_list) {
            devices += dev;
        }

        return new WifiRefreshData((owned) networks, (owned) devices);
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
        var saved_profile_index = build_wifi_saved_profile_index();
        ambiguous = saved_profile_index.ambiguous_ssids.contains(ssid);
        if (ambiguous) {
            return null;
        }

        if (saved_profile_index.ssid_to_conn_path.contains(ssid)) {
            return saved_profile_index.ssid_to_conn_path.get(ssid);
        }

        return null;
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

    private async void fill_runtime_ipv4_for_device_dbus(
        string device_path,
        bool device_connected,
        NetworkIpSettings out_ip,
        Cancellable? cancellable = null
    ) {
        if (!device_connected) {
            return;
        }

        try {
            string active_conn_path = (yield get_prop_dbus(
                device_path,
                NM_DEVICE_IFACE,
                "ActiveConnection",
                cancellable
            )).get_string();
            if (active_conn_path == "/") {
                return;
            }

            string ip4_config_path = (yield get_prop_dbus(
                active_conn_path,
                NM_ACTIVE_CONN_IFACE,
                "Ip4Config",
                cancellable
            )).get_string();
            if (ip4_config_path == "/") {
                return;
            }

            Variant address_data = yield get_prop_dbus(
                ip4_config_path,
                NM_IP4_CONFIG_IFACE,
                "AddressData",
                cancellable
            );
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
                out_ip.current_gateway = (yield get_prop_dbus(
                    ip4_config_path,
                    NM_IP4_CONFIG_IFACE,
                    "Gateway",
                    cancellable
                )).get_string();
            } catch (Error gateway_err) {
                debug_log("could not read runtime IPv4 gateway: " + gateway_err.message);
            }

            try {
                Variant dns_data = yield get_prop_dbus(
                    ip4_config_path,
                    NM_IP4_CONFIG_IFACE,
                    "NameserverData",
                    cancellable
                );
                out_ip.current_dns = extract_dns_list_string(dns_data);
            } catch (Error dns_err) {
                debug_log("could not read runtime IPv4 DNS: " + dns_err.message);
            }
        } catch (Error e) {
            debug_log("could not read runtime IPv4 details: " + e.message);
        }
    }

    private async void fill_runtime_ipv4_for_wifi_dbus(
        WifiNetwork network,
        NetworkIpSettings out_ip,
        Cancellable? cancellable = null
    ) {
        yield fill_runtime_ipv4_for_device_dbus(
            network.device_path,
            network.connected,
            out_ip,
            cancellable
        );
    }

    public async NetworkIpSettings get_wifi_network_ip_settings(
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings();

        if (network.saved) {
            try {
                string conn_path = yield resolve_wifi_connection_path(
                    network,
                    "Multiple saved profiles share this SSID. Select a specific profile by UUID.",
                    "Saved connection not found.",
                    cancellable
                );

                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
                var all_settings = settings_res.get_child_value(0);
                fill_configured_ipv4_from_settings(all_settings, ip_settings);
            } catch (Error e) {
                debug_log("could not read saved wifi ipv4 settings: " + e.message);
            }
        }

        yield fill_runtime_ipv4_for_wifi_dbus(network, ip_settings, cancellable);
        return ip_settings;
    }

    private async string resolve_wifi_connection_path(
        WifiNetwork network,
        string ambiguous_message,
        string not_found_message,
        Cancellable? cancellable = null
    ) throws Error {
        string? uuid_match = null;
        string? ssid_match = null;
        bool ssid_ambiguous = false;

        var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
        var list_res = yield call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string candidate_path = conns.get_child_value(i).get_string();
            var conn = make_proxy(candidate_path, NM_CONN_IFACE);
            var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
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

            if (network.saved_connection_uuid.strip() != "") {
                Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
                if (uuid_v != null && uuid_v.get_string() == network.saved_connection_uuid) {
                    uuid_match = candidate_path;
                    break;
                }
            }

            Variant? ssid_v = wifi_group.lookup_value("ssid", new VariantType("ay"));
            if (ssid_v == null || decode_ssid(ssid_v) != network.ssid) {
                continue;
            }

            if (ssid_match != null) {
                ssid_ambiguous = true;
            } else {
                ssid_match = candidate_path;
            }
        }

        if (uuid_match != null) {
            return uuid_match;
        }

        if (ssid_ambiguous) {
            throw new IOError.FAILED(ambiguous_message);
        }

        if (ssid_match == null) {
            throw new IOError.NOT_FOUND(not_found_message);
        }

        return ssid_match;
    }

    public async bool update_wifi_network_settings(
        WifiNetwork network,
        string password,
        string ipv4_method,
        string ipv4_address,
        uint32 ipv4_prefix,
        bool gateway_auto,
        string ipv4_gateway,
        bool dns_auto,
        string[] ipv4_dns_servers,
        Cancellable? cancellable = null
    ) throws Error {
        string conn_path = yield resolve_wifi_connection_path(
            network,
            "Multiple saved profiles share this SSID. Refusing ambiguous update.",
            "No saved connection found for this network.",
            cancellable
        );

        string method = normalize_ipv4_method(ipv4_method);
        string address = ipv4_address.strip();
        string gateway = ipv4_gateway.strip();

        if (!gateway_auto && gateway == "") {
            throw new IOError.FAILED("Manual gateway requires a gateway address.");
        }

        if (!gateway_auto && method == "disabled") {
            throw new IOError.FAILED("Manual gateway is not supported when IPv4 method is Disabled.");
        }

        if (!dns_auto && ipv4_dns_servers.length == 0) {
            throw new IOError.FAILED("Manual DNS requires at least one DNS server.");
        }

        if (method == "manual") {
            if (address == "") {
                throw new IOError.FAILED("Manual IPv4 requires an address.");
            }
            if (ipv4_prefix == 0 || ipv4_prefix > 32) {
                throw new IOError.FAILED("Manual IPv4 prefix must be between 1 and 32.");
            }
        }

        var conn = make_proxy(conn_path, NM_CONN_IFACE);
        var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
        var all_settings = settings_res.get_child_value(0);

        Variant updated_ipv4;
        string builder_error = "";
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
            out builder_error
        )) {
            throw new IOError.FAILED(builder_error);
        }

        Variant updated_settings = NmWifiSettingsBuilder.build_updated_connection_settings(
            all_settings,
            updated_ipv4,
            network.is_secured,
            password
        );

        yield call_dbus(
            conn,
            "Update",
            new Variant("(@a{sa{sv}})", updated_settings),
            cancellable
        );
        return true;
    }

    private async string resolve_ethernet_connection_path(
        NetworkDevice device,
        string ambiguous_message,
        string not_found_message,
        Cancellable? cancellable = null
    ) throws Error {
        string? uuid_match = null;
        string? name_match = null;
        bool name_ambiguous = false;

        var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
        var list_res = yield call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string candidate_path = conns.get_child_value(i).get_string();
            var conn = make_proxy(candidate_path, NM_CONN_IFACE);
            var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
            var all_settings = settings_res.get_child_value(0);

            Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
            if (conn_group == null) {
                continue;
            }

            Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
            if (type_v == null || type_v.get_string() != "802-3-ethernet") {
                continue;
            }

            if (device.connection_uuid.strip() != "") {
                Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
                if (uuid_v != null && uuid_v.get_string() == device.connection_uuid) {
                    uuid_match = candidate_path;
                    break;
                }
            }

            Variant? id_v = conn_group.lookup_value("id", new VariantType("s"));
            if (id_v != null && id_v.get_string() == device.connection) {
                if (name_match != null) {
                    name_ambiguous = true;
                } else {
                    name_match = candidate_path;
                }
            }
        }

        if (uuid_match != null) {
            return uuid_match;
        }

        if (name_ambiguous) {
            throw new IOError.FAILED(ambiguous_message);
        }

        if (name_match == null) {
            throw new IOError.NOT_FOUND(not_found_message);
        }

        return name_match;
    }

    public async bool connect_ethernet_device(
        NetworkDevice device,
        Cancellable? cancellable = null
    ) throws Error {
        if (device.connection.strip() == "") {
            throw new IOError.FAILED("No saved Ethernet profile available for this interface.");
        }

        string conn_path = yield resolve_ethernet_connection_path(
            device,
            "Multiple Ethernet profiles share this name. Use UUID to activate a specific profile.",
            "No saved Ethernet profile found.",
            cancellable
        );

        var nm = make_proxy(NM_PATH, NM_IFACE);
        yield call_dbus(
            nm,
            "ActivateConnection",
            new Variant("(ooo)", conn_path, "/", "/"),
            cancellable
        );
        return true;
    }

    public async bool disconnect_device(
        string interface_name,
        Cancellable? cancellable = null
    ) throws Error {
        var nm = make_proxy(NM_PATH, NM_IFACE);
        var devices_res = yield call_dbus(nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value(0);

        for (int i = 0; i < devices.n_children(); i++) {
            string dev_path = devices.get_child_value(i).get_string();
            string iface = (yield get_prop_dbus(
                dev_path,
                NM_DEVICE_IFACE,
                "Interface",
                cancellable
            )).get_string();
            if (iface != interface_name) {
                continue;
            }

            var dev = make_proxy(dev_path, NM_DEVICE_IFACE);
            yield call_dbus(dev, "Disconnect", null, cancellable);
            return true;
        }

        throw new IOError.NOT_FOUND("Device not found.");
    }

    public async NetworkIpSettings get_ethernet_device_ip_settings(
        NetworkDevice device,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings();

        if (device.connection.strip() != "") {
            try {
                string conn_path = yield resolve_ethernet_connection_path(
                    device,
                    "Multiple Ethernet profiles share this name. Select by UUID.",
                    "No saved Ethernet profile found.",
                    cancellable
                );
                var conn = make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
                var all_settings = settings_res.get_child_value(0);
                fill_configured_ipv4_from_settings(all_settings, ip_settings);
            } catch (Error e) {
                debug_log("could not read saved ethernet ipv4 settings: " + e.message);
            }
        }

        yield fill_runtime_ipv4_for_device_dbus(
            device.device_path,
            device.is_connected,
            ip_settings,
            cancellable
        );
        return ip_settings;
    }

    public async bool update_ethernet_device_settings(
        NetworkDevice device,
        string ipv4_method,
        string ipv4_address,
        uint32 ipv4_prefix,
        bool gateway_auto,
        string ipv4_gateway,
        bool dns_auto,
        string[] ipv4_dns_servers,
        Cancellable? cancellable = null
    ) throws Error {
        if (device.connection.strip() == "") {
            throw new IOError.FAILED("No Ethernet profile is available for this interface.");
        }

        string conn_path = yield resolve_ethernet_connection_path(
            device,
            "Multiple Ethernet profiles share this name. Refusing ambiguous update.",
            "No saved Ethernet profile found.",
            cancellable
        );

        string method = normalize_ipv4_method(ipv4_method);
        string address = ipv4_address.strip();
        string gateway = ipv4_gateway.strip();

        if (!gateway_auto && gateway == "") {
            throw new IOError.FAILED("Manual gateway requires a gateway address.");
        }
        if (!gateway_auto && method == "disabled") {
            throw new IOError.FAILED("Manual gateway is not supported when IPv4 method is Disabled.");
        }
        if (!dns_auto && ipv4_dns_servers.length == 0) {
            throw new IOError.FAILED("Manual DNS requires at least one DNS server.");
        }
        if (method == "manual") {
            if (address == "") {
                throw new IOError.FAILED("Manual IPv4 requires an address.");
            }
            if (ipv4_prefix == 0 || ipv4_prefix > 32) {
                throw new IOError.FAILED("Manual IPv4 prefix must be between 1 and 32.");
            }
        }

        var conn = make_proxy(conn_path, NM_CONN_IFACE);
        var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
        var all_settings = settings_res.get_child_value(0);

        Variant updated_ipv4;
        string builder_error = "";
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
            out builder_error
        )) {
            throw new IOError.FAILED(builder_error);
        }

        Variant updated_settings = NmWifiSettingsBuilder.build_updated_connection_settings(
            all_settings,
            updated_ipv4,
            false,
            ""
        );

        yield call_dbus(
            conn,
            "Update",
            new Variant("(@a{sa{sv}})", updated_settings),
            cancellable
        );
        return true;
    }

    public async List<NetworkDevice> get_devices(Cancellable? cancellable = null) throws Error {
        return yield get_devices_dbus(cancellable);
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

    private List<NetworkDevice> get_devices_sync() {
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

    private async bool set_nm_bool_property_dbus(
        string prop_name,
        bool value,
        Cancellable? cancellable = null
    ) throws Error {
        var proxy = make_proxy(NM_PATH, DBUS_PROPS_IFACE);
        yield call_dbus(
            proxy,
            "Set",
            new Variant("(ssv)", NM_IFACE, prop_name, new Variant.boolean(value)),
            cancellable
        );
        return true;
    }

    public async bool set_wifi_enabled(bool enabled, Cancellable? cancellable = null) throws Error {
        return yield set_nm_bool_property_dbus("WirelessEnabled", enabled, cancellable);
    }

    public async bool set_networking_enabled(bool enabled, Cancellable? cancellable = null) throws Error {
        try {
            var nm = make_proxy(NM_PATH, NM_IFACE);
            yield call_dbus(
                nm,
                "Enable",
                new Variant("(b)", enabled),
                cancellable
            );
            return true;
        } catch (Error e) {
            debug_log("Enable() failed, falling back to NetworkingEnabled property: " + e.message);
            return yield set_nm_bool_property_dbus("NetworkingEnabled", enabled, cancellable);
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
        if (!set_nm_bool_property("WirelessEnabled", enabled_after_toggle, out error_message)) {
            return false;
        }
        return true;
    }

    public List<WifiNetwork> get_wifi_networks() {
        var networks = new List<WifiNetwork>();
        var by_ssid = new HashTable<string, WifiNetwork>(str_hash, str_equal);
        var saved_profile_index = build_wifi_saved_profile_index();

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
                        existing.saved = saved_profile_index.saved_ssids.contains(ssid);
                        existing.saved_connection_uuid = saved_profile_index.unique_saved_ssid_uuids.contains(ssid)
                            ? saved_profile_index.unique_saved_ssid_uuids.get(ssid)
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
                        saved_connection_uuid = saved_profile_index.unique_saved_ssid_uuids.contains(ssid)
                            ? saved_profile_index.unique_saved_ssid_uuids.get(ssid)
                            : "",
                        signal = signal,
                        connected = is_connected,
                        is_secured = is_secured,
                        saved = saved_profile_index.saved_ssids.contains(ssid),
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

    public async bool connect_saved_wifi(WifiNetwork network, Cancellable? cancellable = null) throws Error {
        string conn_path = yield resolve_wifi_connection_path(
            network,
            "Multiple saved profiles share this SSID. Refusing ambiguous connect.",
            "No saved profile found for SSID.",
            cancellable
        );

        var nm = make_proxy(NM_PATH, NM_IFACE);
        yield call_dbus(
            nm,
            "ActivateConnection",
            new Variant("(ooo)", conn_path, network.device_path, network.ap_path),
            cancellable
        );
        return true;
    }

    public async bool connect_wifi(
        WifiNetwork network,
        string? password,
        Cancellable? cancellable = null
    ) throws Error {
        if (network.saved) {
            return yield connect_saved_wifi(network, cancellable);
        }

        if (password == null) {
            password = "";
        }

        return yield connect_wifi_with_password(network, password, cancellable);
    }

    public async bool connect_wifi_with_password(
        WifiNetwork network,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        if (network.is_secured && password.strip() == "") {
            throw new IOError.FAILED("Password is required for secured networks.");
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

        yield call_dbus(
            nm,
            "AddAndActivateConnection",
            new Variant("(@a{sa{sv}}oo)", conn.end(), network.device_path, network.ap_path),
            cancellable
        );
        return true;
    }

    public async bool disconnect_wifi(WifiNetwork network, Cancellable? cancellable = null) throws Error {
        var dev = make_proxy(network.device_path, NM_DEVICE_IFACE);
        yield call_dbus(dev, "Disconnect", null, cancellable);
        return true;
    }

    public async bool forget_network(string ssid_or_name, Cancellable? cancellable = null) throws Error {
        string? conn_path = null;
        string? ssid_match = null;
        string? name_match = null;
        bool ssid_ambiguous = false;
        bool name_ambiguous = false;

        var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
        var list_res = yield call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string candidate_path = conns.get_child_value(i).get_string();
            var conn = make_proxy(candidate_path, NM_CONN_IFACE);
            var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
            var all_settings = settings_res.get_child_value(0);

            Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
            if (conn_group == null) {
                continue;
            }

            Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
            if (uuid_v != null && uuid_v.get_string() == ssid_or_name) {
                conn_path = candidate_path;
                break;
            }

            Variant? id_v = conn_group.lookup_value("id", new VariantType("s"));
            if (id_v != null && id_v.get_string() == ssid_or_name) {
                if (name_match != null) {
                    name_ambiguous = true;
                } else {
                    name_match = candidate_path;
                }
            }

            Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
            if (type_v == null || type_v.get_string() != "802-11-wireless") {
                continue;
            }

            Variant? wifi_group = all_settings.lookup_value("802-11-wireless", new VariantType("a{sv}"));
            if (wifi_group == null) {
                continue;
            }

            Variant? ssid_v = wifi_group.lookup_value("ssid", new VariantType("ay"));
            if (ssid_v == null || decode_ssid(ssid_v) != ssid_or_name) {
                continue;
            }

            if (ssid_match != null) {
                ssid_ambiguous = true;
            } else {
                ssid_match = candidate_path;
            }
        }

        if (conn_path == null) {
            conn_path = ssid_match != null && !ssid_ambiguous ? ssid_match : null;
        }
        if (conn_path == null) {
            conn_path = name_match != null && !name_ambiguous ? name_match : null;
        }

        if (conn_path == null) {
            if (ssid_ambiguous || name_ambiguous) {
                throw new IOError.FAILED(
                    "Multiple profiles match this identifier. Use UUID to avoid ambiguity."
                );
            }
            throw new IOError.NOT_FOUND("No saved connection found.");
        }

        var conn = make_proxy(conn_path, NM_CONN_IFACE);
        yield call_dbus(conn, "Delete", null, cancellable);
        return true;
    }

    public async bool connect_vpn(string name, Cancellable? cancellable = null) throws Error {
        bool ambiguous = false;
        string? conn_path = find_connection_by_name(name, out ambiguous);
        if (ambiguous) {
            throw new IOError.FAILED(
                "Multiple connections share this name. Use UUID to activate a specific profile."
            );
        }
        if (conn_path == null) {
            throw new IOError.NOT_FOUND("Connection not found.");
        }

        var nm = make_proxy(NM_PATH, NM_IFACE);
        yield call_dbus(
            nm,
            "ActivateConnection",
            new Variant("(ooo)", conn_path, "/", "/"),
            cancellable
        );
        return true;
    }

    public async bool disconnect_vpn(string name, Cancellable? cancellable = null) throws Error {
        var nm = make_proxy(NM_PATH, NM_IFACE);
        Variant active_conns = yield get_prop_dbus(NM_PATH, NM_IFACE, "ActiveConnections", cancellable);
        for (int i = 0; i < active_conns.n_children(); i++) {
            string ac_path = active_conns.get_child_value(i).get_string();
            string id = (yield get_prop_dbus(
                ac_path,
                NM_ACTIVE_CONN_IFACE,
                "Id",
                cancellable
            )).get_string();
            if (id != name) {
                continue;
            }

            yield call_dbus(nm, "DeactivateConnection", new Variant("(o)", ac_path), cancellable);
            return true;
        }

        throw new IOError.NOT_FOUND("Active connection not found.");
    }

    public async List<VpnConnection> get_vpn_connections(Cancellable? cancellable = null) throws Error {
        var vpns = new List<VpnConnection>();

        var active_map = new HashTable<string, string>(str_hash, str_equal);
        Variant active_conns = yield get_prop_dbus(NM_PATH, NM_IFACE, "ActiveConnections", cancellable);
        for (int i = 0; i < active_conns.n_children(); i++) {
            string ac_path = active_conns.get_child_value(i).get_string();
            try {
                string id = (yield get_prop_dbus(ac_path, NM_ACTIVE_CONN_IFACE, "Id", cancellable)).get_string();
                active_map.insert(id, "activated");
            } catch (Error e) {
                debug_log("Could not read active VPN id: " + e.message);
            }
        }

        var settings = make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
        var list_res = yield call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string conn_path = conns.get_child_value(i).get_string();
            var conn = make_proxy(conn_path, NM_CONN_IFACE);
            var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
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

        return vpns;
    }

    public async bool scan_wifi(Cancellable? cancellable = null) throws Error {
        var nm = make_proxy(NM_PATH, NM_IFACE);
        var devices_res = yield call_dbus(nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value(0);

        uint scanned = 0;
        for (int i = 0; i < devices.n_children(); i++) {
            string dev_path = devices.get_child_value(i).get_string();
            uint32 dev_type = (yield get_prop_dbus(
                dev_path,
                NM_DEVICE_IFACE,
                "DeviceType",
                cancellable
            )).get_uint32();
            if (dev_type != NM_DEVICE_TYPE_WIFI) {
                continue;
            }

            var wifi = make_proxy(dev_path, NM_WIRELESS_IFACE);
            var options = new VariantBuilder(new VariantType("a{sv}"));
            yield call_dbus(
                wifi,
                "RequestScan",
                new Variant("(@a{sv})", options.end()),
                cancellable
            );
            scanned++;
        }

        debug_log("requested scan on %u wifi device(s)".printf(scanned));
        return true;
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

        var devices = get_devices_sync();
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
