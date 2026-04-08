using Gtk;

public class MainWindowWifiDetailsPage : Gtk.Box {
    public Gtk.Label details_title { get; private set; }
    public Gtk.Box basic_rows { get; private set; }
    public Gtk.Box advanced_rows { get; private set; }
    public Gtk.Box ip_rows { get; private set; }
    public Gtk.Box action_row { get; private set; }
    public Gtk.Button forget_button { get; private set; }
    public Gtk.Button edit_button { get; private set; }

    public signal void back ();
    public signal void forget ();
    public signal void edit ();

    public MainWindowWifiDetailsPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class ("nm-page");
        this.add_css_class ("nm-page-shell-inset");
        MainWindowCssClassResolver.add_best_class (this, {"nm-page-shell-inset", "nm-page"});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            "nm-page-wifi-details",
            {"nm-page-network-details", "nm-page"}
        );

        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_NONE);
        nav_row.add_css_class ("nm-details-nav-row");

        var back_btn = MainWindowHelpers.build_back_button (() => {
            this.back ();
        });
        back_btn.set_halign (Gtk.Align.START);
        nav_row.append (back_btn);
        this.append (nav_row);

        var network_header = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        network_header.set_halign (Gtk.Align.CENTER);
        network_header.add_css_class ("nm-details-header");

        var network_icon = new Gtk.Image.from_icon_name ("network-wireless-signal-excellent-symbolic");
        MainWindowCssClassResolver.add_best_class (network_icon, {"nm-icon-size-28", "nm-icon-size"});
        MainWindowCssClassResolver.add_best_class (
            network_icon,
            {"nm-details-network-icon", "nm-wifi-icon", "nm-signal-icon"}
        );
        network_header.append (network_icon);

        this.details_title = new Gtk.Label ("Network");
        this.details_title.set_xalign (0.5f);
        this.details_title.set_halign (Gtk.Align.CENTER);
        this.details_title.add_css_class ("nm-details-network-title");
        network_header.append (this.details_title);

        this.action_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        this.action_row.set_halign (Gtk.Align.CENTER);
        this.action_row.add_css_class ("nm-details-action-row");

        this.forget_button = new Gtk.Button.with_label ("Forget");
        this.forget_button.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (
            this.forget_button,
            {"nm-details-action-button", "nm-action-button", "nm-button"}
        );
        this.forget_button.clicked.connect (() => {
            this.forget ();
        });
        this.action_row.append (this.forget_button);

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

        network_header.append (this.action_row);
        this.append (network_header);

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

public class MainWindowWifiEditPage : Gtk.Box {
    public Gtk.Label edit_title { get; private set; }
    public Gtk.Entry password_entry { get; private set; }
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
    public signal void ok ();
    public signal void sync_sensitivity ();

    public MainWindowWifiEditPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class ("nm-page");
        this.add_css_class ("nm-page-shell-inset");
        MainWindowCssClassResolver.add_best_class (this, {"nm-page-shell-inset", "nm-page"});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            "nm-page-wifi-edit",
            {"nm-page-network-edit", "nm-page"}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button (() => {
            this.back ();
        });
        header.append (back_btn);

        this.edit_title = new Gtk.Label ("Edit Network");
        this.edit_title.set_xalign (0.0f);
        this.edit_title.set_hexpand (true);
        this.edit_title.add_css_class ("nm-section-title");
        header.append (this.edit_title);
        this.append (header);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        MainWindowCssClassResolver.add_best_class (
            form,
            {"nm-edit-wifi-form", "nm-edit-network-form", "nm-edit-form"}
        );
        form.add_css_class ("nm-details-scroll-body-inset");

        this.note_label = new Gtk.Label ("");
        this.note_label.set_xalign (0.0f);
        this.note_label.set_wrap (true);
        MainWindowCssClassResolver.add_best_class (this.note_label, {"nm-edit-note", "nm-sub-label"});
        form.append (this.note_label);

        var password_label = new Gtk.Label ("Password");
        password_label.set_xalign (0.0f);
        MainWindowCssClassResolver.add_hook_and_best_class (
            password_label,
            "nm-edit-password-label",
            {"nm-edit-field-label", "nm-form-label"}
        );
        form.append (password_label);

        this.password_entry = new Gtk.Entry ();
        this.password_entry.set_visibility (false);
        this.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        this.password_entry.set_placeholder_text ("Password");
        MainWindowCssClassResolver.add_hook_and_best_class (
            this.password_entry,
            "nm-edit-password-entry",
            {"nm-edit-field-entry", "nm-edit-field-control", "nm-password-entry"}
        );
        this.password_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
        this.password_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
        MainWindowActionCallback update_password_visibility_icon = () => {
            bool reveal = this.password_entry.get_visibility ();
            MainWindowIconResources.set_password_visibility_icon (this.password_entry, reveal);
            this.password_entry.set_icon_tooltip_text (
                Gtk.EntryIconPosition.SECONDARY,
                reveal ? "Hide password" : "Show password"
            );
        };
        update_password_visibility_icon ();

        this.password_entry.icon_press.connect ((icon_pos) => {
            if (icon_pos != Gtk.EntryIconPosition.SECONDARY) {
                return;
            }
            this.password_entry.set_visibility (!this.password_entry.get_visibility ());
            update_password_visibility_icon ();
        });
        this.password_entry.activate.connect (() => {
            this.ok ();
        });
        form.append (this.password_entry);

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
            () => this.sync_sensitivity (),
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
            () => this.sync_sensitivity (),
            true
        );

        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_entry = v6_gw;
        this.ipv6_dns_auto_switch = v6_dns_auto;
        this.ipv6_dns_entry = v6_dns;

        this.sync_sensitivity ();

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        MainWindowCssClassResolver.add_hook_and_best_class (actions, "nm-edit-wifi-actions", {"nm-edit-actions"});

        var apply_btn = new Gtk.Button.with_label ("Apply");
        apply_btn.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_hook_and_best_class (apply_btn, "nm-edit-apply-button", {"nm-button"});
        apply_btn.clicked.connect (() => {
            this.apply ();
        });
        actions.append (apply_btn);

        var ok_btn = new Gtk.Button.with_label ("OK");
        ok_btn.add_css_class ("nm-button");
        MainWindowCssClassResolver.add_best_class (ok_btn, {"suggested-action", "nm-button"});
        ok_btn.clicked.connect (() => {
            this.ok ();
        });
        actions.append (ok_btn);

        form.append (actions);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class ("nm-scroll");
        scroll.set_vexpand (true);
        scroll.set_child (form);

        this.append (scroll);
    }
}
