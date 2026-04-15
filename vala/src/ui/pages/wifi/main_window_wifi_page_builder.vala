using Gtk;

namespace MainWindowWifiPageBuilder {
    public Gtk.Widget build_page (
        out Gtk.Switch wifi_switch,
        out Gtk.ListBox wifi_listbox,
        out Gtk.Stack wifi_stack,
        out Gtk.Button add_network_button,
        out Gtk.Button refresh_button,
        Gtk.Widget details_page,
        Gtk.Widget edit_page,
        Gtk.Widget add_page
    ) {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        page.add_css_class ("nm-page");
        MainWindowCssClassResolver.add_hook_and_best_class (page, "nm-page-wifi", {"nm-page"});

        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        MainWindowCssClassResolver.add_best_class (toolbar, {"nm-toolbar-inset", "nm-page-shell-inset"});
        MainWindowCssClassResolver.add_best_class (toolbar, {"nm-toolbar", "nm-status-bar"});

        var title = new Gtk.Label ("Wi-Fi");
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class ("nm-section-title");
        toolbar.append (title);

        var add_btn = new Gtk.Button.with_label ("Add Network");
        add_btn.add_css_class ("nm-button");
        add_btn.add_css_class ("nm-toolbar-action");
        add_btn.add_css_class ("nm-add-button");
        add_btn.set_valign (Gtk.Align.CENTER);
        MainWindowCssClassResolver.add_best_class (add_btn, {"nm-toolbar-action", "nm-button"});
        add_btn.set_tooltip_text ("Add Hidden Network");
        toolbar.append (add_btn);
        add_network_button = add_btn;

        var refresh_btn = new Gtk.Button.with_label ("Refresh");
        refresh_btn.add_css_class ("nm-button");
        refresh_btn.add_css_class ("nm-toolbar-action");
        refresh_btn.add_css_class ("nm-refresh-button");
        refresh_btn.set_valign (Gtk.Align.CENTER);
        MainWindowCssClassResolver.add_best_class (refresh_btn, {"nm-toolbar-action", "nm-button"});
        toolbar.append (refresh_btn);
        refresh_button = refresh_btn;

        wifi_switch = new Gtk.Switch ();
        MainWindowCssClassResolver.add_hook_and_best_class (wifi_switch, "nm-wifi-switch", {"nm-switch"});
        wifi_switch.set_valign (Gtk.Align.CENTER);
        toolbar.append (wifi_switch);

        page.append (toolbar);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");

        wifi_listbox = new Gtk.ListBox ();
        wifi_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        wifi_listbox.add_css_class ("nm-list");
        scroll.set_child (wifi_listbox);

        var wifi_placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        wifi_placeholder.set_halign (Gtk.Align.CENTER);
        wifi_placeholder.set_valign (Gtk.Align.CENTER);
        wifi_placeholder.add_css_class ("nm-empty-state");
        var ph_icon = new Gtk.Image.from_icon_name ("network-wireless-offline-symbolic");
        MainWindowCssClassResolver.add_best_class (ph_icon, {"nm-icon-size-24", "nm-icon-size"});
        MainWindowCssClassResolver.add_best_class (
            ph_icon,
            {"nm-wifi-placeholder-icon", "nm-placeholder-icon"}
        );
        var ph_lbl = new Gtk.Label ("No networks found");
        ph_lbl.add_css_class ("nm-placeholder-label");
        wifi_placeholder.append (ph_icon);
        wifi_placeholder.append (ph_lbl);

        wifi_stack = new Gtk.Stack ();
        wifi_stack.set_vexpand (true);
        wifi_stack.add_css_class ("nm-content-stack");
        wifi_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        wifi_stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);
        wifi_stack.add_named (scroll, "list");
        wifi_stack.add_named (wifi_placeholder, "empty");
        wifi_stack.add_named (details_page, "details");
        wifi_stack.add_named (edit_page, "edit");
        wifi_stack.add_named (add_page, "add");
        wifi_stack.set_visible_child_name ("empty");
        var wifi_stack_ref = wifi_stack;

        wifi_stack_ref.notify["visible-child-name"].connect (() => {
            string page_name = wifi_stack_ref.get_visible_child_name ();
            bool show_toolbar = page_name == "list" || page_name == "empty";
            toolbar.set_visible (show_toolbar);
        });

        string initial_page_name = wifi_stack_ref.get_visible_child_name ();
        bool show_toolbar_initial = initial_page_name == "list" || initial_page_name == "empty";
        toolbar.set_visible (show_toolbar_initial);

        page.append (wifi_stack);

        return page;
    }
}
