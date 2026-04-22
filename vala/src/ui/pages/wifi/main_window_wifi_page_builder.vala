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
        page.add_css_class (MainWindowCssClasses.PAGE);
        MainWindowCssClassResolver.add_hook_and_best_class (page, MainWindowCssClasses.PAGE_WIFI,
            {MainWindowCssClasses.PAGE});

        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        MainWindowCssClassResolver.add_best_class (toolbar, {MainWindowCssClasses.TOOLBAR_INSET,
            MainWindowCssClasses.PAGE_SHELL_INSET});
        MainWindowCssClassResolver.add_best_class (toolbar, {MainWindowCssClasses.TOOLBAR,
            MainWindowCssClasses.STATUS_BAR});

        var title = new Gtk.Label ("Wi-Fi");
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        toolbar.append (title);

        var add_btn = new Gtk.Button.with_label ("Add Network");
        add_btn.add_css_class (MainWindowCssClasses.BUTTON);
        add_btn.add_css_class (MainWindowCssClasses.TOOLBAR_ACTION);
        add_btn.add_css_class (MainWindowCssClasses.ADD_BUTTON);
        add_btn.set_valign (Gtk.Align.CENTER);
        MainWindowCssClassResolver.add_best_class (add_btn, {MainWindowCssClasses.TOOLBAR_ACTION,
            MainWindowCssClasses.BUTTON});
        add_btn.set_tooltip_text ("Add Hidden Network");
        toolbar.append (add_btn);
        add_network_button = add_btn;

        var refresh_btn = new Gtk.Button.with_label ("Refresh");
        refresh_btn.add_css_class (MainWindowCssClasses.BUTTON);
        refresh_btn.add_css_class (MainWindowCssClasses.TOOLBAR_ACTION);
        refresh_btn.add_css_class (MainWindowCssClasses.REFRESH_BUTTON);
        refresh_btn.set_valign (Gtk.Align.CENTER);
        refresh_btn.set_tooltip_text ("Refresh Wi-Fi networks");
        MainWindowCssClassResolver.add_best_class (refresh_btn, {MainWindowCssClasses.TOOLBAR_ACTION,
            MainWindowCssClasses.BUTTON});
        toolbar.append (refresh_btn);
        refresh_button = refresh_btn;

        wifi_switch = new Gtk.Switch ();
        MainWindowCssClassResolver.add_hook_and_best_class (wifi_switch, MainWindowCssClasses.WIFI_SWITCH,
            {MainWindowCssClasses.SWITCH});
        wifi_switch.set_valign (Gtk.Align.CENTER);
        toolbar.append (wifi_switch);

        page.append (toolbar);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);

        wifi_listbox = new Gtk.ListBox ();
        wifi_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        wifi_listbox.add_css_class (MainWindowCssClasses.LIST);
        wifi_listbox.set_sort_func ((row1, row2) => {
            int idx1 = row1.get_data<int> ("sort-index");
            int idx2 = row2.get_data<int> ("sort-index");
            return idx1 - idx2;
        });
        scroll.set_child (wifi_listbox);

        var wifi_placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        wifi_placeholder.set_halign (Gtk.Align.CENTER);
        wifi_placeholder.set_valign (Gtk.Align.CENTER);
        wifi_placeholder.add_css_class (MainWindowCssClasses.EMPTY_STATE);
        var ph_icon = new Gtk.Image.from_icon_name ("network-wireless-offline-symbolic");
        MainWindowCssClassResolver.add_best_class (ph_icon, {MainWindowCssClasses.ICON_SIZE_24,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (
            ph_icon,
            {MainWindowCssClasses.WIFI_PLACEHOLDER_ICON, MainWindowCssClasses.PLACEHOLDER_ICON}
        );
        var ph_lbl = new Gtk.Label ("No networks found");
        ph_lbl.add_css_class (MainWindowCssClasses.PLACEHOLDER_LABEL);
        wifi_placeholder.append (ph_icon);
        wifi_placeholder.append (ph_lbl);

        wifi_stack = new Gtk.Stack ();
        wifi_stack.set_vexpand (true);
        wifi_stack.add_css_class (MainWindowCssClasses.CONTENT_STACK);
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
