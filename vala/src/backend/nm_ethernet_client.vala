using GLib;

public class NmEthernetClient : GLib.Object {
    private NetworkManagerClient core;

    public NmEthernetClient (NetworkManagerClient core) {
        this.core = core;
    }

    private NM.Connection? resolve_connection (NetworkDevice device) {
        var client = core.nm_client;
        if (device.connection_uuid != "") {
            var c = client.get_connection_by_uuid (device.connection_uuid);
            if (c != null) return c;
        }

        NM.Connection? generic_candidate = null;
        foreach (var conn in client.get_connections ()) {
            var s_eth = conn.get_setting_wired ();
            if (s_eth == null) {
                continue;
            }

            if (device.connection != "" && conn.get_id () == device.connection) {
                return conn;
            }

            var s_conn = conn.get_setting_connection ();
            if (s_conn == null) {
                continue;
            }

            string bound_iface = s_conn.interface_name != null ? s_conn.interface_name.strip () : "";
            if (bound_iface != "" && bound_iface == device.name) {
                return conn;
            }

            if (bound_iface == "" && generic_candidate == null) {
                generic_candidate = conn;
            }
        }

        if (generic_candidate != null) {
            return generic_candidate;
        }

        return null;
    }

    public bool has_profile (NetworkDevice device) {
        return resolve_connection (device) != null;
    }

    public async bool connect_device (
        NetworkDevice device,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = resolve_connection (device);
        if (conn == null) throw new IOError.NOT_FOUND ("No saved Ethernet profile found.");

        var dev = client.get_device_by_path (device.device_path);
        if (dev == null) {
            log_warn ("nm-ethernet-client", "Device not found for connection: " + device.device_path);
            throw new IOError.NOT_FOUND ("Device not found.");
        }

        yield client.activate_connection_async (conn, dev, null, cancellable);
        return true;
    }

    public async bool disconnect_device (
        string interface_name,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var dev = client.get_device_by_iface (interface_name);
        if (dev == null) {
            log_warn ("nm-ethernet-client", "Device not found for interface: " + interface_name);
            throw new IOError.NOT_FOUND ("Device not found.");
        }

        yield dev.disconnect_async (cancellable);
        return true;
    }

    public async NetworkIpSettings get_device_ip_settings (
        NetworkDevice device,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings ();
        var conn = resolve_connection (device);

        if (conn != null) {
            NmIpConfigHelper.populate_configured_ip_settings (ip_settings, conn);
        }

        var client = core.nm_client;
        var dev = client.get_device_by_path (device.device_path);
        NmIpConfigHelper.populate_runtime_ip_settings (ip_settings, dev);
        return ip_settings;
    }

    public async NetworkIpSettings get_device_configured_ip_settings (
        NetworkDevice device,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings ();
        var conn = resolve_connection (device);

        if (conn != null) {
            NmIpConfigHelper.populate_configured_ip_settings (ip_settings, conn);
        }
        return ip_settings;
    }

    public async bool update_device_settings (
        NetworkDevice device,
        NetworkIpUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var conn = resolve_connection (device);
        if (conn == null) {
            throw new IOError.NOT_FOUND ("No saved Ethernet profile found.");
        }

        var s_ip4 = NmIpConfigHelper.ensure_ip4_setting (conn);
        NmIpConfigHelper.apply_ipv4_settings (s_ip4, request.get_ipv4_section ());

        var s_ip6 = NmIpConfigHelper.ensure_ip6_setting (conn);
        NmIpConfigHelper.apply_ipv6_settings (s_ip6, request.get_ipv6_section ());

        if (conn is NM.RemoteConnection) {
            yield ((NM.RemoteConnection)conn).commit_changes_async (true, cancellable);
        }
        return true;
    }

}
