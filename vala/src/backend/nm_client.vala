using GLib;

public class NetworkManagerClientVala : Object {
    private bool debug_enabled;

    public NetworkManagerClientVala(bool debug_enabled) {
        this.debug_enabled = debug_enabled;
    }

    private void debug_log(string message) {
        if (debug_enabled) {
            stderr.printf("[rebuild-nm] %s\n", message);
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

    private static Variant make_ssid_variant(string ssid) {
        var ssid_bytes = new VariantBuilder(new VariantType("ay"));
        for (int i = 0; i < ssid.length; i++) {
            ssid_bytes.add("y", (uint8) ssid[i]);
        }
        return ssid_bytes.end();
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
                    bool is_secured = ((flags & 0x1) != 0) || wpa_flags != 0 || rsn_flags != 0;

                    seen.insert(ssid, true);
                    networks.append(new WifiNetwork() {
                        ssid = ssid,
                        signal = signal,
                        connected = (ap_path == active_ap_path),
                        is_secured = is_secured,
                        saved = saved_ssids.contains(ssid),
                        device_path = dev_path,
                        ap_path = ap_path
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
}
