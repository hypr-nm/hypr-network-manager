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
using Constants;
using HyprNetworkManager.Models;

public class NmWifiClient : GLib.Object {
    private enum Nl80211ApQuery {
        ACTIVE,
        STATION_COUNT
    }

    private NetworkManagerClient core;
    private int hotspot_idle_minutes = 0;
    private bool hotspot_client_query_pending = false;
    private bool is_hotspot_stopping = false;

    private bool is_hotspot_starting = false;

    private string? get_create_ap_path () {
        string vendored = Constants.CREATE_AP_PATH;
        if (vendored != "" && FileUtils.test (vendored, FileTest.EXISTS | FileTest.IS_EXECUTABLE)) {
            return vendored;
        }
        string dev = Constants.CREATE_AP_DEV_PATH;
        if (dev != "" && dev != vendored
            && FileUtils.test (dev, FileTest.EXISTS | FileTest.IS_EXECUTABLE)) {
            return dev;
        }
        return GLib.Environment.find_program_in_path ("create_ap");
    }

    private bool create_ap_deps_available () {
        foreach (string tool in new string[] { "hostapd", "dnsmasq", "iw", "ip" }) {
            if (GLib.Environment.find_program_in_path (tool) == null) {
                return false;
            }
        }
        if (GLib.Environment.find_program_in_path ("iptables") == null) {
            return false;
        }
        return true;
    }

    private bool can_use_create_ap () {
        return get_create_ap_path () != null && create_ap_deps_available ();
    }

    private bool warned_create_ap_fallback = false;
    private void warn_create_ap_fallback_once () {
        if (warned_create_ap_fallback) return;
        warned_create_ap_fallback = true;
        var missing = new GLib.GenericArray<string> ();
        if (get_create_ap_path () == null) {
            missing.add ("create_ap");
        }
        foreach (string tool in new string[] { "hostapd", "dnsmasq", "iw", "ip", "iptables" }) {
            if (GLib.Environment.find_program_in_path (tool) == null) {
                missing.add (tool);
            }
        }
        string list = string.joinv (", ", (string[]) missing.data);
        warning (
            "create_ap runtime dependencies missing (%s); falling back to the native NetworkManager hotspot, which shares the system default route instead of a selected uplink.",
            list);
    }

    private bool has_create_ap () {
        return can_use_create_ap ();
    }

    private async void nm_async_sleep (uint ms) {
        Timeout.add (ms, () => {
            nm_async_sleep.callback ();
            return false;
        });
        yield;
    }

    private string create_ap_runtime_dir () throws Error {
        string base_dir = Environment.get_user_runtime_dir ();
        if (base_dir == "") {
            throw new IOError.FAILED (
                "A private user runtime directory is not available");
        }

        string directory = Path.build_filename (
            base_dir,
            "hypr-network-manager");
        if (DirUtils.create_with_parents (directory, 0700) != 0
            && !FileUtils.test (directory, FileTest.IS_DIR)) {
            throw new IOError.FAILED (
                "Unable to create the hotspot runtime directory");
        }
        if (FileUtils.chmod (directory, 0700) != 0) {
            throw new IOError.FAILED (
                "Unable to secure the hotspot runtime directory");
        }
        return directory;
    }

    private string create_ap_state_dir () throws Error {
        string directory = Path.build_filename (
            Environment.get_user_state_dir (),
            "hypr-network-manager");
        if (DirUtils.create_with_parents (directory, 0700) != 0
            && !FileUtils.test (directory, FileTest.IS_DIR)) {
            throw new IOError.FAILED (
                "Unable to create the hotspot state directory");
        }
        if (FileUtils.chmod (directory, 0700) != 0) {
            throw new IOError.FAILED (
                "Unable to secure the hotspot state directory");
        }
        return directory;
    }

    private void write_private_file (
        string path,
        string contents
    ) throws Error {
        FileUtils.set_contents_full (
            path,
            contents,
            -1,
            FileSetContentsFlags.CONSISTENT,
            0600);
        if (FileUtils.chmod (path, 0600) != 0) {
            throw new IOError.FAILED (
                "Unable to secure hotspot runtime file");
        }
    }

    private string create_ap_runtime_path (
        string iface,
        string suffix
    ) throws Error {
        return Path.build_filename (
            create_ap_runtime_dir (),
            "create-ap-%s.%s".printf (iface, suffix));
    }

    private string create_ap_log_path (string iface) throws Error {
        return Path.build_filename (
            create_ap_state_dir (),
            "create-ap-%s.log".printf (iface));
    }

    private GLib.GenericArray<string> occupied_ipv4_networks () {
        var occupied = new GLib.GenericArray<string> ();
        foreach (var device in core.nm_client.get_devices ()) {
            var ip4_config = device.get_ip4_config ();
            if (ip4_config == null) {
                continue;
            }

            var addresses = ip4_config.get_addresses ();
            for (uint i = 0; i < addresses.length; i++) {
                unowned NM.IPAddress address = addresses[i];
                if (address.get_family () == GLib.SocketFamily.IPV4) {
                    occupied.add ("%s/%u".printf (
                        address.get_address (),
                        address.get_prefix ()));
                }
            }
            var routes = ip4_config.get_routes ();
            for (uint i = 0; i < routes.length; i++) {
                unowned NM.IPRoute route = routes[i];
                if (route.get_family () == GLib.SocketFamily.IPV4
                    && route.get_prefix () > 0) {
                    occupied.add ("%s/%u".printf (
                        route.get_dest (),
                        route.get_prefix ()));
                }
            }
        }
        return occupied;
    }

    private string choose_create_ap_gateway () throws Error {
        string gateway = NmHotspotUtils.choose_create_ap_gateway (
            occupied_ipv4_networks ());
        if (gateway == "") {
            throw new IOError.FAILED (
                "No unused private IPv4 subnet is available for the hotspot");
        }
        return gateway;
    }

    private bool read_live_create_ap_pid (
        string pidfile,
        out string pid
    ) {
        pid = "";
        string contents;
        try {
            FileUtils.get_contents (pidfile, out contents);
        } catch (Error e) {
            return false;
        }

        string candidate = contents.strip ();
        if (candidate == "") {
            return false;
        }
        for (int i = 0; i < candidate.length; i++) {
            if (candidate[i] < '0' || candidate[i] > '9') {
                return false;
            }
        }
        if (!FileUtils.test (
                Path.build_filename ("/proc", candidate),
                FileTest.IS_DIR)) {
            return false;
        }

        pid = candidate;
        return true;
    }

    private bool create_ap_ready_file_is_set (string ready_file) {
        string contents;
        try {
            FileUtils.get_contents (ready_file, out contents);
        } catch (Error e) {
            return false;
        }
        return contents.strip () == "ready";
    }

    private string create_ap_log_summary (string log_file) {
        string contents;
        try {
            FileUtils.get_contents (log_file, out contents);
        } catch (Error e) {
            return "";
        }

        string[] lines = contents.split ("\n");
        var selected = new GLib.GenericArray<string> ();
        int first = int.max (0, lines.length - 8);
        for (int i = first; i < lines.length; i++) {
            string line = lines[i].strip ();
            if (line != "") {
                selected.add (line);
            }
        }
        if (selected.length == 0) {
            return "";
        }
        return string.joinv (" | ", (string[]) selected.data);
    }

    private bool create_ap_log_reports_failure (string log_file) {
        string contents;
        try {
            FileUtils.get_contents (log_file, out contents);
        } catch (Error e) {
            return false;
        }
        string upper = contents.up ();
        return upper.contains ("ERROR:")
            || upper.contains ("FAILED TO")
            || upper.contains ("FAILED TO START")
            || upper.contains ("DOING CLEANUP");
    }

    private async void wait_for_create_ap_ready (
        string iface,
        string pidfile,
        string ready_file,
        string log_file,
        Cancellable? cancellable
    ) throws Error {
        int stable_polls = 0;
        for (int attempt = 0; attempt < 30; attempt++) {
            if (cancellable != null && cancellable.is_cancelled ()) {
                throw new IOError.CANCELLED (
                    "Hotspot startup was cancelled");
            }

            string pid;
            bool daemon_alive = read_live_create_ap_pid (
                pidfile,
                out pid);
            bool ready = create_ap_ready_file_is_set (ready_file);
            bool ap_active = false;
            try {
                ap_active = (yield query_nl80211_ap (
                    iface,
                    Nl80211ApQuery.ACTIVE,
                    cancellable)) != 0;
            } catch (IOError.CANCELLED e) {
                throw e;
            } catch (Error e) {
                core.debug_log (
                    "Waiting for nl80211 AP readiness: " + e.message);
            }

            if (daemon_alive && ready && ap_active) {
                stable_polls++;
                if (stable_polls >= 4) {
                    return;
                }
            } else {
                stable_polls = 0;
            }

            if (attempt >= 3
                && !daemon_alive
                && create_ap_log_reports_failure (log_file)) {
                break;
            }
            yield nm_async_sleep (500);
        }

        string detail = create_ap_log_summary (log_file);
        if (detail != "") {
            throw new IOError.FAILED (
                "create_ap services failed readiness checks: " + detail);
        }
        throw new IOError.FAILED (
            "create_ap services did not remain ready");
    }

    private async void stop_create_ap_pid (
        string create_ap_bin,
        string pid,
        Cancellable? cancellable
    ) throws Error {
        string[] argv = {
            "pkexec",
            create_ap_bin,
            "--stop",
            pid
        };
        var stop_proc = new GLib.Subprocess.newv (
            argv,
            GLib.SubprocessFlags.NONE);
        yield stop_proc.wait_check_async (cancellable);
    }

    private void remove_runtime_file (string path) {
        if (path != "") {
            FileUtils.remove (path);
        }
    }

    private async int query_nl80211_ap (
        string iface,
        Nl80211ApQuery query,
        Cancellable? cancellable = null
    ) throws Error {
        if (iface == "") {
            throw new IOError.INVALID_ARGUMENT ("Wi-Fi interface is empty");
        }

        int result = -1;
        int value = 0;
        SourceFunc resume = query_nl80211_ap.callback;
        MainContext caller_context = MainContext.ref_thread_default ();

        new Thread<void*> ("nl80211-ap-query", () => {
            if (query == Nl80211ApQuery.ACTIVE) {
                result = Nl80211.ap_active_by_iface (iface, out value);
            } else {
                result = Nl80211.ap_station_count_by_iface (iface, out value);
            }
            caller_context.invoke ((owned) resume);
            return null;
        });

        yield;

        if (cancellable != null && cancellable.is_cancelled ()) {
            throw new IOError.CANCELLED ("nl80211 AP query was cancelled");
        }
        if (result != 0) {
            throw new IOError.FAILED (
                "nl80211 AP query failed for interface '%s'".printf (iface));
        }
        return value;
    }

    private async bool interface_is_ap_mode (
        string iface,
        uint timeout_ms = 10000,
        Cancellable? cancellable = null
    ) throws Error {
        if (iface == "") {
            return false;
        }

        uint elapsed = 0;
        const uint step = 500;
        while (elapsed < timeout_ms) {
            try {
                if ((yield query_nl80211_ap (
                        iface,
                        Nl80211ApQuery.ACTIVE,
                        cancellable)) != 0) {
                    return true;
                }
            } catch (IOError.CANCELLED e) {
                throw e;
            } catch (Error e) {
                core.debug_log ("AP-state query failed: " + e.message);
            }

            yield nm_async_sleep (step);
            elapsed += step;
        }
        return false;
    }

    public NmWifiClient (NetworkManagerClient core) {
        this.core = core;
        GLib.Timeout.add_seconds (60, check_hotspot_timeout);
    }

    private bool check_hotspot_timeout () {
        var dev = get_wifi_device ();
        if (dev == null) return true;

        var config = new HotspotConfig ();
        HotspotConfigStorage.load (config);
        
        int timeout_mins = config.timeout;
        string ap_interface = config.ap_interface;

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
                
                if (target_dev != null) {
                    begin_hotspot_client_timeout_check (
                        target_dev.get_iface (),
                        timeout_mins,
                        true);
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

        begin_hotspot_client_timeout_check (
            target_dev.get_iface (),
            timeout_mins,
            false);

        return true;
    }

    private void begin_hotspot_client_timeout_check (
        string iface,
        int timeout_mins,
        bool create_ap_mode
    ) {
        if (hotspot_client_query_pending) {
            return;
        }

        hotspot_client_query_pending = true;
        query_nl80211_ap.begin (
            iface,
            Nl80211ApQuery.STATION_COUNT,
            null,
            (obj, res) => {
                int station_count;

                try {
                    station_count = query_nl80211_ap.end (res);
                } catch (Error e) {
                    hotspot_client_query_pending = false;
                    core.debug_log (
                        "Skipping hotspot idle update because station query failed: " +
                        e.message);
                    return;
                }

                hotspot_client_query_pending = false;
                if (station_count > 0) {
                    hotspot_idle_minutes = 0;
                    return;
                }

                hotspot_idle_minutes++;
                if (hotspot_idle_minutes >= timeout_mins) {
                    core.debug_log (
                        create_ap_mode
                            ? "Hotspot idle timeout reached, disconnecting via create_ap."
                            : "Hotspot idle timeout reached, disconnecting.");
                    disable_hotspot_async.begin (null);
                    hotspot_idle_minutes = 0;
                }
            });
    }

    public async WifiRefreshData get_refresh_data (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var devices = client.get_devices ();
        var connections = client.get_connections ();

        var hotspot_config = yield get_hotspot_status (cancellable);

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
                    foreach (var candidate in valid_conns) {
                        var conn = (NM.Connection) candidate;
                        try {
                            if (!wifidev.connection_compatible (conn)) {
                                continue;
                            }
                        } catch (GLib.Error compat_err) {
                            continue;
                        }
                        saved = true;
                        saved_uuid = conn.get_uuid ();
                        var s_conn = conn.get_setting_connection ();
                        if (s_conn != null) {
                            autoconnect = s_conn.autoconnect;
                        }
                        break;
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

        int num_wifi_devices = 0;
        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi) {
                num_wifi_devices++;
            }
        }
        
        return new WifiRefreshData (networks_arr, devices_arr, hotspot_config.is_active, num_wifi_devices);
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
        Cancellable? cancellable = null,
        out string? read_failure
    ) {
        read_failure = null;
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
            string? last_error = null;
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
                last_error = e.message;
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
                last_error = e.message;
                log_debug ("nm-wifi-client", "get_wifi_password: unable to read wireless secrets: " + e.message);
            }

            read_failure = last_error;
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

    private NM.ActiveConnection? find_active_nm_hotspot (
        NM.DeviceWifi? preferred_dev,
        string configured_ssid,
        out NM.DeviceWifi? hotspot_dev
    ) {
        hotspot_dev = null;

        if (preferred_dev != null) {
            var preferred_active = preferred_dev.get_active_connection ();
            if (preferred_active != null &&
                (preferred_active.get_state () ==
                    NM.ActiveConnectionState.ACTIVATED ||
                 preferred_active.get_state () ==
                    NM.ActiveConnectionState.ACTIVATING)) {
                var preferred_conn = preferred_active.get_connection ();
                if (preferred_conn != null &&
                    NmHotspotUtils.is_owned_connection (
                        preferred_conn,
                        configured_ssid)) {
                    hotspot_dev = preferred_dev;
                    return preferred_active;
                }
            }
        }

        foreach (var active in core.nm_client.get_active_connections ()) {
            if (active.get_state () != NM.ActiveConnectionState.ACTIVATED &&
                active.get_state () != NM.ActiveConnectionState.ACTIVATING) {
                continue;
            }

            var conn = active.get_connection ();
            if (conn == null ||
                !NmHotspotUtils.is_owned_connection (
                    conn,
                    configured_ssid)) {
                continue;
            }

            foreach (var active_dev in active.get_devices ()) {
                if (active_dev is NM.DeviceWifi) {
                    hotspot_dev = (NM.DeviceWifi) active_dev;
                    return active;
                }
            }
        }
        return null;
    }

    public async HotspotConfig get_hotspot_status (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var config = new HotspotConfig ();
        
        HotspotConfigStorage.load (config);
        
        var dev = get_wifi_device ();
        NM.DeviceWifi? target_dev = dev;
        if (config.ap_interface != "" && config.ap_interface != "Auto") {
            var configured_dev = client.get_device_by_iface (config.ap_interface);
            if (configured_dev is NM.DeviceWifi) {
                target_dev = (NM.DeviceWifi) configured_dev;
            }
        }

        if (target_dev != null) {
            var cap = target_dev.get_capabilities ();
            config.supports_2ghz = (cap & NM.DeviceWifiCapabilities.FREQ_2GHZ) != 0;
            config.supports_5ghz = (cap & NM.DeviceWifiCapabilities.FREQ_5GHZ) != 0;
        } else {
            config.supports_2ghz = true;
            config.supports_5ghz = true;
        }
        
        config.is_active = false;
        config.is_starting = false;
        
        if (is_hotspot_stopping) {
            return config;
        }

        if (is_hotspot_starting) {
            config.is_active = false;
            config.is_starting = true;
            return config;
        }

        NM.DeviceWifi? nm_hotspot_dev;
        var nm_hotspot = find_active_nm_hotspot (
            target_dev,
            config.ssid,
            out nm_hotspot_dev);
        if (nm_hotspot != null) {
            config.is_active = true;
            config.connection_uuid = nm_hotspot.get_uuid ();
            if (nm_hotspot_dev != null) {
                target_dev = nm_hotspot_dev;
            }
        } else if (target_dev != null) {
            try {
                string pidfile = create_ap_runtime_path (
                    target_dev.get_iface (),
                    "pid");
                string ready_file = create_ap_runtime_path (
                    target_dev.get_iface (),
                    "ready");
                bool tracked_runtime =
                    FileUtils.test (pidfile, FileTest.EXISTS)
                    || FileUtils.test (ready_file, FileTest.EXISTS);
                if (tracked_runtime) {
                    string daemon_pid;
                    config.is_active =
                        read_live_create_ap_pid (
                            pidfile,
                            out daemon_pid)
                        && create_ap_ready_file_is_set (ready_file)
                        && (yield query_nl80211_ap (
                            target_dev.get_iface (),
                            Nl80211ApQuery.ACTIVE,
                            cancellable)) != 0;
                } else if (has_create_ap ()) {
                    // Compatibility with create_ap instances launched by
                    // older versions that did not create runtime markers.
                    config.is_active = (yield query_nl80211_ap (
                        target_dev.get_iface (),
                        Nl80211ApQuery.ACTIVE,
                        cancellable)) != 0;
                }
            } catch (Error e) {
                core.debug_log (
                    "Unable to read create_ap interface state through nl80211: " +
                    e.message);
            }
        }
        
        if (config.is_active && target_dev != null) {
            try {
                config.connected_clients = yield query_nl80211_ap (
                    target_dev.get_iface (),
                    Nl80211ApQuery.STATION_COUNT,
                    cancellable);
            } catch (Error e) {
                core.debug_log (
                    "Unable to count hotspot clients through nl80211: " +
                    e.message);
            }
        }

        return config;
    }

    public async void create_or_update_hotspot (string ssid, string password, string security, string band, bool is_hidden, int timeout, string ap_interface, string uplink_interface, Cancellable? cancellable = null) throws Error {
        var config = new HotspotConfig ();
        config.ssid = ssid;
        config.password = password;
        config.security = security;
        config.band = band;
        config.is_hidden = is_hidden;
        config.timeout = timeout;
        config.ap_interface = ap_interface;
        config.uplink_interface = uplink_interface;
        
        HotspotConfigStorage.save (config);
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

        yield create_or_update_hotspot (ssid, password, security, band, is_hidden, timeout, ap_interface, uplink_interface, cancellable);
        
        string resolved_ap_iface = (ap_interface != "" && ap_interface != "Auto")
            ? ap_interface : dev.get_iface ();
        string resolved_uplink_iface = (uplink_interface != "" && uplink_interface != "Auto")
            ? uplink_interface : dev.get_iface ();
        if (resolved_ap_iface.has_prefix ("-")
            || !is_valid_interface_name (resolved_ap_iface)) {
            throw new IOError.INVALID_ARGUMENT (
                "Invalid AP interface name");
        }
        if (resolved_uplink_iface != "None"
            && (resolved_uplink_iface.has_prefix ("-")
                || !is_valid_interface_name (resolved_uplink_iface))) {
            throw new IOError.INVALID_ARGUMENT (
                "Invalid uplink interface name");
        }

        NM.Device? uplink_dev = null;
        if (resolved_uplink_iface != "None" && resolved_uplink_iface != resolved_ap_iface) {
            var nm_uplink = client.get_device_by_iface (resolved_uplink_iface);
            if (nm_uplink != null) {
                uplink_dev = nm_uplink;
            }
        }
        bool uplink_has_connection = (uplink_dev != null)
            ? (uplink_dev.get_active_connection () != null)
            : (dev.get_active_connection () != null);
        bool use_create_ap = NmHotspotUtils.should_use_create_ap (
            has_create_ap (),
            resolved_uplink_iface,
            uplink_has_connection);
        if (has_create_ap () && !use_create_ap) {
            core.debug_log (
                ("create_ap uplink '%s' is not active; falling back to " +
                 "NetworkManager-managed sharing on '%s'.").printf (
                    resolved_uplink_iface,
                    resolved_ap_iface));
        }
        if (use_create_ap) {
            string create_ap_bin = get_create_ap_path () ?? "create_ap";
            string pidfile = create_ap_runtime_path (
                resolved_ap_iface,
                "pid");
            string ready_file = create_ap_runtime_path (
                resolved_ap_iface,
                "ready");
            string passphrase_file = create_ap_runtime_path (
                resolved_ap_iface,
                "passphrase");
            string log_file = create_ap_log_path (resolved_ap_iface);

            // Stop a previous app-owned instance on this radio before
            // preparing its deterministic runtime files.
            try {
                string previous_pid;
                if (read_live_create_ap_pid (
                        pidfile,
                        out previous_pid)) {
                    yield stop_create_ap_pid (
                        create_ap_bin,
                        previous_pid,
                        cancellable);
                    for (int i = 0; i < 20; i++) {
                        string ignored_pid;
                        if (!read_live_create_ap_pid (
                                pidfile,
                                out ignored_pid)) {
                            break;
                        }
                        yield nm_async_sleep (250);
                    }
                }
            } catch (Error e) {
                throw new IOError.FAILED (
                    "Failed to stop the previous managed hotspot: " +
                    e.message);
            }
            
            string resolved_band = band;
            var active_ap = dev.get_active_access_point ();

            int channel = 0;
            if (active_ap != null) {
                uint32 freq = active_ap.get_frequency ();
                bool is_2_4 = (freq >= 2412 && freq <= 2484);
                bool is_5 = (freq >= 5000);
                if (resolved_band == "") {
                    if (is_2_4) {
                        resolved_band = "bg";
                    } else if (is_5) {
                        resolved_band = "a";
                    }
                }
                if ((resolved_band == "bg" && is_5)
                    || (resolved_band == "a" && is_2_4)) {
                    throw new IOError.INVALID_ARGUMENT (
                        ("Selected hotspot band does not match the active " +
                         "Wi-Fi channel on '%s'.").printf (
                            resolved_ap_iface));
                }
                if (resolved_band == "bg" && is_2_4) {
                    channel = (freq == 2484) ? 14 : ((int)freq - 2412) / 5 + 1;
                } else if (resolved_band == "a" && is_5) {
                    channel = ((int)freq - 5000) / 5;
                }
            }

            if (channel == 0) {
                if (resolved_band == "a") {
                    channel = 36;
                } else {
                    resolved_band = (resolved_band == "a") ? "a" : "bg";
                    channel = 6;
                }
            }

            string gateway = choose_create_ap_gateway ();
            try {
                write_private_file (pidfile, "");
                write_private_file (ready_file, "");
                write_private_file (log_file, "");
                if (security != "none" && password != "") {
                    write_private_file (passphrase_file, password);
                } else {
                    remove_runtime_file (passphrase_file);
                }

                string final_ap_iface = resolved_ap_iface;
                string final_uplink_iface = resolved_uplink_iface;
                
                if (final_ap_iface.has_prefix ("-") || !is_valid_interface_name (final_ap_iface)) {
                    throw new IOError.INVALID_ARGUMENT ("Invalid AP interface name");
                }
                if (final_uplink_iface != "None" && (final_uplink_iface.has_prefix ("-") || !is_valid_interface_name (final_uplink_iface))) {
                    throw new IOError.INVALID_ARGUMENT ("Invalid uplink interface name");
                }

                var argv = NmHotspotUtils.build_create_ap_command (
                    create_ap_bin,
                    pidfile,
                    log_file,
                    ready_file,
                    gateway,
                    security != "none" && password != ""
                        ? passphrase_file
                        : "",
                    security,
                    resolved_band,
                    is_hidden,
                    channel,
                    final_ap_iface,
                    final_uplink_iface,
                    ssid);

                string[] spawn_args = new string[argv.length + 1];
                for (int i = 0; i < argv.length; i++) {
                    spawn_args[i] = argv[i];
                }
                spawn_args[argv.length] = null;
                
                is_hotspot_starting = true;
                var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.NONE);
                var proc = launcher.spawnv (spawn_args);
                yield proc.wait_check_async (cancellable);

                core.debug_log (
                    ("Waiting for create_ap on '%s' channel %d with " +
                     "gateway %s.").printf (
                        final_ap_iface,
                        channel,
                        gateway));
                yield wait_for_create_ap_ready (
                    final_ap_iface,
                    pidfile,
                    ready_file,
                    log_file,
                    cancellable);
                
                hotspot_idle_minutes = 0;
                is_hotspot_starting = false;
                return true;
            } catch (Error e) {
                string failed_pid;
                if (read_live_create_ap_pid (
                        pidfile,
                        out failed_pid)) {
                    try {
                        yield stop_create_ap_pid (
                            create_ap_bin,
                            failed_pid,
                            null);
                    } catch (Error cleanup_error) {
                        core.debug_log (
                            "Failed to stop the unsuccessful create_ap daemon: " +
                            cleanup_error.message);
                    }
                }
                remove_runtime_file (passphrase_file);
                remove_runtime_file (ready_file);
                remove_runtime_file (pidfile);
                is_hotspot_starting = false;
                throw new IOError.FAILED (
                    "Failed to start create_ap: " + e.message);
            }
        } else {
            // Native NM Hotspot (Volatile)
            if ((dev.get_capabilities () & NM.DeviceWifiCapabilities.AP) == 0) {
                throw new IOError.NOT_SUPPORTED (
                    "Selected Wi-Fi device does not support NetworkManager AP mode");
            }
            if (!can_use_create_ap ()) {
                warn_create_ap_fallback_once ();
            }
            core.debug_log ("Starting native NM hotspot creation...");
            var connections = client.get_connections ();
            foreach (var conn_check in connections) {
                if (conn_check is NM.RemoteConnection &&
                    NmHotspotUtils.is_owned_connection (conn_check, ssid)) {
                    try {
                        core.debug_log (
                            "Deleting previous managed hotspot connection: " +
                            conn_check.get_id ());
                        yield ((NM.RemoteConnection) conn_check).delete_async (
                            cancellable);
                    } catch (Error e) {
                        core.debug_log (
                            "Failed to delete previous hotspot connection: " +
                            e.message);
                    }
                }
            }
            
            // Wait a moment for NM to process the deletion
            yield nm_async_sleep (500);
            
            int channel = 0;
            var active_ap = dev.get_active_access_point ();
            if (active_ap != null) {
                uint32 freq = active_ap.get_frequency ();
                if (band == "bg" && freq >= 2412 && freq <= 2484) {
                    channel = (freq == 2484) ? 14 : ((int)freq - 2412) / 5 + 1;
                } else if (band == "a" && freq >= 5000) {
                    channel = ((int)freq - 5000) / 5;
                }
            }
            
            core.debug_log ("Creating new volatile connection for " + ssid);
            var new_conn = NmHotspotUtils.create_connection (
                ssid,
                password,
                security,
                band,
                is_hidden,
                dev.get_iface (),
                channel);
            
            NM.RemoteConnection? remote_conn = null;
            try {
                core.debug_log ("Adding connection...");
                remote_conn = yield client.add_connection_async (
                    new_conn,
                    false,
                    cancellable);
                core.debug_log ("Connection added successfully. Activating...");
                try {
                    yield client.activate_connection_async (remote_conn, dev, null, cancellable);
                    core.debug_log ("Connection activated successfully.");
                } catch (Error act_err) {
                    core.debug_log ("Activation reported error, polling AP state: " + act_err.message);
                    if (yield interface_is_ap_mode (
                            dev.get_iface (),
                            10000,
                            cancellable)) {
                        core.debug_log ("Interface reached AP mode despite activation error; treating as success.");
                    } else {
                        throw act_err;
                    }
                }
                hotspot_idle_minutes = 0;
                return true;
            } catch (Error e) {
                core.debug_log ("Failed to add/activate AP connection: " + e.message);
                if (remote_conn != null) {
                    try {
                        yield remote_conn.delete_async (null);
                    } catch (Error cleanup_error) {
                        core.debug_log (
                            "Failed to clean up inactive hotspot profile: " +
                            cleanup_error.message);
                    }
                }
                throw e;
            }
        }
    }

    public async bool disable_hotspot_async (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var config = yield get_hotspot_status (cancellable);

        NM.DeviceWifi? dev = null;
        if (config.ap_interface != "" && config.ap_interface != "Auto") {
            var nm_dev = client.get_device_by_iface (config.ap_interface);
            if (nm_dev is NM.DeviceWifi) {
                dev = (NM.DeviceWifi) nm_dev;
            }
        }
        if (dev == null) {
            dev = get_wifi_device ();
        }

        NM.DeviceWifi? nm_hotspot_dev;
        var nm_hotspot = find_active_nm_hotspot (
            dev,
            config.ssid,
            out nm_hotspot_dev);
        if (nm_hotspot_dev != null) {
            dev = nm_hotspot_dev;
        }
        if (nm_hotspot != null) {
            is_hotspot_stopping = true;
            try {
                var remote_conn = nm_hotspot.get_connection ();
                yield client.deactivate_connection_async (
                    nm_hotspot,
                    cancellable);
                if (remote_conn != null &&
                    NmHotspotUtils.is_owned_connection (
                        remote_conn,
                        config.ssid)) {
                    yield remote_conn.delete_async (cancellable);
                }
                is_hotspot_stopping = false;
                hotspot_idle_minutes = 0;
                return true;
            } catch (Error e) {
                is_hotspot_stopping = false;
                throw new IOError.FAILED (
                    "Failed to stop NetworkManager hotspot: " + e.message);
            }
        }

        string? available_create_ap = get_create_ap_path ();
        if (available_create_ap != null && dev != null) {
            string pidfile = create_ap_runtime_path (
                dev.get_iface (),
                "pid");
            string ready_file = create_ap_runtime_path (
                dev.get_iface (),
                "ready");
            string passphrase_file = create_ap_runtime_path (
                dev.get_iface (),
                "passphrase");
            string managed_pid;
            if (read_live_create_ap_pid (
                    pidfile,
                    out managed_pid)) {
                is_hotspot_stopping = true;
                try {
                    yield stop_create_ap_pid (
                        available_create_ap,
                        managed_pid,
                        cancellable);
                    for (int i = 0; i < 20; i++) {
                        string ignored_pid;
                        if (!read_live_create_ap_pid (
                                pidfile,
                                out ignored_pid)) {
                            break;
                        }
                        yield nm_async_sleep (250);
                    }
                    remove_runtime_file (passphrase_file);
                    remove_runtime_file (ready_file);
                    remove_runtime_file (pidfile);
                    is_hotspot_stopping = false;
                    hotspot_idle_minutes = 0;
                    return true;
                } catch (Error e) {
                    is_hotspot_stopping = false;
                    throw new IOError.FAILED (
                        "Failed to stop managed create_ap hotspot: " +
                        e.message);
                }
            }
        }

        if (has_create_ap ()) {
            string create_ap_bin = get_create_ap_path () ?? "create_ap";
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
                            string[] argv = { "pkexec", create_ap_bin, "--stop", pid.strip() };
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
        } else {
            warn_create_ap_fallback_once ();
            if (config.connection_uuid != "") {
                var conn = client.get_connection_by_uuid (config.connection_uuid);
                if (conn != null &&
                    conn is NM.RemoteConnection &&
                    NmHotspotUtils.is_owned_connection (conn, config.ssid)) {
                    try {
                        yield ((NM.RemoteConnection) conn).delete_async (
                            cancellable);
                    } catch (Error e) {}
                }
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
