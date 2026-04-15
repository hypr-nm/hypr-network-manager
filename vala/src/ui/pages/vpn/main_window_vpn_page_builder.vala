using Gtk;

public class MainWindowVpnPageBuilder : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};

    private NetworkManagerClient nm;
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;
    private NetworkManagerRebuild.Models.NetworkStateContext state_context;

    private Gtk.ListBox? vpn_listbox = null;
    private Gtk.Stack? vpn_stack = null;

    public MainWindowVpnPageBuilder (
        NetworkManagerClient nm,
        NetworkManagerRebuild.UI.Interfaces.IWindowHost host,
        NetworkManagerRebuild.Models.NetworkStateContext state_context
    ) {
        this.nm = nm;
        this.host = host;
        this.state_context = state_context;
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
        out Gtk.Stack vpn_stack
    ) {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        page.add_css_class (MainWindowCssClasses.PAGE);
        MainWindowCssClassResolver.add_hook_and_best_class (page, MainWindowCssClasses.PAGE_VPN, {MainWindowCssClasses.PAGE});

        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        MainWindowCssClassResolver.add_best_class (toolbar, {MainWindowCssClasses.TOOLBAR_INSET, MainWindowCssClasses.PAGE_SHELL_INSET});
        MainWindowCssClassResolver.add_best_class (toolbar, {MainWindowCssClasses.TOOLBAR, MainWindowCssClasses.STATUS_BAR});

        var title = new Gtk.Label ("VPN");
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        toolbar.append (title);

        var refresh_btn = new Gtk.Button.with_label ("Refresh");
        refresh_btn.add_css_class (MainWindowCssClasses.BUTTON);
        refresh_btn.add_css_class (MainWindowCssClasses.TOOLBAR_ACTION);
        refresh_btn.add_css_class (MainWindowCssClasses.REFRESH_BUTTON);
        refresh_btn.set_valign (Gtk.Align.CENTER);
        MainWindowCssClassResolver.add_best_class (refresh_btn, {MainWindowCssClasses.TOOLBAR_ACTION, MainWindowCssClasses.BUTTON});
        refresh_btn.clicked.connect (() => {
            refresh ();
        });
        toolbar.append (refresh_btn);

        page.append (toolbar);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);

        vpn_listbox = new Gtk.ListBox ();
        vpn_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        vpn_listbox.add_css_class (MainWindowCssClasses.LIST);

        var vpn_placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        vpn_placeholder.set_halign (Gtk.Align.CENTER);
        vpn_placeholder.set_valign (Gtk.Align.CENTER);
        vpn_placeholder.add_css_class (MainWindowCssClasses.EMPTY_STATE);
        var vpn_icon = new Gtk.Image.from_icon_name ("network-vpn-symbolic");
        MainWindowCssClassResolver.add_best_class (vpn_icon, {MainWindowCssClasses.ICON_SIZE_24, MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (
            vpn_icon,
            {MainWindowCssClasses.VPN_PLACEHOLDER_ICON, MainWindowCssClasses.PLACEHOLDER_ICON}
        );
        var vpn_lbl = new Gtk.Label ("No VPN profiles found");
        vpn_lbl.add_css_class (MainWindowCssClasses.PLACEHOLDER_LABEL);
        vpn_placeholder.append (vpn_icon);
        vpn_placeholder.append (vpn_lbl);

        scroll.set_child (vpn_listbox);

        vpn_stack = new Gtk.Stack ();
        vpn_stack.set_vexpand (true);
        vpn_stack.add_css_class (MainWindowCssClasses.CONTENT_STACK);
        vpn_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        vpn_stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);
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
        row.add_css_class (MainWindowCssClasses.DEVICE_ROW);
        if (conn.is_connected) {
            row.add_css_class (MainWindowCssClasses.CONNECTED);
        }

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
        content.add_css_class (MainWindowCssClasses.ROW_CONTENT_INSET);

        var icon = new Gtk.Image.from_icon_name ("network-vpn-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.ICON_SIZE_16, MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.VPN_ICON, MainWindowCssClasses.SIGNAL_ICON});
        content.append (icon);

        var info = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_INLINE);
        info.set_hexpand (true);
        var name_lbl = new Gtk.Label (conn.name);
        name_lbl.set_xalign (0.0f);
        name_lbl.add_css_class (MainWindowCssClasses.SSID_LABEL);
        info.append (name_lbl);

        var sub = new Gtk.Label (conn.vpn_type);
        sub.set_xalign (0.0f);
        sub.add_css_class (MainWindowCssClasses.SUB_LABEL);
        info.append (sub);
        content.append (info);

        var action = new Gtk.Button.with_label (conn.is_connected ? "Disconnect" : "Connect");
        MainWindowCssClassResolver.add_best_class (
            action,
            {MainWindowCssClasses.ROW_LINK_ACTION, MainWindowCssClasses.BUTTON}
        );
        action.add_css_class (conn.is_connected ? MainWindowCssClasses.DISCONNECT_BUTTON : MainWindowCssClasses.CONNECT_BUTTON);
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
                        host.show_error ("VPN disconnect failed: " + e.message);
                    }
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    host.refresh_after_action (false);
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
                    host.show_error ("VPN connect failed: " + e.message);
                }
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                host.refresh_after_action (false);
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
                host.show_error ("VPN refresh failed: " + e.message);
            }
        });
    }
}
