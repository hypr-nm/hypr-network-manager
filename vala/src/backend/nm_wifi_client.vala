/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using HyprNetworkManager.Models;

public class NmWifiClient : GLib.Object {
    private NetworkManagerClient core;
    private int hotspot_idle_minutes = 0;
    private bool is_hotspot_stopping = false;

    private bool is_hotspot_starting = false;

    private bool has_create_ap () {
        return GLib.Environment.find_program_in_path ("create_ap") != null;
    }

    private async void nm_async_sleep (uint ms) {
        Timeout.add (ms, () => {
            nm_async_sleep.callback ();
            return false;
        });
        yield;
    }

    public NmWifiClient (NetworkManagerClient core) {
        this.core = core;
        GLib.Timeout.add_seconds (60, check_hotspot_timeout);
    }

    private bool check_hotspot_timeout () {
        var dev = get_wifi_device ();
        if (dev == null) return true;

        int timeout_mins = 0;
        string? ap_interface = null;
        var connections = core.nm_client.get_connections ();
        foreach (var conn_it in connections) {
            var s_w = conn_it.get_setting_wireless ();
            if (s_w != null && s_w.mode == "ap") {
                var s_usr = (NM.SettingUser) conn_it.get_setting (typeof (NM.SettingUser));
                if (s_usr != null) {
                    string? to_val = s_usr.get_data ("hypr-network-manager.hotspot.timeout");
                    if (to_val != null) timeout_mins = int.parse (to_val);
                    ap_interface = s_usr.get_data ("hypr-network-manager.hotspot.ap_interface");
                }
                break;
            }
        }

        NM.DeviceWifi? target_dev = dev;
        if (ap_interface != null && ap_interface != "" && ap_interface != "Auto") {
            var nm_dev = core.nm_client.get_device_by_iface (ap_interface);
            if (nm_dev is NM.DeviceWifi) target_dev = (NM.DeviceWifi) nm_dev;
        }

        if (has_create_ap ()) {
            bool is_running = false;
            try {
                if (target_dev != null) {
                    string[] argv = { "pgrep", "-P", "1", "-f", "bash.*create_ap.*" + target_dev.get_iface () };
                    int exit_status;
                    string stdout_content;
                    if (Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_content, null, out exit_status)) {
                        if (exit_status == 0 && stdout_content.strip () != "") {
                            is_running = true;
                        }
                    }
                }
            } catch (Error e) {}
            
            if (!is_running) {
                // Not running via create_ap, fallback to checking NM below
            } else {
                if (timeout_mins <= 0) {
                    hotspot_idle_minutes = 0;
                    return true;
                }
                
                bool has_clients_ap = false;
                try {
                    string[] argv = { "bash", "-c", "for iface in $(iw dev | grep Interface | awk '{print $2}'); do iw dev $iface station dump 2>/dev/null | grep -q 'Station' && echo 'yes'; done" };
                    string stdout_content;
                    if (Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_content, null, null)) {
                        if (stdout_content.contains ("yes")) {
                            has_clients_ap = true;
                        }
                    }
                } catch (Error e) {}
                
                if (has_clients_ap) {
                    hotspot_idle_minutes = 0;
                } else {
                    hotspot_idle_minutes++;
                    if (hotspot_idle_minutes >= timeout_mins) {
                        core.debug_log ("Hotspot idle timeout reached, disconnecting via create_ap.");
                        disable_hotspot_async.begin (null);
                        hotspot_idle_minutes = 0;
                    }
                }
                return true;
            }
        }

        if (target_dev == null) return true;
        var active_conn = target_dev.get_active_connection ();
        if (active_conn == null) {
            hotspot_idle_minutes = 0;
            return true;
        }

        var conn = active_conn.get_connection ();
        if (conn == null) {
            hotspot_idle_minutes = 0;
            return true;
        }

        var s_wifi = conn.get_setting_wireless ();
        if (s_wifi == null || s_wifi.mode != "ap") {
            hotspot_idle_minutes = 0;
            return true;
        }
        
        if (timeout_mins <= 0) {
            hotspot_idle_minutes = 0;
            return true;
        }

        bool has_clients = false;
        try {
            string stdout_content, stderr_content;
            int exit_status;
            
            string[] argv = { "iw", "dev", target_dev.get_iface (), "station", "dump" };
            if (Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_content, out stderr_content, out exit_status)) {
                if (exit_status == 0) {
                    if (stdout_content.contains ("Station ")) {
                        has_clients = true;
                    }
                }
            }
        } catch (Error e) {
            // Ignore gracefully
        }

        if (has_clients) {
            hotspot_idle_minutes = 0;
        } else {
            hotspot_idle_minutes++;
            if (hotspot_idle_minutes >= timeout_mins) {
                core.debug_log ("Hotspot idle timeout reached, disconnecting.");
                disable_hotspot_async.begin (null);
                hotspot_idle_minutes = 0;
            }
        }

        return true;
    }

    public async WifiRefreshData get_refresh_data (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var devices = client.get_devices ();
        var connections = client.get_connections ();

        var networks_map = new HashTable<string, WifiNetwork> (str_hash, str_equal);
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
                        ssid = _("Hidden network %u").printf (hidden_index);
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

            // Bucket signal to 5% increments to avoid jitter from tiny changes
            int bucket_a = (int) (a.signal / 5);
            int bucket_b = (int) (b.signal / 5);
            if (bucket_a != bucket_b) {
                return bucket_b - bucket_a;
            }

            // Tie-breakers for deterministic order
            int ssid_cmp = a.ssid.collate (b.ssid);
            if (ssid_cmp != 0) {
                return ssid_cmp;
            }

            string bssid_a = a.bssid != null ? a.bssid : "";
            string bssid_b = b.bssid != null ? b.bssid : "";
            return bssid_a.collate (bssid_b);
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

        var s_8021x = conn.get_setting_802_1x ();
        if (s_8021x != null) {
            settings.identity = s_8021x.identity != null ? s_8021x.identity : "";
            settings.anonymous_identity = s_8021x.anonymous_identity != null ? s_8021x.anonymous_identity : "";
            settings.domain_suffix_match = s_8021x.domain_suffix_match != null ? s_8021x.domain_suffix_match : "";
            settings.ca_cert = s_8021x.get_ca_cert_path () != null ? s_8021x.get_ca_cert_path () : "";
            settings.ca_cert_password = s_8021x.get_ca_cert_password () != null ? s_8021x.get_ca_cert_password () : "";
            if (s_8021x.get_num_eap_methods () > 0) {
                settings.eap_method = s_8021x.get_eap_method (0);
            }
            settings.phase2_auth = s_8021x.phase2_auth != null ? s_8021x.phase2_auth : "";
            settings.user_cert = s_8021x.get_client_cert_path () != null ? s_8021x.get_client_cert_path () : "";
            settings.user_cert_password = s_8021x.get_client_cert_password () != null ? s_8021x.get_client_cert_password () : "";
            settings.user_private_key = s_8021x.get_private_key_path () != null ? s_8021x.get_private_key_path () : "";
            settings.user_private_key_password = s_8021x.get_private_key_password () != null ? s_8021x.get_private_key_password () : "";
        }

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

    public async string? get_wifi_password (
        string connection_uuid,
        Cancellable? cancellable = null
    ) {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (connection_uuid);
        if (conn == null) {
            return null;
        }

        var s_sec = conn.get_setting_wireless_security ();
        if (s_sec != null && s_sec.psk != null && s_sec.psk != "") {
            return s_sec.psk;
        }

        var s_8021x = conn.get_setting_802_1x ();
        if (s_8021x != null && s_8021x.password != null && s_8021x.password != "") {
            return s_8021x.password;
        }

        if (conn is NM.RemoteConnection) {
            try {
                var secrets = yield ((NM.RemoteConnection) conn).get_secrets_async ("802-1x", cancellable);
                if (secrets != null) {
                    Variant? sec_dict = secrets.lookup_value ("802-1x", new VariantType ("a{sv}"));
                    if (sec_dict != null) {
                        Variant? pass_value = sec_dict.lookup_value ("password", new VariantType ("s"));
                        if (pass_value != null) {
                            return pass_value.get_string ();
                        }
                    }
                }
            } catch (Error e) {
                log_debug ("nm-wifi-client", "get_wifi_password: unable to read 802-1x secrets: " + e.message);
            }

            try {
                var secrets = yield ((NM.RemoteConnection) conn).get_secrets_async ("802-11-wireless-security", cancellable);
                if (secrets != null) {
                    Variant? sec_dict = secrets.lookup_value ("802-11-wireless-security", new VariantType ("a{sv}"));
                    if (sec_dict != null) {
                        Variant? psk_value = sec_dict.lookup_value ("psk", new VariantType ("s"));
                        if (psk_value != null) {
                            return psk_value.get_string ();
                        }
                    }
                }
            } catch (Error e) {
                log_debug ("nm-wifi-client", "get_wifi_password: unable to read wireless secrets: " + e.message);
            }
        }
        return null;
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
        if (request.security_mode == "wpa-eap") {
            var s_8021x = conn.get_setting_802_1x ();
            if (s_8021x != null) {
                s_8021x.clear_eap_methods ();
                s_8021x.add_eap_method (request.eap_method);
                s_8021x.phase2_auth = request.phase2_auth;
                s_8021x.identity = request.identity;
                s_8021x.anonymous_identity = request.anonymous_identity;
                s_8021x.domain_suffix_match = request.domain_suffix_match;
                s_8021x.ca_cert_password = request.ca_cert_password;
                s_8021x.client_cert_password = request.user_cert_password;
                if (request.ca_cert != null && request.ca_cert.strip () != "") {
                    s_8021x.set_ca_cert (request.ca_cert.strip (), NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
                } else {
                    s_8021x.set_ca_cert ((string?) null, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
                }
                if (request.user_cert != null && request.user_cert.strip () != "") {
                    s_8021x.set_client_cert (request.user_cert.strip (), NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
                } else {
                    s_8021x.set_client_cert ((string?) null, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
                }
                if (request.user_private_key != null && request.user_private_key.strip () != "") {
                    s_8021x.set_private_key (request.user_private_key.strip (), request.user_private_key_password, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
                } else {
                    s_8021x.set_private_key ((string?) null, request.user_private_key_password, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
                }
            }
        }

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

        var s_sec = conn.get_setting_wireless_security ();
        if (s_sec != null && s_sec.key_mgmt == "wpa-eap") {
            var s_8021x = conn.get_setting_802_1x ();
            if (s_8021x == null) {
                s_8021x = new NM.Setting8021x ();
                conn.add_setting (s_8021x);
            }
            s_8021x.clear_eap_methods ();
            s_8021x.add_eap_method (request.eap_method);
            s_8021x.phase2_auth = request.phase2_auth;
            if (request.identity != null && request.identity != "") {
                s_8021x.identity = request.identity;
            }
            if (request.anonymous_identity != null && request.anonymous_identity != "") {
                s_8021x.anonymous_identity = request.anonymous_identity;
            }
            if (request.domain_suffix_match != null && request.domain_suffix_match != "") {
                s_8021x.domain_suffix_match = request.domain_suffix_match;
            }
            s_8021x.ca_cert_password = request.ca_cert_password;
            s_8021x.client_cert_password = request.user_cert_password;
            if (request.ca_cert != null && request.ca_cert.strip () != "") {
                s_8021x.set_ca_cert (request.ca_cert.strip (), NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
            } else {
                s_8021x.set_ca_cert ((string?) null, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
            }
            if (request.user_cert != null && request.user_cert.strip () != "") {
                s_8021x.set_client_cert (request.user_cert.strip (), NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
            } else {
                s_8021x.set_client_cert ((string?) null, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
            }
            if (request.user_private_key != null && request.user_private_key.strip () != "") {
                s_8021x.set_private_key (request.user_private_key.strip (), request.user_private_key_password, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
            } else {
                s_8021x.set_private_key ((string?) null, request.user_private_key_password, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
            }
            if (request.password != null && request.password != "") {
                s_8021x.password = request.password;
            }
        } else {
            if (request.password != null && request.password != "") {
                if (s_sec != null) {
                    s_sec.psk = request.password;
                }
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

            var s_8021x = conn.get_setting_802_1x ();
            if (s_8021x != null && s_8021x.password != null) {
                ip_settings.configured_password = s_8021x.password ?? "";
            }

            if (ip_settings.configured_password == "" && conn is NM.RemoteConnection) {
                try {
                    var secrets = yield ((NM.RemoteConnection) conn).get_secrets_async (
                        "802-1x",
                        cancellable
                    );
                    if (secrets != null) {
                        Variant? sec_dict = secrets.lookup_value (
                            "802-1x",
                            new VariantType ("a{sv}")
                        );
                        if (sec_dict != null) {
                            Variant? pass_value = sec_dict.lookup_value ("password", new VariantType ("s"));
                            if (pass_value != null) {
                                ip_settings.configured_password = pass_value.get_string ();
                            }
                        }
                    }
                } catch (Error e) {
                    log_debug (
                        "nm-wifi-client",
                        "get_network_ip_settings: unable to read 802-1x secrets: " + e.message
                    );
                }
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

    private void apply_connection_autoconnect (
        NM.Connection conn,
        string ssid,
        bool autoconnect
    ) {
        var s_conn = conn.get_setting_connection ();
        if (s_conn == null) {
            s_conn = new NM.SettingConnection ();
            conn.add_setting (s_conn);
        }

        if (s_conn.id == null || s_conn.id.strip () == "") {
            s_conn.id = ssid;
        }
        if (s_conn.type == null || s_conn.type.strip () == "") {
            s_conn.type = "802-11-wireless";
        }
        if (s_conn.uuid == null || s_conn.uuid.strip () == "") {
            s_conn.uuid = NM.Utils.uuid_generate ();
        }
        s_conn.autoconnect = autoconnect;
    }

    public new async bool connect (
        WifiNetwork network,
        string? password,
        bool autoconnect = true,
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
                apply_connection_autoconnect (existing_conn, network.ssid, autoconnect);
                if (password != null && password != "") {
                    var s_sec = existing_conn.get_setting_wireless_security ();
                    if (s_sec != null && s_sec.key_mgmt == "wpa-eap") {
                        var s_8021x = existing_conn.get_setting_802_1x ();
                        if (s_8021x == null) {
                            s_8021x = new NM.Setting8021x ();
                            existing_conn.add_setting (s_8021x);
                        }
                        s_8021x.add_eap_method ("peap");
                        s_8021x.phase2_auth = "mschapv2";
                        if (password.contains ("\x1f")) {
                            string[] parts = password.split ("\x1f", 2);
                            s_8021x.identity = parts[0];
                            if (parts.length > 1) {
                                s_8021x.password = parts[1];
                            }
                        } else {
                            s_8021x.password = password;
                        }
                    } else {
                        if (s_sec == null) {
                            s_sec = new NM.SettingWirelessSecurity ();
                            existing_conn.add_setting (s_sec);
                        }
                        s_sec.psk = password;
                    }
                }
                if (existing_conn is NM.RemoteConnection) {
                    yield ((NM.RemoteConnection)existing_conn).commit_changes_async (true, cancellable);
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

        bool is_enterprise = (network.rsn_flags & NM.80211ApSecurityFlags.KEY_MGMT_802_1X) != 0
            || (network.wpa_flags & NM.80211ApSecurityFlags.KEY_MGMT_802_1X) != 0;

        NM.Connection? partial = null;

        if (network.is_hidden || (password != null && password != "") || is_enterprise) {
            partial = (NM.SimpleConnection) NM.SimpleConnection.@new ();

            if (network.is_hidden) {
                var s_wifi = new NM.SettingWireless ();
                uint8[] ssid_arr = network.ssid.data;
                s_wifi.ssid = new Bytes (ssid_arr);
                s_wifi.hidden = true;
                partial.add_setting (s_wifi);
            }

            if (is_enterprise) {
                var s_sec = new NM.SettingWirelessSecurity ();
                s_sec.key_mgmt = "wpa-eap";
                partial.add_setting (s_sec);

                var s_8021x = new NM.Setting8021x ();
                s_8021x.add_eap_method ("peap");
                s_8021x.phase2_auth = "mschapv2";
                if (password != null) {
                    if (password.contains ("\x1f")) {
                        string[] parts = password.split ("\x1f", 2);
                        s_8021x.identity = parts[0];
                        if (parts.length > 1) {
                            s_8021x.password = parts[1];
                        }
                    } else {
                        s_8021x.password = password;
                    }
                }
                partial.add_setting (s_8021x);
            } else if (password != null && password != "") {
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

        if (partial != null || !autoconnect) {
            if (partial == null) {
                partial = (NM.SimpleConnection) NM.SimpleConnection.@new ();
            }
            apply_connection_autoconnect (partial, network.ssid, autoconnect);
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
        bool autoconnect = true,
        Cancellable? cancellable = null
    ) throws Error {
        return yield connect (network, password, autoconnect, cancellable);
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
                yield ((NM.DeviceWifi) dev).request_scan_async (cancellable);
                return true;
            }
        }
        return true;
    }

    private NM.DeviceWifi? get_wifi_device () {
        var devices = core.nm_client.get_devices ();
        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi) {
                return (NM.DeviceWifi) dev;
            }
        }
        return null;
    }

    public async HotspotConfig get_hotspot_status (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var connections = client.get_connections ();
        NM.Connection? hotspot_conn = null;
        
        foreach (var conn in connections) {
            var s_wifi = conn.get_setting_wireless ();
            if (s_wifi != null && s_wifi.mode == "ap") {
                hotspot_conn = conn;
                break;
            }
        }

        var config = new HotspotConfig ();
        
        var dev = get_wifi_device ();
        if (dev != null) {
            var cap = dev.get_capabilities ();
            config.supports_2ghz = (cap & NM.DeviceWifiCapabilities.FREQ_2GHZ) != 0;
            config.supports_5ghz = (cap & NM.DeviceWifiCapabilities.FREQ_5GHZ) != 0;
        } else {
            config.supports_2ghz = true;
            config.supports_5ghz = true;
        }
        
        if (hotspot_conn != null) {
            var s_wifi = hotspot_conn.get_setting_wireless ();
            config.ssid = NmWifiUtils.bytes_to_ssid (s_wifi.ssid);
            config.connection_uuid = hotspot_conn.get_uuid ();
            config.band = s_wifi.band != null ? s_wifi.band : "";
            config.is_hidden = s_wifi.hidden;
            
            var s_user = (NM.SettingUser) hotspot_conn.get_setting (typeof (NM.SettingUser));
            if (s_user != null) {
                string? to_val = s_user.get_data ("hypr-network-manager.hotspot.timeout");
                if (to_val != null) {
                    config.timeout = int.parse (to_val);
                }
                string? ap_iface = s_user.get_data ("hypr-network-manager.hotspot.ap_interface");
                if (ap_iface != null) {
                    config.ap_interface = ap_iface;
                }
                string? up_iface = s_user.get_data ("hypr-network-manager.hotspot.uplink_interface");
                if (up_iface != null) {
                    config.uplink_interface = up_iface;
                }
            }

            var s_sec = hotspot_conn.get_setting_wireless_security ();
            if (s_sec == null) {
                config.security = "none";
            } else {
                config.security = s_sec.key_mgmt != null ? s_sec.key_mgmt : "wpa-psk";
                
                if (hotspot_conn is NM.RemoteConnection) {
                    try {
                        var secrets = yield ((NM.RemoteConnection) hotspot_conn).get_secrets_async ("802-11-wireless-security", cancellable);
                        if (secrets != null) {
                            Variant? sec_dict = secrets.lookup_value ("802-11-wireless-security", new VariantType ("a{sv}"));
                            if (sec_dict != null) {
                                Variant? psk_var = sec_dict.lookup_value ("psk", new VariantType ("s"));
                                if (psk_var != null) {
                                    config.password = psk_var.get_string ();
                                }
                            }
                        }
                    } catch (Error e) {
                        log_warn ("nm-wifi-client", "Failed to get hotspot secrets: " + e.message);
                    }
                } else if (s_sec.psk != null) {
                    config.password = s_sec.psk;
                }
            }

            if (has_create_ap ()) {
                config.is_active = false;
                
                if (is_hotspot_stopping) {
                    return config;
                }
                
                if (is_hotspot_starting) {
                    config.is_active = true;
                    return config;
                }
                
                try {
                    string stdout_content, stderr_content;
                    int exit_status;
                    
                    NM.DeviceWifi? target_dev = dev;
                    if (config.ap_interface != "" && config.ap_interface != "Auto") {
                        var nm_dev = client.get_device_by_iface (config.ap_interface);
                        if (nm_dev is NM.DeviceWifi) target_dev = (NM.DeviceWifi) nm_dev;
                    }
                    
                    if (target_dev != null) {
                        string[] argv = { "pgrep", "-P", "1", "-f", "bash.*create_ap.*" + target_dev.get_iface () };
                        if (Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_content, out stderr_content, out exit_status)) {
                            if (exit_status == 0 && stdout_content.strip () != "") {
                                config.is_active = true;
                            }
                        }
                    }
                } catch (Error e) {
                }
            }
            
            if (!config.is_active) {
                var active_conns = client.get_active_connections ();
                foreach (var ac in active_conns) {
                    if (ac.get_uuid () == config.connection_uuid && 
                        (ac.get_state () == NM.ActiveConnectionState.ACTIVATED ||
                         ac.get_state () == NM.ActiveConnectionState.ACTIVATING)) {
                        config.is_active = true;
                        break;
                    }
                }
            }
        }

        return config;
    }

    public async NM.RemoteConnection create_or_update_hotspot (string ssid, string password, string security, string band, bool is_hidden, int timeout, string ap_interface, string uplink_interface, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var config = yield get_hotspot_status (cancellable);
        
        if (config.connection_uuid != "") {
            var conn = client.get_connection_by_uuid (config.connection_uuid);
            if (conn != null) {
                var s_con = conn.get_setting_connection ();
                if (s_con != null) {
                    s_con.id = ssid;
                    
                    if (ap_interface != "Auto" && ap_interface != "") {
                        s_con.interface_name = ap_interface;
                    } else {
                        s_con.interface_name = null;
                    }
                }
                
                var s_wifi = conn.get_setting_wireless ();
                uint8[] ssid_arr = ssid.data;
                s_wifi.ssid = new Bytes (ssid_arr);
                s_wifi.hidden = is_hidden;
                
                if (band == "") {
                    s_wifi.band = null;
                } else {
                    s_wifi.band = band;
                }
                
                if (security != "none") {
                    var s_sec = conn.get_setting_wireless_security ();
                    if (s_sec == null) {
                        s_sec = new NM.SettingWirelessSecurity ();
                        conn.add_setting (s_sec);
                    }
                    s_sec.key_mgmt = security;
                    if (password != "") {
                        s_sec.psk = password;
                    }
                    
                    // Always ensure modern secure crypto
                    s_sec.proto = new string[] { "rsn" };
                    s_sec.pairwise = new string[] { "ccmp" };
                    s_sec.group = new string[] { "ccmp" };
                } else {
                    conn.remove_setting (typeof (NM.SettingWirelessSecurity));
                }
                
                var s_user = (NM.SettingUser) conn.get_setting (typeof (NM.SettingUser));
                if (s_user == null) {
                    s_user = new NM.SettingUser ();
                    conn.add_setting (s_user);
                }
                try {
                    s_user.set_data ("hypr-network-manager.hotspot.timeout", timeout.to_string ());
                    s_user.set_data ("hypr-network-manager.hotspot.ap_interface", ap_interface);
                    s_user.set_data ("hypr-network-manager.hotspot.uplink_interface", uplink_interface);
                } catch (Error e) {}

                if (conn is NM.RemoteConnection) {
                    yield ((NM.RemoteConnection)conn).commit_changes_async (true, cancellable);
                    return (NM.RemoteConnection)conn;
                }
            }
        }
        
        // Need to create new
        var new_conn = NmWifiUtils.create_hotspot_connection (ssid, password, security, band, is_hidden, timeout);
        
        var s_con = new_conn.get_setting_connection ();
        if (s_con != null) {
            if (ap_interface != "Auto" && ap_interface != "") {
                s_con.interface_name = ap_interface;
            } else {
                s_con.interface_name = null;
            }
        }
        
        var s_user = (NM.SettingUser) new_conn.get_setting (typeof (NM.SettingUser));
        if (s_user == null) {
            s_user = new NM.SettingUser ();
            new_conn.add_setting (s_user);
        }
        try {
            s_user.set_data ("hypr-network-manager.hotspot.ap_interface", ap_interface);
            s_user.set_data ("hypr-network-manager.hotspot.uplink_interface", uplink_interface);
        } catch (Error e) {}

        return yield client.add_connection_async (new_conn, true, cancellable);
    }

    public async bool enable_hotspot_async (string ssid, string password, string security, string band, bool is_hidden, int timeout, string ap_interface, string uplink_interface, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        
        NM.DeviceWifi? dev = null;
        if (ap_interface != "" && ap_interface != "Auto") {
            var nm_dev = client.get_device_by_iface (ap_interface);
            if (nm_dev is NM.DeviceWifi) {
                dev = (NM.DeviceWifi) nm_dev;
            }
        }
        
        if (dev == null) {
            dev = get_wifi_device ();
        }
        
        if (dev == null) {
            throw new IOError.NOT_FOUND ("Wi-Fi device not found");
        }

        var conn = yield create_or_update_hotspot (ssid, password, security, band, is_hidden, timeout, ap_interface, uplink_interface, cancellable);
        
        if (has_create_ap () && dev.get_active_connection () != null) {
            // Stop any existing instance just in case
            try {
                string stdout_content;
                int exit_status;
                string[] pgrep_argv = { "pgrep", "-P", "1", "-f", "bash.*create_ap.*" + dev.get_iface () };
                if (Process.spawn_sync (null, pgrep_argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_content, null, out exit_status)) {
                    if (exit_status == 0 && stdout_content.strip () != "") {
                        string pid = stdout_content.strip().split("\n")[0];
                        string[] stop_argv = { "pkexec", "create_ap", "--stop", pid };
                        Process.spawn_sync (null, stop_argv, null, SpawnFlags.SEARCH_PATH, null, null, null, null);
                    }
                }
            } catch (Error e) {
            }
            
            int channel = 0;
            var active_ap = dev.get_active_access_point ();
            if (active_ap != null) {
                uint32 freq = active_ap.get_frequency ();
                if (freq >= 2412 && freq <= 2484) {
                    channel = (freq == 2484) ? 14 : ((int)freq - 2412) / 5 + 1;
                } else if (freq >= 5000) {
                    channel = ((int)freq - 5000) / 5;
                }
            }
            
            try {
                var argv = new GLib.GenericArray<string> ();
                argv.add ("pkexec");
                argv.add ("create_ap");
                argv.add ("--daemon");
                
                if (band == "a") {
                    argv.add ("--freq-band"); argv.add ("5");
                } else if (band == "bg") {
                    argv.add ("--freq-band"); argv.add ("2.4");
                }
                
                if (is_hidden) {
                    argv.add ("--hidden");
                }
                
                if (channel > 0) {
                    argv.add ("-c"); argv.add (channel.to_string ());
                }
                
                string final_ap_iface = (ap_interface != "" && ap_interface != "Auto") ? ap_interface : dev.get_iface ();
                string final_uplink_iface = (uplink_interface != "" && uplink_interface != "Auto") ? uplink_interface : dev.get_iface ();
                
                if (final_ap_iface.has_prefix ("-") || !is_valid_interface_name (final_ap_iface)) {
                    throw new IOError.INVALID_ARGUMENT ("Invalid AP interface name");
                }
                if (final_uplink_iface != "None" && (final_uplink_iface.has_prefix ("-") || !is_valid_interface_name (final_uplink_iface))) {
                    throw new IOError.INVALID_ARGUMENT ("Invalid uplink interface name");
                }

                if (final_uplink_iface == "None") {
                    argv.add ("-m");
                    argv.add ("none");
                    argv.add ("--");
                    argv.add (final_ap_iface);
                } else {
                    argv.add ("--");
                    argv.add (final_ap_iface); // wifi
                    argv.add (final_uplink_iface); // internet
                }
                
                argv.add (ssid);
                
                if (security != "none" && password != "") {
                    argv.add (password);
                }
                
                string[] spawn_args = new string[argv.length + 1];
                for (int i = 0; i < argv.length; i++) {
                    spawn_args[i] = argv[i];
                }
                spawn_args[argv.length] = null;
                
                is_hotspot_starting = true;
                var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.NONE);
                var proc = launcher.spawnv (spawn_args);
                yield proc.wait_async (cancellable);
                
                hotspot_idle_minutes = 0;
                is_hotspot_starting = false;
                return true;
            } catch (Error e) {
                is_hotspot_starting = false;
                throw new IOError.FAILED ("Failed to spawn create_ap: " + e.message);
            }
        } else {
            yield client.activate_connection_async (conn, dev, null, cancellable);
            return true;
        }
    }

    public async bool disable_hotspot_async (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var config = yield get_hotspot_status (cancellable);
        
        if (has_create_ap ()) {
            NM.DeviceWifi? dev = null;
            if (config.ap_interface != "" && config.ap_interface != "Auto") {
                var nm_dev = client.get_device_by_iface (config.ap_interface);
                if (nm_dev is NM.DeviceWifi) dev = (NM.DeviceWifi) nm_dev;
            }
            if (dev == null) dev = get_wifi_device ();

            if (dev != null) {
                try {
                    string[] pgrep_argv = { "pgrep", "-P", "1", "-f", "bash.*create_ap.*" + dev.get_iface () };
                    var proc = new GLib.Subprocess.newv (pgrep_argv, GLib.SubprocessFlags.STDOUT_PIPE);
                    string? stdout_content;
                    yield proc.communicate_utf8_async (null, cancellable, out stdout_content, null);

                    if (stdout_content != null && stdout_content.strip () != "") {
                        is_hotspot_stopping = true;
                        
                        string[] pids = stdout_content.strip().split("\n");
                        foreach (string pid in pids) {
                            if (pid.strip() == "") continue;
                            string[] argv = { "pkexec", "create_ap", "--stop", pid.strip() };
                            var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.NONE);
                            var stop_proc = launcher.spawnv (argv);
                            yield stop_proc.wait_async (cancellable);
                        }
                        
                        // Poll until all create_ap processes fully exit to prevent UI flashing
                        for (int i = 0; i < 20; i++) {
                            var poll_proc = new GLib.Subprocess.newv (pgrep_argv, GLib.SubprocessFlags.STDOUT_PIPE);
                            string? poll_stdout;
                            yield poll_proc.communicate_utf8_async (null, cancellable, out poll_stdout, null);

                            if (poll_stdout == null || poll_stdout.strip () == "") {
                                break;
                            }
                            yield nm_async_sleep (500);
                        }
                        is_hotspot_stopping = false;
                    }
                } catch (Error e) {
                    is_hotspot_stopping = false;
                    throw new IOError.FAILED ("Failed to stop create_ap: " + e.message);
                }
            }
        }
        
        if (config.connection_uuid == "") {
            return true;
        }
        
        var active_conns = client.get_active_connections ();
        foreach (var ac in active_conns) {
            if (ac.get_uuid () == config.connection_uuid) {
                yield client.deactivate_connection_async (ac, cancellable);
                return true;
            }
        }
        return true;
    }

    private static bool is_valid_interface_name (string name) {
        if (name == "" || name.length > 15) {
            return false;
        }
        for (int i = 0; i < name.length; i++) {
            char c = name[i];
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '.' || c == '-')) {
                return false;
            }
        }
        return true;
    }
}
