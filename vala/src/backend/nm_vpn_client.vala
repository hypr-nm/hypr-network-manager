using GLib;

public class NmVpnClient : Object {
    private NetworkManagerClientVala core;

    public NmVpnClient(NetworkManagerClientVala core) {
        this.core = core;
    }

    private string? find_connection_by_name(string name, out bool ambiguous) {
        ambiguous = false;
        string? match = null;

        try {
            var settings = core.make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
            var list_res = settings.call_sync("ListConnections", null, DBusCallFlags.NONE, NM_DBUS_TIMEOUT_MS, null);
            var conns = list_res.get_child_value(0);

            for (int i = 0; i < conns.n_children(); i++) {
                string conn_path = conns.get_child_value(i).get_string();
                var conn = core.make_proxy(conn_path, NM_CONN_IFACE);
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
            core.debug_log("could not resolve connection by name: " + e.message);
        }

        return match;
    }

    public async bool connect(string name, Cancellable? cancellable = null) throws Error {
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

        var nm = core.make_proxy(NM_PATH, NM_IFACE);
        yield core.call_dbus(
            nm,
            "ActivateConnection",
            new Variant("(ooo)", conn_path, "/", "/"),
            cancellable
        );
        return true;
    }

    public async bool disconnect(string name, Cancellable? cancellable = null) throws Error {
        var nm = core.make_proxy(NM_PATH, NM_IFACE);
        Variant active_conns = yield core.get_prop_dbus(NM_PATH, NM_IFACE, "ActiveConnections", cancellable);
        for (int i = 0; i < active_conns.n_children(); i++) {
            string ac_path = active_conns.get_child_value(i).get_string();
            string id = (yield core.get_prop_dbus(
                ac_path,
                NM_ACTIVE_CONN_IFACE,
                "Id",
                cancellable
            )).get_string();
            if (id != name) {
                continue;
            }

            yield core.call_dbus(nm, "DeactivateConnection", new Variant("(o)", ac_path), cancellable);
            return true;
        }

        throw new IOError.NOT_FOUND("Active connection not found.");
    }

    public async List<VpnConnection> get_connections(Cancellable? cancellable = null) throws Error {
        var vpns = new List<VpnConnection>();

        var active_map = new HashTable<string, string>(str_hash, str_equal);
        Variant active_conns = yield core.get_prop_dbus(NM_PATH, NM_IFACE, "ActiveConnections", cancellable);
        for (int i = 0; i < active_conns.n_children(); i++) {
            string ac_path = active_conns.get_child_value(i).get_string();
            try {
                string id = (yield core.get_prop_dbus(ac_path, NM_ACTIVE_CONN_IFACE, "Id", cancellable)).get_string();
                active_map.insert(id, "activated");
            } catch (Error e) {
                core.debug_log("Could not read active VPN id: " + e.message);
            }
        }

        var settings = core.make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE);
        var list_res = yield core.call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string conn_path = conns.get_child_value(i).get_string();
            var conn = core.make_proxy(conn_path, NM_CONN_IFACE);
            var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
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
            if (id_v == null) {
                continue;
            }

            string name = id_v.get_string();
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
}
