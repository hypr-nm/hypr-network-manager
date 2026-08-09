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

public class Nl80211ApMonitor : GLib.Object {
    private enum Query {
        ACTIVE,
        STATION_COUNT
    }

    public static async void async_sleep (uint ms) {
        Timeout.add (ms, () => {
            async_sleep.callback ();
            return false;
        });
        yield;
    }

    public async int query_active (string iface, Cancellable? cancellable = null) throws Error {
        return yield run_query (iface, Query.ACTIVE, cancellable);
    }

    public async int query_station_count (string iface, Cancellable? cancellable = null) throws Error {
        return yield run_query (iface, Query.STATION_COUNT, cancellable);
    }

    private async int run_query (
        string iface,
        Query query,
        Cancellable? cancellable
    ) throws Error {
        if (iface == "") {
            throw new IOError.INVALID_ARGUMENT ("Wi-Fi interface is empty");
        }

        int result = -1;
        int value = 0;
        SourceFunc resume = run_query.callback;
        MainContext caller_context = MainContext.ref_thread_default ();

        new Thread<void*> ("nl80211-ap-query", () => {
            try {
                if (query == Query.ACTIVE) {
                    result = Nl80211.ap_active_by_iface (iface, out value);
                } else {
                    result = Nl80211.ap_station_count_by_iface (iface, out value);
                }
            } finally {
                caller_context.invoke ((owned) resume);
            }
            return null;
        });

        yield;

        if (cancellable != null && cancellable.is_cancelled ()) {
            throw new IOError.CANCELLED ("nl80211 AP query was cancelled");
        }
        if (result != 0) {
            throw new IOError.FAILED (
                "nl80211 AP query failed for interface '%s'".printf (iface));
        }
        return value;
    }

    public async bool wait_until_ap_active (
        string iface,
        uint timeout_ms = Timeouts.AP_ACTIVATION_TIMEOUT_MS,
        Cancellable? cancellable = null
    ) throws Error {
        if (iface == "") {
            return false;
        }

        uint elapsed = 0;
        const uint step = Timeouts.AP_MONITOR_POLL_INTERVAL_MS;
        while (elapsed < timeout_ms) {
            try {
                if ((yield query_active (iface, cancellable)) != 0) {
                    return true;
                }
            } catch (IOError.CANCELLED e) {
                throw e;
            } catch (Error e) {
                log_debug ("nl80211-ap-monitor", "AP-state query failed: " + e.message);
            }

            yield async_sleep (step);
            elapsed += step;
        }
        return false;
    }
}
