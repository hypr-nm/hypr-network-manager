using Gtk;

public class MainWindowEthernetPageBuilder : Object {
    public static Gtk.Widget build_page(
        out Gtk.ListBox ethernet_listbox,
        out Gtk.Stack ethernet_stack,
        MainWindowActionCallback on_refresh
    ) {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-ethernet");

        var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        toolbar.set_margin_start(12);
        toolbar.set_margin_end(8);
        toolbar.set_margin_top(8);
        toolbar.set_margin_bottom(8);
        toolbar.add_css_class("nm-toolbar");

        var title = new Gtk.Label("Ethernet");
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
        refresh_icon.add_css_class("nm-ethernet-refresh-icon");
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

        ethernet_listbox = new Gtk.ListBox();
        ethernet_listbox.set_selection_mode(Gtk.SelectionMode.NONE);
        ethernet_listbox.add_css_class("nm-list");

        var ethernet_placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        ethernet_placeholder.set_halign(Gtk.Align.CENTER);
        ethernet_placeholder.set_valign(Gtk.Align.CENTER);
        ethernet_placeholder.add_css_class("nm-empty-state");
        var eth_icon = new Gtk.Image.from_icon_name("network-wired-symbolic");
        eth_icon.set_pixel_size(24);
        eth_icon.add_css_class("nm-placeholder-icon");
        eth_icon.add_css_class("nm-ethernet-placeholder-icon");
        var eth_lbl = new Gtk.Label("No Ethernet devices found");
        eth_lbl.add_css_class("nm-placeholder-label");
        ethernet_placeholder.append(eth_icon);
        ethernet_placeholder.append(eth_lbl);

        scroll.set_child(ethernet_listbox);

        ethernet_stack = new Gtk.Stack();
        ethernet_stack.set_vexpand(true);
        ethernet_stack.add_css_class("nm-content-stack");
        ethernet_stack.add_named(scroll, "list");
        ethernet_stack.add_named(ethernet_placeholder, "empty");
        ethernet_stack.set_visible_child_name("empty");

        page.append(ethernet_stack);
        return page;
    }

    public static Gtk.ListBoxRow build_row(
        NetworkDevice dev,
        NetworkManagerClientVala nm,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        var row = new Gtk.ListBoxRow();
        row.add_css_class("nm-device-row");
        if (dev.is_connected) {
            row.add_css_class("connected");
        }

        var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
        content.set_margin_start(12);
        content.set_margin_end(8);
        content.set_margin_top(8);
        content.set_margin_bottom(8);

        var icon = new Gtk.Image.from_icon_name("network-wired-symbolic");
        icon.set_pixel_size(16);
        icon.add_css_class("nm-signal-icon");
        icon.add_css_class("nm-ethernet-icon");
        content.append(icon);

        var info = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
        info.set_hexpand(true);
        var name_lbl = new Gtk.Label(dev.name);
        name_lbl.set_xalign(0.0f);
        name_lbl.add_css_class("nm-ssid-label");
        info.append(name_lbl);

        string subtitle = dev.state_label;
        if (dev.connection != "") {
            subtitle = "%s (%s)".printf(dev.state_label, dev.connection);
        }
        var sub = new Gtk.Label(subtitle);
        sub.set_xalign(0.0f);
        sub.add_css_class("nm-sub-label");
        info.append(sub);
        content.append(info);

        var action = new Gtk.Button.with_label("Disconnect");
        action.add_css_class("nm-button");
        action.add_css_class("nm-disconnect-button");
        action.add_css_class("nm-row-action-button");
        action.set_sensitive(dev.is_connected);
        action.clicked.connect(() => {
            string error_message;
            if (!nm.disconnect_device(dev.name, out error_message)) {
                on_error("Ethernet disconnect failed: " + error_message);
            }
            on_refresh_after_action(false);
        });
        content.append(action);

        row.set_child(content);
        return row;
    }

    public static void refresh(
        Gtk.ListBox ethernet_listbox,
        Gtk.Stack ethernet_stack,
        NetworkManagerClientVala nm,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        var devices = nm.get_devices();
        uint ethernet_count = 0;
        MainWindowHelpers.clear_listbox(ethernet_listbox);

        foreach (var dev in devices) {
            if (dev.is_ethernet) {
                ethernet_listbox.append(build_row(dev, nm, on_error, on_refresh_after_action));
                ethernet_count++;
            }
        }

        ethernet_stack.set_visible_child_name(ethernet_count > 0 ? "list" : "empty");
    }
}