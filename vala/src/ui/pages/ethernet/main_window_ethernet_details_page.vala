using Gtk;

public class MainWindowEthernetDetailsPage : Gtk.Box, IMainWindowNetworkDetailsPage {
    public Gtk.Label details_title { get; set; }
    public Gtk.ListBox basic_rows { get; set; }
    public Gtk.ListBox advanced_rows { get; set; }
    public Gtk.ListBox ip_rows { get; set; }
    public Gtk.Box action_row { get; set; }
    public Gtk.Button primary_button { get; set; }
    public Gtk.Button edit_button { get; set; }

    public signal void back ();
    public signal void primary_action ();
    public signal void edit ();

    public void render_details (
        NetworkDevice dev,
        bool has_profile,
        bool pending,
        bool can_connect
    ) {
        this.details_title.set_text (MainWindowHelpers.safe_text (dev.name));

        MainWindowHelpers.clear_listbox (this.basic_rows);
        MainWindowHelpers.clear_listbox (this.advanced_rows);

        string profile_name = MainWindowHelpers.display_text_or_na (dev.connection);

        this.basic_rows.append (MainWindowHelpers.build_details_row (_("Interface"), dev.name));
        this.basic_rows.append (MainWindowHelpers.build_details_row (_("Profile"), profile_name));
        this.basic_rows.append (MainWindowHelpers.build_details_row (_("State"), dev.state_label));
        this.basic_rows.append (
            MainWindowHelpers.build_details_row (_("Connected"), dev.is_connected ? _("Yes") : _("No"))
        );

        this.advanced_rows.append (
            MainWindowHelpers.build_details_row (_("Device Path"), dev.device_path)
        );
        this.advanced_rows.append (
            MainWindowHelpers.build_details_row (_("State Code"), "%u".printf (dev.state))
        );

        if (pending) {
            this.primary_button.set_label (_("Updating…"));
            this.primary_button.set_sensitive (false);
        } else if (dev.is_connected) {
            this.primary_button.set_label (_("Disconnect"));
            this.primary_button.set_sensitive (true);
        } else if (can_connect) {
            this.primary_button.set_label (_("Connect"));
            this.primary_button.set_sensitive (true);
        } else if (has_profile) {
            this.primary_button.set_label (_("Unavailable"));
            this.primary_button.set_sensitive (false);
        } else {
            this.primary_button.set_label (_("No Profile"));
            this.primary_button.set_sensitive (false);
        }

        this.edit_button.set_sensitive (has_profile && !pending);
    }

    public MainWindowEthernetDetailsPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
            MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_ETHERNET_DETAILS,
            {MainWindowCssClasses.PAGE_NETWORK_DETAILS, MainWindowCssClasses.PAGE}
        );

        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_NONE);
        nav_row.add_css_class (MainWindowCssClasses.DETAILS_NAV_ROW);

        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        nav_row.append (back_btn);
        this.append (nav_row);

        var header = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        header.set_halign (Gtk.Align.CENTER);
        header.add_css_class (MainWindowCssClasses.DETAILS_HEADER);

        var icon = new Gtk.Image.from_icon_name ("network-transmit-receive-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.ICON_SIZE_28,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (
            icon,
            {MainWindowCssClasses.DETAILS_NETWORK_ICON, MainWindowCssClasses.ETHERNET_ICON,
                MainWindowCssClasses.SIGNAL_ICON}
        );
        header.append (icon);

        this.details_title = new Gtk.Label (_("Ethernet"));
        this.details_title.set_xalign (0.5f);
        this.details_title.set_halign (Gtk.Align.CENTER);
        this.details_title.add_css_class (MainWindowCssClasses.DETAILS_NETWORK_TITLE);
        header.append (this.details_title);

        this.action_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        this.action_row.set_halign (Gtk.Align.CENTER);
        this.action_row.add_css_class (MainWindowCssClasses.DETAILS_ACTION_ROW);

        this.primary_button = new Gtk.Button.with_label (_("Connect"));
        this.primary_button.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (
            this.primary_button,
            {MainWindowCssClasses.PRIMARY_ACTION_BUTTON, MainWindowCssClasses.DETAILS_ACTION_BUTTON,
                MainWindowCssClasses.ACTION_BUTTON, MainWindowCssClasses.BUTTON}
        );
        this.primary_button.clicked.connect (() => {
            this.primary_action ();
        });
        this.action_row.append (this.primary_button);

        this.edit_button = new Gtk.Button.with_label (_("Edit"));
        this.edit_button.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (
            this.edit_button,
            {MainWindowCssClasses.EDIT_BUTTON, MainWindowCssClasses.DETAILS_ACTION_BUTTON,
                MainWindowCssClasses.ACTION_BUTTON, MainWindowCssClasses.BUTTON}
        );
        this.edit_button.clicked.connect (() => {
            this.edit ();
        });
        this.action_row.append (this.edit_button);

        header.append (this.action_row);
        this.append (header);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);

        var body = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        body.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        Gtk.ListBox b_rows, a_rows, i_rows;
        body.append (MainWindowHelpers.build_details_section (_("Basic"), out b_rows));
        body.append (MainWindowHelpers.build_details_section (_("Advanced"), out a_rows));
        body.append (MainWindowHelpers.build_details_section (_("IP"), out i_rows));

        this.basic_rows = b_rows;
        this.advanced_rows = a_rows;
        this.ip_rows = i_rows;

        scroll.set_child (body);
        this.append (scroll);
    }
}
