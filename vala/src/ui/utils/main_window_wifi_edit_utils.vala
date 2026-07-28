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
            error_message = _("IPv4 prefix must be a number between 0 and 32.");
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
            error_message = _("IPv6 prefix must be a number between 0 and 128.");
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
