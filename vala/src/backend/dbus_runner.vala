using GLib;

public class DbusRequestResult : Object {
    public bool ok;
    public Variant? value;
    public string error_message;

    public DbusRequestResult.success(Variant value) {
        this.ok = true;
        this.value = value;
        this.error_message = "";
    }

    public DbusRequestResult.failure(string error_message) {
        this.ok = false;
        this.value = null;
        this.error_message = error_message;
    }
}

public class GlobalDbusRunner : Object {
    private static GlobalDbusRunner? instance;

    public static GlobalDbusRunner get_default() {
        if (instance == null) {
            instance = new GlobalDbusRunner();
        }

        return instance;
    }

    public async DbusRequestResult run(
        BusType bus_type,
        string service,
        string object_path,
        string iface,
        string method,
        Variant? parameters = null,
        DBusCallFlags flags = DBusCallFlags.NONE,
        int timeout_ms = 10000,
        Cancellable? cancellable = null
    ) {
        try {
            var proxy = yield new DBusProxy.for_bus(
                bus_type,
                DBusProxyFlags.NONE,
                null,
                service,
                object_path,
                iface,
                cancellable
            );

            return yield run_with_proxy(proxy, method, parameters, flags, timeout_ms, cancellable);
        } catch (Error e) {
            return new DbusRequestResult.failure(e.message);
        }
    }

    public async DbusRequestResult run_with_proxy(
        DBusProxy proxy,
        string method,
        Variant? parameters = null,
        DBusCallFlags flags = DBusCallFlags.NONE,
        int timeout_ms = 10000,
        Cancellable? cancellable = null
    ) {
        try {
            var result = yield proxy.call(method, parameters, flags, timeout_ms, cancellable);
            return new DbusRequestResult.success(result);
        } catch (Error e) {
            return new DbusRequestResult.failure(e.message);
        }
    }
}