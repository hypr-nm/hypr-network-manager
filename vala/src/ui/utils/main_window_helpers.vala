using GLib;
using Gtk;
using Gdk;

public class MainWindowHelpers : Object {
    public static Gtk.Button build_back_button(MainWindowActionCallback on_back) {
        var back_btn = new Gtk.Button();
        back_btn.add_css_class("nm-button");
        back_btn.add_css_class("nm-nav-back");

        var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var icon = new Gtk.Image.from_icon_name("go-previous-symbolic");
        icon.set_pixel_size(14);
        icon.add_css_class("nm-back-icon");

        var label = new Gtk.Label("Back");
        label.add_css_class("nm-back-label");

        content.append(icon);
        content.append(label);
        back_btn.set_child(content);

        back_btn.clicked.connect(() => {
            on_back();
        });

        return back_btn;
    }

    public static void clear_listbox(Gtk.ListBox? listbox) {
        if (listbox == null) {
            return;
        }

        Gtk.Widget? child = listbox.get_first_child();
        while (child != null) {
            Gtk.Widget? next = child.get_next_sibling();
            listbox.remove(child);
            child = next;
        }
    }

    public static void clear_box(Gtk.Box? box) {
        if (box == null) {
            return;
        }

        Gtk.Widget? child = box.get_first_child();
        while (child != null) {
            Gtk.Widget? next = child.get_next_sibling();
            box.remove(child);
            child = next;
        }
    }

    public static string get_mode_label(uint32 mode) {
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

    public static int get_channel_from_frequency(uint32 frequency_mhz) {
        if (frequency_mhz >= 2412 && frequency_mhz <= 2484) {
            return (int) ((frequency_mhz - 2407) / 5);
        }
        if (frequency_mhz >= 5000) {
            return (int) ((frequency_mhz - 5000) / 5);
        }
        return 0;
    }

    public static string get_signal_bars(uint8 signal) {
        return WifiSignalLevels.get_bars(signal);
    }

    public static bool icon_exists(string icon_name) {
        var display = Gdk.Display.get_default();
        if (display == null) {
            return false;
        }

        var icon_theme = Gtk.IconTheme.get_for_display(display);
        return icon_theme.has_icon(icon_name);
    }

    public static string get_secured_signal_icon_name(uint8 signal) {
        return WifiSignalLevels.get_secured_icon_name(signal);
    }

    public static string resolve_wifi_row_icon_name(WifiNetwork net) {
        if (!net.is_secured) {
            return net.signal_icon_name;
        }

        string secure_signal_icon = get_secured_signal_icon_name(net.signal);
        if (icon_exists(secure_signal_icon)) {
            return secure_signal_icon;
        }

        if (icon_exists("network-wireless-encrypted-symbolic")) {
            return "network-wireless-encrypted-symbolic";
        }

        return net.signal_icon_name;
    }

    public static Gtk.Widget build_details_row(string key, string value) {
        var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
        row.add_css_class("nm-details-row");
        row.add_css_class("nm-details-item");

        var key_label = new Gtk.Label(key);
        key_label.set_xalign(0.0f);
        key_label.set_halign(Gtk.Align.START);
        key_label.set_hexpand(false);
        key_label.add_css_class("nm-details-key");
        key_label.add_css_class("nm-details-item-key");

        var value_label = new Gtk.Label(value);
        value_label.set_xalign(0.0f);
        value_label.set_halign(Gtk.Align.START);
        value_label.set_wrap(true);
        value_label.add_css_class("nm-details-value");
        value_label.add_css_class("nm-details-item-value");

        row.append(key_label);
        row.append(value_label);
        return row;
    }

    public static Gtk.Widget build_details_section(string title, out Gtk.Box rows_container) {
        var section = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        section.add_css_class("nm-details-section");

        var heading = new Gtk.Label(title);
        heading.set_xalign(0.5f);
        heading.add_css_class("nm-details-group-title");
        section.append(heading);

        var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        separator.add_css_class("nm-separator");
        section.append(separator);

        rows_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        rows_container.add_css_class("nm-details-rows");
        section.append(rows_container);

        return section;
    }

    public static string get_ipv4_method_label(string method) {
        switch (method.strip().down()) {
        case "manual":
            return "Manual";
        case "disabled":
            return "Disabled";
        case "auto":
        default:
            return "Automatic (DHCP)";
        }
    }

    public static string get_ipv6_method_label(string method) {
        switch (method.strip().down()) {
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

    public static uint get_ipv4_method_dropdown_index(string method) {
        switch (method.strip().down()) {
        case "manual":
            return 1;
        case "disabled":
            return 2;
        case "auto":
        default:
            return 0;
        }
    }

    public static uint get_ipv6_method_dropdown_index(string method) {
        switch (method.strip().down()) {
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

    public static string format_ip_with_prefix(string address, uint32 prefix) {
        string ip = address.strip();
        if (ip == "") {
            return "n/a";
        }
        if (prefix > 0) {
            return "%s/%u".printf(ip, prefix);
        }
        return ip;
    }

    public static string get_band_label(uint32 frequency_mhz) {
        if (frequency_mhz >= 2400 && frequency_mhz < 2500) {
            return "2.4 GHz";
        }
        if (frequency_mhz >= 5000 && frequency_mhz < 6000) {
            return "5 GHz";
        }
        return "";
    }
}