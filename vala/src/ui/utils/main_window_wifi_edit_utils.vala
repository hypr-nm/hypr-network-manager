using GLib;
using Gtk;

public class MainWindowWifiEditUtils : Object {
    public static string get_selected_ipv4_method(Gtk.DropDown dropdown) {
        switch (dropdown.get_selected()) {
        case 1:
            return "manual";
        case 2:
            return "disabled";
        case 0:
        default:
            return "auto";
        }
    }

    public static bool try_parse_prefix(string prefix_text, out uint32 ipv4_prefix, out string error_message) {
        ipv4_prefix = 0;
        error_message = "";

        string trimmed = prefix_text.strip();
        if (trimmed == "") {
            return true;
        }

        uint parsed_prefix;
        if (!uint.try_parse(trimmed, out parsed_prefix) || parsed_prefix > 32) {
            error_message = "IPv4 prefix must be a number between 0 and 32.";
            return false;
        }

        ipv4_prefix = (uint32) parsed_prefix;
        return true;
    }

    public static string[] parse_dns_csv(string dns_csv) {
        string[] dns_servers = {};
        foreach (string token in dns_csv.split(",")) {
            string item = token.strip();
            if (item != "") {
                dns_servers += item;
            }
        }
        return dns_servers;
    }
}