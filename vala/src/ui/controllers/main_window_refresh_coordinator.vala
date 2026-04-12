using GLib;
using Gtk;

public class MainWindowRefreshCoordinator : Object {
    private NetworkManagerClient nm;
    private MainWindowWifiController wifi_controller;
    private uint refresh_interval_seconds;
    private MainWindowActionCallback on_refresh_all;
    private MainWindowLogCallback on_log;

    private uint periodic_refresh_source_id = 0;
    private uint signal_refresh_source_id = 0;
    private ulong nm_events_changed_handler_id = 0;
    private bool nm_events_subscription_enabled = false;
    private bool periodic_scan_failure_reported = false;

    public MainWindowRefreshCoordinator (
        NetworkManagerClient nm,
        MainWindowWifiController wifi_controller,
        uint refresh_interval_seconds,
        owned MainWindowActionCallback on_refresh_all,
        owned MainWindowLogCallback on_log
    ) {
        this.nm = nm;
        this.wifi_controller = wifi_controller;
        this.refresh_interval_seconds = refresh_interval_seconds;
        this.on_refresh_all = (owned) on_refresh_all;
        this.on_log = (owned) on_log;
    }

    public void start () {
        configure_nm_signal_refresh ();

        periodic_refresh_source_id = Timeout.add_seconds (refresh_interval_seconds, () => {
            nm.scan_wifi.begin (null, (obj, res) => {
                try {
                    nm.scan_wifi.end (res);
                    periodic_scan_failure_reported = false;
                } catch (Error e) {
                    string message = e.message;
                    on_log ("wifi_scan: periodic request failed error=" + message + "; outcome=continuing");
                    if (!periodic_scan_failure_reported) {
                        log_warn (
                            "gui",
                            "wifi_scan: periodic request failed; outcome=continuing (additional failures muted until" +
                                "recovery)"
                        );
                        periodic_scan_failure_reported = true;
                    }
                }
            });

            // Keep periodic polling as a fallback when D-Bus signal subscription is unavailable.
            if (!nm_events_subscription_enabled) {
                on_refresh_all ();
            }
            return true;
        });
    }

    public void refresh_after_action (bool request_wifi_scan) {
        wifi_controller.refresh_after_action (
            nm,
            request_wifi_scan
        );
    }

    public void refresh_switch_states (Gtk.Switch wifi_switch, Gtk.Switch networking_switch) {
        wifi_controller.refresh_switch_states (
            nm,
            wifi_switch,
            networking_switch
        );
    }

    public void stop () {
        if (signal_refresh_source_id != 0) {
            Source.remove (signal_refresh_source_id);
            signal_refresh_source_id = 0;
        }

        if (nm_events_changed_handler_id != 0) {
            SignalHandler.disconnect (nm, nm_events_changed_handler_id);
            nm_events_changed_handler_id = 0;
        }

        nm.unsubscribe_network_events ();
        nm_events_subscription_enabled = false;

        if (periodic_refresh_source_id != 0) {
            Source.remove (periodic_refresh_source_id);
            periodic_refresh_source_id = 0;
        }
    }

    private void schedule_signal_refresh () {
        if (signal_refresh_source_id != 0) {
            return;
        }

        signal_refresh_source_id = Timeout.add (200, () => {
            signal_refresh_source_id = 0;
            on_refresh_all ();
            return false;
        });
    }

    private void configure_nm_signal_refresh () {
        nm.subscribe_network_events_dbus.begin (null, (obj, res) => {
            try {
                nm_events_subscription_enabled = nm.subscribe_network_events_dbus.end (res);
            } catch (Error e) {
                nm_events_subscription_enabled = false;
                on_log ("nm_events_subscribe: failed error=" + e.message + "; outcome=polling fallback");
                log_warn ("gui", "nm_events_subscribe: failed; outcome=polling fallback enabled");
                return;
            }
            if (!nm_events_subscription_enabled) {
                on_log ("nm_events_subscribe: unavailable; outcome=polling fallback");
                log_warn ("gui", "nm_events_subscribe: unavailable; outcome=polling fallback enabled");
                return;
            }

            nm_events_changed_handler_id = nm.network_events_changed.connect (() => {
                schedule_signal_refresh ();
            });

            log_info ("gui", "nm_events_subscribe: enabled signal-driven refresh");
        });
    }
}
