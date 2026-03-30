using GLib;

public class NmVpnClient : GLib.Object {
    private NetworkManagerClient core;

    public NmVpnClient (NetworkManagerClient core) {
        this.core = core;
    }

    public new async bool connect (string name, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        NM.Connection? vpn_conn = null;

        foreach (var conn in client.get_connections ()) {
            var s_vpn = conn.get_setting_vpn ();
            if (s_vpn != null && conn.get_id () == name) {
                vpn_conn = conn;
                break;
            }
        }

        if (vpn_conn == null) {
            throw new IOError.NOT_FOUND ("VPN connection not found");
        }

        yield client.activate_connection_async (vpn_conn, null, null, cancellable);
        return true;
    }

    public new async bool disconnect (string name, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        foreach (var ac in client.get_active_connections ()) {
            var conn = ac.get_connection ();
            if (conn != null && conn.get_setting_vpn () != null && conn.get_id () == name) {
                yield client.deactivate_connection_async (ac, cancellable);
                return true;
            }
        }

        throw new IOError.NOT_FOUND ("Active VPN connection not found");
    }

    public async List<VpnConnection> get_connections (Cancellable? cancellable = null) throws Error {
        var vpns = new List<VpnConnection> ();
        var client = core.nm_client;

        foreach (var conn in client.get_connections ()) {
            var s_vpn = conn.get_setting_vpn ();
            if (s_vpn == null) {
                continue;
            }

            var vpn = new VpnConnection () {
                name = conn.get_id (),
                vpn_type = s_vpn.get_service_type (),
                state = "deactivated"
            };

            foreach (var ac in client.get_active_connections ()) {
                var c = ac.get_connection ();
                if (c != null && c.get_uuid () == conn.get_uuid ()) {
                    var s = ac.get_state ();
                    if (s == NM.ActiveConnectionState.ACTIVATED) {
                        vpn.state = "activated";
                    } else if (s == NM.ActiveConnectionState.ACTIVATING) {
                        vpn.state = "activating";
                    } else if (s == NM.ActiveConnectionState.DEACTIVATING) {
                        vpn.state = "deactivating";
                    } else {
                        vpn.state = "deactivated";
                    }
                    break;
                }
            }

            vpns.append (vpn);
        }

        return vpns;
    }
}
