/* SPDX-License-Identifier: GPL-3.0-or-later */

using GLib;
using Constants;
using HyprNetworkManager.Backend;
using HyprNetworkManager.Models;

private class FakeHotspotClient : Object, IHotspotClient {
    public bool create_ap_available = false;
    public string[] all_interfaces = { "wlan0", "eth0" };
    public string[] wifi_interfaces = { "wlan0" };

    public async HotspotConfig get_hotspot_status (
        Cancellable? cancellable = null
    ) throws Error {
        return new HotspotConfig ();
    }

    public async void create_or_update_hotspot (
        string ssid,
        string password,
        string security,
        string band,
        bool is_hidden,
        int timeout,
        string ap_interface,
        string uplink_interface,
        Cancellable? cancellable = null
    ) throws Error {
    }

    public async bool enable_hotspot_async (
        string ssid,
        string password,
        string security,
        string band,
        bool is_hidden,
        int timeout,
        string ap_interface,
        string uplink_interface,
        Cancellable? cancellable = null
    ) throws Error {
        return true;
    }

    public string[] get_all_interfaces () {
        return all_interfaces;
    }

    public string[] get_wifi_interfaces () {
        return wifi_interfaces;
    }

    public async WifiBandSupport get_wifi_band_support_async (
        string iface,
        Cancellable? cancellable = null
    ) throws Error {
        return new WifiBandSupport (true, true);
    }

    public bool has_create_ap () {
        return create_ap_available;
    }

    public async bool disable_hotspot_async (
        Cancellable? cancellable = null
    ) throws Error {
        return true;
    }
}

private static void test_request_mapping () {
    var controller = new MainWindowHotspotController (new FakeHotspotClient ());
    var request = controller.build_request (
        "Test AP",
        "password",
        HotspotSecurityIndex.SAE,
        WifiBand.BAND_5GHZ,
        true,
        HotspotTimeoutIndex.THIRTY_MINUTES,
        "wlan0",
        "eth0"
    );

    assert (request.security == WifiKeyMgmt.SAE);
    assert (request.timeout_minutes == HotspotTimeout.THIRTY_MINUTES);
    assert (request.band == WifiBand.BAND_5GHZ);
    assert (request.is_hidden);
}

private static void test_validation_uses_backend_capability () {
    var fake = new FakeHotspotClient ();
    var controller = new MainWindowHotspotController (fake);
    var request = controller.build_request (
        "Test AP",
        "password",
        HotspotSecurityIndex.WPA_PSK,
        WifiBand.BAND_2GHZ,
        false,
        HotspotTimeoutIndex.DISABLED,
        "wlan0",
        "wlan0"
    );

    assert (controller.validation_message (request) != null);
    fake.create_ap_available = true;
    assert (controller.validation_message (request) == null);
}

private static void test_timeout_shutdown_retry_policy () {
    assert (!HotspotTimeoutPolicy.threshold_reached (4, 5));
    assert (HotspotTimeoutPolicy.threshold_reached (5, 5));
    assert (HotspotTimeoutPolicy.threshold_reached (6, 5));
    assert (!HotspotTimeoutPolicy.threshold_reached (1, 0));

    assert (HotspotTimeoutPolicy.idle_minutes_after_shutdown (true, 5) == 0);
    assert (HotspotTimeoutPolicy.idle_minutes_after_shutdown (false, 5) == 5);
}

private static void test_interface_discovery_is_live () {
    var fake = new FakeHotspotClient ();
    var controller = new MainWindowHotspotController (fake);

    assert (controller.get_wifi_interfaces ().length == 1);
    assert (controller.get_all_interfaces ().length == 2);

    fake.wifi_interfaces = { "wlan0", "wlan1" };
    fake.all_interfaces = { "wlan0", "wlan1", "eth0", "usb0" };

    string[] wifi = controller.get_wifi_interfaces ();
    string[] all = controller.get_all_interfaces ();
    assert (wifi.length == 2);
    assert (wifi[1] == "wlan1");
    assert (all.length == 4);
    assert (all[3] == "usb0");
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/hotspot-controller/request-mapping", test_request_mapping);
    Test.add_func (
        "/hotspot-controller/backend-capability-validation",
        test_validation_uses_backend_capability
    );
    Test.add_func (
        "/hotspot-controller/timeout-shutdown-retry-policy",
        test_timeout_shutdown_retry_policy
    );
    Test.add_func (
        "/hotspot-controller/interface-discovery-is-live",
        test_interface_discovery_is_live
    );
    return Test.run ();
}
