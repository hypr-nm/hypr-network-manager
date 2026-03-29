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
        foreach (var conn in client.get_connections ()) {
            var s_eth = conn.get_setting_wired ();
            if (s_eth != null && conn.get_id () == device.connection) {
                return conn;
            }
        }
        return null;
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
            var s_ip4 = conn.get_setting_ip4_config ();
            if (s_ip4 != null) {
                ip_settings.ipv4_method = s_ip4.get_method ();
                ip_settings.gateway_auto = !s_ip4.ignore_auto_routes;
                if (s_ip4.get_num_addresses () > 0) {
                    unowned NM.IPAddress addr = s_ip4.get_address (0);
                    ip_settings.configured_address = addr.get_address ();
                    ip_settings.configured_prefix = addr.get_prefix ();
                }
                ip_settings.configured_gateway = s_ip4.get_gateway ();
                ip_settings.dns_auto = !s_ip4.ignore_auto_dns;
                if (s_ip4.get_num_dns () > 0) {
                    string[] dns_list = {};
                    for (int i = 0; i < s_ip4.get_num_dns (); i++) {
                        dns_list += s_ip4.get_dns (i);
                    }
                    ip_settings.configured_dns = string.joinv (", ", dns_list);
                }
            }
            var s_ip6 = conn.get_setting_ip6_config ();
            if (s_ip6 != null) {
                ip_settings.ipv6_method = s_ip6.get_method ();
                ip_settings.ipv6_gateway_auto = !s_ip6.ignore_auto_routes;
                if (s_ip6.get_num_addresses () > 0) {
                    unowned NM.IPAddress addr = s_ip6.get_address (0);
                    ip_settings.configured_ipv6_address = addr.get_address ();
                    ip_settings.configured_ipv6_prefix = addr.get_prefix ();
                }
                ip_settings.configured_ipv6_gateway = s_ip6.get_gateway ();
                ip_settings.ipv6_dns_auto = !s_ip6.ignore_auto_dns;
                if (s_ip6.get_num_dns () > 0) {
                    string[] dns_list = {};
                    for (int i = 0; i < s_ip6.get_num_dns (); i++) {
                        dns_list += s_ip6.get_dns (i);
                    }
                    ip_settings.configured_ipv6_dns = string.joinv (", ", dns_list);
                }
            }
        }

        var client = core.nm_client;
        var dev = client.get_device_by_path (device.device_path);
        if (dev != null && dev.get_state () == NM_DEVICE_STATE_ACTIVATED) {
            var ac = dev.get_active_connection ();
            if (ac != null) {
                var ip4 = ac.get_ip4_config ();
                if (ip4 != null) {
                    if (ip4.get_addresses ().length > 0) {
                        unowned NM.IPAddress addr = ip4.get_addresses ().get (0);
                        ip_settings.current_address = addr.get_address ();
                        ip_settings.current_prefix = addr.get_prefix ();
                    }
                    ip_settings.current_gateway = ip4.get_gateway ();
                    if (ip4.get_nameservers ().length > 0) {
                        ip_settings.current_dns = ip4.get_nameservers ()[0];
                    }
                }
                var ip6 = ac.get_ip6_config ();
                if (ip6 != null) {
                    if (ip6.get_addresses ().length > 0) {
                        unowned NM.IPAddress addr = ip6.get_addresses ().get (0);
                        ip_settings.current_ipv6_address = addr.get_address ();
                        ip_settings.current_ipv6_prefix = addr.get_prefix ();
                    }
                    ip_settings.current_ipv6_gateway = ip6.get_gateway ();
                    if (ip6.get_nameservers ().length > 0) {
                        ip_settings.current_ipv6_dns = ip6.get_nameservers ()[0];
                    }
                }
            }
        }
        return ip_settings;
    }

        public async bool update_device_settings (
            NetworkDevice device,
            NetworkIpUpdateRequest request,
            Cancellable? cancellable = null
        ) throws Error {
            var conn = resolve_connection (device);
            if (conn == null) throw new IOError.NOT_FOUND ("No saved Ethernet profile found.");
            
            var s_ip4 = conn.get_setting_ip4_config ();
            if (s_ip4 == null) {
                s_ip4 = new NM.SettingIP4Config ();
                conn.add_setting (s_ip4);
            }
            apply_ipv4_settings (s_ip4, request.get_ipv4_section ());
            
            var s_ip6 = conn.get_setting_ip6_config ();
            if (s_ip6 == null) {
                s_ip6 = new NM.SettingIP6Config ();
                conn.add_setting (s_ip6);
            }
            apply_ipv6_settings (s_ip6, request.get_ipv6_section ());
            
            if (conn is NM.RemoteConnection) {
                yield ((NM.RemoteConnection)conn).commit_changes_async (true, cancellable);
            }
            return true;
        }


    private void apply_ipv4_settings (NM.SettingIP4Config s_ip4, Ipv4UpdateSection req) {
        s_ip4.clear_addresses ();
        s_ip4.clear_dns ();
        
        string method = req.normalized_method ();
        if (method == "auto" || method == "") {
            s_ip4.method = NM.SettingIP4Config.METHOD_AUTO;
        } else if (method == "manual") {
            s_ip4.method = NM.SettingIP4Config.METHOD_MANUAL;
            if (req.address != "") {
                try { var addr = new NM.IPAddress (2, req.address, req.prefix); s_ip4.add_address (addr); } catch (Error e) {}
            }
        } else if (method == "link-local") {
            s_ip4.method = NM.SettingIP4Config.METHOD_LINK_LOCAL;
        } else if (method == "shared") {
            s_ip4.method = NM.SettingIP4Config.METHOD_SHARED;
        } else if (method == "disabled") {
            s_ip4.method = NM.SettingIP4Config.METHOD_DISABLED;
        }

        if (!req.gateway_auto && req.gateway != "") {
            s_ip4.gateway = req.gateway;
        } else if (req.gateway_auto) {
            s_ip4.gateway = null;
        }
        s_ip4.ignore_auto_routes = !req.gateway_auto;
        
        s_ip4.ignore_auto_dns = !req.dns_auto;
        if (!req.dns_auto) {
            foreach (var dns in req.dns_servers) {
                if (dns != "") s_ip4.add_dns (dns);
            }
        }
    }

    private void apply_ipv6_settings (NM.SettingIP6Config s_ip6, Ipv6UpdateSection req) {
        s_ip6.clear_addresses ();
        s_ip6.clear_dns ();
        
        string method = req.normalized_method ();
        if (method == "auto" || method == "") {
            s_ip6.method = NM.SettingIP6Config.METHOD_AUTO;
        } else if (method == "manual") {
            s_ip6.method = NM.SettingIP6Config.METHOD_MANUAL;
            if (req.address != "") {
                try { var addr = new NM.IPAddress (10, req.address, req.prefix); s_ip6.add_address (addr); } catch (Error e) {}
            }
        } else if (method == "link-local") {
            s_ip6.method = NM.SettingIP6Config.METHOD_LINK_LOCAL;
        } else if (method == "shared") {
            s_ip6.method = NM.SettingIP6Config.METHOD_SHARED;
        } else if (method == "disabled") {
            s_ip6.method = NM.SettingIP6Config.METHOD_DISABLED;
        } else if (method == "ignore") {
            s_ip6.method = NM.SettingIP6Config.METHOD_IGNORE;
        }

        if (!req.gateway_auto && req.gateway != "") {
            s_ip6.gateway = req.gateway;
        } else if (req.gateway_auto) {
            s_ip6.gateway = null;
        }
        s_ip6.ignore_auto_routes = !req.gateway_auto;
        
        s_ip6.ignore_auto_dns = !req.dns_auto;
        if (!req.dns_auto) {
            foreach (var dns in req.dns_servers) {
                if (dns != "") s_ip6.add_dns (dns);
            }
        }
    }

}
