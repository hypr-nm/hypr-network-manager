using Gtk;

public class MainWindowWifiDetailsPagesBuilder : Object {
    public static Gtk.Widget build_details_page(
        out Gtk.Label wifi_details_title,
        out Gtk.Box wifi_details_basic_rows,
        out Gtk.Box wifi_details_advanced_rows,
        out Gtk.Box wifi_details_ip_rows,
        out Gtk.Box wifi_details_action_row,
        out Gtk.Button wifi_details_forget_button,
        out Gtk.Button wifi_details_edit_button,
        MainWindowActionCallback on_back,
        MainWindowActionCallback on_forget,
        MainWindowActionCallback on_edit
    ) {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        page.set_margin_start(12);
        page.set_margin_end(12);
        page.set_margin_top(12);
        page.set_margin_bottom(12);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-wifi-details");
        page.add_css_class("nm-page-network-details");

        var nav_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        nav_row.add_css_class("nm-details-nav-row");

        var back_btn = MainWindowHelpers.build_back_button(() => {
            on_back();
        });
        back_btn.set_halign(Gtk.Align.START);
        nav_row.append(back_btn);
        page.append(nav_row);

        var network_header = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        network_header.set_halign(Gtk.Align.CENTER);
        network_header.add_css_class("nm-details-header");

        var network_icon = new Gtk.Image.from_icon_name("network-wireless-signal-excellent-symbolic");
        network_icon.set_pixel_size(28);
        network_icon.add_css_class("nm-signal-icon");
        network_icon.add_css_class("nm-wifi-icon");
        network_icon.add_css_class("nm-details-network-icon");
        network_header.append(network_icon);

        wifi_details_title = new Gtk.Label("Network");
        wifi_details_title.set_xalign(0.5f);
        wifi_details_title.set_halign(Gtk.Align.CENTER);
        wifi_details_title.add_css_class("nm-details-network-title");
        network_header.append(wifi_details_title);

        wifi_details_action_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        wifi_details_action_row.set_halign(Gtk.Align.CENTER);
        wifi_details_action_row.add_css_class("nm-details-action-row");

        wifi_details_forget_button = new Gtk.Button.with_label("Forget");
        wifi_details_forget_button.add_css_class("nm-button");
        wifi_details_forget_button.add_css_class("nm-action-button");
        wifi_details_forget_button.add_css_class("nm-details-action-button");
        wifi_details_forget_button.clicked.connect(() => {
            on_forget();
        });
        wifi_details_action_row.append(wifi_details_forget_button);

        wifi_details_edit_button = new Gtk.Button.with_label("Edit");
        wifi_details_edit_button.add_css_class("nm-button");
        wifi_details_edit_button.add_css_class("nm-action-button");
        wifi_details_edit_button.add_css_class("nm-details-action-button");
        wifi_details_edit_button.clicked.connect(() => {
            on_edit();
        });
        wifi_details_action_row.append(wifi_details_edit_button);

        network_header.append(wifi_details_action_row);
        page.append(network_header);

        var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        sep.add_css_class("nm-separator");
        page.append(sep);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");
        scroll.set_vexpand(true);

        var body = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        body.set_margin_top(4);
        body.set_margin_bottom(4);
        body.append(MainWindowHelpers.build_details_section("Basic", out wifi_details_basic_rows));
        body.append(MainWindowHelpers.build_details_section("Advanced", out wifi_details_advanced_rows));
        body.append(MainWindowHelpers.build_details_section("IP", out wifi_details_ip_rows));

        scroll.set_child(body);
        page.append(scroll);
        return page;
    }

    public static Gtk.Widget build_edit_page(
        out Gtk.Label wifi_edit_title,
        out Gtk.Entry wifi_edit_password_entry,
        out Gtk.Label wifi_edit_note,
        out Gtk.DropDown wifi_edit_ipv4_method_dropdown,
        out Gtk.Entry wifi_edit_ipv4_address_entry,
        out Gtk.Switch wifi_edit_gateway_auto_switch,
        out Gtk.Entry wifi_edit_ipv4_prefix_entry,
        out Gtk.Entry wifi_edit_ipv4_gateway_entry,
        out Gtk.Switch wifi_edit_dns_auto_switch,
        out Gtk.Entry wifi_edit_ipv4_dns_entry,
        out Gtk.DropDown wifi_edit_ipv6_method_dropdown,
        out Gtk.Entry wifi_edit_ipv6_address_entry,
        out Gtk.Switch wifi_edit_ipv6_gateway_auto_switch,
        out Gtk.Entry wifi_edit_ipv6_prefix_entry,
        out Gtk.Entry wifi_edit_ipv6_gateway_entry,
        MainWindowActionCallback on_back,
        MainWindowActionCallback on_apply,
        MainWindowActionCallback on_sync_sensitivity
    ) {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        page.set_margin_start(12);
        page.set_margin_end(12);
        page.set_margin_top(12);
        page.set_margin_bottom(12);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-wifi-edit");
        page.add_css_class("nm-page-network-edit");

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var back_btn = MainWindowHelpers.build_back_button(() => {
            on_back();
        });
        header.append(back_btn);

        wifi_edit_title = new Gtk.Label("Edit Network");
        wifi_edit_title.set_xalign(0.0f);
        wifi_edit_title.set_hexpand(true);
        wifi_edit_title.add_css_class("nm-section-title");
        header.append(wifi_edit_title);
        page.append(header);

        var form = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        form.add_css_class("nm-edit-form");
        form.add_css_class("nm-edit-wifi-form");
        form.add_css_class("nm-edit-network-form");

        wifi_edit_note = new Gtk.Label("");
        wifi_edit_note.set_xalign(0.0f);
        wifi_edit_note.set_wrap(true);
        wifi_edit_note.add_css_class("nm-sub-label");
        wifi_edit_note.add_css_class("nm-edit-note");
        form.append(wifi_edit_note);

        var password_label = new Gtk.Label("Password");
        password_label.set_xalign(0.0f);
        password_label.add_css_class("nm-form-label");
        password_label.add_css_class("nm-edit-field-label");
        password_label.add_css_class("nm-edit-password-label");
        form.append(password_label);

        wifi_edit_password_entry = new Gtk.Entry();
        wifi_edit_password_entry.set_visibility(false);
        wifi_edit_password_entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
        wifi_edit_password_entry.set_placeholder_text("New password");
        wifi_edit_password_entry.add_css_class("nm-password-entry");
        wifi_edit_password_entry.add_css_class("nm-edit-field-control");
        wifi_edit_password_entry.add_css_class("nm-edit-field-entry");
        wifi_edit_password_entry.add_css_class("nm-edit-password-entry");
        wifi_edit_password_entry.activate.connect(() => {
            on_apply();
        });
        form.append(wifi_edit_password_entry);

        MainWindowIpEditFormBuilder.append_ipv4_section(
            form,
            out wifi_edit_ipv4_method_dropdown,
            out wifi_edit_ipv4_address_entry,
            out wifi_edit_ipv4_prefix_entry,
            out wifi_edit_gateway_auto_switch,
            out wifi_edit_ipv4_gateway_entry,
            out wifi_edit_dns_auto_switch,
            out wifi_edit_ipv4_dns_entry,
            on_sync_sensitivity,
            true
        );

        MainWindowIpEditFormBuilder.append_ipv6_section(
            form,
            out wifi_edit_ipv6_method_dropdown,
            out wifi_edit_ipv6_address_entry,
            out wifi_edit_ipv6_prefix_entry,
            out wifi_edit_ipv6_gateway_auto_switch,
            out wifi_edit_ipv6_gateway_entry,
            on_sync_sensitivity,
            true
        );

        on_sync_sensitivity();

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        actions.add_css_class("nm-edit-actions");
        actions.add_css_class("nm-edit-wifi-actions");

        var save_btn = new Gtk.Button.with_label("Apply");
        save_btn.add_css_class("nm-button");
        save_btn.add_css_class("suggested-action");
        save_btn.clicked.connect(() => {
            on_apply();
        });
        actions.append(save_btn);

        form.append(actions);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");
        scroll.set_vexpand(true);
        scroll.set_child(form);

        page.append(scroll);
        return page;
    }
}