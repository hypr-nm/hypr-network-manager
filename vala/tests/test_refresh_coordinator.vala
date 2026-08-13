/* SPDX-License-Identifier: GPL-3.0-or-later */

using GLib;
using Constants;
using HyprNetworkManager.Backend;
using HyprNetworkManager.UI.Interfaces;

private const uint TEST_LONG_REFRESH_INTERVAL_SECONDS = 3600;
private const uint TEST_ASYNC_SETTLE_MS = 10;
private const uint TEST_TIMER_MARGIN_MS = 50;

private class FakeNetworkEventClient : Object, IWifiScanClient, INetworkEventClient {
    public uint subscribe_calls = 0;
    public uint unsubscribe_calls = 0;
    public uint scan_calls = 0;
    public bool delay_subscription = false;

    private async void wait_for_idle () {
        Idle.add (() => {
            wait_for_idle.callback ();
            return Source.REMOVE;
        });
        yield;
    }

    public async bool subscribe_network_events_dbus (
        Cancellable? cancellable = null
    ) throws Error {
        subscribe_calls++;
        if (delay_subscription) {
            yield wait_for_idle ();
        }
        return true;
    }

    public void unsubscribe_network_events () {
        unsubscribe_calls++;
    }

    public async bool scan_wifi (Cancellable? cancellable = null) throws Error {
        scan_calls++;
        return true;
    }

    public void emit_network_change () {
        network_events_changed ();
    }
}

private class FakeWindowHost : Object, IWindowHost {
    public uint refresh_all_calls = 0;

    public void show_error (string message) {}
    public void show_wifi_error (string net_key, string message) {}
    public void show_ethernet_error (string iface_name, string message) {}
    public void show_vpn_error (string vpn_name, string message) {}
    public void show_edit_page_error (string message) {}
    public void show_add_page_error (string message) {}
    public void refresh_after_action (bool request_wifi_scan) {}
    public void refresh_switch_states () {}
    public void hide_active_wifi_password_prompt () {}
    public void debug_log (string message) {}
    public void close_window () {}

    public void refresh_all () {
        refresh_all_calls++;
    }
}

private static void run_main_loop_for (uint milliseconds) {
    var loop = new MainLoop ();
    Timeout.add (milliseconds, () => {
        loop.quit ();
        return Source.REMOVE;
    });
    loop.run ();
}

private static void test_start_is_idempotent () {
    var client = new FakeNetworkEventClient ();
    var host = new FakeWindowHost ();
    var coordinator = new MainWindowRefreshCoordinator (
        client,
        TEST_LONG_REFRESH_INTERVAL_SECONDS,
        host);

    coordinator.start ();
    coordinator.start ();
    run_main_loop_for (TEST_ASYNC_SETTLE_MS);

    assert (client.subscribe_calls == 1);

    client.emit_network_change ();
    client.emit_network_change ();
    run_main_loop_for (
        Timeouts.NETWORK_EVENT_REFRESH_DEBOUNCE_MS + TEST_TIMER_MARGIN_MS);
    assert (host.refresh_all_calls == 1);

    coordinator.stop ();
    client.emit_network_change ();
    run_main_loop_for (
        Timeouts.NETWORK_EVENT_REFRESH_DEBOUNCE_MS + TEST_TIMER_MARGIN_MS);
    assert (host.refresh_all_calls == 1);
}

private static void test_stop_ignores_late_subscription () {
    var client = new FakeNetworkEventClient () {
        delay_subscription = true
    };
    var host = new FakeWindowHost ();
    var coordinator = new MainWindowRefreshCoordinator (
        client,
        TEST_LONG_REFRESH_INTERVAL_SECONDS,
        host);

    coordinator.start ();
    coordinator.stop ();
    run_main_loop_for (TEST_ASYNC_SETTLE_MS);

    client.emit_network_change ();
    run_main_loop_for (
        Timeouts.NETWORK_EVENT_REFRESH_DEBOUNCE_MS + TEST_TIMER_MARGIN_MS);
    assert (host.refresh_all_calls == 0);

    coordinator.start ();
    run_main_loop_for (TEST_ASYNC_SETTLE_MS);
    client.emit_network_change ();
    run_main_loop_for (
        Timeouts.NETWORK_EVENT_REFRESH_DEBOUNCE_MS + TEST_TIMER_MARGIN_MS);
    assert (host.refresh_all_calls == 1);
    coordinator.stop ();
}

private static void test_scan_staleness_policy () {
    const int64 BASE_TIME = 10 * TimeSpan.SECOND;
    uint interval = Timeouts.DEFAULT_SCAN_INTERVAL_SECONDS;
    assert (MainWindowRefreshCoordinator.wifi_scan_is_stale (
        0,
        BASE_TIME,
        interval));
    assert (!MainWindowRefreshCoordinator.wifi_scan_is_stale (
        BASE_TIME,
        BASE_TIME + ((int64) interval - 1) * TimeSpan.SECOND,
        interval));
    assert (MainWindowRefreshCoordinator.wifi_scan_is_stale (
        BASE_TIME,
        BASE_TIME + (int64) interval * TimeSpan.SECOND,
        interval));
    assert (MainWindowRefreshCoordinator.wifi_scan_is_stale (
        BASE_TIME + (int64) interval * TimeSpan.SECOND,
        BASE_TIME,
        interval));
}

private static void test_presentation_scan_is_throttled () {
    var client = new FakeNetworkEventClient ();
    var host = new FakeWindowHost ();
    var coordinator = new MainWindowRefreshCoordinator (
        client,
        TEST_LONG_REFRESH_INTERVAL_SECONDS,
        host);

    coordinator.request_scan_if_stale ();
    coordinator.request_scan_if_stale ();
    run_main_loop_for (TEST_ASYNC_SETTLE_MS);

    assert (client.scan_calls == 1);
    assert (host.refresh_all_calls == 1);
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/refresh-coordinator/idempotent-start", test_start_is_idempotent);
    Test.add_func (
        "/refresh-coordinator/late-subscription-after-stop",
        test_stop_ignores_late_subscription
    );
    Test.add_func (
        "/refresh-coordinator/scan-staleness-policy",
        test_scan_staleness_policy
    );
    Test.add_func (
        "/refresh-coordinator/presentation-scan-throttled",
        test_presentation_scan_is_throttled
    );
    return Test.run ();
}
