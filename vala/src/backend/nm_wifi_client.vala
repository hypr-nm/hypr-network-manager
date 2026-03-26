using GLib;

public class NmWifiClient : Object {
    private NetworkManagerClientVala core;

    public NmWifiClient(NetworkManagerClientVala core) {
        this.core = core;
    }

    private static string decode_ssid(Variant value) {
        return NmClientUtils.decode_ssid(value);
    }

    private void index_saved_profile(
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

    private WifiSavedProfileIndex build_saved_profile_index() {
        var index = new WifiSavedProfileIndex();

        try {
            var settings = core.make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = core.make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = conn.call_sync("GetSettings", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
                var all_settings = settings_res.get_child_value(0);
                index_saved_profile(index, conn_path, all_settings);
            }
        } catch (Error e) {
            core.debug_log("could not build wifi saved profile index: " + e.message);
        }

        return index;
    }

    private async WifiSavedProfileIndex build_saved_profile_index_dbus(
        Cancellable? cancellable = null
    ) throws Error {
        var index = new WifiSavedProfileIndex();

        var settings = core.make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
        var list_res = yield core.call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string conn_path = conns.get_child_value(i).get_string();
            var conn = core.make_proxy(conn_path, NM_CONN_IFACE);
            var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
            var all_settings = settings_res.get_child_value(0);
            index_saved_profile(index, conn_path, all_settings);
        }

        return index;
    }

    private async List<WifiNetwork> get_networks_dbus(Cancellable? cancellable = null) throws Error {
        var networks = new List<WifiNetwork>();
        var by_ssid = new HashTable<string, WifiNetwork>(str_hash, str_equal);
        var saved_profile_index = yield build_saved_profile_index_dbus(cancellable);

        var nm = core.make_proxy(NM_PATH, NM_IFACE);
        var devices_res = yield core.call_dbus(nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value(0);

        for (int i = 0; i < devices.n_children(); i++) {
            string dev_path = devices.get_child_value(i).get_string();
            uint32 dev_type = (yield core.get_prop_dbus(
                dev_path,
                NM_DEVICE_IFACE,
                "DeviceType",
                cancellable
            )).get_uint32();
            if (dev_type != NM_DEVICE_TYPE_WIFI) {
                continue;
            }

            string active_ap_path = (yield core.get_prop_dbus(
                dev_path,
                NM_WIRELESS_IFACE,
                "ActiveAccessPoint",
                cancellable
            )).get_string();

            var wifi = core.make_proxy(dev_path, NM_WIRELESS_IFACE);
            var aps_res = yield core.call_dbus(wifi, "GetAccessPoints", null, cancellable);
            var aps = aps_res.get_child_value(0);

            for (int j = 0; j < aps.n_children(); j++) {
                string ap_path = aps.get_child_value(j).get_string();

                string ssid = decode_ssid(yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Ssid", cancellable));
                if (ssid == "") {
                    ssid = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "HwAddress", cancellable)).get_string();
                }

                uint8 signal = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Strength", cancellable)).get_byte();
                uint32 flags = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Flags", cancellable)).get_uint32();
                uint32 wpa_flags = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "WpaFlags", cancellable)).get_uint32();
                uint32 rsn_flags = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "RsnFlags", cancellable)).get_uint32();
                string bssid = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "HwAddress", cancellable)).get_string();
                uint32 frequency = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Frequency", cancellable)).get_uint32();
                uint32 max_bitrate = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "MaxBitrate", cancellable)).get_uint32();
                uint32 mode = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Mode", cancellable)).get_uint32();
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

    private async string resolve_connection_path(
        WifiNetwork network,
        string ambiguous_message,
        string not_found_message,
        Cancellable? cancellable = null
    ) throws Error {
        string? uuid_match = null;
        string? ssid_match = null;
        bool ssid_ambiguous = false;

        var settings = core.make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
        var list_res = yield core.call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string candidate_path = conns.get_child_value(i).get_string();
            var conn = core.make_proxy(candidate_path, NM_CONN_IFACE);
            var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
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

    public async WifiRefreshData get_refresh_data(Cancellable? cancellable = null) throws Error {
        var networks_list = yield get_networks_dbus(cancellable);
        var devices_list = yield core.get_devices_dbus(cancellable);

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

    public async NetworkIpSettings get_network_ip_settings(
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings();

        if (network.saved) {
            try {
                string conn_path = yield resolve_connection_path(
                    network,
                    "Multiple saved profiles share this SSID. Select a specific profile by UUID.",
                    "Saved connection not found.",
                    cancellable
                );

                var conn = core.make_proxy(conn_path, NM_CONN_IFACE);
                var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
                var all_settings = settings_res.get_child_value(0);
                NetworkManagerClientVala.fill_configured_ipv4_from_settings(all_settings, ip_settings);
                NetworkManagerClientVala.fill_configured_ipv6_from_settings(all_settings, ip_settings);
            } catch (Error e) {
                core.debug_log("could not read saved wifi ipv4 settings: " + e.message);
            }
        }

        yield core.fill_runtime_ipv4_for_device_dbus(
            network.device_path,
            network.connected,
            ip_settings,
            cancellable
        );
        yield core.fill_runtime_ipv6_for_device_dbus(
            network.device_path,
            network.connected,
            ip_settings,
            cancellable
        );
        return ip_settings;
    }

    public async bool update_network_settings(
        WifiNetwork network,
        string password,
        string ipv4_method,
        string ipv4_address,
        uint32 ipv4_prefix,
        bool gateway_auto,
        string ipv4_gateway,
        bool dns_auto,
        string[] ipv4_dns_servers,
        string ipv6_method,
        string ipv6_address,
        uint32 ipv6_prefix,
        bool ipv6_gateway_auto,
        string ipv6_gateway,
        bool ipv6_dns_auto,
        string[] ipv6_dns_servers,
        Cancellable? cancellable = null
    ) throws Error {
        string conn_path = yield resolve_connection_path(
            network,
            "Multiple saved profiles share this SSID. Refusing ambiguous update.",
            "No saved connection found for this network.",
            cancellable
        );

        string method = NetworkManagerClientVala.normalize_ipv4_method(ipv4_method);
        string address = ipv4_address.strip();
        string gateway = ipv4_gateway.strip();
        string method6 = NetworkManagerClientVala.normalize_ipv6_method(ipv6_method);
        string address6 = ipv6_address.strip();
        string gateway6 = ipv6_gateway.strip();

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

        if (!ipv6_gateway_auto && gateway6 == "") {
            throw new IOError.FAILED("Manual IPv6 gateway requires a gateway address.");
        }

        if ((method6 == "disabled" || method6 == "ignore") && !ipv6_gateway_auto) {
            throw new IOError.FAILED(
                "Manual IPv6 gateway is not supported when IPv6 method is Disabled or Ignore."
            );
        }

        if (!ipv6_dns_auto && ipv6_dns_servers.length == 0) {
            throw new IOError.FAILED("Manual IPv6 DNS requires at least one DNS server.");
        }

        if (method6 == "manual") {
            if (address6 == "") {
                throw new IOError.FAILED("Manual IPv6 requires an address.");
            }
            if (ipv6_prefix == 0 || ipv6_prefix > 128) {
                throw new IOError.FAILED("Manual IPv6 prefix must be between 1 and 128.");
            }
        }

        var conn = core.make_proxy(conn_path, NM_CONN_IFACE);
        var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
        var all_settings = settings_res.get_child_value(0);

        Variant updated_ipv4;
        Variant updated_ipv6;
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

        if (!NmWifiSettingsBuilder.build_updated_ipv6_section(
            all_settings,
            method6,
            address6,
            ipv6_prefix,
            ipv6_gateway_auto,
            gateway6,
            ipv6_dns_auto,
            ipv6_dns_servers,
            out updated_ipv6,
            out builder_error
        )) {
            throw new IOError.FAILED(builder_error);
        }

        Variant updated_settings = NmWifiSettingsBuilder.build_updated_connection_settings(
            all_settings,
            updated_ipv4,
            updated_ipv6,
            network.is_secured,
            password
        );

        yield core.call_dbus(
            conn,
            "Update",
            new Variant("(@a{sa{sv}})", updated_settings),
            cancellable
        );
        return true;
    }

    public List<WifiNetwork> get_networks() {
        var networks = new List<WifiNetwork>();
        var by_ssid = new HashTable<string, WifiNetwork>(str_hash, str_equal);
        var saved_profile_index = build_saved_profile_index();

        try {
            var nm = core.make_proxy(NM_PATH, NM_IFACE);
            var devices_res = nm.call_sync("GetDevices", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var devices = devices_res.get_child_value(0);

            for (int i = 0; i < devices.n_children(); i++) {
                string dev_path = devices.get_child_value(i).get_string();
                uint32 dev_type = core.get_prop(dev_path, NM_DEVICE_IFACE, "DeviceType").get_uint32();
                if (dev_type != NM_DEVICE_TYPE_WIFI) {
                    continue;
                }

                string active_ap_path = core.get_prop(dev_path, NM_WIRELESS_IFACE, "ActiveAccessPoint").get_string();

                var wifi = core.make_proxy(dev_path, NM_WIRELESS_IFACE);
                var aps_res = wifi.call_sync("GetAccessPoints", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
                var aps = aps_res.get_child_value(0);

                for (int j = 0; j < aps.n_children(); j++) {
                    string ap_path = aps.get_child_value(j).get_string();

                    string ssid = decode_ssid(core.get_prop(ap_path, NM_AP_IFACE, "Ssid"));
                    if (ssid == "") {
                        ssid = core.get_prop(ap_path, NM_AP_IFACE, "HwAddress").get_string();
                    }

                    uint8 signal = core.get_prop(ap_path, NM_AP_IFACE, "Strength").get_byte();
                    uint32 flags = core.get_prop(ap_path, NM_AP_IFACE, "Flags").get_uint32();
                    uint32 wpa_flags = core.get_prop(ap_path, NM_AP_IFACE, "WpaFlags").get_uint32();
                    uint32 rsn_flags = core.get_prop(ap_path, NM_AP_IFACE, "RsnFlags").get_uint32();
                    string bssid = core.get_prop(ap_path, NM_AP_IFACE, "HwAddress").get_string();
                    uint32 frequency = core.get_prop(ap_path, NM_AP_IFACE, "Frequency").get_uint32();
                    uint32 max_bitrate = core.get_prop(ap_path, NM_AP_IFACE, "MaxBitrate").get_uint32();
                    uint32 mode = core.get_prop(ap_path, NM_AP_IFACE, "Mode").get_uint32();
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
            core.debug_log("get_wifi_networks failed: " + e.message);
        }

        networks.sort((a, b) => {
            if (a.connected != b.connected) {
                return a.connected ? -1 : 1;
            }
            return (int) b.signal - (int) a.signal;
        });

        core.debug_log("discovered %u wifi networks".printf(networks.length()));
        return networks;
    }

    public async bool connect_saved(WifiNetwork network, Cancellable? cancellable = null) throws Error {
        string conn_path = yield resolve_connection_path(
            network,
            "Multiple saved profiles share this SSID. Refusing ambiguous connect.",
            "No saved profile found for SSID.",
            cancellable
        );

        var nm = core.make_proxy(NM_PATH, NM_IFACE);
        yield core.call_dbus(
            nm,
            "ActivateConnection",
            new Variant("(ooo)", conn_path, network.device_path, network.ap_path),
            cancellable
        );
        return true;
    }

    public new async bool connect(
        WifiNetwork network,
        string? password,
        Cancellable? cancellable = null
    ) throws Error {
        if (network.saved) {
            return yield connect_saved(network, cancellable);
        }

        if (password == null) {
            password = "";
        }

        return yield connect_with_password(network, password, cancellable);
    }

    public async bool connect_with_password(
        WifiNetwork network,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        if (network.is_secured && password.strip() == "") {
            throw new IOError.FAILED("Password is required for secured networks.");
        }

        var nm = core.make_proxy(NM_PATH, NM_IFACE);

        var conn = new VariantBuilder(new VariantType("a{sa{sv}}"));

        var conn_section = new VariantBuilder(new VariantType("a{sv}"));
        conn_section.add("{sv}", "id", new Variant.string(network.ssid));
        conn_section.add("{sv}", "type", new Variant.string("802-11-wireless"));
        conn_section.add("{sv}", "uuid", new Variant.string(Uuid.string_random()));
        conn_section.add("{sv}", "autoconnect", new Variant.boolean(true));
        conn.add("{s@a{sv}}", "connection", conn_section.end());

        var wifi_section = new VariantBuilder(new VariantType("a{sv}"));
        wifi_section.add("{sv}", "ssid", NmClientUtils.make_ssid_variant(network.ssid));
        conn.add("{s@a{sv}}", "802-11-wireless", wifi_section.end());

        if (network.is_secured) {
            var sec = new VariantBuilder(new VariantType("a{sv}"));
            sec.add("{sv}", "key-mgmt", new Variant.string("wpa-psk"));
            sec.add("{sv}", "psk", new Variant.string(password));
            conn.add("{s@a{sv}}", "802-11-wireless-security", sec.end());
        }

        yield core.call_dbus(
            nm,
            "AddAndActivateConnection",
            new Variant("(@a{sa{sv}}oo)", conn.end(), network.device_path, network.ap_path),
            cancellable
        );
        return true;
    }

    private async string resolve_wifi_device_path_for_hidden_connect(
        Cancellable? cancellable = null
    ) throws Error {
        string fallback_path = "";
        var devices = yield core.get_devices_dbus(cancellable);
        foreach (var dev in devices) {
            if (!dev.is_wifi) {
                continue;
            }

            if (fallback_path == "") {
                fallback_path = dev.device_path;
            }

            if (dev.is_connected) {
                return dev.device_path;
            }
        }

        if (fallback_path != "") {
            return fallback_path;
        }

        throw new IOError.NOT_FOUND("No Wi-Fi device available for hidden network connection.");
    }

    public async bool connect_hidden_network(
        string ssid,
        HiddenWifiSecurityMode security_mode,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        string hidden_ssid = ssid.strip();
        if (hidden_ssid == "") {
            throw new IOError.FAILED("SSID is required.");
        }

        if (HiddenWifiSecurityModeUtils.requires_password(security_mode) && password.strip() == "") {
            throw new IOError.FAILED("Password is required for the selected security mode.");
        }

        string device_path = yield resolve_wifi_device_path_for_hidden_connect(cancellable);
        var nm = core.make_proxy(NM_PATH, NM_IFACE);

        var conn = new VariantBuilder(new VariantType("a{sa{sv}}"));

        var conn_section = new VariantBuilder(new VariantType("a{sv}"));
        conn_section.add("{sv}", "id", new Variant.string(hidden_ssid));
        conn_section.add("{sv}", "type", new Variant.string("802-11-wireless"));
        conn_section.add("{sv}", "uuid", new Variant.string(Uuid.string_random()));
        conn_section.add("{sv}", "autoconnect", new Variant.boolean(true));
        conn.add("{s@a{sv}}", "connection", conn_section.end());

        var wifi_section = new VariantBuilder(new VariantType("a{sv}"));
        wifi_section.add("{sv}", "ssid", NmClientUtils.make_ssid_variant(hidden_ssid));
        wifi_section.add("{sv}", "hidden", new Variant.boolean(true));
        conn.add("{s@a{sv}}", "802-11-wireless", wifi_section.end());

        if (security_mode != HiddenWifiSecurityMode.OPEN) {
            var sec = new VariantBuilder(new VariantType("a{sv}"));

            sec.add(
                "{sv}",
                "key-mgmt",
                new Variant.string(HiddenWifiSecurityModeUtils.to_nm_key_mgmt(security_mode))
            );

            if (security_mode == HiddenWifiSecurityMode.WEP) {
                sec.add("{sv}", "wep-key0", new Variant.string(password));
                sec.add("{sv}", "wep-key-type", new Variant.uint32(1));
                sec.add("{sv}", "auth-alg", new Variant.string("open"));
            } else {
                // WPA2/WPA3 transition mode generally negotiates via WPA-PSK config.
                sec.add("{sv}", "psk", new Variant.string(password));
            }

            conn.add("{s@a{sv}}", "802-11-wireless-security", sec.end());
        }

        yield core.call_dbus(
            nm,
            "AddAndActivateConnection",
            new Variant("(@a{sa{sv}}oo)", conn.end(), device_path, "/"),
            cancellable
        );
        return true;
    }

    public new async bool disconnect(WifiNetwork network, Cancellable? cancellable = null) throws Error {
        var dev = core.make_proxy(network.device_path, NM_DEVICE_IFACE);
        yield core.call_dbus(dev, "Disconnect", null, cancellable);
        return true;
    }

    public async bool forget_network(string ssid_or_name, Cancellable? cancellable = null) throws Error {
        string? conn_path = null;
        string? ssid_match = null;
        string? name_match = null;
        bool ssid_ambiguous = false;
        bool name_ambiguous = false;

        var settings = core.make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
        var list_res = yield core.call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string candidate_path = conns.get_child_value(i).get_string();
            var conn = core.make_proxy(candidate_path, NM_CONN_IFACE);
            var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
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

        var conn = core.make_proxy(conn_path, NM_CONN_IFACE);
        yield core.call_dbus(conn, "Delete", null, cancellable);
        return true;
    }

    public async bool scan(Cancellable? cancellable = null) throws Error {
        var nm = core.make_proxy(NM_PATH, NM_IFACE);
        var devices_res = yield core.call_dbus(nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value(0);

        uint scanned = 0;
        for (int i = 0; i < devices.n_children(); i++) {
            string dev_path = devices.get_child_value(i).get_string();
            uint32 dev_type = (yield core.get_prop_dbus(
                dev_path,
                NM_DEVICE_IFACE,
                "DeviceType",
                cancellable
            )).get_uint32();
            if (dev_type != NM_DEVICE_TYPE_WIFI) {
                continue;
            }

            var wifi = core.make_proxy(dev_path, NM_WIRELESS_IFACE);
            var options = new VariantBuilder(new VariantType("a{sv}"));
            yield core.call_dbus(
                wifi,
                "RequestScan",
                new Variant("(@a{sv})", options.end()),
                cancellable
            );
            scanned++;
        }

        core.debug_log("requested scan on %u wifi device(s)".printf(scanned));
        return true;
    }
}
