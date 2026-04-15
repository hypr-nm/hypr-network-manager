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
        page.add_css_class ("nm-page");
        MainWindowCssClassResolver.add_hook_and_best_class (page, "nm-page-ethernet", {"nm-page"});

        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        MainWindowCssClassResolver.add_best_class (toolbar, {"nm-toolbar-inset", "nm-page-shell-inset"});
        MainWindowCssClassResolver.add_best_class (toolbar, {"nm-toolbar", "nm-status-bar"});

        var title = new Gtk.Label ("Ethernet");
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class ("nm-section-title");
        toolbar.append (title);

        var refresh_btn = new Gtk.Button.with_label ("Refresh");
        refresh_btn.add_css_class ("nm-button");
        refresh_btn.add_css_class ("nm-toolbar-action");
        refresh_btn.add_css_class ("nm-refresh-button");
        refresh_btn.set_valign (Gtk.Align.CENTER);
        MainWindowCssClassResolver.add_best_class (refresh_btn, {"nm-toolbar-action", "nm-button"});
        refresh_btn.clicked.connect (() => {
            controller.refresh ();
        });
        toolbar.append (refresh_btn);

        page.append (toolbar);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");

        ethernet_listbox = new Gtk.ListBox ();
        ethernet_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        ethernet_listbox.add_css_class ("nm-list");
        scroll.set_child (ethernet_listbox);

        var ethernet_placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        ethernet_placeholder.set_halign (Gtk.Align.CENTER);
        ethernet_placeholder.set_valign (Gtk.Align.CENTER);
        ethernet_placeholder.add_css_class ("nm-empty-state");
        var eth_icon = new Gtk.Image.from_icon_name ("network-wired-symbolic");
        MainWindowCssClassResolver.add_best_class (eth_icon, {"nm-icon-size-24", "nm-icon-size"});
        MainWindowCssClassResolver.add_best_class (
            eth_icon,
            {"nm-ethernet-placeholder-icon", "nm-placeholder-icon"}
        );
        var eth_lbl = new Gtk.Label ("No Ethernet devices found");
        eth_lbl.add_css_class ("nm-placeholder-label");
        ethernet_placeholder.append (eth_icon);
        ethernet_placeholder.append (eth_lbl);

        ethernet_stack = new Gtk.Stack ();
        ethernet_stack.set_vexpand (true);
        ethernet_stack.add_css_class ("nm-content-stack");
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
