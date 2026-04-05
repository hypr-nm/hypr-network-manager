using Gtk;

public class MainWindowEthernetViewContext : Object {
    public Gtk.Widget page { get; private set; }
    public Gtk.ListBox listbox { get; private set; }
    public Gtk.Stack stack { get; private set; }
    public MainWindowEthernetDetailsPage details_page { get; private set; }
    public MainWindowEthernetEditPage edit_page { get; private set; }

    public MainWindowEthernetViewContext (
        Gtk.Widget page,
        Gtk.ListBox listbox,
        Gtk.Stack stack,
        MainWindowEthernetDetailsPage details_page,
        MainWindowEthernetEditPage edit_page
    ) {
        this.page = page;
        this.listbox = listbox;
        this.stack = stack;
        this.details_page = details_page;
        this.edit_page = edit_page;
    }
}

public class MainWindowEthernetDetailsPage : Gtk.Box {
    public Gtk.Label details_title { get; private set; }
    public Gtk.Box basic_rows { get; private set; }
    public Gtk.Box advanced_rows { get; private set; }
    public Gtk.Box ip_rows { get; private set; }
    public Gtk.Box action_row { get; private set; }
    public Gtk.Button primary_button { get; private set; }
    public Gtk.Button edit_button { get; private set; }

    public signal void back ();
    public signal void primary_action ();
    public signal void edit ();

    public MainWindowEthernetDetailsPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class ("nm-page");
        MainWindowCssClassResolver.add_best_class (this, {"nm-page-shell-inset", "nm-page"});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            "nm-page-ethernet-details",
            {"nm-page-network-details", "nm-page"}
        );

        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_NONE);
        nav_row.add_css_class ("nm-details-nav-row");

        var back_btn = MainWindowHelpers.build_back_button (() => {
            this.back ();
        });
        nav_row.append (back_btn);
        this.append (nav_row);

        var header = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        header.set_halign (Gtk.Align.CENTER);
        header.add_css_class ("nm-details-header");

        var icon = new Gtk.Image.from_icon_name ("network-transmit-receive-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {"nm-icon-size-28", "nm-icon-size"});
        MainWindowCssClassResolver.add_best_class (
            icon,
            {"nm-details-network-icon", "nm-ethernet-icon", "nm-signal-icon"}
        );
        header.append (icon);

        this.details_title = new Gtk.Label ("Ethernet");
        this.details_title.set_xalign (0.5f);
        this.details_title.set_halign (Gtk.Align.CENTER);
        this.details_title.add_css_class ("nm-details-network-title");
        header.append (this.details_title);

        this.action_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        this.action_row.set_halign (Gtk.Align.CENTER);
        this.action_row.add_css_class ("nm-details-action-row");

        this.primary_button = new Gtk.Button.with_label ("Connect");
        this.primary_button.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (
            this.primary_button,
            {"nm-details-action-button", "nm-action-button", "nm-button"}
        );
        this.primary_button.clicked.connect (() => {
            this.primary_action ();
        });
        this.action_row.append (this.primary_button);

        this.edit_button = new Gtk.Button.with_label ("Edit");
        this.edit_button.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (
            this.edit_button,
            {"nm-details-action-button", "nm-action-button", "nm-button"}
        );
        this.edit_button.clicked.connect (() => {
            this.edit ();
        });
        this.action_row.append (this.edit_button);

        header.append (this.action_row);
        this.append (header);

        var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep.add_css_class ("nm-separator");
        this.append (sep);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");
        scroll.set_vexpand (true);

        var body = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        body.add_css_class ("nm-details-scroll-body-inset");

        Gtk.Box b_rows, a_rows, i_rows;
        body.append (MainWindowHelpers.build_details_section ("Basic", out b_rows));
        body.append (MainWindowHelpers.build_details_section ("Advanced", out a_rows));
        body.append (MainWindowHelpers.build_details_section ("IP", out i_rows));

        this.basic_rows = b_rows;
        this.advanced_rows = a_rows;
        this.ip_rows = i_rows;

        scroll.set_child (body);
        this.append (scroll);
    }
}

public class MainWindowEthernetEditPage : Gtk.Box {
    public Gtk.Label edit_title { get; private set; }
    public Gtk.Label note_label { get; private set; }
    public Gtk.DropDown ipv4_method_dropdown { get; private set; }
    public Gtk.Entry ipv4_address_entry { get; private set; }
    public Gtk.Entry ipv4_prefix_entry { get; private set; }
    public Gtk.Entry ipv4_gateway_entry { get; private set; }
    public Gtk.Switch dns_auto_switch { get; private set; }
    public Gtk.Entry ipv4_dns_entry { get; private set; }
    public Gtk.DropDown ipv6_method_dropdown { get; private set; }
    public Gtk.Entry ipv6_address_entry { get; private set; }
    public Gtk.Entry ipv6_prefix_entry { get; private set; }
    public Gtk.Entry ipv6_gateway_entry { get; private set; }
    public Gtk.Switch ipv6_dns_auto_switch { get; private set; }
    public Gtk.Entry ipv6_dns_entry { get; private set; }

    public signal void back ();
    public signal void apply ();
    public signal void sync_sensitivity ();

    public MainWindowEthernetEditPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class ("nm-page");
        MainWindowCssClassResolver.add_best_class (this, {"nm-page-shell-inset", "nm-page"});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            "nm-page-ethernet-edit",
            {"nm-page-network-edit", "nm-page"}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button (() => {
            this.back ();
        });
        header.append (back_btn);

        this.edit_title = new Gtk.Label ("Edit Ethernet");
        this.edit_title.set_xalign (0.0f);
        this.edit_title.set_hexpand (true);
        this.edit_title.add_css_class ("nm-section-title");
        header.append (this.edit_title);
        this.append (header);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        MainWindowCssClassResolver.add_best_class (
            form,
            {"nm-edit-ethernet-form", "nm-edit-network-form", "nm-edit-form"}
        );

        this.note_label = new Gtk.Label ("");
        this.note_label.set_xalign (0.0f);
        this.note_label.set_wrap (true);
        MainWindowCssClassResolver.add_best_class (this.note_label, {"nm-edit-note", "nm-sub-label"});
        form.append (this.note_label);

        Gtk.DropDown v4_method;
        Gtk.Entry v4_address, v4_prefix, v4_gw, v4_dns;
        Gtk.Switch v4_dns_auto;

        MainWindowIpEditFormBuilder.append_ipv4_section (
            form,
            out v4_method,
            out v4_address,
            out v4_prefix,
            out v4_gw,
            out v4_dns_auto,
            out v4_dns,
            () => {
                this.sync_sensitivity ();
            },
            true
        );

        this.ipv4_method_dropdown = v4_method;
        this.ipv4_address_entry = v4_address;
        this.ipv4_prefix_entry = v4_prefix;
        this.ipv4_gateway_entry = v4_gw;
        this.dns_auto_switch = v4_dns_auto;
        this.ipv4_dns_entry = v4_dns;

        Gtk.DropDown v6_method;
        Gtk.Entry v6_address, v6_prefix, v6_gw, v6_dns;
        Gtk.Switch v6_dns_auto;

        MainWindowIpEditFormBuilder.append_ipv6_section (
            form,
            out v6_method,
            out v6_address,
            out v6_prefix,
            out v6_gw,
            out v6_dns_auto,
            out v6_dns,
            () => {
                this.sync_sensitivity ();
            },
            true
        );

        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_entry = v6_gw;
        this.ipv6_dns_auto_switch = v6_dns_auto;
        this.ipv6_dns_entry = v6_dns;

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var save_btn = new Gtk.Button.with_label ("Apply");
        save_btn.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (save_btn, {"suggested-action", "nm-button"});
        save_btn.clicked.connect (() => {
            this.apply ();
        });
        actions.append (save_btn);

        form.append (actions);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");
        scroll.set_vexpand (true);
        scroll.set_child (form);

        this.append (scroll);
    }
}

namespace MainWindowEthernetPageBuilder {
    public Gtk.Widget build_page (
        out Gtk.ListBox ethernet_listbox,
        out Gtk.Stack ethernet_stack,
        Gtk.Widget details_page,
        Gtk.Widget edit_page,
        MainWindowActionCallback on_refresh
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

        var refresh_btn = new Gtk.Button ();
        refresh_btn.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (refresh_btn, {"nm-icon-button", "nm-button"});
        var refresh_icon = new Gtk.Image.from_icon_name ("view-refresh-symbolic");
        MainWindowCssClassResolver.add_best_class (refresh_icon, {"nm-icon-size-16", "nm-icon-size"});
        MainWindowCssClassResolver.add_best_class (
            refresh_icon,
            {"nm-ethernet-refresh-icon", "nm-refresh-icon", "nm-toolbar-icon"}
        );
        refresh_btn.set_child (refresh_icon);
        refresh_btn.clicked.connect (() => {
            on_refresh ();
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

        MainWindowActionCallback sync_toolbar_visibility = () => {
            string page_name = ethernet_stack_ref.get_visible_child_name ();
            bool show_toolbar = page_name == "list" || page_name == "empty";
            toolbar.set_visible (show_toolbar);
        };

        ethernet_stack_ref.notify["visible-child-name"].connect (() => {
            sync_toolbar_visibility ();
        });

        sync_toolbar_visibility ();

        page.append (ethernet_stack);
        return page;
    }
}
