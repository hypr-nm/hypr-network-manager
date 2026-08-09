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

private class WifiNetworkCandidateGroup : GLib.Object {
    public List<WifiNetwork> candidates = new List<WifiNetwork> ();
}

public class WifiScannerService : GLib.Object {
    private NM.Client client;

    public WifiScannerService (NM.Client client) {
        this.client = client;
    }

    private static int candidate_preference_rank (WifiNetwork candidate) {
        if (candidate.connected) {
            return 0;
        }
        if (candidate.device_is_available
            && !candidate.device_is_connecting
            && !candidate.device_is_connected) {
            return 1;
        }
        if (candidate.device_is_available && !candidate.device_is_connecting) {
            return 2;
        }
        if (candidate.device_is_connecting) {
            return 3;
        }
        return 4;
    }

    private static int compare_candidates (WifiNetwork a, WifiNetwork b) {
        int rank_cmp = candidate_preference_rank (a) - candidate_preference_rank (b);
        if (rank_cmp != 0) {
            return rank_cmp;
        }
        if (a.saved != b.saved) {
            return a.saved ? -1 : 1;
        }
        if (a.signal != b.signal) {
            return (int) b.signal - (int) a.signal;
        }

        string device_a = a.device_name != null ? a.device_name : "";
        string device_b = b.device_name != null ? b.device_name : "";
        int device_cmp = device_a.collate (device_b);
        if (device_cmp != 0) {
            return device_cmp;
        }
        string bssid_a = a.bssid != null ? a.bssid : "";
        string bssid_b = b.bssid != null ? b.bssid : "";
        return bssid_a.collate (bssid_b);
    }

    private static WifiNetwork build_group_network (WifiNetworkCandidateGroup group) {
        group.candidates.sort (compare_candidates);

        var candidates = new WifiNetwork[group.candidates.length ()];
        int index = 0;
        foreach (var candidate in group.candidates) {
            candidates[index++] = candidate;
        }

        var display = candidates[0];
        return new WifiNetwork () {
            ssid = display.ssid,
            saved_connection_uuid = display.saved_connection_uuid,
            signal = display.signal,
            connected = display.connected,
            is_hidden = display.is_hidden,
            saved = display.saved,
            autoconnect = display.autoconnect,
            device_name = display.device_name,
            device_path = display.device_path,
            device_is_connected = display.device_is_connected,
            device_is_connecting = display.device_is_connecting,
            device_is_available = display.device_is_available,
            device_connection = display.device_connection,
            ap_path = display.ap_path,
            bssid = display.bssid,
            frequency_mhz = display.frequency_mhz,
            max_bitrate_kbps = display.max_bitrate_kbps,
            mode = display.mode,
            security = display.security,
            radio_candidates = candidates
        };
    }

    public async WifiScanData scan_networks (Cancellable? cancellable = null) throws Error {
        var devices = client.get_devices ();
        var connections = client.get_connections ();

        var per_device_networks = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        var devices_out = new List<NetworkDevice> ();

        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi == false) continue;

            var wifidev = (NM.DeviceWifi) dev;
            var active_ap = wifidev.get_active_access_point ();

            var d = HyprNetworkManager.Backend.Mappers.DeviceMapper.map_device (dev);
            devices_out.append (d);

            var aps = wifidev.get_access_points ();
            uint hidden_total = 0;
            foreach (var ap in aps) {
                var ssid_bytes = ap.get_ssid ();
                if (ssid_bytes == null || NM.Utils.is_empty_ssid (ssid_bytes.get_data ())) {
                    hidden_total++;
                }
            }

            uint hidden_index = 0;
            foreach (var ap in aps) {
                var ssid_bytes = ap.get_ssid ();
                string ssid = NmWifiUtils.bytes_to_ssid (ssid_bytes);

                bool is_hidden = ssid_bytes == null || NM.Utils.is_empty_ssid (ssid_bytes.get_data ());

                if (is_hidden) {
                    hidden_index++;
                    if (hidden_total > 1) {
                        ssid = _("Hidden network %u").printf (hidden_index);
                    } else {
                        ssid = "Hidden network";
                    }
                }

                                bool saved = false;
                string saved_uuid = "";
                bool autoconnect = true;

                var caps = HyprNetworkManager.Backend.Mappers.WifiSecurityMapper.map_capabilities (
                    ap.get_flags (),
                    ap.get_wpa_flags (),
                    ap.get_rsn_flags ()
                );

                // Bind the first profile valid for this AP, mirroring nmtui
                // (nm_device_connection_valid + nm_access_point_connection_valid).
                // We walk the connection list ourselves rather than calling
                // ap.filter_connections() because libnm documents its transfer
                // annotation as unreliable for language bindings.
                foreach (var candidate in connections) {
                    try {
                        if (!wifidev.connection_compatible (candidate)) {
                            continue;
                        }
                    } catch (GLib.Error compat_err) {
                        continue;
                    }
                    if (!ap.connection_valid (candidate)) {
                        continue;
                    }
                    // Guard: libnm deliberately lets a WPA2-PSK profile activate
                    // against a WPA3-SAE-only AP, but that times out on many
                    // radios. Skip just that one lenient case; everything else
                    // is already decided by ap.connection_valid() above.
                    if (caps.supports_sae && !caps.supports_psk
                        && NmWifiUtils.connection_key_mgmt (candidate) == WifiKeyMgmt.WPA_PSK) {
                        continue;
                    }
                    saved = true;
                    saved_uuid = candidate.get_uuid ();
                    var s_conn = candidate.get_setting_connection ();
                    if (s_conn != null) {
                        autoconnect = s_conn.autoconnect;
                    }
                    break;
                }

                bool connected = (active_ap != null && active_ap.get_path () == ap.get_path ());

                var net = new WifiNetwork () {
                    ssid = ssid,
                    saved_connection_uuid = saved_uuid,
                    signal = ap.get_strength (),
                    connected = connected,
                    is_hidden = is_hidden,
                    saved = saved,
                    autoconnect = autoconnect,
                    device_name = d.name,
                    device_path = ((NM.Object)dev).get_path (),
                    device_is_connected = d.is_connected,
                    device_is_connecting = d.is_connecting,
                    device_is_available = d.is_available,
                    device_connection = d.connection,
                    ap_path = ((NM.Object)ap).get_path (),
                    bssid = ap.get_bssid (),
                    frequency_mhz = ap.get_frequency (),
                    max_bitrate_kbps = ap.get_max_bitrate (),
                    mode = HyprNetworkManager.Backend.Mappers.WifiSecurityMapper.map_mode (ap.get_mode ()),
                    security = caps
                };

                string network_key = net.network_key;
                string per_device_key = network_key + "\x1f" + net.device_path;

                // Keep the best AP for this network on each radio. Cross-radio
                // candidates are retained for the row's explicit radio picker.
                if (!per_device_networks.contains (per_device_key)
                    || compare_candidates (net, per_device_networks.get (per_device_key)) < 0) {
                    per_device_networks.insert (per_device_key, net);
                }
            }
        }

        var candidate_groups = new HashTable<string, WifiNetworkCandidateGroup> (str_hash, str_equal);
        var candidate_iter = HashTableIter<string, WifiNetwork> (per_device_networks);
        string candidate_key;
        WifiNetwork candidate;
        while (candidate_iter.next (out candidate_key, out candidate)) {
            string network_key = candidate.network_key;
            var group = candidate_groups.lookup (network_key);
            if (group == null) {
                group = new WifiNetworkCandidateGroup ();
                candidate_groups.insert (network_key, group);
            }
            group.candidates.append (candidate);
        }

        var networks_map = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        var group_iter = HashTableIter<string, WifiNetworkCandidateGroup> (candidate_groups);
        string group_key;
        WifiNetworkCandidateGroup group;
        while (group_iter.next (out group_key, out group)) {
            networks_map.insert (group_key, build_group_network (group));
        }

        // collapse entries that point to the same BSSID so hidden placeholders
        // do not appear alongside the actual connected network for the same AP.
        var deduped_map = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        var iter = HashTableIter<string, WifiNetwork> (networks_map);
        string k;
        WifiNetwork v;
        while (iter.next (out k, out v)) {
            string bssid = v.bssid != null ? v.bssid : "";
            string dedupe_key = bssid.strip ().down ();
            if (dedupe_key == "") {
                dedupe_key = "key:" + k;
            }

            if (!deduped_map.contains (dedupe_key)) {
                deduped_map.insert (dedupe_key, v);
                continue;
            }

            var existing = deduped_map.get (dedupe_key);
            bool replace = false;

            if (v.connected && !existing.connected) {
                replace = true;
            } else if (v.connected == existing.connected) {
                if (!v.is_hidden && existing.is_hidden) {
                    replace = true;
                } else if (v.is_hidden == existing.is_hidden) {
                    if (v.saved && !existing.saved) {
                        replace = true;
                    } else if (v.saved == existing.saved && v.signal > existing.signal) {
                        replace = true;
                    }
                }
            }

            if (replace) {
                deduped_map.insert (dedupe_key, v);
            }
        }

        var networks_list = new List<WifiNetwork> ();
        var deduped_iter = HashTableIter<string, WifiNetwork> (deduped_map);
        string dk;
        WifiNetwork dv;
        while (deduped_iter.next (out dk, out dv)) {
            networks_list.append (dv);
        }

        networks_list.sort ((a, b) => {
            if (a.connected != b.connected) {
                return a.connected ? -1 : 1;
            }
            if (a.saved != b.saved) {
                return a.saved ? -1 : 1;
            }

            // Bucket signal to 5% increments to avoid jitter from tiny changes
            int bucket_a = (int) (a.signal / 5);
            int bucket_b = (int) (b.signal / 5);
            if (bucket_a != bucket_b) {
                return bucket_b - bucket_a;
            }

            // Tie-breakers for deterministic order
            int ssid_cmp = a.ssid.collate (b.ssid);
            if (ssid_cmp != 0) {
                return ssid_cmp;
            }

            string bssid_a = a.bssid != null ? a.bssid : "";
            string bssid_b = b.bssid != null ? b.bssid : "";
            return bssid_a.collate (bssid_b);
        });

        var networks_arr = new WifiNetwork[networks_list.length ()];
        int i = 0;
        foreach (var net in networks_list) {
            networks_arr[i++] = net;
        }

        var devices_arr = new NetworkDevice[devices_out.length ()];
        i = 0;
        foreach (var d in devices_out) {
            devices_arr[i++] = d;
        }

        int num_wifi_devices = 0;
        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi) {
                num_wifi_devices++;
            }
        }

        return new WifiScanData (networks_arr, devices_arr, num_wifi_devices);
    }

    public async bool scan (Cancellable? cancellable = null) throws Error {
        var devices = client.get_devices ();
        uint wifi_devices = 0;
        uint successful_scans = 0;
        string last_error_message = "";

        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi == false) {
                continue;
            }
            wifi_devices++;
            try {
                yield ((NM.DeviceWifi) dev).request_scan_async (cancellable);
                successful_scans++;
            } catch (GLib.Error scan_err) {
                if (scan_err is IOError.CANCELLED
                    || (cancellable != null && cancellable.is_cancelled ())) {
                    throw scan_err;
                }
                last_error_message = scan_err.message;
                log_debug ("wifi-scanner-service",
                    "request_scan_async failed on %s: %s"
                        .printf (((NM.Object) dev).get_path (), scan_err.message));
            }
        }

        if (wifi_devices > 0 && successful_scans == 0) {
            throw new IOError.FAILED (
                last_error_message != ""
                    ? "Wi-Fi scan failed on all devices: " + last_error_message
                    : "Wi-Fi scan failed on all devices");
        }
        return true;
    }
}
