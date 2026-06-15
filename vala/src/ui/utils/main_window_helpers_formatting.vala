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

using Gtk;
using Gdk;

namespace MainWindowHelpers {
    public string safe_text (string? value) {
        return value != null ? value : "";
    }

    public string display_text_or_na (string? value) {
        string normalized = safe_text (value).strip ();
        return normalized != "" ? normalized : _("n/a");
    }

    public string get_mode_label (uint32 mode) {
        switch (mode) {
        case 1:
            return _("Ad-hoc");
        case 2:
            return _("Infrastructure");
        case 3:
            return _("Access Point");
        default:
            return _("Unknown");
        }
    }

    public int get_channel_from_frequency (uint32 frequency_mhz) {
        if (frequency_mhz >= 2412 && frequency_mhz <= 2484) {
            return (int) ((frequency_mhz - 2407) / 5);
        }
        if (frequency_mhz >= 5000) {
            return (int) ((frequency_mhz - 5000) / 5);
        }
        return 0;
    }

    public string get_signal_bars (uint8 signal) {
        return WifiSignalLevels.get_bars (signal);
    }

    public bool icon_exists (string icon_name) {
        var display = Gdk.Display.get_default ();
        if (display == null) {
            return false;
        }

        var icon_theme = Gtk.IconTheme.get_for_display (display);
        return icon_theme.has_icon (icon_name);
    }

    public string get_secured_signal_icon_name (uint8 signal) {
        return WifiSignalLevels.get_secured_icon_name (signal);
    }

    public string resolve_wifi_row_icon_name (WifiNetwork net) {
        return net.signal_icon_name;
    }

    public string get_ipv4_method_label (string? method) {
        switch (safe_text (method).strip ().down ()) {
        case "manual":
            return _("Manual");
        case "disabled":
            return _("Disabled");
        case "auto":
        default:
            return _("Automatic (DHCP)");
        }
    }

    public string get_ipv6_method_label (string? method) {
        switch (safe_text (method).strip ().down ()) {
        case "manual":
            return _("Manual");
        case "disabled":
            return _("Disabled");
        case "ignore":
            return _("Ignore");
        case "dhcp":
            return _("DHCPv6");
        case "link-local":
            return _("Link-local");
        case "shared":
            return _("Shared");
        case "auto":
        default:
            return _("Automatic");
        }
    }

    public uint get_ipv4_method_dropdown_index (string? method) {
        switch (safe_text (method).strip ().down ()) {
        case "manual":
            return 1;
        case "disabled":
            return 2;
        case "auto":
        default:
            return 0;
        }
    }

    public uint get_ipv6_method_dropdown_index (string? method) {
        switch (safe_text (method).strip ().down ()) {
        case "manual":
            return 1;
        case "disabled":
            return 2;
        case "ignore":
            return 3;
        case "auto":
        default:
            return 0;
        }
    }

    public string format_ip_with_prefix (string? address, uint32 prefix) {
        string ip = safe_text (address).strip ();
        if (ip == "") {
            return _("n/a");
        }
        if (prefix > 0) {
            return "%s/%u".printf (ip, prefix);
        }
        return ip;
    }

    public string get_band_label (uint32 frequency_mhz) {
        if (frequency_mhz >= 2400 && frequency_mhz < 2500) {
            return "2.4 GHz";
        }
        if (frequency_mhz >= 5000 && frequency_mhz < 6000) {
            return "5 GHz";
        }
        return "";
    }
}
