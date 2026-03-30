using GLib;
using NM;

public class WifiRefreshData : GLib.Object {
    public WifiNetwork[] networks;
    public NetworkDevice[] devices;

    public WifiRefreshData (WifiNetwork[] networks_in, NetworkDevice[] devices_in) {
        networks = networks_in;
        devices = devices_in;
    }
}

public class NetworkManagerClient : GLib.Object {
    public NM.Client nm_client;

    private NmWifiClient wifi_client;
    private NmEthernetClient ethernet_client;
    private NmVpnClient vpn_client;
    private bool nm_signals_active = false;

    public signal void network_events_changed ();

    public static string normalize_ipv4_method (string value) {
        if (value == "auto" || value == "manual" || value == "link-local" || value == "shared" || value == "disabled") {
            return value;
        }
        return "auto";
    }

    public static string normalize_ipv6_method (string value) {
        if (value == "auto" || value == "manual" || value == "ignore" || value == "shared" || value == "disabled" |
            value == "link-local") {
            return value;
        }
        return "auto";
    }

    public NetworkManagerClient () {
        try {
            nm_client = new NM.Client (null);
        } catch (Error e) {
            log_error ("nm-client", "Failed to initialize NM.Client: " + e.message);
        }
        wifi_client = new NmWifiClient (this);
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

    public async bool subscribe_network_events_dbus (Cancellable? cancellable = null) throws Error {
        if (nm_signals_active || nm_client == null) {
            return true;
        }

        nm_client.device_added.connect ((dev) => {
            emit_nm_change_event ("DeviceAdded (" + dev.get_iface () + ")");
            dev.state_changed.connect ((new_state, old_state, reason) => {
                emit_nm_change_event ("DeviceStateChanged (" + dev.get_iface () + ")");
            });
            if (dev is NM.DeviceWifi) {
                ((NM.DeviceWifi)dev).access_point_added.connect ((ap) => {
                    emit_nm_change_event ("AccessPointAdded (" + dev.get_iface () + ")");
                });
                ((NM.DeviceWifi)dev).access_point_removed.connect ((ap) => {
                    emit_nm_change_event ("AccessPointRemoved (" + dev.get_iface () + ")");
                });
            }
        });

        nm_client.device_removed.connect ((dev) => {
            emit_nm_change_event ("DeviceRemoved (" + dev.get_iface () + ")");
        });

        nm_client.any_device_added.connect ((dev) => {
            emit_nm_change_event ("AnyDeviceAdded");
        });

        nm_client.any_device_removed.connect ((dev) => {
            emit_nm_change_event ("AnyDeviceRemoved");
        });

        nm_client.active_connection_added.connect ((conn) => {
            emit_nm_change_event ("ActiveConnectionAdded");
        });

        nm_client.active_connection_removed.connect ((conn) => {
            emit_nm_change_event ("ActiveConnectionRemoved");
        });

        nm_client.notify["wireless-enabled"].connect (() => {
            emit_nm_change_event ("WirelessEnabled");
        });

        nm_client.notify["networking-enabled"].connect (() => {
            emit_nm_change_event ("NetworkingEnabled");
        });

        foreach (var dev in nm_client.get_devices ()) {
            dev.state_changed.connect ((new_state, old_state, reason) => {
                emit_nm_change_event ("DeviceStateChanged (" + dev.get_iface () + ")");
            });
            if (dev is NM.DeviceWifi) {
                ((NM.DeviceWifi)dev).access_point_added.connect ((ap) => {
                    emit_nm_change_event ("AccessPointAdded (" + dev.get_iface () + ")");
                });
                ((NM.DeviceWifi)dev).access_point_removed.connect ((ap) => {
                    emit_nm_change_event ("AccessPointRemoved (" + dev.get_iface () + ")");
                });
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
            }
            devices_out.append (d);
        }
        return devices_out;
    }

    public async WifiRefreshData get_wifi_refresh_data (Cancellable? cancellable = null) throws Error {
        return yield wifi_client.get_refresh_data (cancellable);
    }

    public async NetworkIpSettings get_wifi_network_ip_settings (
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        return yield wifi_client.get_network_ip_settings (network, cancellable);
    }

    public async bool update_wifi_network_settings (
        WifiNetwork network,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.update_network_settings (
            network,
            request,
            cancellable
        );
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
        return yield wifi_client.connect_saved (network, cancellable);
    }

    public async bool connect_wifi (
        WifiNetwork network,
        string? password,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.connect (network, password, cancellable);
    }

    public async bool connect_wifi_with_password (
        WifiNetwork network,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.connect_with_password (network, password, cancellable);
    }

    public async bool connect_hidden_wifi (
        string ssid,
        HiddenWifiSecurityMode security_mode,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.connect_hidden_network (ssid, security_mode, password, cancellable);
    }

    public async bool disconnect_wifi (WifiNetwork network, Cancellable? cancellable = null) throws Error {
        return yield wifi_client.disconnect (network, cancellable);
    }

    public async bool forget_network (
        string profile_uuid,
        string network_key,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.forget_network (profile_uuid, network_key, cancellable);
    }

    public async bool set_wifi_network_autoconnect (
        WifiNetwork network,
        bool enabled,
        int32 priority = 10,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.set_network_autoconnect (network, enabled, priority, cancellable);
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

    public async bool scan_wifi (Cancellable? cancellable = null) throws Error {
        return yield wifi_client.scan (cancellable);
    }

    public async string get_status_json_dbus (Cancellable? cancellable = null) {
        bool networking_on = nm_client.networking_enabled;
        bool wifi_on = nm_client.wireless_enabled;

        NetworkDevice[] devices = {};
        WifiNetwork[] wifi_nets = {};
        try {
            var refresh_data = yield get_wifi_refresh_data (cancellable);
            devices = refresh_data.devices;
            wifi_nets = refresh_data.networks;
        } catch (Error e) {
            debug_log ("status_read: device/network snapshot failed error=" + e.message);
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
        NmStatusFormatter.pick_status_fields (
            networking_on,
            wifi_on,
            active_wifi,
            active_eth,
            signal,
            out text,
            out alt,
            out tooltip,
            out klass
        );

        return NmStatusFormatter.build_status_json (text, alt, tooltip, klass);
    }

    ~NetworkManagerClient () {
        unsubscribe_network_events ();
    }
}
