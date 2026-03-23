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

    public bool is_networking_enabled(out string error_message) {
        error_message = "";

        try {
            var proxy = make_proxy(NM_PATH, DBUS_PROPS_IFACE);
            var result = proxy.call_sync(
                "Get",
                new Variant("(ss)", NM_IFACE, "NetworkingEnabled"),
                DBusCallFlags.NONE,
                -1,
                null
            );
            var boxed = result.get_child_value(0);
            bool enabled = boxed.get_variant().get_boolean();
            debug_log("networking enabled: %s".printf(enabled.to_string()));
            return enabled;
        } catch (Error e) {
            error_message = e.message;
            debug_log("failed to read NetworkingEnabled: " + e.message);
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
