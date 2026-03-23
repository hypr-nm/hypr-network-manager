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
