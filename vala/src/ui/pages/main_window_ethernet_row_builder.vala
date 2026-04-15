using GLib;
using Gtk;

public delegate void MainWindowEthernetDeviceCallback (NetworkDevice dev);
public delegate void MainWindowEthernetRefreshCallback ();

public class MainWindowEthernetRowBuilder {
    public static Gtk.ListBoxRow build_row (
        NetworkDevice dev,
        bool is_pending,
        bool can_connect,
        bool has_profile,
        owned MainWindowEthernetDeviceCallback on_open_details,
        owned MainWindowEthernetDeviceCallback on_trigger_toggle
    ) {
        var row = new Gtk.ListBoxRow ();
        row.add_css_class ("nm-device-row");
        if (dev.is_connected) {
            row.add_css_class ("connected");
        }

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
        content.add_css_class ("nm-row-content-inset");

        var icon = new Gtk.Image.from_icon_name ("network-wired-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {"nm-icon-size-16", "nm-icon-size"});
        MainWindowCssClassResolver.add_best_class (icon, {"nm-ethernet-icon", "nm-signal-icon"});
        content.append (icon);

        var info = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_INLINE);
        info.set_hexpand (true);
        var name_lbl = new Gtk.Label (dev.name);
        name_lbl.set_xalign (0.0f);
        name_lbl.add_css_class ("nm-ssid-label");
        info.append (name_lbl);

        string subtitle = dev.state_label;
        if (dev.connection != "") {
            subtitle = "%s (%s)".printf (dev.state_label, dev.connection);
        }
        var sub = new Gtk.Label (subtitle);
        sub.set_xalign (0.0f);
        sub.add_css_class ("nm-sub-label");
        info.append (sub);
        content.append (info);

        var details_btn = new Gtk.Button ();
        details_btn.add_css_class ("row-icon-action");
        MainWindowCssClassResolver.add_best_class (
            details_btn,
            {"row-icon-action", "nm-button"}
        );
        MainWindowCssClassResolver.add_best_class (details_btn, {"nm-details-open-button", "row-icon-action"});
        details_btn.set_tooltip_text ("Details");
        var details_icon = new Gtk.Image.from_icon_name ("document-properties-symbolic");
        details_btn.set_child (details_icon);
        details_btn.clicked.connect (() => {
            on_open_details (dev);
        });
        content.append (details_btn);

        string action_label;
        bool can_toggle = true;

        if (is_pending) {
            action_label = "Updating…";
            can_toggle = false;
        } else if (dev.is_connected) {
            action_label = "Disconnect";
        } else if (can_connect) {
            action_label = "Connect";
        } else if (has_profile) {
            action_label = "Unavailable";
            can_toggle = false;
        } else {
            action_label = "No Profile";
            can_toggle = false;
        }

        var action = new Gtk.Button.with_label (action_label);
        MainWindowCssClassResolver.add_best_class (
            action,
            {"row-link-action", "nm-button"}
        );
        action.add_css_class (dev.is_connected ? "nm-disconnect-button" : "nm-connect-button");
        action.set_sensitive (can_toggle);
        action.clicked.connect (() => {
            on_trigger_toggle (dev);
        });
        content.append (action);

        row.set_child (content);
        return row;
    }
}
