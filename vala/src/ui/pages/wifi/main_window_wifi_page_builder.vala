using Gtk;

namespace MainWindowWifiPageBuilder {
    private Gtk.Widget build_placeholder (MainWindowIconResources.NetworkPlaceholderIcon icon_type, string label_text) {
        var placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        placeholder.set_halign (Gtk.Align.CENTER);
        placeholder.set_valign (Gtk.Align.CENTER);
        placeholder.add_css_class (MainWindowCssClasses.EMPTY_STATE);

        var icon = MainWindowIconResources.create_network_placeholder_icon (icon_type);
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.ICON_SIZE_24,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (
            icon,
            {MainWindowCssClasses.WIFI_PLACEHOLDER_ICON, MainWindowCssClasses.PLACEHOLDER_ICON}
        );

        var label = new Gtk.Label (label_text);
        label.add_css_class (MainWindowCssClasses.PLACEHOLDER_LABEL);

        placeholder.append (icon);
        placeholder.append (label);
        return placeholder;
    }

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

        wifi_listbox.set_header_func ((row, before) => {
            if (row == null) {
                return;
            }

            var net = row.get_data<WifiNetwork> ("wifi-network");
            if (net == null) {
                row.set_header (null);
                return;
            }

            bool is_known = net.saved || net.connected;

            bool before_is_known = false;
            if (before != null) {
                var before_net = before.get_data<WifiNetwork> ("wifi-network");
                if (before_net != null) {
                    before_is_known = before_net.saved || before_net.connected;
                }
            }

            if (!is_known && before_is_known && before != null) {
                var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                header_box.set_margin_top (16);
                header_box.set_margin_bottom (4);
                header_box.set_margin_start (12);
                header_box.set_margin_end (12);

                var label = new Gtk.Label ("Other Networks");
                label.set_xalign (0.0f);
                label.add_css_class (MainWindowCssClasses.SUB_LABEL);

                var attrs = new Pango.AttrList ();
                attrs.insert (Pango.attr_weight_new (Pango.Weight.BOLD));
                attrs.insert (Pango.attr_scale_new (0.85));
                label.set_attributes (attrs);

                header_box.append (label);
                row.set_header (header_box);
            } else {
                row.set_header (null);
            }
        });

        scroll.set_child (wifi_listbox);

        wifi_stack = new Gtk.Stack ();
        wifi_stack.set_vexpand (true);
        wifi_stack.add_css_class (MainWindowCssClasses.CONTENT_STACK);
        wifi_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        wifi_stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);
        wifi_stack.add_named (scroll, "list");
        wifi_stack.add_named (
            build_placeholder (
                MainWindowIconResources.NetworkPlaceholderIcon.WIFI_EMPTY,
                "No Wi-Fi networks found"
            ),
            "empty"
        );
        wifi_stack.add_named (
            build_placeholder (
                MainWindowIconResources.NetworkPlaceholderIcon.WIFI_DISABLED,
                "Wi-Fi is disabled"
            ),
            "wifi-disabled"
        );
        wifi_stack.add_named (
            build_placeholder (
                MainWindowIconResources.NetworkPlaceholderIcon.FLIGHT_MODE,
                "Flight mode is on"
            ),
            "flight-mode"
        );
        wifi_stack.add_named (details_page, "details");
        wifi_stack.add_named (edit_page, "edit");
        wifi_stack.add_named (add_page, "add");
        wifi_stack.set_visible_child_name ("empty");
        var wifi_stack_ref = wifi_stack;

        wifi_stack_ref.notify["visible-child-name"].connect (() => {
            string page_name = wifi_stack_ref.get_visible_child_name ();
            bool show_toolbar = page_name == "list" || page_name == "empty" || page_name == "wifi-disabled"
                || page_name == "flight-mode";
            toolbar.set_visible (show_toolbar);
        });

        string initial_page_name = wifi_stack_ref.get_visible_child_name ();
        bool show_toolbar_initial = initial_page_name == "list" || initial_page_name == "empty"
            || initial_page_name == "wifi-disabled" || initial_page_name == "flight-mode";
        toolbar.set_visible (show_toolbar_initial);

        page.append (wifi_stack);

        return page;
    }
}
