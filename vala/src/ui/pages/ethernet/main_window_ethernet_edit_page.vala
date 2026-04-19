using Gtk;

public class MainWindowEthernetEditPage : Gtk.Box, IMainWindowIpEditPage {
    public Gtk.Label edit_title { get; set; }
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

    public void setup_edit_form (NetworkDevice dev) {
        this.edit_title.set_text ("Edit: %s".printf (dev.name));
        string profile_display = MainWindowHelpers.safe_text (dev.connection).strip ();
        if (profile_display == "") {
            profile_display = "Profile %s".printf (MainWindowHelpers.safe_text (dev.connection_uuid));
        }

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

    public MainWindowEthernetEditPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
            MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_ETHERNET_EDIT,
            {MainWindowCssClasses.PAGE_NETWORK_EDIT, MainWindowCssClasses.PAGE}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        header.append (back_btn);

        this.edit_title = new Gtk.Label ("Edit Ethernet");
        this.edit_title.set_xalign (0.0f);
        this.edit_title.set_hexpand (true);
        this.edit_title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.append (this.edit_title);
        this.append (header);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        MainWindowCssClassResolver.add_best_class (
            form,
            {MainWindowCssClasses.EDIT_ETHERNET_FORM, MainWindowCssClasses.EDIT_NETWORK_FORM,
                MainWindowCssClasses.EDIT_FORM}
        );
        form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

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
        var save_btn = new Gtk.Button.with_label ("Apply");
        save_btn.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (save_btn, {MainWindowCssClasses.SUGGESTED_ACTION,
            MainWindowCssClasses.BUTTON});
        save_btn.clicked.connect (() => {
            this.apply ();
        });
        actions.append (save_btn);

        form.append (actions);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);
        scroll.set_child (form);

        this.append (scroll);
    }
}
