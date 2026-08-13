/* SPDX-License-Identifier: GPL-3.0-or-later */

using GLib;
using HyprNetworkManager.Backend;
using HyprNetworkManager.Models;
using HyprNetworkManager.UI.Interfaces;

private class FakeWifiClient : Object,
    IDeviceClient,
    IWifiScanClient,
    IForgetNetworkClient,
    IWifiClient {
    public uint hidden_connect_calls = 0;
    public string hidden_connect_ssid = "";
    public string hidden_connect_password = "";
    public string hidden_connect_device_path = "";

    public async List<NetworkDevice> get_devices (
        Cancellable? cancellable = null
    ) throws Error {
        return new List<NetworkDevice> ();
    }

    public async bool scan_wifi (Cancellable? cancellable = null) throws Error {
        return true;
    }

    public async bool forget_network (
        string profile_uuid,
        Cancellable? cancellable = null
    ) throws Error {
        return true;
    }

    public async WifiRefreshData get_wifi_refresh_data (
        Cancellable? cancellable = null
    ) throws Error {
        return new WifiRefreshData ({}, {});
    }

    public async NetworkIpSettings get_wifi_network_ip_settings (
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        return new NetworkIpSettings ();
    }

    public async bool update_wifi_network_settings (
        WifiNetwork network,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        return true;
    }

    public async string? get_wifi_password (
        string connection_uuid,
        Cancellable? cancellable = null,
        out string? read_failure
    ) {
        read_failure = null;
        return null;
    }

    public async bool get_wifi_enabled_dbus (
        Cancellable? cancellable = null
    ) throws Error {
        return true;
    }

    public async bool set_wifi_enabled (
        bool enabled,
        Cancellable? cancellable = null
    ) throws Error {
        return true;
    }

    public async bool connect_wifi (
        WifiNetwork network,
        string? password,
        bool autoconnect = true,
        Cancellable? cancellable = null
    ) throws Error {
        return true;
    }

    public async bool connect_hidden_wifi (
        string ssid,
        HiddenWifiSecurityMode security_mode,
        string password,
        string device_path,
        Cancellable? cancellable = null
    ) throws Error {
        hidden_connect_calls++;
        hidden_connect_ssid = ssid;
        hidden_connect_password = password;
        hidden_connect_device_path = device_path;
        return true;
    }

    public async bool disconnect_wifi (
        WifiNetwork network,
        Cancellable? cancellable = null
    ) throws Error {
        return true;
    }

    public async bool set_wifi_network_autoconnect (
        WifiNetwork network,
        bool enabled,
        int32 priority = 10,
        Cancellable? cancellable = null
    ) throws Error {
        return true;
    }
}

private class WifiDetailsTestHost : Object, IWindowHost {
    public void show_error (string message) {}
    public void show_wifi_error (string net_key, string message) {}
    public void show_ethernet_error (string iface_name, string message) {}
    public void show_vpn_error (string vpn_name, string message) {}
    public void show_edit_page_error (string message) {}
    public void show_add_page_error (string message) {}
    public void refresh_after_action (bool request_wifi_scan) {}
    public void refresh_all () {}
    public void refresh_switch_states () {}
    public void hide_active_wifi_password_prompt () {}
    public void debug_log (string message) {}
    public void close_window () {}
}

private static WifiNetwork build_candidate (string device_path, bool connected) {
    return new WifiNetwork () {
        ssid = "Example",
        saved_connection_uuid = "00000000-0000-0000-0000-000000000001",
        connected = connected,
        saved = true,
        device_path = device_path,
        ap_path = "/aps/example",
        security = new WifiSecurityCapabilities ()
    };
}

private static void test_connection_state_is_candidate_specific () {
    var state = new NetworkStateContext ();
    var disconnected_candidate = build_candidate ("/devices/wlan1", false);
    var connected_candidate = build_candidate ("/devices/wlan0", true);

    // The logical network is active on wlan0, but wlan1 must still be reported
    // as disconnected when it is the candidate selected in the radio picker.
    state.active_wifi_connections.insert (disconnected_candidate.network_key, true);

    var controller = new MainWindowWifiDetailsEditController (
        new FakeWifiClient (),
        new WifiDetailsTestHost (),
        state
    );

    assert (!controller.is_connected (disconnected_candidate));
    assert (controller.is_connected (connected_candidate));
    controller.dispose_controller ();
}

private static void test_hidden_connect_uses_selected_radio () {
    var client = new FakeWifiClient ();
    var controller = new MainWindowWifiController (
        client,
        new WifiDetailsTestHost (),
        new NetworkStateContext ()
    );
    var loop = new MainLoop ();
    uint timeout_id = 0;
    bool timed_out = false;

    controller.hidden_network_connected.connect (() => {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
            timeout_id = 0;
        }
        loop.quit ();
    });
    timeout_id = Timeout.add (1000, () => {
        timeout_id = 0;
        timed_out = true;
        loop.quit ();
        return Source.REMOVE;
    });

    controller.connect_hidden_network (
        " Hidden network ",
        HiddenWifiSecurityMode.WPA_PSK,
        "password",
        "/devices/wlan2"
    );
    loop.run ();

    assert (!timed_out);
    assert (client.hidden_connect_calls == 1);
    assert (client.hidden_connect_ssid == "Hidden network");
    assert (client.hidden_connect_password == "password");
    assert (client.hidden_connect_device_path == "/devices/wlan2");
    controller.dispose_controller ();
}

private static void test_hidden_connect_requires_selected_radio () {
    var client = new FakeWifiClient ();
    var controller = new MainWindowWifiController (
        client,
        new WifiDetailsTestHost (),
        new NetworkStateContext ()
    );
    string failure = "";

    controller.add_network_failed.connect ((message) => {
        failure = message;
    });
    controller.connect_hidden_network (
        "Hidden network",
        HiddenWifiSecurityMode.WPA_PSK,
        "password",
        ""
    );

    assert (client.hidden_connect_calls == 0);
    assert (failure != "");
    controller.dispose_controller ();
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/wifi-details/candidate-specific-connection-state",
        test_connection_state_is_candidate_specific
    );
    Test.add_func (
        "/wifi-hidden-connect/uses-selected-radio",
        test_hidden_connect_uses_selected_radio
    );
    Test.add_func (
        "/wifi-hidden-connect/requires-selected-radio",
        test_hidden_connect_requires_selected_radio
    );
    return Test.run ();
}
