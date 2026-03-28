using GLib;

public class WifiRefreshData : Object {
    public WifiNetwork[] networks;
    public NetworkDevice[] devices;

    public WifiRefreshData(WifiNetwork[] networks_in, NetworkDevice[] devices_in) {
        networks = networks_in;
        devices = devices_in;
    }
}

public class WifiSavedProfileIndex : Object {
    public HashTable<string, bool> generic_saved_network_keys;
    public HashTable<string, bool> bssid_locked_profiles;
    public HashTable<string, string> unique_saved_network_key_uuids;

    public WifiSavedProfileIndex() {
        generic_saved_network_keys = new HashTable<string, bool>(str_hash, str_equal);
        bssid_locked_profiles = new HashTable<string, bool>(str_hash, str_equal);
        unique_saved_network_key_uuids = new HashTable<string, string>(str_hash, str_equal);
    }
}

public class NmSignalSubscription : Object {
    public DBusProxy proxy;
    public ulong handler_id;

    public NmSignalSubscription(DBusProxy proxy, ulong handler_id) {
        this.proxy = proxy;
        this.handler_id = handler_id;
    }
}

public class NetworkManagerClient : Object {
    private bool debug_enabled;
    private GlobalDbusRunner dbus_runner;
    private NmWifiClient wifi_client;
    private NmEthernetClient ethernet_client;
    private NmVpnClient vpn_client;
    private bool nm_signals_active = false;
    private List<NmSignalSubscription> nm_signal_subscriptions = new List<NmSignalSubscription>();
    private HashTable<string, bool> nm_subscribed_device_paths = new HashTable<string, bool>(str_hash, str_equal);

    public signal void network_events_changed();

    public NetworkManagerClient(bool debug_enabled) {
        this.debug_enabled = debug_enabled;
        dbus_runner = GlobalDbusRunner.get_default();
        wifi_client = new NmWifiClient(this);
        ethernet_client = new NmEthernetClient(this);
        vpn_client = new NmVpnClient(this);
    }

    internal void debug_log(string message) {
        if (debug_enabled) {
            stderr.printf("[hypr-nm] %s\n", message);
        }
    }

    private void add_nm_signal_subscription(DBusProxy proxy, ulong handler_id) {
        nm_signal_subscriptions.append(new NmSignalSubscription(proxy, handler_id));
    }

    private void emit_nm_change_event(string reason) {
        debug_log("NM signal received: " + reason);
        network_events_changed();
    }

    private async void subscribe_device_signals_dbus(
        string device_path,
        Cancellable? cancellable = null
    ) {
        if (nm_subscribed_device_paths.contains(device_path)) {
            return;
        }

        try {
            var dev_proxy = yield make_proxy(device_path, NM_DEVICE_IFACE, cancellable);
            ulong state_handler_id = dev_proxy.g_signal.connect((sender_name, signal_name, parameters) => {
                if (signal_name == "StateChanged") {
                    emit_nm_change_event("Device.StateChanged (" + device_path + ")");
                }
            });
            add_nm_signal_subscription(dev_proxy, state_handler_id);

            uint32 dev_type = (yield get_prop_dbus(
                device_path,
                NM_DEVICE_IFACE,
                "DeviceType",
                cancellable
            )).get_uint32();
            if (dev_type == NM_DEVICE_TYPE_WIFI) {
                var wireless_proxy = yield make_proxy(device_path, NM_WIRELESS_IFACE, cancellable);
                ulong wifi_handler_id = wireless_proxy.g_signal.connect((sender_name, signal_name, parameters) => {
                    if (signal_name == "AccessPointAdded" || signal_name == "AccessPointRemoved") {
                        emit_nm_change_event("Wireless." + signal_name + " (" + device_path + ")");
                    }
                });
                add_nm_signal_subscription(wireless_proxy, wifi_handler_id);
            }

            nm_subscribed_device_paths.insert(device_path, true);
        } catch (Error e) {
            debug_log("could not subscribe device signals for " + device_path + ": " + e.message);
        }
    }

    private void clear_nm_signal_subscriptions() {
        foreach (var sub in nm_signal_subscriptions) {
            SignalHandler.disconnect(sub.proxy, sub.handler_id);
        }
        nm_signal_subscriptions = new List<NmSignalSubscription>();
        nm_subscribed_device_paths.remove_all();
    }

    internal async DBusProxy make_proxy(
        string object_path,
        string iface,
        Cancellable? cancellable = null
    ) throws Error {
        return yield new DBusProxy.for_bus(
            BusType.SYSTEM,
            DBusProxyFlags.NONE,
            null,
            NM_SERVICE,
            object_path,
            iface,
            cancellable
        );
    }

    internal async Variant call_dbus(
        DBusProxy proxy,
        string method,
        Variant? parameters,
        Cancellable? cancellable = null
    ) throws Error {
        var result = yield dbus_runner.run_with_proxy(
            proxy,
            method,
            parameters,
            DBusCallFlags.NONE,
            NM_DBUS_TIMEOUT_MS,
            cancellable
        );

        if (!result.ok || result.value == null) {
            string message = result.error_message != "" ? result.error_message : "unknown error";
            throw new IOError.FAILED("D-Bus call '%s' failed: %s".printf(method, message));
        }

        return result.value;
    }

    public async DbusRequestResult run_dbus_request(
        string service,
        string object_path,
        string iface,
        string method,
        Variant? parameters = null,
        Cancellable? cancellable = null
    ) {
        return yield dbus_runner.run(
            BusType.SYSTEM,
            service,
            object_path,
            iface,
            method,
            parameters,
            DBusCallFlags.NONE,
            NM_DBUS_TIMEOUT_MS,
            cancellable
        );
    }

    internal async Variant get_prop_dbus(
        string object_path,
        string iface,
        string prop,
        Cancellable? cancellable = null
    ) throws Error {
        var proxy = yield make_proxy(object_path, DBUS_PROPS_IFACE, cancellable);
        var result = yield call_dbus(
            proxy,
            "Get",
            new Variant("(ss)", iface, prop),
            cancellable
        );
        var boxed = result.get_child_value(0);
        return boxed.get_variant();
    }

    public async bool subscribe_network_events_dbus(Cancellable? cancellable = null) throws Error {
        if (nm_signals_active) {
            return true;
        }

        try {
            var nm_proxy = yield make_proxy(NM_PATH, NM_IFACE, cancellable);
            ulong nm_handler_id = nm_proxy.g_signal.connect((sender_name, signal_name, parameters) => {
                if (signal_name == "StateChanged") {
                    emit_nm_change_event("NetworkManager.StateChanged");
                    return;
                }

                if (signal_name == "DeviceAdded") {
                    string? device_path = null;
                    if (parameters != null && parameters.n_children() > 0) {
                        device_path = parameters.get_child_value(0).get_string();
                    }

                    if (device_path != null && device_path != "") {
                        subscribe_device_signals_dbus.begin(device_path, null);
                    }

                    emit_nm_change_event("NetworkManager.DeviceAdded");
                    return;
                }

                if (signal_name == "DeviceRemoved") {
                    emit_nm_change_event("NetworkManager.DeviceRemoved");
                    return;
                }
            });
            add_nm_signal_subscription(nm_proxy, nm_handler_id);

            var devices_res = yield call_dbus(nm_proxy, "GetDevices", null, cancellable);
            var devices = devices_res.get_child_value(0);
            for (int i = 0; i < devices.n_children(); i++) {
                yield subscribe_device_signals_dbus(devices.get_child_value(i).get_string(), cancellable);
            }

            nm_signals_active = true;
            debug_log("subscribed to NetworkManager D-Bus signals");
            return true;
        } catch (Error e) {
            clear_nm_signal_subscriptions();
            nm_signals_active = false;
            throw e;
        }
    }

    public void unsubscribe_network_events() {
        if (!nm_signals_active && nm_signal_subscriptions.length() == 0) {
            return;
        }

        clear_nm_signal_subscriptions();
        nm_signals_active = false;
        debug_log("unsubscribed from NetworkManager D-Bus signals");
    }

    internal async List<NetworkDevice> get_devices_dbus(Cancellable? cancellable = null) throws Error {
        var devices_out = new List<NetworkDevice>();

        var nm = yield make_proxy(NM_PATH, NM_IFACE, cancellable);
        var devices_res = yield call_dbus(nm, "GetDevices", null, cancellable);
        var devices = devices_res.get_child_value(0);

        for (int i = 0; i < devices.n_children(); i++) {
            string dev_path = devices.get_child_value(i).get_string();
            try {
                string iface = (yield get_prop_dbus(dev_path, NM_DEVICE_IFACE, "Interface", cancellable)).get_string();
                if (iface == "" || iface == "lo") {
                    continue;
                }

                uint32 dev_type = (yield get_prop_dbus(dev_path, NM_DEVICE_IFACE, "DeviceType", cancellable)).get_uint32();
                uint32 state = (yield get_prop_dbus(dev_path, NM_DEVICE_IFACE, "State", cancellable)).get_uint32();

                string conn_name = "";
                string conn_uuid = "";
                string ac_path = (yield get_prop_dbus(
                    dev_path,
                    NM_DEVICE_IFACE,
                    "ActiveConnection",
                    cancellable
                )).get_string();
                if (ac_path != "/") {
                    try {
                        conn_name = (yield get_prop_dbus(ac_path, NM_ACTIVE_CONN_IFACE, "Id", cancellable)).get_string();
                        conn_uuid = (yield get_prop_dbus(ac_path, NM_ACTIVE_CONN_IFACE, "Uuid", cancellable)).get_string();
                    } catch (Error e) {
                        debug_log("Could not read active connection id for " + dev_path + ": " + e.message);
                    }
                }

                if (conn_name == "" && dev_type == NM_DEVICE_TYPE_ETHERNET) {
                    try {
                        Variant available_connections = yield get_prop_dbus(
                            dev_path,
                            NM_DEVICE_IFACE,
                            "AvailableConnections",
                            cancellable
                        );
                        for (int j = 0; j < available_connections.n_children(); j++) {
                            string conn_path = available_connections.get_child_value(j).get_string();
                            try {
                                var conn = yield make_proxy(conn_path, NM_CONN_IFACE, cancellable);
                                var settings_res = yield call_dbus(conn, "GetSettings", null, cancellable);
                                var all_settings = settings_res.get_child_value(0);

                                Variant? conn_group = all_settings.lookup_value(
                                    "connection",
                                    new VariantType("a{sv}")
                                );
                                if (conn_group == null) {
                                    continue;
                                }

                                Variant? type_v = conn_group.lookup_value("type", new VariantType("s"));
                                if (type_v == null || type_v.get_string() != "802-3-ethernet") {
                                    continue;
                                }

                                Variant? id_v = conn_group.lookup_value("id", new VariantType("s"));
                                Variant? uuid_v = conn_group.lookup_value("uuid", new VariantType("s"));
                                if (id_v != null && id_v.get_string() != "") {
                                    conn_name = id_v.get_string();
                                    conn_uuid = uuid_v != null ? uuid_v.get_string() : "";
                                    break;
                                }
                            } catch (Error e) {
                                debug_log("Skipping stale connection object " + conn_path + ": " + e.message);
                            }
                        }
                    } catch (Error e) {
                        debug_log("Could not read available Ethernet profiles for " + dev_path + ": " + e.message);
                    }
                }

                devices_out.append(new NetworkDevice() {
                    name = iface,
                    device_path = dev_path,
                    device_type = dev_type,
                    state = state,
                    connection = conn_name,
                    connection_uuid = conn_uuid
                });
            } catch (Error e) {
                debug_log("Skipping transient device object " + dev_path + ": " + e.message);
            }
        }

        return devices_out;
    }

    public async WifiRefreshData get_wifi_refresh_data(Cancellable? cancellable = null) throws Error {
        return yield wifi_client.get_refresh_data(cancellable);
    }

    internal static string normalize_ipv4_method(string value) {
        return NmClientUtils.normalize_ipv4_method(value);
    }

    internal static string normalize_ipv6_method(string value) {
        return NmClientUtils.normalize_ipv6_method(value);
    }

    private static string extract_dns_list_string(Variant dns_variant) {
        return NmClientUtils.extract_dns_list_string(dns_variant);
    }

    internal static void fill_configured_ipv4_from_settings(Variant all_settings, NetworkIpSettings out_ip) {
        NmClientUtils.fill_configured_ipv4_from_settings(all_settings, out_ip);
    }

    internal static void fill_configured_ipv6_from_settings(Variant all_settings, NetworkIpSettings out_ip) {
        NmClientUtils.fill_configured_ipv6_from_settings(all_settings, out_ip);
    }

    internal async void fill_runtime_ipv4_for_device_dbus(
        string device_path,
        bool device_connected,
        NetworkIpSettings out_ip,
        Cancellable? cancellable = null
    ) {
        if (!device_connected) {
            return;
        }

        try {
            string active_conn_path = (yield get_prop_dbus(
                device_path,
                NM_DEVICE_IFACE,
                "ActiveConnection",
                cancellable
            )).get_string();
            if (active_conn_path == "/") {
                return;
            }

            string ip4_config_path = (yield get_prop_dbus(
                active_conn_path,
                NM_ACTIVE_CONN_IFACE,
                "Ip4Config",
                cancellable
            )).get_string();
            if (ip4_config_path == "/") {
                return;
            }

            Variant address_data = yield get_prop_dbus(
                ip4_config_path,
                NM_IP4_CONFIG_IFACE,
                "AddressData",
                cancellable
            );
            if (address_data.n_children() > 0) {
                Variant first_addr = address_data.get_child_value(0);
                Variant? addr_v = first_addr.lookup_value("address", new VariantType("s"));
                Variant? prefix_v = first_addr.lookup_value("prefix", new VariantType("u"));
                if (addr_v != null) {
                    out_ip.current_address = addr_v.get_string();
                }
                if (prefix_v != null) {
                    out_ip.current_prefix = prefix_v.get_uint32();
                }
            }

            try {
                out_ip.current_gateway = (yield get_prop_dbus(
                    ip4_config_path,
                    NM_IP4_CONFIG_IFACE,
                    "Gateway",
                    cancellable
                )).get_string();
            } catch (Error gateway_err) {
                debug_log("could not read runtime IPv4 gateway: " + gateway_err.message);
            }

            try {
                Variant dns_data = yield get_prop_dbus(
                    ip4_config_path,
                    NM_IP4_CONFIG_IFACE,
                    "NameserverData",
                    cancellable
                );
                out_ip.current_dns = extract_dns_list_string(dns_data);
            } catch (Error dns_err) {
                debug_log("could not read runtime IPv4 DNS: " + dns_err.message);
            }
        } catch (Error e) {
            debug_log("could not read runtime IPv4 details: " + e.message);
        }
    }

    internal async void fill_runtime_ipv6_for_device_dbus(
        string device_path,
        bool device_connected,
        NetworkIpSettings out_ip,
        Cancellable? cancellable = null
    ) {
        if (!device_connected) {
            return;
        }

        try {
            string active_conn_path = (yield get_prop_dbus(
                device_path,
                NM_DEVICE_IFACE,
                "ActiveConnection",
                cancellable
            )).get_string();
            if (active_conn_path == "/") {
                return;
            }

            string ip6_config_path = (yield get_prop_dbus(
                active_conn_path,
                NM_ACTIVE_CONN_IFACE,
                "Ip6Config",
                cancellable
            )).get_string();
            if (ip6_config_path == "/") {
                return;
            }

            Variant address_data = yield get_prop_dbus(
                ip6_config_path,
                NM_IP6_CONFIG_IFACE,
                "AddressData",
                cancellable
            );
            if (address_data.n_children() > 0) {
                Variant first_addr = address_data.get_child_value(0);
                Variant? addr_v = first_addr.lookup_value("address", new VariantType("s"));
                Variant? prefix_v = first_addr.lookup_value("prefix", new VariantType("u"));
                if (addr_v != null) {
                    out_ip.current_ipv6_address = addr_v.get_string();
                }
                if (prefix_v != null) {
                    out_ip.current_ipv6_prefix = prefix_v.get_uint32();
                }
            }

            try {
                out_ip.current_ipv6_gateway = (yield get_prop_dbus(
                    ip6_config_path,
                    NM_IP6_CONFIG_IFACE,
                    "Gateway",
                    cancellable
                )).get_string();
            } catch (Error gateway_err) {
                debug_log("could not read runtime IPv6 gateway: " + gateway_err.message);
            }

            try {
                Variant dns_data = yield get_prop_dbus(
                    ip6_config_path,
                    NM_IP6_CONFIG_IFACE,
                    "NameserverData",
                    cancellable
                );
                out_ip.current_ipv6_dns = extract_dns_list_string(dns_data);
            } catch (Error dns_err) {
                debug_log("could not read runtime IPv6 DNS: " + dns_err.message);
            }
        } catch (Error e) {
            debug_log("could not read runtime IPv6 details: " + e.message);
        }
    }

    public async NetworkIpSettings get_wifi_network_ip_settings(
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        return yield wifi_client.get_network_ip_settings(network, cancellable);
    }

    public async bool update_wifi_network_settings(
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
        return yield wifi_client.update_network_settings(
            network,
            password,
            ipv4_method,
            ipv4_address,
            ipv4_prefix,
            gateway_auto,
            ipv4_gateway,
            dns_auto,
            ipv4_dns_servers,
            ipv6_method,
            ipv6_address,
            ipv6_prefix,
            ipv6_gateway_auto,
            ipv6_gateway,
            ipv6_dns_auto,
            ipv6_dns_servers,
            cancellable
        );
    }

    public async bool connect_ethernet_device(
        NetworkDevice device,
        Cancellable? cancellable = null
    ) throws Error {
        return yield ethernet_client.connect_device(device, cancellable);
    }

    public async bool disconnect_device(
        string interface_name,
        Cancellable? cancellable = null
    ) throws Error {
        return yield ethernet_client.disconnect_device(interface_name, cancellable);
    }

    public async NetworkIpSettings get_ethernet_device_ip_settings(
        NetworkDevice device,
        Cancellable? cancellable = null
    ) {
        return yield ethernet_client.get_device_ip_settings(device, cancellable);
    }

    public async bool update_ethernet_device_settings(
        NetworkDevice device,
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
        return yield ethernet_client.update_device_settings(
            device,
            ipv4_method,
            ipv4_address,
            ipv4_prefix,
            gateway_auto,
            ipv4_gateway,
            dns_auto,
            ipv4_dns_servers,
            ipv6_method,
            ipv6_address,
            ipv6_prefix,
            ipv6_gateway_auto,
            ipv6_gateway,
            ipv6_dns_auto,
            ipv6_dns_servers,
            cancellable
        );
    }

    public async List<NetworkDevice> get_devices(Cancellable? cancellable = null) throws Error {
        return yield get_devices_dbus(cancellable);
    }

    public async bool get_wifi_enabled_dbus(Cancellable? cancellable = null) throws Error {
        return (yield get_prop_dbus(NM_PATH, NM_IFACE, "WirelessEnabled", cancellable)).get_boolean();
    }

    public async bool get_networking_enabled_dbus(Cancellable? cancellable = null) throws Error {
        return (yield get_prop_dbus(NM_PATH, NM_IFACE, "NetworkingEnabled", cancellable)).get_boolean();
    }

    private async bool set_nm_bool_property_dbus(
        string prop_name,
        bool value,
        Cancellable? cancellable = null
    ) throws Error {
        var proxy = yield make_proxy(NM_PATH, DBUS_PROPS_IFACE, cancellable);
        yield call_dbus(
            proxy,
            "Set",
            new Variant("(ssv)", NM_IFACE, prop_name, new Variant.boolean(value)),
            cancellable
        );
        return true;
    }

    public async bool set_wifi_enabled(bool enabled, Cancellable? cancellable = null) throws Error {
        return yield set_nm_bool_property_dbus("WirelessEnabled", enabled, cancellable);
    }

    public async bool set_networking_enabled(bool enabled, Cancellable? cancellable = null) throws Error {
        try {
            var nm = yield make_proxy(NM_PATH, NM_IFACE, cancellable);
            yield call_dbus(
                nm,
                "Enable",
                new Variant("(b)", enabled),
                cancellable
            );
            return true;
        } catch (Error e) {
            debug_log("Enable() failed, falling back to NetworkingEnabled property: " + e.message);
            return yield set_nm_bool_property_dbus("NetworkingEnabled", enabled, cancellable);
        }
    }

    public async bool toggle_wifi_dbus(Cancellable? cancellable = null) throws Error {
        bool current = yield get_wifi_enabled_dbus(cancellable);
        bool enabled_after_toggle = !current;
        yield set_nm_bool_property_dbus("WirelessEnabled", enabled_after_toggle, cancellable);
        return enabled_after_toggle;
    }

    public async bool connect_saved_wifi(WifiNetwork network, Cancellable? cancellable = null) throws Error {
        return yield wifi_client.connect_saved(network, cancellable);
    }

    public async bool connect_wifi(
        WifiNetwork network,
        string? password,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.connect(network, password, cancellable);
    }

    public async bool connect_wifi_with_password(
        WifiNetwork network,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.connect_with_password(network, password, cancellable);
    }

    public async bool connect_hidden_wifi(
        string ssid,
        HiddenWifiSecurityMode security_mode,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.connect_hidden_network(ssid, security_mode, password, cancellable);
    }

    public async bool disconnect_wifi(WifiNetwork network, Cancellable? cancellable = null) throws Error {
        return yield wifi_client.disconnect(network, cancellable);
    }

    public async bool forget_network(
        string profile_uuid,
        string network_key,
        Cancellable? cancellable = null
    ) throws Error {
        return yield wifi_client.forget_network(profile_uuid, network_key, cancellable);
    }

    public async bool connect_vpn(string name, Cancellable? cancellable = null) throws Error {
        return yield vpn_client.connect(name, cancellable);
    }

    public async bool disconnect_vpn(string name, Cancellable? cancellable = null) throws Error {
        return yield vpn_client.disconnect(name, cancellable);
    }

    public async List<VpnConnection> get_vpn_connections(Cancellable? cancellable = null) throws Error {
        return yield vpn_client.get_connections(cancellable);
    }

    public async bool scan_wifi(Cancellable? cancellable = null) throws Error {
        return yield wifi_client.scan(cancellable);
    }

    public async string get_status_json_dbus(Cancellable? cancellable = null) {
        bool networking_on = false;
        bool wifi_on = false;
        try {
            networking_on = yield get_networking_enabled_dbus(cancellable);
        } catch (Error e) {
            debug_log("could not read NetworkingEnabled for status: " + e.message);
        }
        try {
            wifi_on = yield get_wifi_enabled_dbus(cancellable);
        } catch (Error e) {
            debug_log("could not read WirelessEnabled for status: " + e.message);
        }

        NetworkDevice[] devices = {};
        WifiNetwork[] wifi_nets = {};
        try {
            var refresh_data = yield get_wifi_refresh_data(cancellable);
            devices = refresh_data.devices;
            wifi_nets = refresh_data.networks;
        } catch (Error e) {
            debug_log("could not read status device/network data: " + e.message);
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
        NmStatusFormatter.pick_status_fields(
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

        return NmStatusFormatter.build_status_json(text, alt, tooltip, klass);
    }

    ~NetworkManagerClient() {
        unsubscribe_network_events();
    }
}
