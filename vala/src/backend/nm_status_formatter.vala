using GLib;

public class NmStatusFormatter : Object {
    public static void pick_status_fields(
        bool networking_on,
        bool wifi_on,
        NetworkDevice? active_wifi,
        NetworkDevice? active_eth,
        uint wifi_signal,
        out string text,
        out string alt,
        out string tooltip,
        out string klass
    ) {
        if (!networking_on) {
            text = "NET-OFF";
            alt = "Offline";
            tooltip = "Networking is disabled";
            klass = "offline";
            return;
        }

        if (active_eth != null) {
            text = "ETH";
            alt = active_eth.connection != "" ? active_eth.connection : "Ethernet";
            tooltip = "Ethernet: " + active_eth.name;
            klass = "ethernet";
            return;
        }

        if (active_wifi != null) {
            text = "WIFI";
            alt = active_wifi.connection != "" ? active_wifi.connection : "WiFi";
            tooltip = "WiFi: " + alt + " (" + wifi_signal.to_string() + "%)\\nDevice: " + active_wifi.name;
            klass = "wifi";
            return;
        }

        if (!wifi_on) {
            text = "WIFI-OFF";
            alt = "WiFi Off";
            tooltip = "WiFi is disabled";
            klass = "wifi-off";
            return;
        }

        text = "DISCONNECTED";
        alt = "Disconnected";
        tooltip = "Not connected to any network";
        klass = "disconnected";
    }

    public static string build_status_json(string text, string alt, string tooltip, string klass) {
        return "{\"text\":\"%s\",\"alt\":\"%s\",\"tooltip\":\"%s\",\"class\":\"%s\"}".printf(
            NmClientUtils.json_escape(text),
            NmClientUtils.json_escape(alt),
            NmClientUtils.json_escape(tooltip),
            NmClientUtils.json_escape(klass)
        );
    }
}