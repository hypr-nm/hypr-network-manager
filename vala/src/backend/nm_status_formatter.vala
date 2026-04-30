using GLib;

public class NmStatusFormatter : GLib.Object {
    public static void pick_status_fields (
        bool networking_on,
        bool wifi_on,
        NetworkDevice? active_wifi,
        NetworkDevice? active_eth,
        uint wifi_signal,
        out string text,
        out string alt,
        out string tooltip,
        out string klass,
        out int percentage
    ) {
        percentage = 0;

        if (!networking_on) {
            text = _("Offline");
            alt = "offline";
            tooltip = _("Networking is disabled");
            klass = "offline";
            return;
        }

        if (active_eth != null) {
            text = active_eth.connection != "" ? active_eth.connection : _("Ethernet");
            alt = "ethernet";
            tooltip = _("Ethernet: %s").printf (active_eth.name);
            klass = "ethernet";
            percentage = 100;
            return;
        }

        if (active_wifi != null) {
            text = active_wifi.connection != "" ? active_wifi.connection : _("WiFi");
            alt = "wifi";
            tooltip = _("WiFi: %s (%d%%)\nDevice: %s").printf (text, (int) wifi_signal, active_wifi.name);
            klass = "wifi";
            percentage = (int) wifi_signal;
            return;
        }

        if (!wifi_on) {
            text = _("WiFi Off");
            alt = "wifi-off";
            tooltip = _("WiFi is disabled");
            klass = "wifi-off";
            return;
        }

        text = _("Disconnected");
        alt = "disconnected";
        tooltip = _("Not connected to any network");
        klass = "disconnected";
    }

    public static string build_status_json (string text, string alt, string tooltip, string klass, int percentage) {
        var builder = new Json.Builder ();
        builder.begin_object ();
        builder.set_member_name ("text");
        builder.add_string_value (text);
        builder.set_member_name ("alt");
        builder.add_string_value (alt);
        builder.set_member_name ("tooltip");
        builder.add_string_value (tooltip);
        builder.set_member_name ("class");
        builder.add_string_value (klass);
        builder.set_member_name ("percentage");
        builder.add_int_value (percentage);
        builder.end_object ();

        var generator = new Json.Generator ();
        generator.set_root (builder.get_root ());
        return generator.to_data (null);
    }
}
