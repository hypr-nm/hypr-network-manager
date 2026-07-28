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
using NM;

public class WifiRefreshData : GLib.Object {
    public WifiNetwork[] networks;
    public NetworkDevice[] devices;
    public bool is_hotspot_active;
    public int num_wifi_devices;

    public WifiRefreshData (WifiNetwork[] networks_in, NetworkDevice[] devices_in, bool is_hotspot_active = false, int num_wifi_devices = 0) {
        networks = networks_in;
        devices = devices_in;
        this.is_hotspot_active = is_hotspot_active;
        this.num_wifi_devices = num_wifi_devices;
    }
}

public class WifiScanData : GLib.Object {
    public WifiNetwork[] networks;
    public NetworkDevice[] devices;
    public int num_wifi_devices;

    public WifiScanData (WifiNetwork[] networks_in, NetworkDevice[] devices_in, int num_wifi_devices = 0) {
        networks = networks_in;
        devices = devices_in;
        this.num_wifi_devices = num_wifi_devices;
    }
}

public class WifiBandSupport : GLib.Object {
    public bool supports_2ghz;
    public bool supports_5ghz;

    public WifiBandSupport (bool supports_2ghz, bool supports_5ghz) {
        this.supports_2ghz = supports_2ghz;
        this.supports_5ghz = supports_5ghz;
    }
}

private class NmSignalSubscription {
    public GLib.Object instance;
    public ulong handler_id;

    public NmSignalSubscription (GLib.Object instance, ulong handler_id) {
        this.instance = instance;
        this.handler_id = handler_id;
    }
}

public class NetworkManagerClient : GLib.Object {
    public NM.Client nm_client;

    private WifiScannerService wifi_scanner;
    private SavedProfileService saved_profiles;
    private SecretsService secrets;
    private HotspotService hotspot;
    private Nl80211ApMonitor ap_monitor;
    private NmEthernetClient ethernet_client;
    private NmVpnClient vpn_client;
    private bool nm_signals_active = false;
    private GLib.List<NmSignalSubscription> nm_signal_subscriptions;

    public signal void network_events_changed ();

    public static string normalize_ipv4_method (string value) {
        if (value == "auto" || value == "manual" || value == "link-local" || value == "shared" || value == "disabled") {
            return value;
        }
        return "auto";
    }

    public static string normalize_ipv6_method (string value) {
        if (value == "auto" || value == "manual" || value == "ignore" || value == "shared" || value == "disabled" ||
            value == "link-local") {
            return value;
        }
        return "auto";
    }

    public NetworkManagerClient () throws Error {
        try {
            nm_client = new NM.Client (null);
        } catch (Error e) {
            log_error ("nm-client", "Failed to initialize NM.Client: " + e.message);
            throw e;
        }
        ap_monitor = new Nl80211ApMonitor (this);
        secrets = new SecretsService (this);
        hotspot = new HotspotService (this, ap_monitor);
        wifi_scanner = new WifiScannerService (this);
        saved_profiles = new SavedProfileService (this, secrets);
        ethernet_client = new NmEthernetClient (this);
        vpn_client = new NmVpnClient (this);
    }

    internal void debug_log (string message) {
        log_debug ("nm-client", message);
    }

    private void emit_nm_change_event (string reason) {
        debug_log ("nm_signal_event: received reason=" + reason);
        network_events_changed ();
    }

    private NM.Connection? find_saved_ethernet_profile_for_iface (string iface_name) {
        NM.Connection? generic_candidate = null;

        foreach (var conn in nm_client.get_connections ()) {
            if (conn.get_setting_wired () == null) {
                continue;
            }

            var s_conn = conn.get_setting_connection ();
            if (s_conn == null) {
                continue;
            }

            string bound_iface = s_conn.interface_name != null ? s_conn.interface_name.strip () : "";
            if (bound_iface == iface_name) {
                return conn;
            }

            if (bound_iface == "") {
                if (generic_candidate == null) {
                    generic_candidate = conn;
                }
            }
        }

        return generic_candidate;
    }

    public bool has_ethernet_profile_for_device (NetworkDevice device) {
        return ethernet_client.has_profile (device);
    }

    private void track_subscription (GLib.Object instance, ulong handler_id) {
        nm_signal_subscriptions.append (new NmSignalSubscription (instance, handler_id));
    }

    public async bool subscribe_network_events_dbus (Cancellable? cancellable = null) throws Error {
        if (nm_signals_active || nm_client == null) {
            return true;
        }

        // Every handler is an anonymous closure that captures `this`, so each one
        // must be tracked and later disconnected in unsubscribe_network_events() --
        // otherwise the long-lived NM.Client keeps the closures (and thus this
        // NetworkManagerClient) alive forever, leaking it and dead-locking its
        // finalizer.
        track_subscription (nm_client, nm_client.device_added.connect ((dev) => {
            emit_nm_change_event ("DeviceAdded (" + dev.get_iface () + ")");
            track_subscription (dev, dev.state_changed.connect ((new_state, old_state, reason) => {
                emit_nm_change_event ("DeviceStateChanged (" + dev.get_iface () + ")");
            }));
            if (dev is NM.DeviceWifi) {
                var wifi_dev = (NM.DeviceWifi) dev;
                track_subscription (wifi_dev, wifi_dev.access_point_added.connect ((ap) => {
                    emit_nm_change_event ("AccessPointAdded (" + dev.get_iface () + ")");
                }));
                track_subscription (wifi_dev, wifi_dev.access_point_removed.connect ((ap) => {
                    emit_nm_change_event ("AccessPointRemoved (" + dev.get_iface () + ")");
                }));
            }
        }));

        track_subscription (nm_client, nm_client.device_removed.connect ((dev) => {
            emit_nm_change_event ("DeviceRemoved (" + dev.get_iface () + ")");
        }));

        track_subscription (nm_client, nm_client.any_device_added.connect ((dev) => {
            emit_nm_change_event ("AnyDeviceAdded");
        }));

        track_subscription (nm_client, nm_client.any_device_removed.connect ((dev) => {
            emit_nm_change_event ("AnyDeviceRemoved");
        }));

        track_subscription (nm_client, nm_client.active_connection_added.connect ((conn) => {
            emit_nm_change_event ("ActiveConnectionAdded");
        }));

        track_subscription (nm_client, nm_client.active_connection_removed.connect ((conn) => {
            emit_nm_change_event ("ActiveConnectionRemoved");
        }));

        track_subscription (nm_client, nm_client.notify["wireless-enabled"].connect (() => {
            emit_nm_change_event ("WirelessEnabled");
        }));

        track_subscription (nm_client, nm_client.notify["networking-enabled"].connect (() => {
            emit_nm_change_event ("NetworkingEnabled");
        }));

        foreach (var dev in nm_client.get_devices ()) {
            track_subscription (dev, dev.state_changed.connect ((new_state, old_state, reason) => {
                emit_nm_change_event ("DeviceStateChanged (" + dev.get_iface () + ")");
            }));
            if (dev is NM.DeviceWifi) {
                var wifi_dev = (NM.DeviceWifi) dev;
                track_subscription (wifi_dev, wifi_dev.access_point_added.connect ((ap) => {
                    emit_nm_change_event ("AccessPointAdded (" + dev.get_iface () + ")");
                }));
                track_subscription (wifi_dev, wifi_dev.access_point_removed.connect ((ap) => {
                    emit_nm_change_event ("AccessPointRemoved (" + dev.get_iface () + ")");
                }));
            }
        }

        nm_signals_active = true;
        log_info ("nm-client", "nm_events_subscribe: enabled");
        return true;
    }

    public void unsubscribe_network_events () {
        if (!nm_signals_active) {
            return;
        }
        nm_signals_active = false;

        // Disconnect every tracked handler so the closures (which capture `this`)
        // are released by their host objects. This includes both the client-level
        // signals on nm_client and the per-device handlers attached at subscribe
        // time and dynamically inside device_added.
        foreach (var sub in nm_signal_subscriptions) {
            if (sub.handler_id != 0) {
                sub.instance.disconnect (sub.handler_id);
            }
        }
        nm_signal_subscriptions = null;

        log_info ("nm-client", "nm_events_subscribe: disabled");
    }

    public async List<NetworkDevice> get_devices (Cancellable? cancellable = null) throws Error {
        var devices_out = new List<NetworkDevice> ();
        var devices = nm_client.get_devices ();
        foreach (var dev in devices) {
            var d = new NetworkDevice () {
                name = dev.get_iface (),
                device_path = ((NM.Object)dev).get_path (),
                device_type = dev.get_device_type (),
                state = dev.get_state (),
                connection = "",
                connection_uuid = ""
            };

            var ac = dev.get_active_connection ();
            if (ac != null) {
                d.connection = ac.get_id ();
                d.connection_uuid = ac.get_uuid ();
            } else if (d.is_ethernet) {
                var saved_profile = find_saved_ethernet_profile_for_iface (d.name);
                if (saved_profile != null) {
                    d.connection = saved_profile.get_id ();
                    d.connection_uuid = saved_profile.get_uuid ();
                }
            }
            devices_out.append (d);
        }
        return devices_out;
    }

    public async WifiRefreshData get_wifi_refresh_data (Cancellable? cancellable = null) throws Error {
        var scan = yield wifi_scanner.scan_networks (cancellable);
        var hotspot_config = yield hotspot.get_hotspot_status (cancellable);
        return new WifiRefreshData (
            scan.networks,
            scan.devices,
            hotspot_config.is_active,
            scan.num_wifi_devices);
    }

    public async WifiSavedProfile[] get_saved_wifi_profiles (Cancellable? cancellable = null) throws Error {
        return yield saved_profiles.get_saved_profiles (cancellable);
    }

    public async NetworkIpSettings get_wifi_network_ip_settings (
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        return yield saved_profiles.get_network_ip_settings (network, cancellable);
    }

    public async bool update_wifi_network_settings (
        WifiNetwork network,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        return yield saved_profiles.update_network_settings (
            network,
            request,
            cancellable
        );
    }

    public async WifiSavedProfileSettings get_saved_wifi_profile_settings (
        WifiSavedProfile profile,
        Cancellable? cancellable = null
    ) throws Error {
        return yield saved_profiles.get_saved_profile_settings (profile, cancellable);
    }

    public async string? get_wifi_password (
        string connection_uuid,
        Cancellable? cancellable = null,
        out string? read_failure
    ) {
        return yield secrets.get_wifi_password (connection_uuid, cancellable, out read_failure);
    }

    public async bool update_saved_wifi_profile_settings (
        WifiSavedProfile profile,
        WifiSavedProfileUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        return yield saved_profiles.update_saved_profile_settings (profile, request, cancellable);
    }

    public async bool update_saved_wifi_profile_network_settings (
        WifiSavedProfile profile,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        return yield saved_profiles.update_saved_profile_network_settings (profile, request, cancellable);
    }

    public async bool connect_ethernet_device (
        NetworkDevice device,
        Cancellable? cancellable = null
    ) throws Error {
        return yield ethernet_client.connect_device (device, cancellable);
    }

    public async bool disconnect_device (
        string interface_name,
        Cancellable? cancellable = null
    ) throws Error {
        return yield ethernet_client.disconnect_device (interface_name, cancellable);
    }

    public async NetworkIpSettings get_ethernet_device_ip_settings (
        NetworkDevice device,
        Cancellable? cancellable = null
    ) {
        return yield ethernet_client.get_device_ip_settings (device, cancellable);
    }

    public async NetworkIpSettings get_ethernet_device_configured_ip_settings (
        NetworkDevice device,
        Cancellable? cancellable = null
    ) {
        return yield ethernet_client.get_device_configured_ip_settings (device, cancellable);
    }

    public async bool update_ethernet_device_settings (
        NetworkDevice device,
        NetworkIpUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        return yield ethernet_client.update_device_settings (
            device,
            request,
            cancellable
        );
    }

    public async bool get_wifi_enabled_dbus (Cancellable? cancellable = null) throws Error {
        return nm_client.wireless_enabled;
    }

    public async bool get_networking_enabled_dbus (Cancellable? cancellable = null) throws Error {
        return nm_client.networking_enabled;
    }

    public async bool set_wifi_enabled (bool enabled, Cancellable? cancellable = null) throws Error {
        nm_client.wireless_enabled = enabled;
        return true;
    }

    public async bool set_networking_enabled (bool enabled, Cancellable? cancellable = null) throws Error {
        nm_client.networking_enabled = enabled;
        return true;
    }

    public async bool toggle_wifi_dbus (Cancellable? cancellable = null) throws Error {
        bool current = nm_client.wireless_enabled;
        bool enabled_after_toggle = !current;
        nm_client.wireless_enabled = enabled_after_toggle;
        return enabled_after_toggle;
    }

    public async bool connect_saved_wifi (WifiNetwork network, Cancellable? cancellable = null) throws Error {
        return yield saved_profiles.connect_saved (network, cancellable);
    }

    public async bool connect_wifi (
        WifiNetwork network,
        string? password,
        bool autoconnect = true,
        Cancellable? cancellable = null
    ) throws Error {
        return yield saved_profiles.connect (network, password, autoconnect, cancellable);
    }

    public async bool connect_wifi_with_password (
        WifiNetwork network,
        string password,
        bool autoconnect = true,
        Cancellable? cancellable = null
    ) throws Error {
        return yield saved_profiles.connect_with_password (network, password, autoconnect, cancellable);
    }

    public async bool connect_hidden_wifi (
        string ssid,
        HiddenWifiSecurityMode security_mode,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        return yield saved_profiles.connect_hidden_network (ssid, security_mode, password, cancellable);
    }

    public async bool disconnect_wifi (WifiNetwork network, Cancellable? cancellable = null) throws Error {
        return yield saved_profiles.disconnect (network, cancellable);
    }

    public async bool forget_network (
        string profile_uuid,
        string network_key,
        Cancellable? cancellable = null
    ) throws Error {
        return yield saved_profiles.forget_network (profile_uuid, network_key, cancellable);
    }

    public async bool set_wifi_network_autoconnect (
        WifiNetwork network,
        bool enabled,
        int32 priority = 10,
        Cancellable? cancellable = null
    ) throws Error {
        return yield saved_profiles.set_network_autoconnect (network, enabled, priority, cancellable);
    }

    public async bool connect_vpn (string name, Cancellable? cancellable = null) throws Error {
        return yield vpn_client.connect (name, cancellable);
    }

    public async bool disconnect_vpn (string name, Cancellable? cancellable = null) throws Error {
        return yield vpn_client.disconnect (name, cancellable);
    }

    public async List<VpnConnection> get_vpn_connections (Cancellable? cancellable = null) throws Error {
        return yield vpn_client.get_connections (cancellable);
    }

    public async VpnProfileDetails get_vpn_details (
        string id,
        Cancellable? cancellable = null
    ) throws Error {
        return yield vpn_client.get_details (id, cancellable);
    }

    public async bool update_vpn_settings (
        string id,
        VpnUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        return yield vpn_client.update_vpn_settings (id, request, cancellable);
    }

    public async bool delete_vpn (
        string id,
        Cancellable? cancellable = null
    ) throws Error {
        return yield vpn_client.delete_vpn (id, cancellable);
    }

    public async bool create_vpn (
        VpnUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        return yield vpn_client.create_vpn (request, cancellable);
    }

    public async bool scan_wifi (Cancellable? cancellable = null) throws Error {
        return yield wifi_scanner.scan (cancellable);
    }

    public async HyprNetworkManager.Models.HotspotConfig get_hotspot_status (Cancellable? cancellable = null) throws Error {
        return yield hotspot.get_hotspot_status (cancellable);
    }

    public async void create_or_update_hotspot (string ssid, string password, string security, string band, bool is_hidden, int timeout, string ap_interface, string uplink_interface, Cancellable? cancellable = null) throws Error {
        yield hotspot.create_or_update_hotspot (ssid, password, security, band, is_hidden, timeout, ap_interface, uplink_interface, cancellable);
    }

    public async bool enable_hotspot_async (string ssid, string password, string security, string band, bool is_hidden, int timeout, string ap_interface, string uplink_interface, Cancellable? cancellable = null) throws Error {
        return yield hotspot.enable_hotspot_async (ssid, password, security, band, is_hidden, timeout, ap_interface, uplink_interface, cancellable);
    }

    public string[] get_all_interfaces () {
        string[] list = {};
        foreach (var dev in nm_client.get_devices ()) {
            if (dev.get_iface () == "lo" || dev.get_iface () == null || dev.get_iface () == "") continue;
            list += dev.get_iface ();
        }
        return list;
    }

    public string[] get_wifi_interfaces () {
        string[] list = {};
        foreach (var dev in nm_client.get_devices ()) {
            if (dev is NM.DeviceWifi && dev.get_iface () != null && dev.get_iface () != "") {
                list += dev.get_iface ();
            }
        }
        return list;
    }

    public async WifiBandSupport get_wifi_band_support_async (string iface, Cancellable? cancellable = null) throws Error {
        var resolved_iface = (iface != "" && iface != "Auto") ? iface : primary_wifi_iface ();
        var fallback = fallback_wifi_band_support (resolved_iface);

        log_debug ("nm-client",
            "get_wifi_band_support_async: in_iface='%s' resolved_iface='%s'".printf (iface, resolved_iface));

        if (resolved_iface == "") {
            return fallback;
        }

        int result = -1;
        int supports_2ghz = 0;
        int supports_5ghz = 0;
        SourceFunc resume = get_wifi_band_support_async.callback;
        MainContext caller_context = MainContext.ref_thread_default ();

        new Thread<void*> ("nl80211-band-query", () => {
            try {
                result = Nl80211.band_support_by_iface (
                    resolved_iface,
                    out supports_2ghz,
                    out supports_5ghz);
            } catch (Error e) {
                result = -1;
                log_debug ("nm-client",
                    "get_wifi_band_support_async: nl80211 query raised: %s".printf (e.message));
            } finally {
                caller_context.invoke ((owned) resume);
            }
            return null;
        });

        yield;

        if (cancellable != null && cancellable.is_cancelled ()) {
            throw new IOError.CANCELLED ("Wi-Fi band query was cancelled");
        }

        if (result == 0) {
            log_debug ("nm-client",
                "get_wifi_band_support_async: nl80211 succeeded -> 2ghz=%s 5ghz=%s".printf (
                    supports_2ghz != 0 ? "true" : "false",
                    supports_5ghz != 0 ? "true" : "false"));
            return new WifiBandSupport (
                supports_2ghz != 0,
                supports_5ghz != 0);
        }

        log_debug ("nm-client",
            "get_wifi_band_support_async: nl80211 failed for '%s' -> falling back to NM.DeviceWifi capabilities".printf (
                resolved_iface));
        return fallback;
    }

    private WifiBandSupport fallback_wifi_band_support (string resolved_iface) {
        bool supports_2ghz = true;
        bool supports_5ghz = true;
        NM.DeviceWifi? dev = null;
        if (resolved_iface != "") {
            var nm_dev = nm_client.get_device_by_iface (resolved_iface);
            if (nm_dev is NM.DeviceWifi) {
                dev = (NM.DeviceWifi) nm_dev;
            }
        }
        if (dev == null) {
            foreach (var d in nm_client.get_devices ()) {
                if (d is NM.DeviceWifi) {
                    dev = (NM.DeviceWifi) d;
                    break;
                }
            }
        }
        if (dev != null) {
            var cap = dev.get_capabilities ();
            supports_2ghz = (cap & NM.DeviceWifiCapabilities.FREQ_2GHZ) != 0;
            supports_5ghz = (cap & NM.DeviceWifiCapabilities.FREQ_5GHZ) != 0;
        }
        return new WifiBandSupport (supports_2ghz, supports_5ghz);
    }

    private string primary_wifi_iface () {
        foreach (var d in nm_client.get_devices ()) {
            if (d is NM.DeviceWifi && d.get_iface () != null && d.get_iface () != "") {
                return d.get_iface ();
            }
        }
        return "";
    }

    public bool has_create_ap () {
        return hotspot.has_create_ap ();
    }

    public async bool disable_hotspot_async (Cancellable? cancellable = null) throws Error {
        return yield hotspot.disable_hotspot_async (cancellable);
    }

    public async string get_status_json_dbus (Cancellable? cancellable = null) throws Error {
        bool networking_on = nm_client.networking_enabled;
        bool wifi_on = nm_client.wireless_enabled;

        NetworkDevice[] devices = {};
        WifiNetwork[] wifi_nets = {};
        try {
            var refresh_data = yield get_wifi_refresh_data (cancellable);
            devices = refresh_data.devices;
            wifi_nets = refresh_data.networks;
        } catch (Error e) {
            if (e is IOError.CANCELLED) {
                throw e;
            }
            debug_log ("status_read: device/network snapshot failed error=" + e.message);
            throw e;
        }

        NetworkDevice? active_wifi = null;
        NetworkDevice? active_eth = null;
        foreach (var dev in devices) {
            if (dev.is_wifi && dev.is_connected) {
                active_wifi = dev;
            } else if (dev.is_ethernet && dev.is_connected) {
                active_eth = dev;
            }
        }

        uint signal = 100;
        if (active_wifi != null) {
            foreach (var net in wifi_nets) {
                if (net.connected) {
                    signal = net.signal;
                    break;
                }
            }
        }

        string text;
        string alt;
        string tooltip;
        string klass;
        int percentage;
        NmStatusFormatter.pick_status_fields (
            networking_on,
            wifi_on,
            active_wifi,
            active_eth,
            signal,
            out text,
            out alt,
            out tooltip,
            out klass,
            out percentage
        );

        return NmStatusFormatter.build_status_json (text, alt, tooltip, klass, percentage);
    }

    ~NetworkManagerClient () {
        unsubscribe_network_events ();
    }
}
