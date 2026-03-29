using GLib;

public class NmEthernetClient : Object {
    private NetworkManagerClient core;

    public NmEthernetClient (NetworkManagerClient core) {
        this.core = core;
    }

    private async string resolve_connection_path (
        NetworkDevice device,
        string ambiguous_message,
        string not_found_message,
        Cancellable? cancellable = null
    ) throws Error {
        string? uuid_match = null;
        string? name_match = null;
        bool name_ambiguous = false;

        var settings = yield core.make_proxy (NM_SETTINGS_PATH, NM_SETTINGS_IFACE, cancellable);
        var list_res = yield core.call_dbus (settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value (0);

        for (int i = 0; i < conns.n_children (); i++) {
            string candidate_path = conns.get_child_value (i).get_string ();
            var conn = yield core.make_proxy (candidate_path, NM_CONN_IFACE, cancellable);
            var settings_res = yield core.call_dbus (conn, "GetSettings", null, cancellable);
            var all_settings = settings_res.get_child_value (0);

            Variant? conn_group = all_settings.lookup_value ("connection", new VariantType ("a{sv}"));
            if (conn_group == null) {
                continue;
            }

            Variant? type_v = conn_group.lookup_value ("type", new VariantType ("s"));
            if (type_v == null || type_v.get_string () != "802-3-ethernet") {
                continue;
            }

            if (device.connection_uuid.strip () != "") {
                Variant? uuid_v = conn_group.lookup_value ("uuid", new VariantType ("s"));
                if (uuid_v != null && uuid_v.get_string () == device.connection_uuid) {
                    uuid_match = candidate_path;
                    break;
                }
            }

            Variant? id_v = conn_group.lookup_value ("id", new VariantType ("s"));
            if (id_v != null && id_v.get_string () == device.connection) {
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
            throw new IOError.FAILED (ambiguous_message);
        }

        if (name_match == null) {
            throw new IOError.NOT_FOUND (not_found_message);
        }

        return name_match;
    }

    public async bool connect_device (
        NetworkDevice device,
        Cancellable? cancellable = null
    ) throws Error {
        if (device.connection.strip () == "") {
            throw new IOError.FAILED ("No saved Ethernet profile available for this interface.");
        }

        string conn_path = yield resolve_connection_path (
            device,
            "Multiple Ethernet profiles share this name. Use UUID to activate a specific profile.",
            "No saved Ethernet profile found.",
            cancellable
        );

        var nm = yield core.make_proxy (NM_PATH, NM_IFACE, cancellable);
        yield core.call_dbus (
            nm,
            "ActivateConnection",
            new Variant ("(ooo)", conn_path, "/", "/"),
            cancellable
        );
        return true;
    }

    public async bool disconnect_device (
        string interface_name,
        Cancellable? cancellable = null
    ) throws Error {
        var nm = yield core.make_proxy (NM_PATH, NM_IFACE, cancellable);
        var devices_res = yield core.call_dbus (nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value (0);

        for (int i = 0; i < devices.n_children (); i++) {
            string dev_path = devices.get_child_value (i).get_string ();
            string iface = (yield core.get_prop_dbus (
                dev_path,
                NM_DEVICE_IFACE,
                "Interface",
                cancellable
            )).get_string ();
            if (iface != interface_name) {
                continue;
            }

            var dev = yield core.make_proxy (dev_path, NM_DEVICE_IFACE, cancellable);
            yield core.call_dbus (dev, "Disconnect", null, cancellable);
            return true;
        }

        throw new IOError.NOT_FOUND ("Device not found.");
    }

    public async NetworkIpSettings get_device_ip_settings (
        NetworkDevice device,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings ();

        if (device.connection.strip () != "") {
            try {
                string conn_path = yield resolve_connection_path (
                    device,
                    "Multiple Ethernet profiles share this name. Select by UUID.",
                    "No saved Ethernet profile found.",
                    cancellable
                );
                var conn = yield core.make_proxy (conn_path, NM_CONN_IFACE, cancellable);
                var settings_res = yield core.call_dbus (conn, "GetSettings", null, cancellable);
                var all_settings = settings_res.get_child_value (0);
                NetworkManagerClient.fill_configured_ipv4_from_settings (all_settings, ip_settings);
                NetworkManagerClient.fill_configured_ipv6_from_settings (all_settings, ip_settings);
            } catch (Error e) {
                core.debug_log ("ethernet_profile_read: saved settings lookup failed error=" + e.message);
            }
        }

        yield core.fill_runtime_ipv4_for_device_dbus (
            device.device_path,
            device.is_connected,
            ip_settings,
            cancellable
        );
        yield core.fill_runtime_ipv6_for_device_dbus (
            device.device_path,
            device.is_connected,
            ip_settings,
            cancellable
        );
        return ip_settings;
    }

    public async bool update_device_settings (
        NetworkDevice device,
        NetworkIpUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        if (device.connection.strip () == "") {
            throw new IOError.FAILED ("No Ethernet profile is available for this interface.");
        }

        string conn_path = yield resolve_connection_path (
            device,
            "Multiple Ethernet profiles share this name. Refusing ambiguous update.",
            "No saved Ethernet profile found.",
            cancellable
        );

        var ipv4 = request.get_ipv4_section ();
        var ipv6 = request.get_ipv6_section ();

        string ipv4_method = ipv4.normalized_method ();
        string ipv6_method = ipv6.normalized_method ();

        if (!ipv4.gateway_auto && ipv4.gateway == "") {
            throw new IOError.FAILED ("Manual gateway requires a gateway address.");
        }
        if (!ipv4.gateway_auto && ipv4_method == "disabled") {
            throw new IOError.FAILED ("Manual gateway is not supported when IPv4 method is Disabled.");
        }
        if (!ipv4.dns_auto && ipv4.dns_servers.length == 0) {
            throw new IOError.FAILED ("Manual DNS requires at least one DNS server.");
        }
        if (ipv4_method == "manual") {
            if (ipv4.address == "") {
                throw new IOError.FAILED ("Manual IPv4 requires an address.");
            }
            if (ipv4.prefix == 0 || ipv4.prefix > 32) {
                throw new IOError.FAILED ("Manual IPv4 prefix must be between 1 and 32.");
            }
        }

        if (!ipv6.gateway_auto && ipv6.gateway == "") {
            throw new IOError.FAILED ("Manual IPv6 gateway requires a gateway address.");
        }
        if ((ipv6_method == "disabled" || ipv6_method == "ignore") && !ipv6.gateway_auto) {
            throw new IOError.FAILED (
                "Manual IPv6 gateway is not supported when IPv6 method is Disabled or Ignore."
            );
        }
        if (!ipv6.dns_auto && ipv6.dns_servers.length == 0) {
            throw new IOError.FAILED ("Manual IPv6 DNS requires at least one DNS server.");
        }
        if (ipv6_method == "manual") {
            if (ipv6.address == "") {
                throw new IOError.FAILED ("Manual IPv6 requires an address.");
            }
            if (ipv6.prefix == 0 || ipv6.prefix > 128) {
                throw new IOError.FAILED ("Manual IPv6 prefix must be between 1 and 128.");
            }
        }

        var conn = yield core.make_proxy (conn_path, NM_CONN_IFACE, cancellable);
        var settings_res = yield core.call_dbus (conn, "GetSettings", null, cancellable);
        var all_settings = settings_res.get_child_value (0);

        Variant updated_ipv4;
        Variant updated_ipv6;
        string builder_error = "";
        if (!NmWifiSettingsBuilder.build_updated_ipv4_section (all_settings, ipv4,
             out updated_ipv4, out builder_error)) {
            throw new IOError.FAILED (builder_error);
        }

        if (!NmWifiSettingsBuilder.build_updated_ipv6_section (all_settings, ipv6, out updated_ipv6,
             out builder_error)) {
            throw new IOError.FAILED (builder_error);
        }

        Variant updated_settings = NmWifiSettingsBuilder.build_updated_connection_settings (
            all_settings,
            updated_ipv4,
            updated_ipv6,
            false,
            ""
        );

        yield core.call_dbus (
            conn,
            "Update",
            new Variant ("(@a{sa{sv}})", updated_settings),
            cancellable
        );
        return true;
    }
}
