using Gtk;
using Gdk;

namespace MainWindowHelpers {
    public string safe_text (string? value) {
        return value != null ? value : "";
    }

    public string display_text_or_na (string? value) {
        string normalized = safe_text (value).strip ();
        return normalized != "" ? normalized : "n/a";
    }

    public string get_mode_label (uint32 mode) {
        switch (mode) {
        case 1:
            return "Ad-hoc";
        case 2:
            return "Infrastructure";
        case 3:
            return "Access Point";
        default:
            return "Unknown";
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
        if (!net.is_secured) {
            return net.signal_icon_name;
        }

        string secure_signal_icon = get_secured_signal_icon_name (net.signal);
        if (icon_exists (secure_signal_icon)) {
            return secure_signal_icon;
        }

        if (icon_exists ("network-wireless-encrypted-symbolic")) {
            return "network-wireless-encrypted-symbolic";
        }

        return net.signal_icon_name;
    }

    public string get_ipv4_method_label (string? method) {
        switch (safe_text (method).strip ().down ()) {
        case "manual":
            return "Manual";
        case "disabled":
            return "Disabled";
        case "auto":
        default:
            return "Automatic (DHCP)";
        }
    }

    public string get_ipv6_method_label (string? method) {
        switch (safe_text (method).strip ().down ()) {
        case "manual":
            return "Manual";
        case "disabled":
            return "Disabled";
        case "ignore":
            return "Ignore";
        case "dhcp":
            return "DHCPv6";
        case "link-local":
            return "Link-local";
        case "shared":
            return "Shared";
        case "auto":
        default:
            return "Automatic";
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
            return "n/a";
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
