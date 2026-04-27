using GLib;
using Gtk;

namespace MainWindowWifiEditUtils {
    public string get_selected_ipv4_method (HyprNetworkManager.UI.Widgets.TrackedDropDown dropdown) {
        switch (dropdown.get_selected ()) {
        case 1:
            return "manual";
        case 2:
            return "disabled";
        case 0:
        default:
            return "auto";
        }
    }

    public string get_selected_ipv6_method (HyprNetworkManager.UI.Widgets.TrackedDropDown dropdown) {
        switch (dropdown.get_selected ()) {
        case 1:
            return "manual";
        case 2:
            return "disabled";
        case 3:
            return "ignore";
        case 0:
        default:
            return "auto";
        }
    }

    public bool try_parse_prefix (string prefix_text, out uint32 ipv4_prefix, out string error_message) {
        ipv4_prefix = 0;
        error_message = "";

        string trimmed = prefix_text.strip ();
        if (trimmed == "") {
            return true;
        }

        uint parsed_prefix;
        if (!uint.try_parse (trimmed, out parsed_prefix) || parsed_prefix > 32) {
            error_message = "IPv4 prefix must be a number between 0 and 32.";
            return false;
        }

        ipv4_prefix = (uint32) parsed_prefix;
        return true;
    }

    public bool try_parse_ipv6_prefix (string prefix_text, out uint32 ipv6_prefix, out string error_message) {
        ipv6_prefix = 0;
        error_message = "";

        string trimmed = prefix_text.strip ();
        if (trimmed == "") {
            return true;
        }

        uint parsed_prefix;
        if (!uint.try_parse (trimmed, out parsed_prefix) || parsed_prefix > 128) {
            error_message = "IPv6 prefix must be a number between 0 and 128.";
            return false;
        }

        ipv6_prefix = (uint32) parsed_prefix;
        return true;
    }

    public string[] parse_dns_csv (string dns_csv) {
        string[] dns_servers = {};
        foreach (string token in dns_csv.split (",")) {
            string item = token.strip ();
            if (item != "") {
                dns_servers += item;
            }
        }
        return dns_servers;
    }
}
