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

    private const int DBUS_TIMEOUT_MIN_MS = 3000;
    private const int DBUS_TIMEOUT_MAX_MS = 120000;

    private static int clamp_timeout_ms(int timeout_ms) {
        if (timeout_ms < DBUS_TIMEOUT_MIN_MS) {
            return DBUS_TIMEOUT_MIN_MS;
        }
        if (timeout_ms > DBUS_TIMEOUT_MAX_MS) {
            return DBUS_TIMEOUT_MAX_MS;
        }
        return timeout_ms;
    }

    private static int resolve_timeout_ms(int requested_timeout_ms) {
        int base_timeout = requested_timeout_ms > 0 ? requested_timeout_ms : NM_DBUS_TIMEOUT_MS;
        return clamp_timeout_ms(base_timeout);
    }

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
        int timeout_ms = 20000,
        Cancellable? cancellable = null
    ) {
        int effective_timeout_ms = resolve_timeout_ms(timeout_ms);

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

            return yield run_with_proxy(proxy, method, parameters, flags, effective_timeout_ms, cancellable);
        } catch (Error e) {
            log_warn(
                "dbus-runner",
                "dbus_call: proxy creation failed service=" + service
                    + " iface=" + iface
                    + " object=" + redact_object_path(object_path)
                    + " method=" + method
                    + " timeout_ms=" + effective_timeout_ms.to_string()
                    + " error=" + e.message
            );
            return new DbusRequestResult.failure(e.message);
        }
    }

    public async DbusRequestResult run_with_proxy(
        DBusProxy proxy,
        string method,
        Variant? parameters = null,
        DBusCallFlags flags = DBusCallFlags.NONE,
        int timeout_ms = 20000,
        Cancellable? cancellable = null
    ) {
        int effective_timeout_ms = resolve_timeout_ms(timeout_ms);

        try {
            var result = yield proxy.call(method, parameters, flags, effective_timeout_ms, cancellable);
            return new DbusRequestResult.success(result);
        } catch (Error e) {
            string proxy_path = proxy.get_object_path();
            log_warn(
                "dbus-runner",
                "dbus_call: request failed object=" + redact_object_path(proxy_path)
                    + " method=" + method
                    + " timeout_ms=" + effective_timeout_ms.to_string()
                    + " error=" + e.message
            );
            return new DbusRequestResult.failure(e.message);
        }
    }
}