/* SPDX-License-Identifier: GPL-3.0-or-later */

using GLib;
using Constants;
using HyprNetworkManager.Backend;
using HyprNetworkManager.Models;

private class FakeHotspotClient : Object, IHotspotClient {
    public bool create_ap_available = false;

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
        return { "wlan0", "eth0" };
    }

    public string[] get_wifi_interfaces () {
        return { "wlan0" };
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

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/hotspot-controller/request-mapping", test_request_mapping);
    Test.add_func (
        "/hotspot-controller/backend-capability-validation",
        test_validation_uses_backend_capability
    );
    return Test.run ();
}
