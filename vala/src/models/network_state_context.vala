namespace HyprNetworkManager.Models {

    /**
     * Context holding the volatile state dictionaries for Wi-Fi connections.
     */
    public class NetworkStateContext : Object {
        public HashTable<string, bool> pending_wifi_connect { get; private set; }
        public HashTable<string, bool> pending_wifi_seen_connecting { get; private set; }
        public HashTable<string, bool> active_wifi_connections { get; private set; }

        public NetworkStateContext() {
            pending_wifi_connect = new HashTable<string, bool>(str_hash, str_equal);
            pending_wifi_seen_connecting = new HashTable<string, bool>(str_hash, str_equal);
            active_wifi_connections = new HashTable<string, bool>(str_hash, str_equal);
        }

        public void mark_wifi_connecting(string ssid_or_key) {
            pending_wifi_connect.insert(ssid_or_key, true);
        }

        public void mark_wifi_seen_connecting(string ssid_or_key) {
            pending_wifi_seen_connecting.insert(ssid_or_key, true);
        }

        public void clear_wifi_connecting(string ssid_or_key) {
            pending_wifi_connect.remove(ssid_or_key);
            pending_wifi_seen_connecting.remove(ssid_or_key);
        }

        public bool is_wifi_connecting(string ssid_or_key) {
            return pending_wifi_connect.contains(ssid_or_key);
        }

        public void update_active_connections(GLib.GenericArray<NM.ActiveConnection> active_connections) {
            active_wifi_connections.remove_all();
            for (uint i = 0; i < active_connections.length; i++) {
                var conn = active_connections.get(i);
                if (conn.get_connection_type() == "802-11-wireless" || conn.get_connection_type() == "wifi") {
                    if (conn.get_state() == NM.ActiveConnectionState.ACTIVATED) {
                        active_wifi_connections.insert(conn.get_id(), true);
                    }
                }
            }
        }
    }
}