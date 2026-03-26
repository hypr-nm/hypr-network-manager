using Gtk;

public class MainWindowWifiPageBuilder : Object {
    public static Gtk.Widget build_page(
        out Gtk.Switch wifi_switch,
        out Gtk.ListBox wifi_listbox,
        out Gtk.Stack wifi_stack,
        Gtk.Widget details_page,
        Gtk.Widget edit_page,
        MainWindowActionCallback on_refresh,
        MainWindowActionCallback on_switch_changed
    ) {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-wifi");

        var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        toolbar.set_margin_start(12);
        toolbar.set_margin_end(8);
        toolbar.set_margin_top(8);
        toolbar.set_margin_bottom(8);
        toolbar.add_css_class("nm-toolbar");

        var title = new Gtk.Label("Wi-Fi");
        title.set_xalign(0.0f);
        title.set_hexpand(true);
        title.add_css_class("nm-section-title");
        toolbar.append(title);

        var refresh_btn = new Gtk.Button();
        refresh_btn.add_css_class("nm-button");
        refresh_btn.add_css_class("nm-icon-button");
        var refresh_icon = new Gtk.Image.from_icon_name("view-refresh-symbolic");
        refresh_icon.add_css_class("nm-toolbar-icon");
        refresh_icon.add_css_class("nm-refresh-icon");
        refresh_icon.add_css_class("nm-wifi-refresh-icon");
        refresh_btn.set_child(refresh_icon);
        refresh_btn.clicked.connect(() => {
            on_refresh();
        });
        toolbar.append(refresh_btn);

        wifi_switch = new Gtk.Switch();
        wifi_switch.add_css_class("nm-switch");
        wifi_switch.add_css_class("nm-wifi-switch");
        wifi_switch.set_valign(Gtk.Align.CENTER);
        wifi_switch.notify["active"].connect(() => {
            on_switch_changed();
        });
        toolbar.append(wifi_switch);

        page.append(toolbar);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");

        wifi_listbox = new Gtk.ListBox();
        wifi_listbox.set_selection_mode(Gtk.SelectionMode.NONE);
        wifi_listbox.add_css_class("nm-list");
        scroll.set_child(wifi_listbox);

        var wifi_placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        wifi_placeholder.set_halign(Gtk.Align.CENTER);
        wifi_placeholder.set_valign(Gtk.Align.CENTER);
        wifi_placeholder.add_css_class("nm-empty-state");
        var ph_icon = new Gtk.Image.from_icon_name("network-wireless-offline-symbolic");
        ph_icon.set_pixel_size(24);
        ph_icon.add_css_class("nm-placeholder-icon");
        ph_icon.add_css_class("nm-wifi-placeholder-icon");
        var ph_lbl = new Gtk.Label("No networks found");
        ph_lbl.add_css_class("nm-placeholder-label");
        wifi_placeholder.append(ph_icon);
        wifi_placeholder.append(ph_lbl);

        wifi_stack = new Gtk.Stack();
        wifi_stack.set_vexpand(true);
        wifi_stack.add_css_class("nm-content-stack");
        wifi_stack.add_named(scroll, "list");
        wifi_stack.add_named(wifi_placeholder, "empty");
        wifi_stack.add_named(details_page, "details");
        wifi_stack.add_named(edit_page, "edit");
        wifi_stack.set_visible_child_name("empty");

        page.append(wifi_stack);

        return page;
    }
}