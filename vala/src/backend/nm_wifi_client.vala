using GLib;

public class NmWifiClient : Object {
    private NetworkManagerClient core;

    public NmWifiClient(NetworkManagerClient core) {
        this.core = core;
    }

    private static string decode_ssid(Variant value) {
        return NmClientUtils.decode_ssid(value);
    }

    private static string normalize_bssid(string bssid) {
        return bssid.strip().down();
    }

    private static bool looks_like_bssid(string value) {
        string normalized = normalize_bssid(value);
        if (normalized.length != 17) {
            return false;
        }

        for (int i = 0; i < normalized.length; i++) {
            char c = normalized[i];
            if (i == 2 || i == 5 || i == 8 || i == 11 || i == 14) {
                if (c != ':') {
                    return false;
                }
                continue;
            }

            bool is_digit = c >= '0' && c <= '9';
            bool is_hex_alpha = c >= 'a' && c <= 'f';
            if (!is_digit && !is_hex_alpha) {
                return false;
            }
        }

        return true;
    }

    private static string extract_profile_bssid_key(Variant wifi_group) {
        Variant? bssid_v = wifi_group.lookup_value("bssid", new VariantType("s"));
        if (bssid_v != null) {
            string bssid = normalize_bssid(bssid_v.get_string());
            if (looks_like_bssid(bssid)) {
                return bssid;
            }
        }

        return "";
    }

    private void index_saved_profile(
        WifiSavedProfileIndex index,
        Variant all_settings
    ) {
        Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
        Variant? wifi_group = all_settings.lookup_value("802-11-wireless", new VariantType("a{sv}"));
        if (conn_group == null || wifi_group == null) {
            return;
        }

        Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
        if (type_v == null || type_v.get_string() != "802-11-wireless") {
            return;
        }

        Variant? ssid_v = wifi_group.lookup_value("ssid", new VariantType("ay"));
        if (ssid_v == null) {
            core.debug_log("index_saved_profile: no ssid found for profile");
            return;
        }
        string ssid = decode_ssid(ssid_v);

        if (ssid.strip() == "") {
            core.debug_log("index_saved_profile: ignoring profile with empty ssid");
            return;
        }

        Variant? security_group = all_settings.lookup_value("802-11-wireless-security", new VariantType("a{sv}"));
        bool is_secured = (security_group != null);
        string network_key = ssid + ":" + (is_secured ? "secured" : "open");

        string profile_bssid = extract_profile_bssid_key(wifi_group);

        if (profile_bssid != "") {
            // Profile is explicitly locked to a BSSID
            index.bssid_locked_profiles.insert(profile_bssid, true);
        } else {
            // Profile matches ANY BSSID with this SSID
            index.generic_saved_network_keys.insert(network_key, true);
        }

        core.debug_log(
            "index_saved_profile: indexed profile with network_key='%s' (bssid_locked='%s')"
                .printf(redact_network_key(network_key), redact_bssid(profile_bssid))
        );

        Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
        if (uuid_v != null) {
            if (!index.unique_saved_network_key_uuids.contains(network_key)) {
                index.unique_saved_network_key_uuids.insert(network_key, uuid_v.get_string());
            }
        }
    }

    private async WifiSavedProfileIndex build_saved_profile_index_dbus(
        Cancellable? cancellable = null
    ) throws Error {
        var index = new WifiSavedProfileIndex();

        var settings = yield core.make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE, cancellable);
        var list_res = yield core.call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string conn_path = conns.get_child_value(i).get_string();
            var conn = yield core.make_proxy(conn_path, NM_CONN_IFACE, cancellable);
            var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
            var all_settings = settings_res.get_child_value(0);
            index_saved_profile(index, all_settings);
        }

        return index;
    }

    private async List<WifiNetwork> get_networks_dbus(Cancellable? cancellable = null) throws Error {
        var networks = new List<WifiNetwork>();
        var network_map = new HashTable<string, WifiNetwork>(str_hash, str_equal);
        var saved_profile_index = yield build_saved_profile_index_dbus(cancellable);

        var nm = yield core.make_proxy(NM_PATH, NM_IFACE, cancellable);
        var devices_res = yield core.call_dbus(nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value(0);

        for (int i = 0; i < devices.n_children(); i++) {
            string dev_path = devices.get_child_value(i).get_string();
            uint32 dev_type = (yield core.get_prop_dbus(
                dev_path,
                NM_DEVICE_IFACE,
                "DeviceType",
                cancellable
            )).get_uint32();
            if (dev_type != NM_DEVICE_TYPE_WIFI) {
                continue;
            }

            string active_ap_path = (yield core.get_prop_dbus(
                dev_path,
                NM_WIRELESS_IFACE,
                "ActiveAccessPoint",
                cancellable
            )).get_string();
            var wifi = yield core.make_proxy(dev_path, NM_WIRELESS_IFACE, cancellable);
            var aps_res = yield core.call_dbus(wifi, "GetAccessPoints", null, cancellable);
            var aps = aps_res.get_child_value(0);

            for (int j = 0; j < aps.n_children(); j++) {
                string ap_path = aps.get_child_value(j).get_string();

                string ssid = decode_ssid(yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Ssid", cancellable));
                if (ssid == "") {
                    ssid = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "HwAddress", cancellable)).get_string();
                }

                uint8 signal = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Strength", cancellable)).get_byte();
                uint32 flags = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Flags", cancellable)).get_uint32();
                uint32 wpa_flags = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "WpaFlags", cancellable)).get_uint32();
                uint32 rsn_flags = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "RsnFlags", cancellable)).get_uint32();
                string bssid = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "HwAddress", cancellable)).get_string();
                uint32 frequency = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Frequency", cancellable)).get_uint32();
                uint32 max_bitrate = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "MaxBitrate", cancellable)).get_uint32();
                uint32 mode = (yield core.get_prop_dbus(ap_path, NM_AP_IFACE, "Mode", cancellable)).get_uint32();
                bool is_secured = ((flags & 0x1) != 0) || wpa_flags != 0 || rsn_flags != 0;
                bool is_connected = (ap_path == active_ap_path);
                
                string network_key = ssid + ":" + (is_secured ? "secured" : "open");
                
                string profile_uuid = "";
                if (saved_profile_index.unique_saved_network_key_uuids.contains(network_key)) {
                    profile_uuid = saved_profile_index.unique_saved_network_key_uuids.get(network_key);
                }
                
                string normalized_bssid = normalize_bssid(bssid);
                bool is_saved_profile = false;
                
                if (saved_profile_index.generic_saved_network_keys.contains(network_key)) {
                    is_saved_profile = true;
                } else if (normalized_bssid != "" && saved_profile_index.bssid_locked_profiles.contains(normalized_bssid)) {
                    is_saved_profile = true;
                }

                var network = new WifiNetwork() {
                    ssid = ssid,
                    saved_connection_uuid = profile_uuid,
                    signal = signal,
                    connected = is_connected,
                    is_secured = is_secured,
                    saved = is_saved_profile,
                    device_path = dev_path,
                    ap_path = ap_path,
                    bssid = bssid,
                    frequency_mhz = frequency,
                    max_bitrate_kbps = max_bitrate,
                    mode = mode,
                    flags = flags,
                    wpa_flags = wpa_flags,
                    rsn_flags = rsn_flags
                };

                WifiNetwork? existing = network_map.get(network_key);
                if (existing == null || is_connected || (!existing.connected && signal > existing.signal)) {
                    network_map.insert(network_key, network);
                }
            }
        }
        
        network_map.foreach((key, net) => {
            networks.append(net);
        });

        networks.sort((a, b) => {
            if (a.connected != b.connected) {
                return a.connected ? -1 : 1;
            }
            return (int) b.signal - (int) a.signal;
        });

        return (owned) networks;
    }

    private async string resolve_connection_path(
        WifiNetwork network,
        Cancellable? cancellable = null
    ) throws Error {
        string? best_match = null;
        string? generic_match = null;
        string? fallback_match = null;
        bool exact_bssid_match = false;
        string required_uuid = network.saved_connection_uuid.strip();

        core.debug_log(
            "resolve_connection_path: finding profile for ssid='%s' bssid='%s' uuid='%s'".printf(
                redact_ssid(network.ssid),
                redact_bssid(network.bssid),
                redact_uuid(required_uuid)
            )
        );

        var settings = yield core.make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE, cancellable);
        var list_res = yield core.call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string candidate_path = conns.get_child_value(i).get_string();
            var conn = yield core.make_proxy(candidate_path, NM_CONN_IFACE, cancellable);
            var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
            var all_settings = settings_res.get_child_value(0);

            Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
            Variant? wifi_group = all_settings.lookup_value("802-11-wireless", new VariantType("a{sv}"));
            if (conn_group == null || wifi_group == null) continue;

            Variant? id_v = conn_group.lookup_value("id", new VariantType("s"));
            if (id_v == null || id_v.get_string() != network.ssid) {
                continue;
            }

            Variant? ssid_v = wifi_group.lookup_value("ssid", new VariantType("ay"));
            if (ssid_v == null) continue;
            
            string ssid = decode_ssid(ssid_v);
            Variant? security_group = all_settings.lookup_value("802-11-wireless-security", new VariantType("a{sv}"));
            bool is_secured = (security_group != null);
            
            string candidate_key = ssid + ":" + (is_secured ? "secured" : "open");
            if (candidate_key != network.network_key) continue;

            // We have a matching SSID + Security. Check BSSID.
            string profile_bssid = "";
            Variant? bssid_v = wifi_group.lookup_value("bssid", new VariantType("s"));
            if (bssid_v != null) {
                profile_bssid = normalize_bssid(bssid_v.get_string());
            }

            string network_bssid = normalize_bssid(network.bssid);
            bool is_uuid_match = false;
            
            Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
            if (uuid_v != null && required_uuid != "" && uuid_v.get_string() == required_uuid) {
                is_uuid_match = true;
            }

            if (profile_bssid != "") {
                if (profile_bssid == network_bssid) {
                    best_match = candidate_path;
                    exact_bssid_match = true;
                }
            } else {
                if (is_uuid_match) {
                    generic_match = candidate_path;
                } else if (generic_match == null) {
                    fallback_match = candidate_path;
                }
            }
        }

        string? final_match = null;
        if (exact_bssid_match && best_match != null) {
            final_match = best_match;
        } else if (generic_match != null) {
            final_match = generic_match;
        } else if (fallback_match != null) {
            final_match = fallback_match;
        } else if (best_match != null) {
            // Could be a case where we found a BSSID match but didn't mark exact_bssid_match? 
            // The logic above sets both simultaneously, but just in case.
            final_match = best_match;
        }

        if (final_match == null) {
            throw new IOError.NOT_FOUND("No saved connection found for this network.");
        }

        core.debug_log(
            "resolve_connection_path: matched conn_path='%s'".printf(redact_object_path(final_match))
        );
        return final_match;
    }

    public async WifiRefreshData get_refresh_data(Cancellable? cancellable = null) throws Error {
        var networks_list = yield get_networks_dbus(cancellable);
        var devices_list = yield core.get_devices_dbus(cancellable);

        WifiNetwork[] networks = {};
        foreach (var net in networks_list) {
            networks += net;
        }

        NetworkDevice[] devices = {};
        foreach (var dev in devices_list) {
            devices += dev;
        }

        return new WifiRefreshData((owned) networks, (owned) devices);
    }

    public async NetworkIpSettings get_network_ip_settings(
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings();

        if (network.saved) {
            try {
                string conn_path = yield resolve_connection_path(
                    network,
                    cancellable
                );

                var conn = yield core.make_proxy(conn_path, NM_CONN_IFACE, cancellable);
                var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
                var all_settings = settings_res.get_child_value(0);
                NetworkManagerClient.fill_configured_ipv4_from_settings(all_settings, ip_settings);
                NetworkManagerClient.fill_configured_ipv6_from_settings(all_settings, ip_settings);
            } catch (Error e) {
                core.debug_log("could not read saved wifi ipv4 settings: " + e.message);
            }
        }

        yield core.fill_runtime_ipv4_for_device_dbus(
            network.device_path,
            network.connected,
            ip_settings,
            cancellable
        );
        yield core.fill_runtime_ipv6_for_device_dbus(
            network.device_path,
            network.connected,
            ip_settings,
            cancellable
        );
        return ip_settings;
    }

    public async bool update_network_settings(
        WifiNetwork network,
        string password,
        string ipv4_method,
        string ipv4_address,
        uint32 ipv4_prefix,
        bool gateway_auto,
        string ipv4_gateway,
        bool dns_auto,
        string[] ipv4_dns_servers,
        string ipv6_method,
        string ipv6_address,
        uint32 ipv6_prefix,
        bool ipv6_gateway_auto,
        string ipv6_gateway,
        bool ipv6_dns_auto,
        string[] ipv6_dns_servers,
        Cancellable? cancellable = null
    ) throws Error {
        string conn_path = yield resolve_connection_path(
            network,
            cancellable
        );

        string method = NetworkManagerClient.normalize_ipv4_method(ipv4_method);
        string address = ipv4_address.strip();
        string gateway = ipv4_gateway.strip();
        string method6 = NetworkManagerClient.normalize_ipv6_method(ipv6_method);
        string address6 = ipv6_address.strip();
        string gateway6 = ipv6_gateway.strip();

        if (!gateway_auto && gateway == "") {
            throw new IOError.FAILED("Manual gateway requires a gateway address.");
        }

        if (!gateway_auto && method == "disabled") {
            throw new IOError.FAILED("Manual gateway is not supported when IPv4 method is Disabled.");
        }

        if (!dns_auto && ipv4_dns_servers.length == 0) {
            throw new IOError.FAILED("Manual DNS requires at least one DNS server.");
        }

        if (method == "manual") {
            if (address == "") {
                throw new IOError.FAILED("Manual IPv4 requires an address.");
            }
            if (ipv4_prefix == 0 || ipv4_prefix > 32) {
                throw new IOError.FAILED("Manual IPv4 prefix must be between 1 and 32.");
            }
        }

        if (!ipv6_gateway_auto && gateway6 == "") {
            throw new IOError.FAILED("Manual IPv6 gateway requires a gateway address.");
        }

        if ((method6 == "disabled" || method6 == "ignore") && !ipv6_gateway_auto) {
            throw new IOError.FAILED(
                "Manual IPv6 gateway is not supported when IPv6 method is Disabled or Ignore."
            );
        }

        if (!ipv6_dns_auto && ipv6_dns_servers.length == 0) {
            throw new IOError.FAILED("Manual IPv6 DNS requires at least one DNS server.");
        }

        if (method6 == "manual") {
            if (address6 == "") {
                throw new IOError.FAILED("Manual IPv6 requires an address.");
            }
            if (ipv6_prefix == 0 || ipv6_prefix > 128) {
                throw new IOError.FAILED("Manual IPv6 prefix must be between 1 and 128.");
            }
        }

        var conn = yield core.make_proxy(conn_path, NM_CONN_IFACE, cancellable);
        var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
        var all_settings = settings_res.get_child_value(0);

        Variant updated_ipv4;
        Variant updated_ipv6;
        string builder_error = "";
        if (!NmWifiSettingsBuilder.build_updated_ipv4_section(
            all_settings,
            method,
            address,
            ipv4_prefix,
            gateway_auto,
            gateway,
            dns_auto,
            ipv4_dns_servers,
            out updated_ipv4,
            out builder_error
        )) {
            throw new IOError.FAILED(builder_error);
        }

        if (!NmWifiSettingsBuilder.build_updated_ipv6_section(
            all_settings,
            method6,
            address6,
            ipv6_prefix,
            ipv6_gateway_auto,
            gateway6,
            ipv6_dns_auto,
            ipv6_dns_servers,
            out updated_ipv6,
            out builder_error
        )) {
            throw new IOError.FAILED(builder_error);
        }

        Variant updated_settings = NmWifiSettingsBuilder.build_updated_connection_settings(
            all_settings,
            updated_ipv4,
            updated_ipv6,
            network.is_secured,
            password
        );

        yield core.call_dbus(
            conn,
            "Update",
            new Variant("(@a{sa{sv}})", updated_settings),
            cancellable
        );
        return true;
    }

    public async bool connect_saved(WifiNetwork network, Cancellable? cancellable = null) throws Error {
        core.debug_log(
            "connect_saved: ssid='%s' uuid='%s' bssid='%s' device='%s' ap='%s'".printf(
                redact_ssid(network.ssid),
                redact_uuid(network.saved_connection_uuid.strip()),
                redact_bssid(normalize_bssid(network.bssid)),
                redact_object_path(network.device_path),
                redact_object_path(network.ap_path)
            )
        );
        try {
            string conn_path = "/";
            // If we have an exact UUID, we could resolve it. 
            // But telling NM to activate "/" for a specific AP allows NM to pick 
            // the best existing connection for that AP natively.
            // However, we can also try to resolve it explicitly:
            try {
                conn_path = yield resolve_connection_path(network, cancellable);
            } catch (Error resolve_err) {
                log_warn(
                    "nm-wifi",
                    "connect_saved: profile lookup fallback for ssid='%s': %s"
                        .printf(redact_ssid(network.ssid), resolve_err.message)
                );
                conn_path = "/";
            }

            log_info(
                "nm-wifi",
                "activating saved network ssid='%s' via conn_path='%s'"
                    .printf(redact_ssid(network.ssid), redact_object_path(conn_path))
            );
            var nm = yield core.make_proxy(NM_PATH, NM_IFACE, cancellable);
            yield core.call_dbus(
                nm,
                "ActivateConnection",
                new Variant("(ooo)", conn_path, network.device_path, network.ap_path),
                cancellable
            );
            log_info("nm-wifi", "saved network activation request sent successfully");
            return true;
        } catch (Error e) {
            log_warn(
                "nm-wifi",
                "connect_saved failed for ssid='%s': %s".printf(redact_ssid(network.ssid), e.message)
            );
            throw e;
        }
    }

    public new async bool connect(
        WifiNetwork network,
        string? password,
        Cancellable? cancellable = null
    ) throws Error {
        bool has_saved_uuid = network.saved_connection_uuid.strip() != "";
        bool can_use_saved_profile = network.saved;
        core.debug_log(
            "connect: ssid='%s' saved=%s uuid_present=%s secured=%s bssid='%s'".printf(
                redact_ssid(network.ssid),
                network.saved ? "true" : "false",
                has_saved_uuid ? "true" : "false",
                network.is_secured ? "true" : "false",
                redact_bssid(normalize_bssid(network.bssid))
            )
        );
        try {
            if (can_use_saved_profile) {
                try {
                    return yield connect_saved(network, cancellable);
                } catch (Error saved_err) {
                    log_warn(
                        "nm-wifi",
                        "saved-profile connect failed for ssid='%s': %s; falling back to password connect"
                            .printf(redact_ssid(network.ssid), saved_err.message)
                    );
                }
            }

            if (password == null) {
                password = "";
            }

            return yield connect_with_password(network, password, cancellable);
        } catch (Error e) {
            log_warn("nm-wifi", "connect failed for ssid='%s': %s".printf(redact_ssid(network.ssid), e.message));
            throw e;
        }
    }

    public async bool connect_with_password(
        WifiNetwork network,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        core.debug_log(
            "connect_with_password: ssid='%s' secured=%s bssid='%s' password_len=%u".printf(
                redact_ssid(network.ssid),
                network.is_secured ? "true" : "false",
                redact_bssid(normalize_bssid(network.bssid)),
                (uint) password.strip().char_count()
            )
        );
        if (network.is_secured && password.strip() == "") {
            throw new IOError.FAILED("Password is required for secured networks.");
        }

        string password_clean = password.strip();
        if (network.is_secured && password_clean.char_count() < HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH) {
            throw new IOError.FAILED(
                "Password must be at least %d characters for secured networks.".printf(
                    HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH
                )
            );
        }

        uint32 key_mgmt_flags = network.wpa_flags | network.rsn_flags;
        bool supports_sae = (key_mgmt_flags & NM_80211_AP_SEC_KEY_MGMT_SAE) != 0;
        bool supports_psk = (key_mgmt_flags & NM_80211_AP_SEC_KEY_MGMT_PSK) != 0;
        string key_mgmt = "wpa-psk";
        if (supports_sae && !supports_psk) {
            key_mgmt = "sae";
        }

        var nm = yield core.make_proxy(NM_PATH, NM_IFACE, cancellable);

        var conn = new VariantBuilder(new VariantType("a{sa{sv}}"));

        var conn_section = new VariantBuilder(new VariantType("a{sv}"));
        string connection_id = network.ssid;
        conn_section.add("{sv}", "id", new Variant.string(connection_id));
        conn_section.add("{sv}", "type", new Variant.string("802-11-wireless"));
        conn_section.add("{sv}", "uuid", new Variant.string(Uuid.string_random()));
        conn_section.add("{sv}", "autoconnect", new Variant.boolean(true));
        conn.add("{s@a{sv}}", "connection", conn_section.end());

        var wifi_section = new VariantBuilder(new VariantType("a{sv}"));
        wifi_section.add("{sv}", "ssid", NmClientUtils.make_ssid_variant(network.ssid));
        conn.add("{s@a{sv}}", "802-11-wireless", wifi_section.end());

        if (network.is_secured) {
            var sec = new VariantBuilder(new VariantType("a{sv}"));
            sec.add("{sv}", "key-mgmt", new Variant.string(key_mgmt));
            sec.add("{sv}", "psk", new Variant.string(password_clean));
            conn.add("{s@a{sv}}", "802-11-wireless-security", sec.end());
        }

        try {
            yield core.call_dbus(
                nm,
                "AddAndActivateConnection",
                new Variant("(@a{sa{sv}}oo)", conn.end(), network.device_path, network.ap_path),
                cancellable
            );
            log_info(
                "nm-wifi",
                "password-based connect request sent for ssid='%s'"
                    .printf(redact_ssid(network.ssid))
            );
            return true;
        } catch (Error e) {
            log_warn(
                "nm-wifi",
                "connect_with_password failed for ssid='%s': %s".printf(redact_ssid(network.ssid), e.message)
            );
            throw e;
        }
    }

    private async string resolve_wifi_device_path_for_hidden_connect(
        Cancellable? cancellable = null
    ) throws Error {
        string fallback_path = "";
        var devices = yield core.get_devices_dbus(cancellable);
        foreach (var dev in devices) {
            if (!dev.is_wifi) {
                continue;
            }

            if (fallback_path == "") {
                fallback_path = dev.device_path;
            }

            if (dev.is_connected) {
                return dev.device_path;
            }
        }

        if (fallback_path != "") {
            return fallback_path;
        }

        throw new IOError.NOT_FOUND("No Wi-Fi device available for hidden network connection.");
    }

    public async bool connect_hidden_network(
        string ssid,
        HiddenWifiSecurityMode security_mode,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        string hidden_ssid = ssid.strip();
        if (hidden_ssid == "") {
            throw new IOError.FAILED("SSID is required.");
        }

        if (HiddenWifiSecurityModeUtils.requires_password(security_mode) && password.strip() == "") {
            throw new IOError.FAILED("Password is required for the selected security mode.");
        }

        string device_path = yield resolve_wifi_device_path_for_hidden_connect(cancellable);
        var nm = yield core.make_proxy(NM_PATH, NM_IFACE, cancellable);

        var conn = new VariantBuilder(new VariantType("a{sa{sv}}"));

        var conn_section = new VariantBuilder(new VariantType("a{sv}"));
        conn_section.add("{sv}", "id", new Variant.string(hidden_ssid));
        conn_section.add("{sv}", "type", new Variant.string("802-11-wireless"));
        conn_section.add("{sv}", "uuid", new Variant.string(Uuid.string_random()));
        conn_section.add("{sv}", "autoconnect", new Variant.boolean(true));
        conn.add("{s@a{sv}}", "connection", conn_section.end());

        var wifi_section = new VariantBuilder(new VariantType("a{sv}"));
        wifi_section.add("{sv}", "ssid", NmClientUtils.make_ssid_variant(hidden_ssid));
        wifi_section.add("{sv}", "hidden", new Variant.boolean(true));
        conn.add("{s@a{sv}}", "802-11-wireless", wifi_section.end());

        if (security_mode != HiddenWifiSecurityMode.OPEN) {
            var sec = new VariantBuilder(new VariantType("a{sv}"));

            sec.add(
                "{sv}",
                "key-mgmt",
                new Variant.string(HiddenWifiSecurityModeUtils.to_nm_key_mgmt(security_mode))
            );

            if (security_mode == HiddenWifiSecurityMode.WEP) {
                sec.add("{sv}", "wep-key0", new Variant.string(password));
                sec.add("{sv}", "wep-key-type", new Variant.uint32(1));
                sec.add("{sv}", "auth-alg", new Variant.string("open"));
            } else {
                // WPA2/WPA3 transition mode generally negotiates via WPA-PSK config.
                sec.add("{sv}", "psk", new Variant.string(password));
            }

            conn.add("{s@a{sv}}", "802-11-wireless-security", sec.end());
        }

        yield core.call_dbus(
            nm,
            "AddAndActivateConnection",
            new Variant("(@a{sa{sv}}oo)", conn.end(), device_path, "/"),
            cancellable
        );

        log_info("nm-wifi", "hidden network connect request sent for ssid='%s'".printf(redact_ssid(hidden_ssid)));
        return true;
    }

    public new async bool disconnect(WifiNetwork network, Cancellable? cancellable = null) throws Error {
        var dev = yield core.make_proxy(network.device_path, NM_DEVICE_IFACE, cancellable);
        yield core.call_dbus(dev, "Disconnect", null, cancellable);
        return true;
    }

    public async bool forget_network(
        string profile_uuid,
        string network_key,
        Cancellable? cancellable = null
    ) throws Error {
        string uuid = profile_uuid.strip();
        if (uuid == "") {
            throw new IOError.FAILED("Missing saved profile UUID. Cannot forget network.");
        }

        string? conn_path = null;

        var settings = yield core.make_proxy(NM_SETTINGS_PATH, NM_SETTINGS_IFACE, cancellable);
        var list_res = yield core.call_dbus(settings, "ListConnections", null, cancellable);
        var conns = list_res.get_child_value(0);

        for (int i = 0; i < conns.n_children(); i++) {
            string candidate_path = conns.get_child_value(i).get_string();
            var conn = yield core.make_proxy(candidate_path, NM_CONN_IFACE, cancellable);
            var settings_res = yield core.call_dbus(conn, "GetSettings", null, cancellable);
            var all_settings = settings_res.get_child_value(0);

            Variant? conn_group = all_settings.lookup_value("connection", new VariantType("a{sv}"));
            if (conn_group == null) {
                continue;
            }

            Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
            if (uuid_v != null && uuid_v.get_string() == uuid) {
                conn_path = candidate_path;
                break;
            }
        }

        if (conn_path == null) {
            throw new IOError.NOT_FOUND("Saved connection profile not found.");
        }

        var conn = yield core.make_proxy(conn_path, NM_CONN_IFACE, cancellable);
        yield core.call_dbus(conn, "Delete", null, cancellable);
        log_info(
            "nm-wifi",
            "forgot saved profile uuid='%s' network_key='%s'"
                .printf(redact_uuid(uuid), redact_network_key(network_key))
        );
        
        return true;
    }

    public async bool scan(Cancellable? cancellable = null) throws Error {
        var nm = yield core.make_proxy(NM_PATH, NM_IFACE, cancellable);
        var devices_res = yield core.call_dbus(nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value(0);

        uint scanned = 0;
        for (int i = 0; i < devices.n_children(); i++) {
            string dev_path = devices.get_child_value(i).get_string();
            uint32 dev_type = (yield core.get_prop_dbus(
                dev_path,
                NM_DEVICE_IFACE,
                "DeviceType",
                cancellable
            )).get_uint32();
            if (dev_type != NM_DEVICE_TYPE_WIFI) {
                continue;
            }

            var wifi = yield core.make_proxy(dev_path, NM_WIRELESS_IFACE, cancellable);
            var options = new VariantBuilder(new VariantType("a{sv}"));
            yield core.call_dbus(
                wifi,
                "RequestScan",
                new Variant("(@a{sv})", options.end()),
                cancellable
            );
            scanned++;
        }

        log_info("nm-wifi", "requested scan on %u wifi device(s)".printf(scanned));
        return true;
    }
}
