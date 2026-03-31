using Gtk;

public class MainWindowVpnPageBuilder : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};

    private NetworkManagerClient nm;
    private MainWindowErrorCallback on_error;
    private MainWindowRefreshActionCallback on_refresh_after_action;

    private Gtk.ListBox? vpn_listbox = null;
    private Gtk.Stack? vpn_stack = null;

    public MainWindowVpnPageBuilder (
        NetworkManagerClient nm,
        owned MainWindowErrorCallback on_error,
        owned MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        this.nm = nm;
        this.on_error = (owned) on_error;
        this.on_refresh_after_action = (owned) on_refresh_after_action;
    }

    public void on_page_leave () {
        invalidate_ui_state ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        invalidate_ui_state ();
    }

    private uint capture_ui_epoch () {
        return ui_epoch;
    }

    private bool is_ui_epoch_valid (uint epoch) {
        return !is_disposed && epoch == ui_epoch;
    }

    private void invalidate_ui_state () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_all_timeout_sources ();
    }

    private void cancel_all_timeout_sources () {
        if (timeout_source_ids.length == 0) {
            return;
        }

        foreach (uint source_id in timeout_source_ids) {
            Source.remove (source_id);
        }
        timeout_source_ids = {};
    }

    public Gtk.Widget build_page (
        out Gtk.ListBox vpn_listbox,
        out Gtk.Stack vpn_stack,
        MainWindowActionCallback on_refresh
    ) {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        page.add_css_class ("nm-page");
        page.add_css_class ("nm-page-vpn");

        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        toolbar.set_margin_start (12);
        toolbar.set_margin_end (8);
        toolbar.set_margin_top (8);
        toolbar.set_margin_bottom (8);
        toolbar.add_css_class ("nm-toolbar");

        var title = new Gtk.Label ("VPN");
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class ("nm-section-title");
        toolbar.append (title);

        var refresh_btn = new Gtk.Button ();
        refresh_btn.add_css_class ("nm-button");
        refresh_btn.add_css_class ("nm-icon-button");
        var refresh_icon = new Gtk.Image.from_icon_name ("view-refresh-symbolic");
        refresh_icon.set_pixel_size (16);
        refresh_icon.add_css_class ("nm-toolbar-icon");
        refresh_icon.add_css_class ("nm-refresh-icon");
        refresh_icon.add_css_class ("nm-vpn-refresh-icon");
        refresh_btn.set_child (refresh_icon);
        refresh_btn.clicked.connect (() => {
            on_refresh ();
        });
        toolbar.append (refresh_btn);

        page.append (toolbar);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");

        vpn_listbox = new Gtk.ListBox ();
        vpn_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        vpn_listbox.add_css_class ("nm-list");

        var vpn_placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        vpn_placeholder.set_halign (Gtk.Align.CENTER);
        vpn_placeholder.set_valign (Gtk.Align.CENTER);
        vpn_placeholder.add_css_class ("nm-empty-state");
        var vpn_icon = new Gtk.Image.from_icon_name ("network-vpn-symbolic");
        vpn_icon.set_pixel_size (24);
        vpn_icon.add_css_class ("nm-placeholder-icon");
        vpn_icon.add_css_class ("nm-vpn-placeholder-icon");
        var vpn_lbl = new Gtk.Label ("No VPN profiles found");
        vpn_lbl.add_css_class ("nm-placeholder-label");
        vpn_placeholder.append (vpn_icon);
        vpn_placeholder.append (vpn_lbl);

        scroll.set_child (vpn_listbox);

        vpn_stack = new Gtk.Stack ();
        vpn_stack.set_vexpand (true);
        vpn_stack.add_css_class ("nm-content-stack");
        vpn_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        vpn_stack.set_transition_duration (320);
        vpn_stack.add_named (scroll, "list");
        vpn_stack.add_named (vpn_placeholder, "empty");
        vpn_stack.set_visible_child_name ("empty");

        this.vpn_listbox = vpn_listbox;
        this.vpn_stack = vpn_stack;

        page.append (vpn_stack);
        return page;
    }

    private Gtk.ListBoxRow build_row (VpnConnection conn) {
        var row = new Gtk.ListBoxRow ();
        row.add_css_class ("nm-device-row");
        if (conn.is_connected) {
            row.add_css_class ("connected");
        }

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        content.set_margin_start (12);
        content.set_margin_end (8);
        content.set_margin_top (8);
        content.set_margin_bottom (8);

        var icon = new Gtk.Image.from_icon_name ("network-vpn-symbolic");
        icon.set_pixel_size (16);
        icon.add_css_class ("nm-signal-icon");
        icon.add_css_class ("nm-vpn-icon");
        content.append (icon);

        var info = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
        info.set_hexpand (true);
        var name_lbl = new Gtk.Label (conn.name);
        name_lbl.set_xalign (0.0f);
        name_lbl.add_css_class ("nm-ssid-label");
        info.append (name_lbl);

        var sub = new Gtk.Label (conn.vpn_type);
        sub.set_xalign (0.0f);
        sub.add_css_class ("nm-sub-label");
        info.append (sub);
        content.append (info);

        var action = new Gtk.Button.with_label (conn.is_connected ? "Disconnect" : "Connect");
        action.add_css_class ("nm-button");
        action.add_css_class (conn.is_connected ? "nm-disconnect-button" : "nm-connect-button");
        action.add_css_class ("nm-row-action-button");
        action.clicked.connect (() => {
            uint epoch = capture_ui_epoch ();
            if (conn.is_connected) {
                nm.disconnect_vpn.begin (conn.name, null, (obj, res) => {
                    try {
                        nm.disconnect_vpn.end (res);
                    } catch (Error e) {
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        on_error ("VPN disconnect failed: " + e.message);
                    }
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    on_refresh_after_action (false);
                });
                return;
            }

            nm.connect_vpn.begin (conn.name, null, (obj, res) => {
                try {
                    nm.connect_vpn.end (res);
                } catch (Error e) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    on_error ("VPN connect failed: " + e.message);
                }
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                on_refresh_after_action (false);
            });
        });
        content.append (action);

        row.set_child (content);
        return row;
    }

    public void refresh () {
        if (vpn_listbox == null || vpn_stack == null) {
            return;
        }

        uint epoch = capture_ui_epoch ();
        nm.get_vpn_connections.begin (null, (obj, res) => {
            try {
                var connections = nm.get_vpn_connections.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                MainWindowHelpers.clear_listbox (vpn_listbox);

                foreach (var conn in connections) {
                    vpn_listbox.append (build_row (conn));
                }

                vpn_stack.set_visible_child_name (connections.length () > 0 ? "list" : "empty");
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                on_error ("VPN refresh failed: " + e.message);
            }
        });
    }
}
