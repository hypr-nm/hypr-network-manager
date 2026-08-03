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
using Gtk;

public class MainWindowVpnPageBuilder : Object {
    private HyprNetworkManager.Models.NetworkStateContext state_context;

    private Gtk.ListBox? vpn_listbox = null;
    private Gtk.Stack? vpn_stack = null;

    public signal void refresh_started ();
    public signal void refresh_finished ();
    public signal void refresh_requested ();
    public signal void toggle_requested (VpnConnection conn);
    public signal void open_details (VpnConnection conn);
    public signal void add_clicked ();

    public MainWindowVpnPageBuilder (
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        this.state_context = state_context;
    }

    public void on_page_leave () {
        refresh_finished ();
    }

    public void dispose_controller () {
        refresh_finished ();
    }

    public Gtk.Widget build_page (
        out Gtk.ListBox vpn_listbox,
        out Gtk.Stack vpn_stack
    ) {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        page.add_css_class (MainWindowCssClasses.PAGE);
        MainWindowCssClassResolver.add_hook_and_best_class (page, MainWindowCssClasses.PAGE_VPN,
            {MainWindowCssClasses.PAGE});

        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        MainWindowCssClassResolver.add_best_class (toolbar, {MainWindowCssClasses.TOOLBAR_INSET,
            MainWindowCssClasses.PAGE_SHELL_INSET});
        MainWindowCssClassResolver.add_best_class (toolbar, {MainWindowCssClasses.TOOLBAR,
            MainWindowCssClasses.STATUS_BAR});

        var title = new Gtk.Label (_("VPN"));
        title.set_xalign (0.0f);
        title.set_valign (Gtk.Align.CENTER);
        title.set_hexpand (true);
        title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        toolbar.append (title);

        var refresh_btn = new Gtk.Button.with_label (_("Refresh"));
        refresh_btn.add_css_class (MainWindowCssClasses.BUTTON);
        refresh_btn.add_css_class (MainWindowCssClasses.TOOLBAR_ACTION);
        refresh_btn.add_css_class (MainWindowCssClasses.REFRESH_BUTTON);
        refresh_btn.set_valign (Gtk.Align.CENTER);
        refresh_btn.set_tooltip_text (_("Refresh VPN profiles"));
        MainWindowCssClassResolver.add_best_class (refresh_btn, {MainWindowCssClasses.TOOLBAR_ACTION,
            MainWindowCssClasses.BUTTON});
        refresh_btn.clicked.connect (() => {
            refresh_requested ();
        });
        toolbar.append (refresh_btn);

        var add_btn = new Gtk.Button.with_label (_("Add VPN"));
        // TODO: Handle VPN profile creation in a dedicated window or dialog
        // to support file imports and copy-pasting, as transient popups close on focus loss.
        add_btn.set_visible (false);
        add_btn.add_css_class (MainWindowCssClasses.BUTTON);
        add_btn.add_css_class (MainWindowCssClasses.TOOLBAR_ACTION);
        add_btn.add_css_class (MainWindowCssClasses.ADD_BUTTON);
        add_btn.set_valign (Gtk.Align.CENTER);
        add_btn.set_tooltip_text (_("Add new VPN profile"));
        MainWindowCssClassResolver.add_best_class (add_btn, {MainWindowCssClasses.TOOLBAR_ACTION,
            MainWindowCssClasses.BUTTON});
        add_btn.clicked.connect (() => {
            this.add_clicked ();
        });
        toolbar.append (add_btn);

        page.append (toolbar);

        var prog = new Gtk.ProgressBar ();
        page.append (prog);
        var progress_controller = new HyprNetworkManager.UI.Widgets.MainWindowRefreshProgressController (prog);

        refresh_started.connect (() => {
            progress_controller.start ();
        });
        refresh_finished.connect (() => {
            progress_controller.finish ();
        });

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
        MainWindowCssClassResolver.add_best_class (vpn_icon, {MainWindowCssClasses.ICON_SIZE_24,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (
            vpn_icon,
            {MainWindowCssClasses.VPN_PLACEHOLDER_ICON, MainWindowCssClasses.PLACEHOLDER_ICON}
        );
        var vpn_lbl = new Gtk.Label (_("No VPN profiles found"));
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
        this.vpn_stack = vpn_stack;
        this.vpn_stack.notify["visible-child-name"].connect (() => {
            string current_page = this.vpn_stack.get_visible_child_name ();
            bool show_top_bar = current_page == "list" || current_page == "empty";
            toolbar.set_visible (show_top_bar);
            prog.set_visible (show_top_bar);
        });

        this.vpn_listbox = vpn_listbox;

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
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.ICON_SIZE_16,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.VPN_ICON,
            MainWindowCssClasses.SIGNAL_ICON});
        content.append (icon);

        var info = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_INLINE);
        info.set_hexpand (true);
        var name_lbl = new Gtk.Label (conn.name);
        name_lbl.set_xalign (0.0f);
        name_lbl.add_css_class (MainWindowCssClasses.SSID_LABEL);
        info.append (name_lbl);

        string? error_message = state_context.vpn_errors.lookup (conn.name);
        if (error_message != null) {
            var err = new Gtk.Label (error_message);
            err.set_xalign (0.0f);
            err.set_wrap (true);
            err.add_css_class (MainWindowCssClasses.ERROR_LABEL);
            err.add_css_class (MainWindowCssClasses.ROW_ERROR_LABEL);
            info.append (err);
        }

        var sub = new Gtk.Label (conn.vpn_type);
        sub.set_xalign (0.0f);
        sub.add_css_class (MainWindowCssClasses.SUB_LABEL);
        info.append (sub);
        content.append (info);

        var action = new Gtk.Button.with_label (conn.is_connected ? _("Disconnect") : _("Connect"));
        MainWindowCssClassResolver.add_best_class (
            action,
            {MainWindowCssClasses.ROW_LINK_ACTION, MainWindowCssClasses.BUTTON}
        );
        action.add_css_class (
            conn.is_connected ? MainWindowCssClasses.DISCONNECT_BUTTON : MainWindowCssClasses.CONNECT_BUTTON);
        action.clicked.connect (() => {
            toggle_requested (conn);
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
        details_btn.set_valign (Gtk.Align.CENTER);
        details_btn.set_tooltip_text (_("Details"));
        var details_icon = new Gtk.Image.from_icon_name ("document-properties-symbolic");
        MainWindowCssClassResolver.add_best_class (
            details_icon,
            {MainWindowCssClasses.DETAILS_BUTTON_ICON, MainWindowCssClasses.DETAILS_OPEN_ICON}
        );
        details_btn.set_child (details_icon);
        details_btn.clicked.connect (() => {
            this.open_details (conn);
        });
        content.append (details_btn);

        row.set_child (content);
        return row;
    }

    public void begin_refresh () {
        refresh_started ();
    }

    public void finish_refresh () {
        refresh_finished ();
    }

    public void render_connections (List<VpnConnection> connections) {
        if (vpn_listbox == null || vpn_stack == null) {
            return;
        }

        MainWindowHelpers.clear_listbox (vpn_listbox);
        foreach (var conn in connections) {
            vpn_listbox.append (build_row (conn));
        }
        vpn_stack.set_visible_child_name (connections.length () > 0 ? "list" : "empty");
    }
}
