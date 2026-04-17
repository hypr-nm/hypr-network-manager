using Gtk;

namespace MainWindowEthernetPageBuilder {
    public Gtk.Widget build_page (
        out Gtk.ListBox ethernet_listbox,
        out Gtk.Stack ethernet_stack,
        Gtk.Widget details_page,
        Gtk.Widget edit_page,
        MainWindowEthernetController controller
    ) {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        page.add_css_class (MainWindowCssClasses.PAGE);
        MainWindowCssClassResolver.add_hook_and_best_class (page, MainWindowCssClasses.PAGE_ETHERNET,
            {MainWindowCssClasses.PAGE});

        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        MainWindowCssClassResolver.add_best_class (toolbar, {MainWindowCssClasses.TOOLBAR_INSET,
            MainWindowCssClasses.PAGE_SHELL_INSET});
        MainWindowCssClassResolver.add_best_class (toolbar, {MainWindowCssClasses.TOOLBAR,
            MainWindowCssClasses.STATUS_BAR});

        var title = new Gtk.Label ("Ethernet");
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        toolbar.append (title);

        var refresh_btn = new Gtk.Button.with_label ("Refresh");
        refresh_btn.add_css_class (MainWindowCssClasses.BUTTON);
        refresh_btn.add_css_class (MainWindowCssClasses.TOOLBAR_ACTION);
        refresh_btn.add_css_class (MainWindowCssClasses.REFRESH_BUTTON);
        refresh_btn.set_valign (Gtk.Align.CENTER);
        MainWindowCssClassResolver.add_best_class (refresh_btn, {MainWindowCssClasses.TOOLBAR_ACTION,
            MainWindowCssClasses.BUTTON});
        refresh_btn.clicked.connect (() => {
            controller.refresh ();
        });
        toolbar.append (refresh_btn);

        page.append (toolbar);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);

        ethernet_listbox = new Gtk.ListBox ();
        ethernet_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        ethernet_listbox.add_css_class (MainWindowCssClasses.LIST);
        scroll.set_child (ethernet_listbox);

        var ethernet_placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        ethernet_placeholder.set_halign (Gtk.Align.CENTER);
        ethernet_placeholder.set_valign (Gtk.Align.CENTER);
        ethernet_placeholder.add_css_class (MainWindowCssClasses.EMPTY_STATE);
        var eth_icon = new Gtk.Image.from_icon_name ("network-wired-symbolic");
        MainWindowCssClassResolver.add_best_class (eth_icon, {MainWindowCssClasses.ICON_SIZE_24,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (
            eth_icon,
            {MainWindowCssClasses.ETHERNET_PLACEHOLDER_ICON, MainWindowCssClasses.PLACEHOLDER_ICON}
        );
        var eth_lbl = new Gtk.Label ("No Ethernet devices found");
        eth_lbl.add_css_class (MainWindowCssClasses.PLACEHOLDER_LABEL);
        ethernet_placeholder.append (eth_icon);
        ethernet_placeholder.append (eth_lbl);

        ethernet_stack = new Gtk.Stack ();
        ethernet_stack.set_vexpand (true);
        ethernet_stack.add_css_class (MainWindowCssClasses.CONTENT_STACK);
        ethernet_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        ethernet_stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);
        ethernet_stack.add_named (scroll, "list");
        ethernet_stack.add_named (ethernet_placeholder, "empty");
        ethernet_stack.add_named (details_page, "details");
        ethernet_stack.add_named (edit_page, "edit");
        ethernet_stack.set_visible_child_name ("empty");
        var ethernet_stack_ref = ethernet_stack;

        ethernet_stack_ref.notify["visible-child-name"].connect (() => {
            string page_name = ethernet_stack_ref.get_visible_child_name ();
            bool show_toolbar = page_name == "list" || page_name == "empty";
            toolbar.set_visible (show_toolbar);
        });

        string initial_page_name = ethernet_stack_ref.get_visible_child_name ();
        bool show_toolbar_initial = initial_page_name == "list" || initial_page_name == "empty";
        toolbar.set_visible (show_toolbar_initial);

        page.append (ethernet_stack);
        return page;
    }
}
