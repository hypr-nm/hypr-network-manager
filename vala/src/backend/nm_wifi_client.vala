using GLib;

public class NmWifiClient : GLib.Object {
    private NetworkManagerClient core;

    public NmWifiClient (NetworkManagerClient core) {
        this.core = core;
    }

    public async WifiRefreshData get_refresh_data (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var devices = client.get_devices ();
        var connections = client.get_connections ();

        var networks_map = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        var devices_out = new List<NetworkDevice> ();

        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi == false) continue;

            var wifidev = (NM.DeviceWifi) dev;
            var active_ap = wifidev.get_active_access_point ();

            var d = new NetworkDevice () {
                name = dev.get_iface (),
                device_path = ((NM.Object)dev).get_path (),
                device_type = NM_DEVICE_TYPE_WIFI,
                state = dev.get_state (),
                connection = "",
                connection_uuid = ""
            };

            var ac = dev.get_active_connection ();
            if (ac != null) {
                d.connection = ac.get_id ();
                d.connection_uuid = ac.get_uuid ();
            }
            devices_out.append (d);

            var aps = wifidev.get_access_points ();
            foreach (var ap in aps) {
                var ssid_bytes = ap.get_ssid ();
                string ssid = "";
                if (ssid_bytes != null) {
                    ssid = NM.Utils.ssid_to_utf8 (ssid_bytes.get_data());
                }

                if (ssid == "") {
                    ssid = ap.get_bssid ();
                }

                bool is_secured = (ap.get_flags () != 0) || (ap.get_wpa_flags () != 0) || (ap.get_rsn_flags () != 0);
                string network_key = ssid + ":" + (is_secured ? "secured" : "open");

                bool saved = false;
                string saved_uuid = "";
                bool autoconnect = true;

                foreach (var conn in connections) {
                    var s_wireless = conn.get_setting_wireless ();
                    if (s_wireless == null) continue;

                    if (ap.connection_valid (conn)) {
                        saved = true;
                        saved_uuid = conn.get_uuid ();
                        var s_conn = conn.get_setting_connection ();
                        if (s_conn != null) {
                            autoconnect = s_conn.autoconnect;
                        }
                        break;
                    }
                }

                bool connected = (active_ap != null && active_ap.get_path() == ap.get_path());

                var net = new WifiNetwork () {
                    ssid = ssid,
                    saved_connection_uuid = saved_uuid,
                    signal = ap.get_strength (),
                    connected = connected,
                    is_secured = is_secured,
                    saved = saved,
                    autoconnect = autoconnect,
                    device_path = ((NM.Object)dev).get_path (),
                    ap_path = ((NM.Object)ap).get_path (),
                    bssid = ap.get_bssid (),
                    frequency_mhz = ap.get_frequency (),
                    max_bitrate_kbps = ap.get_max_bitrate (),
                    mode = ap.get_mode (),
                    flags = ap.get_flags (),
                    wpa_flags = ap.get_wpa_flags (),
                    rsn_flags = ap.get_rsn_flags ()
                };

                // Deduplicate by network_key, keeping the best signal but prioritizing saved networks
                if (!networks_map.contains (network_key)) {
                    networks_map.insert (network_key, net);
                } else {
                    var existing = networks_map.get (network_key);
                    if (net.connected) {
                        networks_map.insert (network_key, net);
                    } else if (!existing.connected) {
                        if (net.saved && !existing.saved) {
                            networks_map.insert (network_key, net);
                        } else if (net.saved == existing.saved && net.signal > existing.signal) {
                            networks_map.insert (network_key, net);
                        }
                    }
                }
            }
        }

        var networks_arr = new WifiNetwork[networks_map.size ()];
        int i = 0;
        var iter = HashTableIter<string, WifiNetwork> (networks_map);
        string k;
        WifiNetwork v;
        while (iter.next (out k, out v)) {
            networks_arr[i++] = v;
        }

        var devices_arr = new NetworkDevice[devices_out.length ()];
        i = 0;
        foreach (var d in devices_out) {
            devices_arr[i++] = d;
        }

        return new WifiRefreshData (networks_arr, devices_arr);
    }

    public async NetworkIpSettings get_network_ip_settings (
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings ();
        var client = core.nm_client;
        
        NM.Connection? matching_conn = null;
        if (network.saved_connection_uuid != "") {
            matching_conn = client.get_connection_by_uuid (network.saved_connection_uuid);
        }

        if (matching_conn != null) {
            var s_ip4 = matching_conn.get_setting_ip4_config ();
            if (s_ip4 != null) {
                ip_settings.ipv4_method = s_ip4.get_method ();
                ip_settings.gateway_auto = true;
                // Simplified, more config mapping needed if we had manual parsing
            }
        }
        
        return ip_settings;
    }

        public async bool update_network_settings (
        WifiNetwork network,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (network.saved_connection_uuid);
        if (conn == null) {
            log_warn ("nm-wifi-client", "Connection not found for UUID: " + network.saved_connection_uuid);
             throw new IOError.NOT_FOUND ("Connection not found");
        }
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
        
        if (request.password != null) {
            var s_sec = conn.get_setting_wireless_security ();
            if (s_sec != null) {
                s_sec.psk = request.password;
            }
        }
        
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
        
        if (!req.dns_auto) {
            foreach (var dns in req.dns_servers) {
                if (dns != "") s_ip6.add_dns (dns);
            }
        }
    }


    public async bool set_network_autoconnect (
        WifiNetwork network,
        bool enabled,
        int32 priority = 10,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (network.saved_connection_uuid);
        if (conn == null) {
            log_warn ("nm-wifi-client", "Connection not found for UUID: " + network.saved_connection_uuid);
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            s_conn.autoconnect = enabled;
            s_conn.autoconnect_priority = priority;
            
            if (conn is NM.RemoteConnection) {
                yield ((NM.RemoteConnection)conn).commit_changes_async (true, cancellable);
            }
        }
        return true;
    }

    public async bool connect_saved (WifiNetwork network, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (network.saved_connection_uuid);
        if (conn == null) {
            log_warn ("nm-wifi-client", "Connection not found for UUID: " + network.saved_connection_uuid);
            throw new IOError.NOT_FOUND ("Connection not found");
        }
        
        var dev = client.get_device_by_path (network.device_path);
        if (dev == null) {
            log_warn ("nm-wifi-client", "Device not found for path: " + network.device_path);
            throw new IOError.NOT_FOUND ("Device not found");
        }
        
        yield client.activate_connection_async (conn, dev, network.ap_path, cancellable);
        return true;
    }

    
    private NM.Connection create_wifi_connection (
        string ssid,
        string? password,
        bool is_hidden = false,
        HiddenWifiSecurityMode security_mode = HiddenWifiSecurityMode.OPEN,
        uint32 rsn_flags = 0,
        uint32 wpa_flags = 0
    ) {
        var conn = (NM.SimpleConnection) NM.SimpleConnection.@new ();
        
        var s_con = new NM.SettingConnection ();
        s_con.id = ssid;
        s_con.type = "802-11-wireless";
        s_con.uuid = NM.Utils.uuid_generate ();
        s_con.autoconnect = true;
        conn.add_setting (s_con);
        
        var s_wifi = new NM.SettingWireless ();
        uint8[] ssid_arr = ssid.data;
        s_wifi.ssid = new Bytes (ssid_arr);
        if (is_hidden) {
            s_wifi.hidden = true;
        }
        conn.add_setting (s_wifi);

        if (password != null && password != "") {
            var s_sec = new NM.SettingWirelessSecurity ();
            
            if (is_hidden) {
                if (security_mode == HiddenWifiSecurityMode.WPA_PSK) {
                    s_sec.key_mgmt = "wpa-psk";
                    s_sec.psk = password;
                } else if (security_mode == HiddenWifiSecurityMode.WEP) {
                    s_sec.key_mgmt = "none";
                    s_sec.wep_key0 = password;
                    s_sec.wep_key_type = NM.WepKeyType.PASSPHRASE;
                } else if (security_mode == HiddenWifiSecurityMode.SAE) {
                    s_sec.key_mgmt = "sae";
                    s_sec.psk = password;
                } else if (security_mode == HiddenWifiSecurityMode.WPA_PSK_SAE) {
                    s_sec.key_mgmt = "sae";
                    s_sec.psk = password;
                }
            } else {
                if ((rsn_flags & NM.80211ApSecurityFlags.KEY_MGMT_SAE) != 0) {
                    s_sec.key_mgmt = "sae";
                    s_sec.psk = password;
                } else if ((rsn_flags & NM.80211ApSecurityFlags.KEY_MGMT_OWE) != 0) {
                    s_sec.key_mgmt = "owe";
                    s_sec.psk = password;
                } else if ((rsn_flags & NM.80211ApSecurityFlags.KEY_MGMT_PSK) != 0 ||
                           (wpa_flags & NM.80211ApSecurityFlags.KEY_MGMT_PSK) != 0) {
                    s_sec.key_mgmt = "wpa-psk";
                    s_sec.psk = password;
                } else {
                    // Fallback
                    s_sec.key_mgmt = "wpa-psk";
                    s_sec.psk = password;
                }
            }
            conn.add_setting (s_sec);
        }
        
        // Add default IP configs
        var s_ip4 = new NM.SettingIP4Config ();
        s_ip4.method = "auto";
        conn.add_setting (s_ip4);
        
        var s_ip6 = new NM.SettingIP6Config ();
        s_ip6.method = "auto";
        conn.add_setting (s_ip6);
        
        return conn;
    }

    public new async bool connect (
        WifiNetwork network,
        string? password,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var dev = client.get_device_by_path (network.device_path);
        if (dev == null) {
            log_warn ("nm-wifi-client", "Device not found for path: " + network.device_path);
            throw new IOError.NOT_FOUND ("Device not found");
        }

        if (network.saved && network.saved_connection_uuid != "") {
            var existing_conn = client.get_connection_by_uuid (network.saved_connection_uuid);
            if (existing_conn != null) {
                if (password != null && password != "") {
                    var s_sec = existing_conn.get_setting_wireless_security ();
                    if (s_sec == null) {
                        s_sec = new NM.SettingWirelessSecurity ();
                        existing_conn.add_setting (s_sec);
                    }
                    s_sec.psk = password;
                    if (existing_conn is NM.RemoteConnection) {
                        yield ((NM.RemoteConnection)existing_conn).commit_changes_async (true, cancellable);
                    }
                }
                yield client.activate_connection_async (existing_conn, dev, network.ap_path, cancellable);
                return true;
            }
        }

        var conn = create_wifi_connection (network.ssid, password, false, HiddenWifiSecurityMode.OPEN, network.rsn_flags, network.wpa_flags);
        yield client.add_and_activate_connection_async (conn, dev, network.ap_path, cancellable);
        return true;
    }

    public async bool connect_with_password (
        WifiNetwork network,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        return yield connect (network, password, cancellable);
    }

    public async bool connect_hidden_network (
        string ssid,
        HiddenWifiSecurityMode security_mode,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        NM.Device? wifi_dev = null;
        foreach (var d in client.get_devices ()) {
            if (d is NM.DeviceWifi) {
                wifi_dev = d;
                break;
            }
        }
        if (wifi_dev == null) throw new IOError.NOT_FOUND ("No Wi-Fi device found");

        var conn = create_wifi_connection (ssid, password, true, security_mode);
        yield client.add_and_activate_connection_async (conn, wifi_dev, null, cancellable);
        return true;
    }

    public new async bool disconnect (WifiNetwork network, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var dev = client.get_device_by_path (network.device_path);
        if (dev == null) {
            log_warn ("nm-wifi-client", "Device not found for path: " + network.device_path);
            throw new IOError.NOT_FOUND ("Device not found");
        }

        yield dev.disconnect_async (cancellable);
        return true;
    }

    public async bool forget_network (
        string profile_uuid,
        string network_key,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (profile_uuid);
        if (conn == null) {
            log_warn ("nm-wifi-client", "Connection not found for UUID: " + profile_uuid);
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        yield conn.delete_async (cancellable);
        return true;
    }

    public async bool scan (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var devices = client.get_devices ();
        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi) {
                try {
                    yield ((NM.DeviceWifi)dev).request_scan_async (cancellable);
                } catch (Error e) {}
            }
        }
        return true;
    }
}
