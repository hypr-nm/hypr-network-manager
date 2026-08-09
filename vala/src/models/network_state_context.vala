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
namespace HyprNetworkManager.Models {

    /**
     * Context holding the volatile state dictionaries for Wi-Fi connections.
     */
    public class NetworkStateContext : Object {
        public HashTable<string, bool> pending_wifi_connect { get; private set; }
        public HashTable<string, bool> pending_wifi_seen_connecting { get; private set; }
        public HashTable<string, string> pending_wifi_device_paths { get; private set; }
        public HashTable<string, bool> active_wifi_connections { get; private set; }
        public HashTable<string, string> wifi_errors { get; private set; }
        public HashTable<string, string> ethernet_errors { get; private set; }
        public HashTable<string, string> vpn_errors { get; private set; }

        public NetworkStateContext () {
            pending_wifi_connect = new HashTable<string, bool> (str_hash, str_equal);
            pending_wifi_seen_connecting = new HashTable<string, bool> (str_hash, str_equal);
            pending_wifi_device_paths = new HashTable<string, string> (str_hash, str_equal);
            active_wifi_connections = new HashTable<string, bool> (str_hash, str_equal);
            wifi_errors = new HashTable<string, string> (str_hash, str_equal);
            ethernet_errors = new HashTable<string, string> (str_hash, str_equal);
            vpn_errors = new HashTable<string, string> (str_hash, str_equal);
        }

        public void mark_wifi_connecting (string ssid_or_key, string device_path = "") {
            wifi_errors.remove (ssid_or_key);
            pending_wifi_connect.insert (ssid_or_key, true);
            if (device_path != "") {
                pending_wifi_device_paths.insert (ssid_or_key, device_path);
            } else {
                pending_wifi_device_paths.remove (ssid_or_key);
            }
        }

        public void mark_wifi_error (string ssid_or_key, string error) {
            wifi_errors.insert (ssid_or_key, error);
        }

        public void clear_wifi_error (string ssid_or_key) {
            wifi_errors.remove (ssid_or_key);
        }

        public void clear_all_wifi_errors () {
            wifi_errors.remove_all ();
        }

        public void mark_ethernet_error (string iface_name, string error) {
            ethernet_errors.insert (iface_name, error);
        }

        public void clear_ethernet_error (string iface_name) {
            ethernet_errors.remove (iface_name);
        }

        public void mark_vpn_error (string vpn_name, string error) {
            vpn_errors.insert (vpn_name, error);
        }

        public void clear_vpn_error (string vpn_name) {
            vpn_errors.remove (vpn_name);
        }

        public void mark_wifi_seen_connecting (string ssid_or_key) {
            pending_wifi_seen_connecting.insert (ssid_or_key, true);
        }

        public void clear_wifi_connecting (string ssid_or_key) {
            pending_wifi_connect.remove (ssid_or_key);
            pending_wifi_seen_connecting.remove (ssid_or_key);
            pending_wifi_device_paths.remove (ssid_or_key);
        }

        public bool is_wifi_connecting (string ssid_or_key) {
            return pending_wifi_connect.contains (ssid_or_key);
        }
    }
}
