using Gtk;
using GLib;

public class MainWindowVpnPageBuilder : Object {
    public static Gtk.Widget build_page(
        out Gtk.ListBox vpn_listbox,
        out Gtk.Stack vpn_stack,
        MainWindowActionCallback on_refresh
    ) {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-vpn");

        var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        toolbar.set_margin_start(12);
        toolbar.set_margin_end(8);
        toolbar.set_margin_top(8);
        toolbar.set_margin_bottom(8);
        toolbar.add_css_class("nm-toolbar");

        var title = new Gtk.Label("VPN");
        title.set_xalign(0.0f);
        title.set_hexpand(true);
        title.add_css_class("nm-section-title");
        toolbar.append(title);

        var refresh_btn = new Gtk.Button();
        refresh_btn.add_css_class("nm-button");
        refresh_btn.add_css_class("nm-icon-button");
        var refresh_icon = new Gtk.Image.from_icon_name("view-refresh-symbolic");
        refresh_icon.set_pixel_size(16);
        refresh_icon.add_css_class("nm-toolbar-icon");
        refresh_icon.add_css_class("nm-refresh-icon");
        refresh_icon.add_css_class("nm-vpn-refresh-icon");
        refresh_btn.set_child(refresh_icon);
        refresh_btn.clicked.connect(() => {
            on_refresh();
        });
        toolbar.append(refresh_btn);

        page.append(toolbar);
        var toolbar_sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        toolbar_sep.add_css_class("nm-separator");
        page.append(toolbar_sep);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");

        vpn_listbox = new Gtk.ListBox();
        vpn_listbox.set_selection_mode(Gtk.SelectionMode.NONE);
        vpn_listbox.add_css_class("nm-list");

        var vpn_placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        vpn_placeholder.set_halign(Gtk.Align.CENTER);
        vpn_placeholder.set_valign(Gtk.Align.CENTER);
        vpn_placeholder.add_css_class("nm-empty-state");
        var vpn_icon = new Gtk.Image.from_icon_name("network-vpn-symbolic");
        vpn_icon.set_pixel_size(24);
        vpn_icon.add_css_class("nm-placeholder-icon");
        vpn_icon.add_css_class("nm-vpn-placeholder-icon");
        var vpn_lbl = new Gtk.Label("No VPN profiles found");
        vpn_lbl.add_css_class("nm-placeholder-label");
        vpn_placeholder.append(vpn_icon);
        vpn_placeholder.append(vpn_lbl);

        scroll.set_child(vpn_listbox);

        vpn_stack = new Gtk.Stack();
        vpn_stack.set_vexpand(true);
        vpn_stack.add_css_class("nm-content-stack");
        vpn_stack.add_named(scroll, "list");
        vpn_stack.add_named(vpn_placeholder, "empty");
        vpn_stack.set_visible_child_name("empty");

        page.append(vpn_stack);
        return page;
    }

    public static Gtk.ListBoxRow build_row(
        VpnConnection conn,
        NetworkManagerClientVala nm,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        var row = new Gtk.ListBoxRow();
        row.add_css_class("nm-device-row");
        if (conn.is_connected) {
            row.add_css_class("connected");
        }

        var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
        content.set_margin_start(12);
        content.set_margin_end(8);
        content.set_margin_top(8);
        content.set_margin_bottom(8);

        var icon = new Gtk.Image.from_icon_name("network-vpn-symbolic");
        icon.set_pixel_size(16);
        icon.add_css_class("nm-signal-icon");
        icon.add_css_class("nm-vpn-icon");
        content.append(icon);

        var info = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
        info.set_hexpand(true);
        var name_lbl = new Gtk.Label(conn.name);
        name_lbl.set_xalign(0.0f);
        name_lbl.add_css_class("nm-ssid-label");
        info.append(name_lbl);

        var sub = new Gtk.Label(conn.vpn_type);
        sub.set_xalign(0.0f);
        sub.add_css_class("nm-sub-label");
        info.append(sub);
        content.append(info);

        var action = new Gtk.Button.with_label(conn.is_connected ? "Disconnect" : "Connect");
        action.add_css_class("nm-button");
        action.add_css_class(conn.is_connected ? "nm-disconnect-button" : "nm-connect-button");
        action.add_css_class("nm-row-action-button");
        action.clicked.connect(() => {
            try {
                Thread.create<void>(() => {
                    string error_message;
                    bool ok;
                    if (conn.is_connected) {
                        ok = nm.disconnect_vpn(conn.name, out error_message);
                    } else {
                        ok = nm.connect_vpn(conn.name, out error_message);
                    }

                    Idle.add(() => {
                        if (!ok) {
                            on_error(
                                (conn.is_connected ? "VPN disconnect failed: " : "VPN connect failed: ")
                                + error_message
                            );
                        }
                        on_refresh_after_action(false);
                        return false;
                    });
                    return;
                }, false);
            } catch (ThreadError e) {
                on_error("VPN action failed: " + e.message);
            }
        });
        content.append(action);

        row.set_child(content);
        return row;
    }

    public static void refresh(
        Gtk.ListBox vpn_listbox,
        Gtk.Stack vpn_stack,
        NetworkManagerClientVala nm,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        try {
            Thread.create<void>(() => {
                var connections = nm.get_vpn_connections();
                Idle.add(() => {
                    MainWindowHelpers.clear_listbox(vpn_listbox);

                    foreach (var conn in connections) {
                        vpn_listbox.append(build_row(conn, nm, on_error, on_refresh_after_action));
                    }

                    vpn_stack.set_visible_child_name(connections.length() > 0 ? "list" : "empty");
                    return false;
                });
                return;
            }, false);
        } catch (ThreadError e) {
            on_error("VPN refresh failed: " + e.message);
        }
    }
}