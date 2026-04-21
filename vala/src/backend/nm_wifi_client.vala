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
        var seen_saved_uuids = new HashTable<string, bool> (str_hash, str_equal);
        var devices_out = new List<NetworkDevice> ();
        string primary_wifi_device_path = "";

        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi == false) continue;

            var wifidev = (NM.DeviceWifi) dev;
            var active_ap = wifidev.get_active_access_point ();
            if (primary_wifi_device_path == "") {
                primary_wifi_device_path = ((NM.Object)dev).get_path ();
            }

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
            uint hidden_total = 0;
            foreach (var ap in aps) {
                var ssid_bytes = ap.get_ssid ();
                if (ssid_bytes == null || NM.Utils.is_empty_ssid (ssid_bytes.get_data ())) {
                    hidden_total++;
                }
            }

            uint hidden_index = 0;
            foreach (var ap in aps) {
                var ssid_bytes = ap.get_ssid ();
                string ssid = NmWifiUtils.bytes_to_ssid (ssid_bytes);

                bool is_hidden = ssid_bytes == null || NM.Utils.is_empty_ssid (ssid_bytes.get_data ());

                if (is_hidden) {
                    hidden_index++;
                    if (hidden_total > 1) {
                        ssid = "Hidden network %u".printf (hidden_index);
                    } else {
                        ssid = "Hidden network";
                    }
                }

                bool is_secured = (ap.get_flags () != 0) || (ap.get_wpa_flags () != 0) || (ap.get_rsn_flags () != 0);
                string network_key = ssid + ":" + (is_secured ? "secured" : "open");

                bool saved = false;
                string saved_uuid = "";
                bool autoconnect = true;

                var valid_conns = ap.filter_connections (connections);
                if (valid_conns != null && valid_conns.length > 0) {
                    var conn = (NM.Connection) valid_conns[0];
                    saved = true;
                    saved_uuid = conn.get_uuid ();
                    if (saved_uuid != "") {
                        seen_saved_uuids.insert (saved_uuid, true);
                    }
                    var s_conn = conn.get_setting_connection ();
                    if (s_conn != null) {
                        autoconnect = s_conn.autoconnect;
                    }
                }

                bool connected = (active_ap != null && active_ap.get_path () == ap.get_path ());

                var net = new WifiNetwork () {
                    ssid = ssid,
                    saved_connection_uuid = saved_uuid,
                    signal = ap.get_strength (),
                    connected = connected,
                    is_secured = is_secured,
                    is_hidden = is_hidden,
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

        string primary_active_uuid = "";
        if (primary_wifi_device_path != "") {
            var primary_wifi_device = client.get_device_by_path (primary_wifi_device_path);
            if (primary_wifi_device != null) {
                var ac = primary_wifi_device.get_active_connection ();
                if (ac != null) {
                    primary_active_uuid = ac.get_uuid ();
                }
            }
        }

        // Include saved Wi-Fi profiles even when the AP is not currently visible.
        foreach (var conn in connections) {
            string uuid = conn.get_uuid ();
            if (uuid == "" || seen_saved_uuids.contains (uuid)) {
                continue;
            }

            var net = NmWifiUtils.build_saved_network (conn, primary_wifi_device_path, primary_active_uuid);
            if (net == null) {
                continue;
            }

            string network_key = net.ssid + ":" + (net.is_secured ? "secured" : "open");

            if (!networks_map.contains (network_key)) {
                networks_map.insert (network_key, net);
            }
        }

        // collapse entries that point to the same BSSID so hidden placeholders
        // do not appear alongside the actual connected network for the same AP.
        var deduped_map = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        var iter = HashTableIter<string, WifiNetwork> (networks_map);
        string k;
        WifiNetwork v;
        while (iter.next (out k, out v)) {
            string bssid = v.bssid != null ? v.bssid : "";
            string dedupe_key = bssid.strip ().down ();
            if (dedupe_key == "") {
                dedupe_key = "key:" + k;
            }

            if (!deduped_map.contains (dedupe_key)) {
                deduped_map.insert (dedupe_key, v);
                continue;
            }

            var existing = deduped_map.get (dedupe_key);
            bool replace = false;

            if (v.connected && !existing.connected) {
                replace = true;
            } else if (v.connected == existing.connected) {
                if (!v.is_hidden && existing.is_hidden) {
                    replace = true;
                } else if (v.is_hidden == existing.is_hidden) {
                    if (v.saved && !existing.saved) {
                        replace = true;
                    } else if (v.saved == existing.saved && v.signal > existing.signal) {
                        replace = true;
                    }
                }
            }

            if (replace) {
                deduped_map.insert (dedupe_key, v);
            }
        }

        var networks_list = new List<WifiNetwork> ();
        var deduped_iter = HashTableIter<string, WifiNetwork> (deduped_map);
        string dk;
        WifiNetwork dv;
        while (deduped_iter.next (out dk, out dv)) {
            networks_list.append (dv);
        }

        networks_list.sort ((a, b) => {
            if (a.connected != b.connected) {
                return a.connected ? -1 : 1;
            }
            if (a.saved != b.saved) {
                return a.saved ? -1 : 1;
            }
            return (int) b.signal - (int) a.signal;
        });

        var networks_arr = new WifiNetwork[networks_list.length ()];
        int i = 0;
        foreach (var net in networks_list) {
            networks_arr[i++] = net;
        }

        var devices_arr = new NetworkDevice[devices_out.length ()];
        i = 0;
        foreach (var d in devices_out) {
            devices_arr[i++] = d;
        }

        return new WifiRefreshData (networks_arr, devices_arr);
    }

    public async WifiSavedProfile[] get_saved_profiles (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var connections = client.get_connections ();
        var devices = client.get_devices ();

        string wifi_device_path = "";
        string active_uuid = "";
        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi == false) {
                continue;
            }

            wifi_device_path = ((NM.Object)dev).get_path ();
            var ac = dev.get_active_connection ();
            if (ac != null) {
                active_uuid = ac.get_uuid ();
            }
            break;
        }

        var out_list = new List<WifiSavedProfile> ();
        foreach (var conn in connections) {
            var profile = NmWifiUtils.build_saved_profile (conn, wifi_device_path, active_uuid);
            if (profile != null) {
                out_list.append (profile);
            }
        }

        var profiles_arr = new WifiSavedProfile[out_list.length ()];
        int i = 0;
        foreach (var profile in out_list) {
            profiles_arr[i++] = profile;
        }

        return profiles_arr;
    }

    public async WifiSavedProfileSettings get_saved_profile_settings (
        WifiSavedProfile profile,
        Cancellable? cancellable = null
    ) throws Error {
        var settings = new WifiSavedProfileSettings ();
        var client = core.nm_client;

        var conn = client.get_connection_by_uuid (profile.saved_connection_uuid);
        if (conn == null) {
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            settings.profile_name = s_conn.id != null ? s_conn.id : "";
            settings.autoconnect = s_conn.autoconnect;
            settings.available_to_all_users = s_conn.get_num_permissions () == 0;
        }

        var s_wireless = conn.get_setting_wireless ();
        if (s_wireless != null) {
            settings.ssid = NmWifiUtils.bytes_to_ssid (s_wireless.ssid).strip ();
            settings.bssid = s_wireless.bssid != null ? s_wireless.bssid : "";
        }

        settings.security_mode = NmWifiUtils.infer_security_mode (conn.get_setting_wireless_security ());

        var ip_settings = yield get_ip_settings_by_connection_uuid_and_device_path (
            profile.saved_connection_uuid,
            profile.device_path,
            cancellable
        );
        settings.configured_password = ip_settings.configured_password;
        settings.ipv4_method = ip_settings.ipv4_method;
        settings.ipv6_method = ip_settings.ipv6_method;
        settings.gateway_auto = ip_settings.gateway_auto;
        settings.dns_auto = ip_settings.dns_auto;
        settings.ipv6_gateway_auto = ip_settings.ipv6_gateway_auto;
        settings.ipv6_dns_auto = ip_settings.ipv6_dns_auto;
        settings.configured_address = ip_settings.configured_address;
        settings.configured_prefix = ip_settings.configured_prefix;
        settings.configured_gateway = ip_settings.configured_gateway;
        settings.configured_dns = ip_settings.configured_dns;
        settings.configured_ipv6_address = ip_settings.configured_ipv6_address;
        settings.configured_ipv6_prefix = ip_settings.configured_ipv6_prefix;
        settings.configured_ipv6_gateway = ip_settings.configured_ipv6_gateway;
        settings.configured_ipv6_dns = ip_settings.configured_ipv6_dns;

        return settings;
    }

    public async bool update_saved_profile_settings (
        WifiSavedProfile profile,
        WifiSavedProfileUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (profile.saved_connection_uuid);
        if (conn == null) {
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        var s_conn = conn.get_setting_connection ();
        if (s_conn == null) {
            s_conn = new NM.SettingConnection ();
            conn.add_setting (s_conn);
        }

        string profile_name = request.profile_name.strip () != ""
            ? request.profile_name.strip ()
            : request.ssid.strip ();
        if (profile_name != "") {
            s_conn.id = profile_name;
        }
        s_conn.autoconnect = request.autoconnect;

        while (s_conn.get_num_permissions () > 0) {
            s_conn.remove_permission (0);
        }
        if (!request.available_to_all_users) {
            string username = Environment.get_user_name ();
            if (username.strip () == "") {
                username = "user";
            }
            s_conn.add_permission ("user", username, null);
        }

        var s_wireless = conn.get_setting_wireless ();
        if (s_wireless == null) {
            s_wireless = new NM.SettingWireless ();
            conn.add_setting (s_wireless);
        }

        string ssid = request.ssid.strip ();
        if (ssid != "") {
            uint8[] ssid_arr = ssid.data;
            s_wireless.ssid = new Bytes (ssid_arr);
        }
        s_wireless.bssid = request.bssid.strip ();

        NmWifiUtils.apply_security_mode (conn, request.security_mode);

        if (conn is NM.RemoteConnection) {
            yield ((NM.RemoteConnection)conn).commit_changes_async (true, cancellable);
        }
        return true;
    }

    private async void apply_network_update_request (
        NM.Connection conn,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var s_ip4 = NmIpConfigHelper.ensure_ip4_setting (conn);
        NmIpConfigHelper.apply_ipv4_settings (s_ip4, request.get_ipv4_section ());

        var s_ip6 = NmIpConfigHelper.ensure_ip6_setting (conn);
        NmIpConfigHelper.apply_ipv6_settings (s_ip6, request.get_ipv6_section ());

        if (request.password != null && request.password != "") {
            var s_sec = conn.get_setting_wireless_security ();
            if (s_sec != null) {
                s_sec.psk = request.password;
            }
        }

        if (conn is NM.RemoteConnection) {
            yield ((NM.RemoteConnection)conn).commit_changes_async (true, cancellable);
        }
    }

    public async bool update_saved_profile_network_settings (
        WifiSavedProfile profile,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (profile.saved_connection_uuid);
        if (conn == null) {
            log_warn ("nm-wifi-client", "Connection not found for UUID: " + profile.saved_connection_uuid);
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        yield apply_network_update_request (conn, request, cancellable);
        return true;
    }

    private async NetworkIpSettings get_ip_settings_by_connection_uuid_and_device_path (
        string connection_uuid,
        string device_path,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings ();
        var client = core.nm_client;

        NM.Connection? conn = null;
        if (connection_uuid != "") {
            conn = client.get_connection_by_uuid (connection_uuid);
        }

        if (conn != null) {
            var s_sec = conn.get_setting_wireless_security ();
            if (s_sec != null && s_sec.psk != null) {
                ip_settings.configured_password = s_sec.psk ?? "";
            }

            if (ip_settings.configured_password == "" && conn is NM.RemoteConnection) {
                try {
                    var secrets = yield ((NM.RemoteConnection) conn).get_secrets_async (
                        "802-11-wireless-security",
                        cancellable
                    );
                    if (secrets != null) {
                        Variant? sec_dict = secrets.lookup_value (
                            "802-11-wireless-security",
                            new VariantType ("a{sv}")
                        );
                        if (sec_dict != null) {
                            Variant? psk_value = sec_dict.lookup_value ("psk", new VariantType ("s"));
                            if (psk_value != null) {
                                ip_settings.configured_password = psk_value.get_string ();
                            }
                        }
                    }
                } catch (Error e) {
                    log_debug (
                        "nm-wifi-client",
                        "get_network_ip_settings: unable to read wireless secrets: " + e.message
                    );
                }
            }

            NmIpConfigHelper.populate_configured_ip_settings (ip_settings, conn);
        }

        var dev = client.get_device_by_path (device_path);
        NmIpConfigHelper.populate_runtime_ip_settings (ip_settings, dev);
        return ip_settings;
    }

    public async NetworkIpSettings get_network_ip_settings (
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        return yield get_ip_settings_by_connection_uuid_and_device_path (
            network.saved_connection_uuid,
            network.device_path,
            cancellable
        );
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

        yield apply_network_update_request (conn, request, cancellable);
        return true;
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

        string? specific_object = NmWifiUtils.is_valid_specific_object (network.ap_path) ? network.ap_path : null;
        yield client.activate_connection_async (conn, dev, specific_object, cancellable);
        return true;
    }

    public new async bool connect (
        WifiNetwork network,
        string? password,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        log_debug (
            "nm-wifi-client",
            "connect_decision: ssid='%s' hidden=%s saved=%s uuid=%s password_supplied=%s"
                .printf (
                    redact_ssid (network.ssid),
                    network.is_hidden ? "true" : "false",
                    network.saved ? "true" : "false",
                    redact_uuid (network.saved_connection_uuid),
                    (password != null && password.strip () != "") ? "true" : "false"
                )
        );

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
                string? specific_object = (NmWifiUtils.is_valid_specific_object (network.ap_path)
                 ? network.ap_path : null);
                yield client.activate_connection_async (existing_conn, dev, specific_object, cancellable);
                log_info (
                    "nm-wifi-client",
                    "connect_path: activated existing saved profile for ssid='%s'"
                        .printf (redact_ssid (network.ssid))
                );
                return true;
            }
        }

        if (network.is_hidden && network.ssid.strip () == "") {
            throw new IOError.FAILED ("Hidden network requires an SSID.");
        }

        NM.Connection? partial = null;

        if (network.is_hidden || (password != null && password != "")) {
            partial = (NM.SimpleConnection) NM.SimpleConnection.@new ();

            if (network.is_hidden) {
                var s_wifi = new NM.SettingWireless ();
                uint8[] ssid_arr = network.ssid.data;
                s_wifi.ssid = new Bytes (ssid_arr);
                s_wifi.hidden = true;
                partial.add_setting (s_wifi);
            }

            if (password != null && password != "") {
                var s_sec = new NM.SettingWirelessSecurity ();
                s_sec.psk = password;
                partial.add_setting (s_sec);
            }
        }

        string? specific_object = network.is_hidden ? null : network.ap_path;

        if (network.is_hidden && specific_object == null) {
            // For hidden networks, we must build a full connection manually
            // because specific_object is null and NM cannot infer settings.
            HiddenWifiSecurityMode mode = HiddenWifiSecurityMode.OPEN;
            if (password != null && password != "") {
                bool supports_sae = (network.rsn_flags & NM.80211ApSecurityFlags.KEY_MGMT_SAE) != 0;
                bool supports_psk = (network.rsn_flags & NM.80211ApSecurityFlags.KEY_MGMT_PSK) != 0
                    || (network.wpa_flags & NM.80211ApSecurityFlags.KEY_MGMT_PSK) != 0;

                if (supports_sae && supports_psk) {
                    mode = HiddenWifiSecurityMode.WPA_PSK_SAE;
                } else if (supports_sae) {
                    mode = HiddenWifiSecurityMode.SAE;
                } else if (supports_psk) {
                    mode = HiddenWifiSecurityMode.WPA_PSK;
                } else {
                    mode = HiddenWifiSecurityMode.WPA_PSK;
                }
            }
            partial = NmWifiUtils.create_hidden_wifi_connection (network.ssid, password, mode);
        }

        yield client.add_and_activate_connection_async (partial, dev, specific_object, cancellable);

        log_info (
            "nm-wifi-client",
            "connect_path: add-and-activate for ssid='%s' hidden=%s specific_object=%s"
                .printf (
                    redact_ssid (network.ssid),
                    network.is_hidden ? "true" : "false",
                    specific_object != null ? redact_object_path (specific_object) : "<none>"
                )
        );
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

        var conn = NmWifiUtils.create_hidden_wifi_connection (ssid, password, security_mode);
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
                } catch (Error e) {
                    log_warn (
                        "nm-wifi-client",
                        "wifi_scan request failed iface=%s error=%s".printf (dev.get_iface (), e.message)
                    );
                }
            }
        }
        return true;
    }
}
