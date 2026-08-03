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

public class WifiScannerService : GLib.Object {
    private NetworkManagerClient core;

    public WifiScannerService (NetworkManagerClient core) {
        this.core = core;
    }

    public async WifiScanData scan_networks (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var devices = client.get_devices ();
        var connections = client.get_connections ();

        var networks_map = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        var devices_out = new List<NetworkDevice> ();
        string primary_wifi_device_path = "";

        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi == false) continue;

            var wifidev = (NM.DeviceWifi) dev;
            var active_ap = wifidev.get_active_access_point ();
            if (primary_wifi_device_path == "") {
                primary_wifi_device_path = ((NM.Object)dev).get_path ();
            }

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

                var valid_conns = ap.filter_connections (connections);
                if (valid_conns != null && valid_conns.length > 0) {
                    foreach (var candidate in valid_conns) {
                        var conn = (NM.Connection) candidate;
                        try {
                            if (!wifidev.connection_compatible (conn)) {
                                continue;
                            }
                        } catch (GLib.Error compat_err) {
                            continue;
                        }
                        saved = true;
                        saved_uuid = conn.get_uuid ();
                        var s_conn = conn.get_setting_connection ();
                        if (s_conn != null) {
                            autoconnect = s_conn.autoconnect;
                        }
                        break;
                    }
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
                    device_path = ((NM.Object)dev).get_path (),
                    ap_path = ((NM.Object)ap).get_path (),
                    bssid = ap.get_bssid (),
                    frequency_mhz = ap.get_frequency (),
                    max_bitrate_kbps = ap.get_max_bitrate (),
                    mode = HyprNetworkManager.Backend.Mappers.WifiSecurityMapper.map_mode (ap.get_mode ()),
                    security = HyprNetworkManager.Backend.Mappers.WifiSecurityMapper.map_capabilities (
                        ap.get_flags (),
                        ap.get_wpa_flags (),
                        ap.get_rsn_flags ()
                    )
                };

                string network_key = net.network_key;

                // Deduplicate by network_key, keeping the best signal but prioritizing saved networks
                if (!networks_map.contains (network_key)) {
                    networks_map.insert (network_key, net);
                } else {
                    var existing = networks_map.get (network_key);
                    if (net.connected) {
                        networks_map.insert (network_key, net);
                    } else if (!existing.connected) {
                        if (net.saved && !existing.saved) {
                            networks_map.insert (network_key, net);
                        } else if (net.saved == existing.saved && net.signal > existing.signal) {
                            networks_map.insert (network_key, net);
                        }
                    }
                }
            }
        }

        string primary_active_uuid = "";
        if (primary_wifi_device_path != "") {
            var primary_wifi_device = client.get_device_by_path (primary_wifi_device_path);
            if (primary_wifi_device != null) {
                var ac = primary_wifi_device.get_active_connection ();
                if (ac != null) {
                    primary_active_uuid = ac.get_uuid ();
                }
            }
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
        var client = core.nm_client;
        var devices = client.get_devices ();
        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi) {
                yield ((NM.DeviceWifi) dev).request_scan_async (cancellable);
                return true;
            }
        }
        return true;
    }
}
