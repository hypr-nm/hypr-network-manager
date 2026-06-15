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
using Gtk;
using HyprNetworkManager.UI.Interfaces;

public class MainWindowRefreshCoordinator : Object {
    private NetworkManagerClient nm;
    private MainWindowWifiController wifi_controller;
    private uint refresh_interval_seconds;
    private IWindowHost host;

    private uint periodic_refresh_source_id = 0;
    private uint signal_refresh_source_id = 0;
    private ulong nm_events_changed_handler_id = 0;
    private bool nm_events_subscription_enabled = false;
    private bool periodic_scan_failure_reported = false;

    public MainWindowRefreshCoordinator (
        NetworkManagerClient nm,
        MainWindowWifiController wifi_controller,
        uint refresh_interval_seconds,
        IWindowHost host
    ) {
        this.nm = nm;
        this.wifi_controller = wifi_controller;
        this.refresh_interval_seconds = refresh_interval_seconds;
        this.host = host;
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
                    host.debug_log ("wifi_scan: periodic request failed error=" + message + "; outcome=continuing");
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
                host.refresh_all ();
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

    public void refresh_switch_states (Gtk.Switch wifi_switch) {
        wifi_controller.refresh_switch_states (
            nm,
            wifi_switch
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
            host.refresh_all ();
            return false;
        });
    }

    private void configure_nm_signal_refresh () {
        nm.subscribe_network_events_dbus.begin (null, (obj, res) => {
            try {
                nm_events_subscription_enabled = nm.subscribe_network_events_dbus.end (res);
            } catch (Error e) {
                nm_events_subscription_enabled = false;
                host.debug_log ("nm_events_subscribe: failed error=" + e.message + "; outcome=polling fallback");
                log_warn ("gui", "nm_events_subscribe: failed; outcome=polling fallback enabled");
                return;
            }
            if (!nm_events_subscription_enabled) {
                host.debug_log ("nm_events_subscribe: unavailable; outcome=polling fallback");
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
