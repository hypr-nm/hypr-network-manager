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

public delegate void MainWindowEthernetDeviceCallback (NetworkDevice dev);
public delegate void MainWindowEthernetRefreshCallback ();

public class MainWindowEthernetRowBuilder {
    public static Gtk.ListBoxRow build_row (
        NetworkDevice dev,
        bool is_pending,
        bool can_connect,
        bool has_profile,
        string? error_message,
        IMainWindowEthernetRowActionHandler action_handler
    ) {
        var row = new Gtk.ListBoxRow ();
        row.add_css_class (MainWindowCssClasses.DEVICE_ROW);
        if (dev.is_connected) {
            row.add_css_class (MainWindowCssClasses.CONNECTED);
        }

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
        content.add_css_class (MainWindowCssClasses.ROW_CONTENT_INSET);

        var icon = new Gtk.Image.from_icon_name ("network-wired-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.ICON_SIZE_16,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.ETHERNET_ICON,
            MainWindowCssClasses.SIGNAL_ICON});
        content.append (icon);

        var info = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_INLINE);
        info.set_hexpand (true);
        var name_lbl = new Gtk.Label (dev.name);
        name_lbl.set_xalign (0.0f);
        name_lbl.add_css_class (MainWindowCssClasses.SSID_LABEL);
        info.append (name_lbl);

        if (error_message != null) {
            var err = new Gtk.Label (error_message);
            err.set_xalign (0.0f);
            err.set_wrap (true);
            err.add_css_class (MainWindowCssClasses.ERROR_LABEL);
            err.add_css_class (MainWindowCssClasses.ROW_ERROR_LABEL);
            info.append (err);
        }

        string state_label_str = HyprNetworkManager.UI.Formatters.NetworkDeviceFormatter.get_state_label (dev.state);
        string subtitle = state_label_str;
        if (dev.connection != "") {
            subtitle = "%s (%s)".printf (state_label_str, dev.connection);
        }
        var sub = new Gtk.Label (subtitle);
        sub.set_xalign (0.0f);
        sub.add_css_class (MainWindowCssClasses.SUB_LABEL);
        info.append (sub);
        content.append (info);

        string action_label;
        bool can_toggle = true;

        if (is_pending) {
            action_label = _("Updating…");
            can_toggle = false;
        } else if (dev.is_connected) {
            action_label = _("Disconnect");
        } else if (can_connect) {
            action_label = _("Connect");
        } else if (has_profile) {
            action_label = _("Unavailable");
            can_toggle = false;
        } else {
            action_label = _("No Profile");
            can_toggle = false;
        }

        var action = new Gtk.Button.with_label (action_label);
        MainWindowCssClassResolver.add_best_class (
            action,
            {MainWindowCssClasses.ROW_LINK_ACTION, MainWindowCssClasses.BUTTON}
        );
        action.add_css_class (
            dev.is_connected ? MainWindowCssClasses.DISCONNECT_BUTTON : MainWindowCssClasses.CONNECT_BUTTON);
        action.set_sensitive (can_toggle);
        action.clicked.connect (() => {
            action_handler.trigger_toggle (dev);
        });
        content.append (action);

        var details_btn = new Gtk.Button ();
        details_btn.add_css_class (MainWindowCssClasses.ROW_ICON_ACTION);
        MainWindowCssClassResolver.add_best_class (
            details_btn,
            {MainWindowCssClasses.ROW_ICON_ACTION, MainWindowCssClasses.BUTTON}
        );
        MainWindowCssClassResolver.add_best_class (details_btn, {MainWindowCssClasses.DETAILS_OPEN_BUTTON,
            MainWindowCssClasses.ROW_ICON_ACTION});
        details_btn.set_tooltip_text (_("Details"));
        var details_icon = new Gtk.Image.from_icon_name ("document-properties-symbolic");
        MainWindowCssClassResolver.add_best_class (
            details_icon,
            {MainWindowCssClasses.DETAILS_BUTTON_ICON, MainWindowCssClasses.DETAILS_OPEN_ICON}
        );
        details_btn.set_child (details_icon);
        details_btn.clicked.connect (() => {
            action_handler.open_details (dev);
        });
        content.append (details_btn);

        row.set_child (content);
        return row;
    }
}
