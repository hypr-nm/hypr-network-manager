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

using Constants;
using GLib;
using HyprNetworkManager.UI.Interfaces;

public class MainWindowRefreshCoordinator : Object {
    private const uint MIN_TIMER_DELAY_SECONDS = 1;
    private const string SCAN_REASON_PERIODIC = "periodic";
    private const string SCAN_REASON_PRESENTATION = "presentation";

    private HyprNetworkManager.Backend.INetworkEventClient nm;
    private uint refresh_interval_seconds;
    private IWindowHost host;

    private uint periodic_refresh_source_id = 0;
    private uint signal_refresh_source_id = 0;
    private ulong nm_events_changed_handler_id = 0;
    private Cancellable? subscription_cancellable = null;
    private bool nm_events_subscription_enabled = false;
    private bool scan_failure_reported = false;
    private bool wifi_scan_in_flight = false;
    private int64 last_wifi_scan_request_us = 0;
    private bool started = false;
    private uint lifecycle_epoch = 1;

    public MainWindowRefreshCoordinator (
        HyprNetworkManager.Backend.INetworkEventClient nm,
        uint refresh_interval_seconds,
        IWindowHost host
    ) {
        this.nm = nm;
        this.refresh_interval_seconds = refresh_interval_seconds;
        this.host = host;
    }

    public void start () {
        if (started) {
            return;
        }
        started = true;

        configure_nm_signal_refresh ();

        // Window mapping may be reported repeatedly across popup presentations.
        // The started guard makes that idempotent; this cleanup remains
        // defensive in case a source was externally removed or replaced.
        if (periodic_refresh_source_id != 0) {
            Source.remove (periodic_refresh_source_id);
            periodic_refresh_source_id = 0;
        }

        schedule_periodic_scan ();
    }

    private void schedule_periodic_scan () {
        if (!started || periodic_refresh_source_id != 0) {
            return;
        }

        uint delay_seconds = uint.max (
            refresh_interval_seconds,
            MIN_TIMER_DELAY_SECONDS);
        if (last_wifi_scan_request_us > 0) {
            int64 interval_us = (int64) delay_seconds * TimeSpan.SECOND;
            int64 elapsed_us = GLib.get_monotonic_time ()
                - last_wifi_scan_request_us;
            if (elapsed_us >= 0 && elapsed_us < interval_us) {
                int64 remaining_us = interval_us - elapsed_us;
                delay_seconds = (uint) int64.max (
                    MIN_TIMER_DELAY_SECONDS,
                    (remaining_us + TimeSpan.SECOND - 1)
                        / TimeSpan.SECOND);
            }
        }

        periodic_refresh_source_id = Timeout.add_seconds (delay_seconds, () => {
            periodic_refresh_source_id = 0;
            if (started) {
                request_scan_if_stale_for_reason (SCAN_REASON_PERIODIC);
                schedule_periodic_scan ();
            }
            return false;
        });
    }

    public static bool wifi_scan_is_stale (
        int64 last_request_us,
        int64 now_us,
        uint stale_after_seconds
    ) {
        if (last_request_us <= 0 || now_us < last_request_us) {
            return true;
        }
        return now_us - last_request_us
            >= ((int64) stale_after_seconds * TimeSpan.SECOND);
    }

    public void request_scan_if_stale () {
        request_scan_if_stale_for_reason (SCAN_REASON_PRESENTATION);
    }

    private void request_scan_if_stale_for_reason (string reason) {
        int64 now_us = GLib.get_monotonic_time ();
        if (!wifi_scan_is_stale (
                last_wifi_scan_request_us,
                now_us,
                refresh_interval_seconds)) {
            return;
        }
        request_wifi_scan (reason);
    }

    public void note_external_scan_request () {
        last_wifi_scan_request_us = GLib.get_monotonic_time ();
        if (periodic_refresh_source_id != 0) {
            Source.remove (periodic_refresh_source_id);
            periodic_refresh_source_id = 0;
        }
        schedule_periodic_scan ();
    }

    private void request_wifi_scan (string reason) {
        if (wifi_scan_in_flight) {
            return;
        }

        wifi_scan_in_flight = true;
        last_wifi_scan_request_us = GLib.get_monotonic_time ();
        nm.scan_wifi.begin (null, (obj, res) => {
            wifi_scan_in_flight = false;
            try {
                nm.scan_wifi.end (res);
                scan_failure_reported = false;
            } catch (Error e) {
                string message = e.message;
                host.debug_log (
                    "wifi_scan: %s request failed error=%s; outcome=continuing".printf (
                        reason,
                        message));
                if (!scan_failure_reported) {
                    log_warn (
                        "gui",
                        "wifi_scan: request failed; outcome=continuing (additional failures muted until recovery)"
                    );
                    scan_failure_reported = true;
                }
            }
            // Scan completion may not produce a distinct NM state signal, and
            // a failed scan must not suppress the polling fallback for other
            // device state. Reconcile the current snapshot quietly either way.
            host.refresh_all ();
        });
    }

    public void stop () {
        if (!started
            && periodic_refresh_source_id == 0
            && signal_refresh_source_id == 0
            && nm_events_changed_handler_id == 0
            && subscription_cancellable == null) {
            return;
        }

        started = false;
        lifecycle_epoch++;
        if (lifecycle_epoch == 0) {
            lifecycle_epoch = 1;
        }

        if (subscription_cancellable != null) {
            subscription_cancellable.cancel ();
            subscription_cancellable = null;
        }

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
        if (!started || signal_refresh_source_id != 0) {
            return;
        }

        signal_refresh_source_id = Timeout.add (
            Timeouts.NETWORK_EVENT_REFRESH_DEBOUNCE_MS,
            () => {
                signal_refresh_source_id = 0;
                if (started) {
                    host.refresh_all ();
                }
                return false;
            });
    }

    private void configure_nm_signal_refresh () {
        if (!started
            || nm_events_changed_handler_id != 0
            || subscription_cancellable != null) {
            return;
        }

        uint epoch = lifecycle_epoch;
        var request = new Cancellable ();
        subscription_cancellable = request;

        nm.subscribe_network_events_dbus.begin (request, (obj, res) => {
            bool subscription_enabled;
            try {
                subscription_enabled = nm.subscribe_network_events_dbus.end (res);
            } catch (Error e) {
                if (subscription_cancellable == request) {
                    subscription_cancellable = null;
                }
                if (e is IOError.CANCELLED
                    || request.is_cancelled ()
                    || !started
                    || epoch != lifecycle_epoch) {
                    return;
                }
                nm_events_subscription_enabled = false;
                host.debug_log ("nm_events_subscribe: failed error=" + e.message + "; outcome=polling fallback");
                log_warn ("gui", "nm_events_subscribe: failed; outcome=polling fallback enabled");
                return;
            }

            if (subscription_cancellable == request) {
                subscription_cancellable = null;
            }
            if (request.is_cancelled ()
                || !started
                || epoch != lifecycle_epoch) {
                if (!started && subscription_enabled) {
                    nm.unsubscribe_network_events ();
                }
                return;
            }

            nm_events_subscription_enabled = subscription_enabled;
            if (!nm_events_subscription_enabled) {
                host.debug_log ("nm_events_subscribe: unavailable; outcome=polling fallback");
                log_warn ("gui", "nm_events_subscribe: unavailable; outcome=polling fallback enabled");
                return;
            }

            if (nm_events_changed_handler_id == 0) {
                nm_events_changed_handler_id = nm.network_events_changed.connect (() => {
                    schedule_signal_refresh ();
                });
            }

            log_info ("gui", "nm_events_subscribe: enabled signal-driven refresh");
        });
    }
}
