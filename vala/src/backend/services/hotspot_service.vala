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

public class HotspotService : GLib.Object {
    private NM.Client nm_client;
    private Nl80211ApMonitor monitor;
    private uint idle_check_source_id = 0;

    private int hotspot_idle_minutes = 0;
    private bool hotspot_client_query_pending = false;
    private bool is_hotspot_stopping = false;
    private bool is_hotspot_starting = false;
    private bool warned_create_ap_fallback = false;
    private bool hotspot_timeout_check_in_flight = false;

    public HotspotService (NM.Client nm_client, Nl80211ApMonitor monitor) {
        this.nm_client = nm_client;
        this.monitor = monitor;
        idle_check_source_id = GLib.Timeout.add_seconds (
            Timeouts.HOTSPOT_IDLE_CHECK_SECONDS,
            check_hotspot_timeout
        );
    }

    public void shutdown () {
        if (idle_check_source_id != 0) {
            Source.remove (idle_check_source_id);
            idle_check_source_id = 0;
        }
    }

    private void debug_log (string message) {
        log_debug ("hotspot-service", message);
    }

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
        return GLib.Environment.find_program_in_path ("hypr-create-ap");
    }

    private bool create_ap_deps_available () {
        foreach (string tool in new string[] { "hostapd", "dnsmasq", "iw", "ip", "iptables" }) {
            if (GLib.Environment.find_program_in_path (tool) == null) {
                return false;
            }
        }
        return true;
    }

    public bool has_create_ap () {
        return get_create_ap_path () != null && create_ap_deps_available ();

    }
    private void warn_create_ap_fallback_once () {
        if (warned_create_ap_fallback) return;
        warned_create_ap_fallback = true;
        var missing = new GLib.GenericArray<string> ();
        if (get_create_ap_path () == null) {
            missing.add ("hypr-create-ap");
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
        foreach (var device in nm_client.get_devices ()) {
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
        for (int attempt = 0; attempt < Timeouts.CREATE_AP_MAX_ATTEMPTS; attempt++) {
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
                ap_active = (yield monitor.query_active (
                    iface,
                    cancellable)) != 0;
            } catch (IOError.CANCELLED e) {
                throw e;
            } catch (Error e) {
                debug_log (
                    "Waiting for nl80211 AP readiness: " + e.message);
            }

            if (daemon_alive && ready && ap_active) {
                stable_polls++;
                if (stable_polls >= Timeouts.CREATE_AP_STABLE_POLLS) {
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
            yield Nl80211ApMonitor.async_sleep (Timeouts.AP_MONITOR_POLL_INTERVAL_MS);
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

    private NM.DeviceWifi? get_wifi_device () {
        return NmWifiUtils.primary_wifi_device (nm_client);
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

        foreach (var active in nm_client.get_active_connections ()) {
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
        var client = nm_client;
        var config = new HotspotConfig ();

        try {
            yield HotspotConfigStorage.load (config, cancellable);
        } catch (Error e) {
            debug_log ("Failed to load hotspot config: " + e.message);
        }

        var dev = get_wifi_device ();
        NM.DeviceWifi? target_dev = dev;
        if (config.ap_interface != ""
            && config.ap_interface != NetworkInterface.AUTO) {
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
                        && (yield monitor.query_active (
                            target_dev.get_iface (),
                            cancellable)) != 0;
                } else if (has_create_ap ()) {
                    // Compatibility with create_ap instances launched by
                    // older versions that did not create runtime markers.
                    config.is_active = (yield monitor.query_active (
                        target_dev.get_iface (),
                        cancellable)) != 0;
                }
            } catch (Error e) {
                debug_log (
                    "Unable to read create_ap interface state through nl80211: " +
                    e.message);
            }
        }

        if (config.is_active && target_dev != null) {
            try {
                config.connected_clients = yield monitor.query_station_count (
                    target_dev.get_iface (),
                    cancellable);
            } catch (Error e) {
                debug_log (
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

        yield HotspotConfigStorage.save (config, cancellable);
    }

    public async bool enable_hotspot_async (string ssid, string password, string security, string band, bool is_hidden, int timeout, string ap_interface, string uplink_interface, Cancellable? cancellable = null) throws Error {
        var client = nm_client;

        NM.DeviceWifi? dev = null;
        if (ap_interface != "" && ap_interface != NetworkInterface.AUTO) {
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

        string resolved_ap_iface = (ap_interface != ""
            && ap_interface != NetworkInterface.AUTO)
            ? ap_interface : dev.get_iface ();
        string resolved_uplink_iface = (uplink_interface != ""
            && uplink_interface != NetworkInterface.AUTO)
            ? uplink_interface : dev.get_iface ();
        if (resolved_ap_iface.has_prefix ("-")
            || !is_valid_interface_name (resolved_ap_iface)) {
            throw new IOError.INVALID_ARGUMENT (
                "Invalid AP interface name");
        }
        if (resolved_uplink_iface != NetworkInterface.NONE
            && (resolved_uplink_iface.has_prefix ("-")
                || !is_valid_interface_name (resolved_uplink_iface))) {
            throw new IOError.INVALID_ARGUMENT (
                "Invalid uplink interface name");
        }

        NM.Device? uplink_dev = null;
        if (resolved_uplink_iface != NetworkInterface.NONE
            && resolved_uplink_iface != resolved_ap_iface) {
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
            debug_log (
                ("create_ap uplink '%s' is not active; falling back to " +
                 "NetworkManager-managed sharing on '%s'.").printf (
                    resolved_uplink_iface,
                    resolved_ap_iface));
        }
        if (use_create_ap) {
            string create_ap_bin = get_create_ap_path () ?? "hypr-create-ap";
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
                        yield Nl80211ApMonitor.async_sleep (250);
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
                bool is_2_4 = (freq >= WifiFreq.BAND_2GHZ_MIN && freq <= WifiFreq.BAND_2GHZ_MAX);
                bool is_5 = (freq >= WifiFreq.BAND_5GHZ_MIN);
                if (resolved_band == "") {
                    if (is_2_4) {
                        resolved_band = WifiBand.BAND_2GHZ;
                    } else if (is_5) {
                        resolved_band = WifiBand.BAND_5GHZ;
                    }
                }
                if ((resolved_band == WifiBand.BAND_2GHZ && is_5)
                    || (resolved_band == WifiBand.BAND_5GHZ && is_2_4)) {
                    throw new IOError.INVALID_ARGUMENT (
                        ("Selected hotspot band does not match the active " +
                         "Wi-Fi channel on '%s'.").printf (
                            resolved_ap_iface));
                }
                if (resolved_band == WifiBand.BAND_2GHZ && is_2_4) {
                    channel = (int) ((freq == WifiFreq.CHANNEL_14) ? WifiChannel.CHANNEL_14 : ((int)freq - (int)WifiFreq.BAND_2GHZ_MIN) / (int)WifiFreq.CHANNEL_STEP + 1);
                } else if (resolved_band == WifiBand.BAND_5GHZ && is_5) {
                    channel = (int) (((int)freq - (int)WifiFreq.BAND_5GHZ_MIN) / (int)WifiFreq.CHANNEL_STEP);
                }
            }

            if (channel == 0) {
                if (resolved_band == WifiBand.BAND_5GHZ) {
                    channel = WifiChannel.DEFAULT_5GHZ;
                } else {
                    resolved_band = (resolved_band == WifiBand.BAND_5GHZ) ? WifiBand.BAND_5GHZ : WifiBand.BAND_2GHZ;
                    channel = WifiChannel.DEFAULT_2GHZ;
                }
            }

            string gateway = choose_create_ap_gateway ();
            try {
                write_private_file (pidfile, "");
                write_private_file (ready_file, "");
                write_private_file (log_file, "");
                if (security != WifiKeyMgmt.NONE && password != "") {
                    write_private_file (passphrase_file, password);
                } else {
                    remove_runtime_file (passphrase_file);
                }

                string final_ap_iface = resolved_ap_iface;
                string final_uplink_iface = resolved_uplink_iface;

                if (final_ap_iface.has_prefix ("-") || !is_valid_interface_name (final_ap_iface)) {
                    throw new IOError.INVALID_ARGUMENT ("Invalid AP interface name");
                }
                if (final_uplink_iface != NetworkInterface.NONE
                    && (final_uplink_iface.has_prefix ("-")
                        || !is_valid_interface_name (final_uplink_iface))) {
                    throw new IOError.INVALID_ARGUMENT ("Invalid uplink interface name");
                }

                var argv = NmHotspotUtils.build_create_ap_command (
                    create_ap_bin,
                    pidfile,
                    log_file,
                    ready_file,
                    gateway,
                    security != WifiKeyMgmt.NONE && password != ""
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

                debug_log (
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
                        debug_log (
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
            if (!has_create_ap ()) {
                warn_create_ap_fallback_once ();
            }
            debug_log ("Starting native NM hotspot creation...");
            var connections = client.get_connections ();
            foreach (var conn_check in connections) {
                if (conn_check is NM.RemoteConnection &&
                    NmHotspotUtils.is_owned_connection (conn_check, ssid)) {
                    try {
                        debug_log (
                            "Deleting previous managed hotspot connection: " +
                            conn_check.get_id ());
                        yield ((NM.RemoteConnection) conn_check).delete_async (
                            cancellable);
                    } catch (Error e) {
                        debug_log (
                            "Failed to delete previous hotspot connection: " +
                            e.message);
                    }
                }
            }

            // Wait a moment for NM to process the deletion
            yield Nl80211ApMonitor.async_sleep (Timeouts.AP_MONITOR_POLL_INTERVAL_MS);

            int channel = 0;
            var active_ap = dev.get_active_access_point ();
            if (active_ap != null) {
                uint32 freq = active_ap.get_frequency ();
                if (band == WifiBand.BAND_2GHZ && freq >= WifiFreq.BAND_2GHZ_MIN && freq <= WifiFreq.BAND_2GHZ_MAX) {
                    channel = (int) ((freq == WifiFreq.CHANNEL_14) ? WifiChannel.CHANNEL_14 : ((int)freq - (int)WifiFreq.BAND_2GHZ_MIN) / (int)WifiFreq.CHANNEL_STEP + 1);
                } else if (band == WifiBand.BAND_5GHZ && freq >= WifiFreq.BAND_5GHZ_MIN) {
                    channel = (int) (((int)freq - (int)WifiFreq.BAND_5GHZ_MIN) / (int)WifiFreq.CHANNEL_STEP);
                }
            }

            debug_log ("Creating new volatile connection for " + ssid);
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
                debug_log ("Adding connection...");
                remote_conn = yield client.add_connection_async (
                    new_conn,
                    false,
                    cancellable);
                debug_log ("Connection added successfully. Activating...");
                try {
                    yield client.activate_connection_async (remote_conn, dev, null, cancellable);
                    debug_log ("Connection activated successfully.");
                } catch (Error act_err) {
                    debug_log ("Activation reported error, polling AP state: " + act_err.message);
                    if (yield monitor.wait_until_ap_active (
                            dev.get_iface (),
                            Timeouts.AP_ACTIVATION_TIMEOUT_MS,
                            cancellable)) {
                        debug_log ("Interface reached AP mode despite activation error; treating as success.");
                    } else {
                        throw act_err;
                    }
                }
                hotspot_idle_minutes = 0;
                return true;
            } catch (Error e) {
                debug_log ("Failed to add/activate AP connection: " + e.message);
                if (remote_conn != null) {
                    try {
                        yield remote_conn.delete_async (null);
                    } catch (Error cleanup_error) {
                        debug_log (
                            "Failed to clean up inactive hotspot profile: " +
                            cleanup_error.message);
                    }
                }
                throw e;
            }
        }
    }

    public async bool disable_hotspot_async (Cancellable? cancellable = null) throws Error {
        var client = nm_client;
        var config = yield get_hotspot_status (cancellable);

        NM.DeviceWifi? dev = null;
        if (config.ap_interface != ""
            && config.ap_interface != NetworkInterface.AUTO) {
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
                        yield Nl80211ApMonitor.async_sleep (250);
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
            string create_ap_bin = get_create_ap_path () ?? "hypr-create-ap";
            if (dev != null) {
                try {
                    string[] pgrep_argv = { "pgrep", "-P", "1", "-f", "bash.*hypr-create-ap.*" + dev.get_iface () };
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
                            yield Nl80211ApMonitor.async_sleep (Timeouts.AP_MONITOR_POLL_INTERVAL_MS);
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
                    } catch (Error e) {
                        debug_log ("Failed to delete previous hotspot connection: " + e.message);
                    }
                }
            }
        }

        return true;
    }

    private bool check_hotspot_timeout () {
        if (hotspot_timeout_check_in_flight) {
            return true;
        }

        hotspot_timeout_check_in_flight = true;
        check_hotspot_timeout_async.begin ((obj, res) => {
            check_hotspot_timeout_async.end (res);
            hotspot_timeout_check_in_flight = false;
        });
        return true;
    }

    private async void check_hotspot_timeout_async () {
        var dev = get_wifi_device ();
        if (dev == null) return;

        var config = new HotspotConfig ();
        try {
            yield HotspotConfigStorage.load (config);
        } catch (Error e) {
            debug_log ("Failed to load hotspot config for timeout check: " + e.message);
        }

        int timeout_mins = config.timeout;
        string ap_interface = config.ap_interface;

        NM.DeviceWifi? target_dev = dev;
        if (ap_interface != "" && ap_interface != NetworkInterface.AUTO) {
            var nm_dev = nm_client.get_device_by_iface (ap_interface);
            if (nm_dev is NM.DeviceWifi) target_dev = (NM.DeviceWifi) nm_dev;
        }

        if (has_create_ap ()) {
            bool is_running = false;
            try {
                if (target_dev != null) {
                    string[] argv = { "pgrep", "-P", "1", "-f", "bash.*hypr-create-ap.*" + target_dev.get_iface () };
                    int exit_status;
                    string stdout_content;
                    if (Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_content, null, out exit_status)) {
                        if (exit_status == 0 && stdout_content.strip () != "") {
                            is_running = true;
                        }
                    }
                }
            } catch (Error e) {
                debug_log ("Failed to check create_ap process: " + e.message);
            }

            if (!is_running) {
                // Not running via create_ap, fallback to checking NM below
            } else {
                if (timeout_mins <= 0) {
                    hotspot_idle_minutes = 0;
                    return;
                }

                if (target_dev != null) {
                    yield check_hotspot_client_timeout (
                        target_dev.get_iface (),
                        timeout_mins,
                        true);
                }
                return;
            }
        }

        if (target_dev == null) return;
        var active_conn = target_dev.get_active_connection ();
        if (active_conn == null) {
            hotspot_idle_minutes = 0;
            return;
        }

        var conn = active_conn.get_connection ();
        if (conn == null) {
            hotspot_idle_minutes = 0;
            return;
        }

        var s_wifi = conn.get_setting_wireless ();
        if (s_wifi == null || s_wifi.mode != WifiMode.AP) {
            hotspot_idle_minutes = 0;
            return;
        }

        if (timeout_mins <= 0) {
            hotspot_idle_minutes = 0;
            return;
        }

        yield check_hotspot_client_timeout (
            target_dev.get_iface (),
            timeout_mins,
            false);
    }

    private async void check_hotspot_client_timeout (
        string iface,
        int timeout_mins,
        bool create_ap_mode
    ) {
        if (hotspot_client_query_pending) {
            return;
        }

        hotspot_client_query_pending = true;
        int station_count;
        try {
            station_count = yield monitor.query_station_count (iface, null);
        } catch (Error e) {
            debug_log (
                "Skipping hotspot idle update because station query failed: " +
                e.message);
            hotspot_client_query_pending = false;
            return;
        }
        hotspot_client_query_pending = false;

        if (station_count > 0) {
            hotspot_idle_minutes = 0;
            return;
        }

        hotspot_idle_minutes++;
        if (!HotspotTimeoutPolicy.threshold_reached (
                hotspot_idle_minutes,
                timeout_mins)) {
            return;
        }

        debug_log (
            create_ap_mode
                ? "Hotspot idle timeout reached, disconnecting via create_ap."
                : "Hotspot idle timeout reached, disconnecting.");
        try {
            yield disable_hotspot_async (null);
            hotspot_idle_minutes = HotspotTimeoutPolicy.idle_minutes_after_shutdown (
                true,
                timeout_mins
            );
        } catch (Error e) {
            // Keep the counter at the threshold so the next periodic check
            // retries instead of silently treating a failed shutdown as done.
            hotspot_idle_minutes = HotspotTimeoutPolicy.idle_minutes_after_shutdown (
                false,
                timeout_mins
            );
            debug_log ("Hotspot idle-timeout shutdown failed: " + e.message);
            log_warn (
                "hotspot-service",
                "Hotspot idle-timeout shutdown failed; outcome=retrying on next check"
            );
        }
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
