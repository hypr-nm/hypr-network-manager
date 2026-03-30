using GLib;

public class NmIpConfigHelper : GLib.Object {
    public static NM.SettingIPConfig ensure_ip4_setting (NM.Connection conn) {
        NM.SettingIPConfig? s_ip4 = (NM.SettingIPConfig?) conn.get_setting (typeof (NM.SettingIP4Config));
        if (s_ip4 == null) {
            s_ip4 = new NM.SettingIP4Config ();
            conn.add_setting (s_ip4);
        }
        return s_ip4;
    }

    public static NM.SettingIPConfig ensure_ip6_setting (NM.Connection conn) {
        NM.SettingIPConfig? s_ip6 = (NM.SettingIPConfig?) conn.get_setting (typeof (NM.SettingIP6Config));
        if (s_ip6 == null) {
            s_ip6 = new NM.SettingIP6Config ();
            conn.add_setting (s_ip6);
        }
        return s_ip6;
    }

    public static void populate_configured_ip_settings (NetworkIpSettings ip_settings, NM.Connection conn) {
        NM.SettingIPConfig? s_ip4 = (NM.SettingIPConfig?) conn.get_setting (typeof (NM.SettingIP4Config));
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

        NM.SettingIPConfig? s_ip6 = (NM.SettingIPConfig?) conn.get_setting (typeof (NM.SettingIP6Config));
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

    public static void populate_runtime_ip_settings (NetworkIpSettings ip_settings, NM.Device? dev) {
        if (dev == null || dev.get_state () != NM.DeviceState.ACTIVATED) {
            return;
        }

        var ac = dev.get_active_connection ();
        if (ac == null) {
            return;
        }

        var ip4 = ac.get_ip4_config ();
        if (ip4 != null) {
            if (ip4.get_addresses ().length > 0) {
                unowned NM.IPAddress addr = ip4.get_addresses ().get (0);
                ip_settings.current_address = addr.get_address ();
                ip_settings.current_prefix = addr.get_prefix ();
            }
            ip_settings.current_gateway = ip4.get_gateway ();
            foreach (unowned string nameserver in ip4.get_nameservers ()) {
                ip_settings.current_dns = nameserver;
                break;
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
            foreach (unowned string nameserver in ip6.get_nameservers ()) {
                ip_settings.current_ipv6_dns = nameserver;
                break;
            }
        }
    }

    public static void apply_ipv4_settings (NM.SettingIPConfig s_ip4, Ipv4UpdateSection req) {
        s_ip4.clear_addresses ();
        s_ip4.clear_dns ();

        string method = req.normalized_method ();
        if (method == "auto" || method == "") {
            s_ip4.method = NM.SettingIP4Config.METHOD_AUTO;
        } else if (method == "manual") {
            s_ip4.method = NM.SettingIP4Config.METHOD_MANUAL;
            if (req.address != "") {
                try {
                    var addr = new NM.IPAddress (2, req.address, req.prefix);
                    s_ip4.add_address (addr);
                } catch (Error e) {
                }
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
                if (dns != "") {
                    s_ip4.add_dns (dns);
                }
            }
        }
    }

    public static void apply_ipv6_settings (NM.SettingIPConfig s_ip6, Ipv6UpdateSection req) {
        s_ip6.clear_addresses ();
        s_ip6.clear_dns ();

        string method = req.normalized_method ();
        if (method == "auto" || method == "") {
            s_ip6.method = NM.SettingIP6Config.METHOD_AUTO;
        } else if (method == "manual") {
            s_ip6.method = NM.SettingIP6Config.METHOD_MANUAL;
            if (req.address != "") {
                try {
                    var addr = new NM.IPAddress (10, req.address, req.prefix);
                    s_ip6.add_address (addr);
                } catch (Error e) {
                }
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
                if (dns != "") {
                    s_ip6.add_dns (dns);
                }
            }
        }
    }
}
