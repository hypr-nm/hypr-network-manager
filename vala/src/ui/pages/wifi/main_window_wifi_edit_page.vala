using Gtk;

public class MainWindowWifiEditPage : Gtk.Box, IMainWindowIpEditPage {
    public Gtk.Label edit_title { get; set; }
    public Gtk.Entry password_entry { get; set; }
    public Gtk.Label note_label { get; set; }
    public Gtk.DropDown ipv4_method_dropdown { get; set; }
    public Gtk.Entry ipv4_address_entry { get; set; }
    public Gtk.Entry ipv4_prefix_entry { get; set; }
    public Gtk.Entry ipv4_gateway_entry { get; set; }
    public Gtk.Switch dns_auto_switch { get; set; }
    public Gtk.Entry ipv4_dns_entry { get; set; }
    public Gtk.DropDown ipv6_method_dropdown { get; set; }
    public Gtk.Entry ipv6_address_entry { get; set; }
    public Gtk.Entry ipv6_prefix_entry { get; set; }
    public Gtk.Entry ipv6_gateway_entry { get; set; }
    public Gtk.Switch ipv6_dns_auto_switch { get; set; }
    public Gtk.Entry ipv6_dns_entry { get; set; }

    public signal void back ();
    public signal void apply ();
    public signal void ok ();

    public void setup_edit_form (WifiNetwork net) {
        this.edit_title.set_text ("Edit: %s".printf (net.ssid));
        this.password_entry.set_text ("");
        this.password_entry.set_visibility (false);

        if (net.is_secured) {
            this.note_label.set_text (
                "Current password is prefilled when available.\n"
                + "IPv4 and IPv6 settings can be changed below (auto/manual/disabled)."
            );
        } else {
            this.note_label.set_text ("Open network. Password is not required.");
        }

        this.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        this.password_entry.grab_focus ();

        this.ipv4_method_dropdown.set_selected (0);
        this.ipv4_address_entry.set_text ("");
        this.ipv4_prefix_entry.set_text ("");
        this.ipv4_gateway_entry.set_text ("");
        this.dns_auto_switch.set_active (true);
        this.ipv4_dns_entry.set_text ("");
        this.ipv6_method_dropdown.set_selected (0);
        this.ipv6_address_entry.set_text ("");
        this.ipv6_prefix_entry.set_text ("");
        this.ipv6_gateway_entry.set_text ("");
        this.ipv6_dns_auto_switch.set_active (true);
        this.ipv6_dns_entry.set_text ("");
        this.sync_edit_gateway_dns_sensitivity ();
    }

    public string get_password () {
        return this.password_entry.get_text ().strip ();
    }

    public void set_password (string password) {
        this.password_entry.set_text (password);
    }

    public MainWindowWifiEditPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
            MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_WIFI_EDIT,
            {MainWindowCssClasses.PAGE_NETWORK_EDIT, MainWindowCssClasses.PAGE}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        header.append (back_btn);

        this.edit_title = new Gtk.Label ("Edit Network");
        this.edit_title.set_xalign (0.0f);
        this.edit_title.set_hexpand (true);
        this.edit_title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.append (this.edit_title);
        this.append (header);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        MainWindowCssClassResolver.add_best_class (
            form,
            {MainWindowCssClasses.EDIT_WIFI_FORM, MainWindowCssClasses.EDIT_NETWORK_FORM,
                MainWindowCssClasses.EDIT_FORM}
        );
        form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        this.note_label = new Gtk.Label ("");
        this.note_label.set_xalign (0.0f);
        this.note_label.set_wrap (true);
        MainWindowCssClassResolver.add_best_class (this.note_label, {MainWindowCssClasses.EDIT_NOTE,
            MainWindowCssClasses.SUB_LABEL});
        form.append (this.note_label);

        var password_label = new Gtk.Label ("Password");
        password_label.set_xalign (0.0f);
        MainWindowCssClassResolver.add_hook_and_best_class (
            password_label,
            MainWindowCssClasses.EDIT_PASSWORD_LABEL,
            {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL}
        );
        form.append (password_label);

        this.password_entry = new Gtk.Entry ();
        this.password_entry.set_visibility (false);
        this.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        this.password_entry.set_placeholder_text ("Password");
        MainWindowCssClassResolver.add_hook_and_best_class (
            this.password_entry,
            MainWindowCssClasses.EDIT_PASSWORD_ENTRY,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL,
                MainWindowCssClasses.PASSWORD_ENTRY}
        );
        this.password_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
        this.password_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
        MainWindowHelpers.sync_password_visibility_icon (this.password_entry);

        this.password_entry.icon_press.connect ((icon_pos) => {
            if (icon_pos != Gtk.EntryIconPosition.SECONDARY) {
                return;
            }
            this.password_entry.set_visibility (!this.password_entry.get_visibility ());
            MainWindowHelpers.sync_password_visibility_icon (this.password_entry);
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
            true
        );

        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_entry = v6_gw;
        this.ipv6_dns_auto_switch = v6_dns_auto;
        this.ipv6_dns_entry = v6_dns;

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        MainWindowCssClassResolver.add_hook_and_best_class (actions, MainWindowCssClasses.EDIT_WIFI_ACTIONS,
            {MainWindowCssClasses.EDIT_ACTIONS});

        var apply_btn = new Gtk.Button.with_label ("Apply");
        apply_btn.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_hook_and_best_class (apply_btn, MainWindowCssClasses.EDIT_APPLY_BUTTON,
            {MainWindowCssClasses.BUTTON});
        apply_btn.clicked.connect (() => {
            this.apply ();
        });
        actions.append (apply_btn);

        var ok_btn = new Gtk.Button.with_label ("OK");
        ok_btn.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (ok_btn, {MainWindowCssClasses.SUGGESTED_ACTION,
            MainWindowCssClasses.BUTTON});
        ok_btn.clicked.connect (() => {
            this.ok ();
        });
        actions.append (ok_btn);

        form.append (actions);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);
        scroll.set_child (form);

        this.append (scroll);
    }
}
