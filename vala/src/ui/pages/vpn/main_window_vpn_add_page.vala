using Gtk;

public class MainWindowVpnAddPage : Gtk.Box {
    public signal void back ();
    public signal void type_selected (string type);
    
    public MainWindowVpnAddPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.set_hexpand (true);
        this.set_vexpand (true);
        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
            MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_VPN_ADD,
            {MainWindowCssClasses.PAGE_NETWORK_ADD, MainWindowCssClasses.PAGE_NETWORK_EDIT, MainWindowCssClasses.PAGE}
        );
        
        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        header.append (back_btn);

        var title = new Gtk.Label (_("Add VPN"));
        title.set_xalign (0.0f);
        title.set_hexpand (true);
        title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.append (title);
        this.append (header);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);

        var body = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        MainWindowCssClassResolver.add_best_class (
            body,
            {MainWindowCssClasses.ADD_NETWORK_FORM, MainWindowCssClasses.EDIT_NETWORK_FORM,
                MainWindowCssClasses.EDIT_FORM}
        );
        body.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        var lbl = new Gtk.Label (_("Choose a VPN type:"));
        lbl.set_xalign (0.0f);
        lbl.add_css_class (MainWindowCssClasses.FORM_LABEL);
        body.append (lbl);

        var listbox = new Gtk.ListBox ();
        listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        listbox.add_css_class ("boxed-list");
        listbox.add_css_class (MainWindowCssClasses.LIST);

        listbox.row_activated.connect ((row) => {
            string? id = row.get_data ("vpn-type-id");
            if (id != null) {
                this.type_selected (id);
            }
        });

        add_type_row (listbox, "WireGuard", "wireguard", "network-vpn-symbolic");
        add_type_row (listbox, "OpenVPN", "openvpn", "network-vpn-symbolic");
        add_type_row (listbox, "Cisco AnyConnect (openconnect)", "openconnect", "network-vpn-symbolic");
        add_type_row (listbox, "PPTP", "pptp", "network-vpn-symbolic");
        add_type_row (listbox, "L2TP", "l2tp", "network-vpn-symbolic");

        body.append (listbox);
        scroll.set_child (body);
        this.append (scroll);
    }

    private void add_type_row (Gtk.ListBox listbox, string label, string id, string icon_name) {
        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        row.add_css_class (MainWindowCssClasses.ROW_CONTENT);
        row.set_margin_top (10);
        row.set_margin_bottom (10);
        row.set_margin_start (10);
        row.set_margin_end (10);

        var icon = new Gtk.Image.from_icon_name (icon_name);
        icon.add_css_class (MainWindowCssClasses.ICON_SIZE_16);
        row.append (icon);

        var lbl = new Gtk.Label (label);
        lbl.set_xalign (0.0f);
        lbl.set_hexpand (true);
        row.append (lbl);

        var arrow = new Gtk.Image.from_icon_name ("go-next-symbolic");
        arrow.add_css_class (MainWindowCssClasses.ICON_SIZE_16);
        row.append (arrow);

        var list_row = new Gtk.ListBoxRow ();
        list_row.set_child (row);
        list_row.set_data ("vpn-type-id", id);

        listbox.append (list_row);
    }
}
