using Gtk;

public class MainWindowWifiDetailsPage : Gtk.Box {
    public Gtk.Label details_title { get; private set; }
    public Gtk.Box basic_rows { get; private set; }
    public Gtk.Box advanced_rows { get; private set; }
    public Gtk.Box ip_rows { get; private set; }
    public Gtk.Box action_row { get; private set; }
    public Gtk.Button forget_button { get; private set; }
    public Gtk.Button edit_button { get; private set; }

    public signal void back();
    public signal void forget();
    public signal void edit();

    public MainWindowWifiDetailsPage() {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 10);
        
        this.set_margin_start(12);
        this.set_margin_end(12);
        this.set_margin_top(12);
        this.set_margin_bottom(12);
        this.add_css_class("nm-page");
        this.add_css_class("nm-page-wifi-details");
        this.add_css_class("nm-page-network-details");

        var nav_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        nav_row.add_css_class("nm-details-nav-row");

        var back_btn = MainWindowHelpers.build_back_button(() => {
            this.back();
        });
        back_btn.set_halign(Gtk.Align.START);
        nav_row.append(back_btn);
        this.append(nav_row);

        var network_header = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        network_header.set_halign(Gtk.Align.CENTER);
        network_header.add_css_class("nm-details-header");

        var network_icon = new Gtk.Image.from_icon_name("network-wireless-signal-excellent-symbolic");
        network_icon.set_pixel_size(28);
        network_icon.add_css_class("nm-signal-icon");
        network_icon.add_css_class("nm-wifi-icon");
        network_icon.add_css_class("nm-details-network-icon");
        network_header.append(network_icon);

        this.details_title = new Gtk.Label("Network");
        this.details_title.set_xalign(0.5f);
        this.details_title.set_halign(Gtk.Align.CENTER);
        this.details_title.add_css_class("nm-details-network-title");
        network_header.append(this.details_title);

        this.action_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        this.action_row.set_halign(Gtk.Align.CENTER);
        this.action_row.add_css_class("nm-details-action-row");

        this.forget_button = new Gtk.Button.with_label("Forget");
        this.forget_button.add_css_class("nm-button");
        this.forget_button.add_css_class("nm-action-button");
        this.forget_button.add_css_class("nm-details-action-button");
        this.forget_button.clicked.connect(() => {
            this.forget();
        });
        this.action_row.append(this.forget_button);

        this.edit_button = new Gtk.Button.with_label("Edit");
        this.edit_button.add_css_class("nm-button");
        this.edit_button.add_css_class("nm-action-button");
        this.edit_button.add_css_class("nm-details-action-button");
        this.edit_button.clicked.connect(() => {
            this.edit();
        });
        this.action_row.append(this.edit_button);

        network_header.append(this.action_row);
        this.append(network_header);

        var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        sep.add_css_class("nm-separator");
        this.append(sep);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");
        scroll.set_vexpand(true);

        var body = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        body.set_margin_top(4);
        body.set_margin_bottom(4);
        
        Gtk.Box b_rows, a_rows, i_rows;
        body.append(MainWindowHelpers.build_details_section("Basic", out b_rows));
        body.append(MainWindowHelpers.build_details_section("Advanced", out a_rows));
        body.append(MainWindowHelpers.build_details_section("IP", out i_rows));
        
        this.basic_rows = b_rows;
        this.advanced_rows = a_rows;
        this.ip_rows = i_rows;

        scroll.set_child(body);
        this.append(scroll);
    }
}

public class MainWindowWifiEditPage : Gtk.Box {
    public Gtk.Label edit_title { get; private set; }
    public Gtk.Entry password_entry { get; private set; }
    public Gtk.Label note_label { get; private set; }
    public Gtk.DropDown ipv4_method_dropdown { get; private set; }
    public Gtk.Entry ipv4_address_entry { get; private set; }
    public Gtk.Switch gateway_auto_switch { get; private set; }
    public Gtk.Entry ipv4_prefix_entry { get; private set; }
    public Gtk.Entry ipv4_gateway_entry { get; private set; }
    public Gtk.Switch dns_auto_switch { get; private set; }
    public Gtk.Entry ipv4_dns_entry { get; private set; }
    public Gtk.DropDown ipv6_method_dropdown { get; private set; }
    public Gtk.Entry ipv6_address_entry { get; private set; }
    public Gtk.Switch ipv6_gateway_auto_switch { get; private set; }
    public Gtk.Entry ipv6_prefix_entry { get; private set; }
    public Gtk.Entry ipv6_gateway_entry { get; private set; }

    public signal void back();
    public signal void apply();
    public signal void sync_sensitivity();

    public MainWindowWifiEditPage() {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 10);
        
        this.set_margin_start(12);
        this.set_margin_end(12);
        this.set_margin_top(12);
        this.set_margin_bottom(12);
        this.add_css_class("nm-page");
        this.add_css_class("nm-page-wifi-edit");
        this.add_css_class("nm-page-network-edit");

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var back_btn = MainWindowHelpers.build_back_button(() => {
            this.back();
        });
        header.append(back_btn);

        this.edit_title = new Gtk.Label("Edit Network");
        this.edit_title.set_xalign(0.0f);
        this.edit_title.set_hexpand(true);
        this.edit_title.add_css_class("nm-section-title");
        header.append(this.edit_title);
        this.append(header);

        var form = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        form.add_css_class("nm-edit-form");
        form.add_css_class("nm-edit-wifi-form");
        form.add_css_class("nm-edit-network-form");

        this.note_label = new Gtk.Label("");
        this.note_label.set_xalign(0.0f);
        this.note_label.set_wrap(true);
        this.note_label.add_css_class("nm-sub-label");
        this.note_label.add_css_class("nm-edit-note");
        form.append(this.note_label);

        var password_label = new Gtk.Label("Password");
        password_label.set_xalign(0.0f);
        password_label.add_css_class("nm-form-label");
        password_label.add_css_class("nm-edit-field-label");
        password_label.add_css_class("nm-edit-password-label");
        form.append(password_label);

        this.password_entry = new Gtk.Entry();
        this.password_entry.set_visibility(false);
        this.password_entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
        this.password_entry.set_placeholder_text("New password");
        this.password_entry.add_css_class("nm-password-entry");
        this.password_entry.add_css_class("nm-edit-field-control");
        this.password_entry.add_css_class("nm-edit-field-entry");
        this.password_entry.add_css_class("nm-edit-password-entry");
        this.password_entry.activate.connect(() => {
            this.apply();
        });
        form.append(this.password_entry);

        Gtk.DropDown v4_method;
        Gtk.Entry v4_address, v4_prefix, v4_gw, v4_dns;
        Gtk.Switch v4_gw_auto, v4_dns_auto;

        MainWindowIpEditFormBuilder.append_ipv4_section(
            form,
            out v4_method,
            out v4_address,
            out v4_prefix,
            out v4_gw_auto,
            out v4_gw,
            out v4_dns_auto,
            out v4_dns,
            () => this.sync_sensitivity(),
            true
        );
        
        this.ipv4_method_dropdown = v4_method;
        this.ipv4_address_entry = v4_address;
        this.ipv4_prefix_entry = v4_prefix;
        this.gateway_auto_switch = v4_gw_auto;
        this.ipv4_gateway_entry = v4_gw;
        this.dns_auto_switch = v4_dns_auto;
        this.ipv4_dns_entry = v4_dns;

        Gtk.DropDown v6_method;
        Gtk.Entry v6_address, v6_prefix, v6_gw;
        Gtk.Switch v6_gw_auto;

        MainWindowIpEditFormBuilder.append_ipv6_section(
            form,
            out v6_method,
            out v6_address,
            out v6_prefix,
            out v6_gw_auto,
            out v6_gw,
            () => this.sync_sensitivity(),
            true
        );
        
        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_auto_switch = v6_gw_auto;
        this.ipv6_gateway_entry = v6_gw;

        this.sync_sensitivity();

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        actions.add_css_class("nm-edit-actions");
        actions.add_css_class("nm-edit-wifi-actions");

        var save_btn = new Gtk.Button.with_label("Apply");
        save_btn.add_css_class("nm-button");
        save_btn.add_css_class("suggested-action");
        save_btn.clicked.connect(() => {
            this.apply();
        });
        actions.append(save_btn);

        form.append(actions);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");
        scroll.set_vexpand(true);
        scroll.set_child(form);

        this.append(scroll);
    }
}
