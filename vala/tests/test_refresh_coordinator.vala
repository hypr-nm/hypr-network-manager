/* SPDX-License-Identifier: GPL-3.0-or-later */

using GLib;
using HyprNetworkManager.Backend;
using HyprNetworkManager.UI.Interfaces;

private class FakeNetworkEventClient : Object, IWifiScanClient, INetworkEventClient {
    public uint subscribe_calls = 0;
    public uint unsubscribe_calls = 0;
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
    var coordinator = new MainWindowRefreshCoordinator (client, 3600, host);

    coordinator.start ();
    coordinator.start ();
    run_main_loop_for (10);

    assert (client.subscribe_calls == 1);

    client.emit_network_change ();
    client.emit_network_change ();
    run_main_loop_for (250);
    assert (host.refresh_all_calls == 1);

    coordinator.stop ();
    client.emit_network_change ();
    run_main_loop_for (250);
    assert (host.refresh_all_calls == 1);
}

private static void test_stop_ignores_late_subscription () {
    var client = new FakeNetworkEventClient () {
        delay_subscription = true
    };
    var host = new FakeWindowHost ();
    var coordinator = new MainWindowRefreshCoordinator (client, 3600, host);

    coordinator.start ();
    coordinator.stop ();
    run_main_loop_for (10);

    client.emit_network_change ();
    run_main_loop_for (250);
    assert (host.refresh_all_calls == 0);

    coordinator.start ();
    run_main_loop_for (10);
    client.emit_network_change ();
    run_main_loop_for (250);
    assert (host.refresh_all_calls == 1);
    coordinator.stop ();
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/refresh-coordinator/idempotent-start", test_start_is_idempotent);
    Test.add_func (
        "/refresh-coordinator/late-subscription-after-stop",
        test_stop_ignores_late_subscription
    );
    return Test.run ();
}
