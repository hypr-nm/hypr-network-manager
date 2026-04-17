using Gtk;

public class MainWindowWifiDetailsPage : Gtk.Box, IMainWindowNetworkDetailsPage {
    public Gtk.Label details_title { get; set; }
    public Gtk.ListBox basic_rows { get; set; }
    public Gtk.ListBox advanced_rows { get; set; }
    public Gtk.ListBox ip_rows { get; set; }
    public Gtk.Box action_row { get; set; }
    public Gtk.Button forget_button { get; set; }
    public Gtk.Button edit_button { get; set; }

    public signal void back ();
    public signal void forget ();
    public signal void edit ();

    public void render_details (
        WifiNetwork net,
        bool is_connected_now,
        bool pending
    ) {
        this.details_title.set_text (MainWindowHelpers.safe_text (net.ssid));
        bool can_manage_saved_profile = net.saved;
        this.action_row.set_visible (can_manage_saved_profile);
        this.forget_button.set_visible (can_manage_saved_profile);
        this.edit_button.set_visible (can_manage_saved_profile);

        MainWindowHelpers.clear_listbox (this.basic_rows);
        MainWindowHelpers.clear_listbox (this.advanced_rows);

        this.basic_rows.append (
            MainWindowHelpers.build_details_row (
                "Connection Status",
                is_connected_now ? "Connected" : "Not connected"
            )
        );
        this.basic_rows.append (
            MainWindowHelpers.build_details_row ("Signal Strength", "%u%%".printf (net.signal))
        );
        this.basic_rows.append (
            MainWindowHelpers.build_details_row ("Bars", MainWindowHelpers.get_signal_bars (net.signal))
        );
        this.basic_rows.append (
            MainWindowHelpers.build_details_row ("Security", net.is_secured ? "Secured" : "Open")
        );
        this.basic_rows.append (
            MainWindowHelpers.build_details_row ("Saved Profile", net.saved ? "Yes" : "No")
        );

        string band = MainWindowHelpers.get_band_label (net.frequency_mhz);
        int channel = MainWindowHelpers.get_channel_from_frequency (net.frequency_mhz);
        this.advanced_rows.append (
            MainWindowHelpers.build_details_row (
                "Frequency",
                net.frequency_mhz > 0 ? "%.1f GHz".printf ((double) net.frequency_mhz / 1000.0) : "n/a"
            )
        );
        this.advanced_rows.append (
            MainWindowHelpers.build_details_row ("Channel", channel > 0 ? "%d".printf (channel) : "n/a")
        );
        this.advanced_rows.append (
            MainWindowHelpers.build_details_row ("Band", band != "" ? band : "n/a")
        );
        this.advanced_rows.append (
            MainWindowHelpers.build_details_row ("BSSID", MainWindowHelpers.display_text_or_na (net.bssid))
        );
        this.advanced_rows.append (
            MainWindowHelpers.build_details_row (
                "Max bitrate",
                net.max_bitrate_kbps > 0
                    ? "%.1f Mbps".printf ((double) net.max_bitrate_kbps / 1000.0)
                    : "n/a"
            )
        );
        this.advanced_rows.append (
            MainWindowHelpers.build_details_row ("Mode", MainWindowHelpers.get_mode_label (net.mode))
        );

        this.forget_button.set_sensitive (net.saved && !pending);
        this.edit_button.set_sensitive (net.saved && !pending);
    }

    public MainWindowWifiDetailsPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
            MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_WIFI_DETAILS,
            {MainWindowCssClasses.PAGE_NETWORK_DETAILS, MainWindowCssClasses.PAGE}
        );

        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_NONE);
        nav_row.add_css_class (MainWindowCssClasses.DETAILS_NAV_ROW);

        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        back_btn.set_halign (Gtk.Align.START);
        nav_row.append (back_btn);
        this.append (nav_row);

        var network_header = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        network_header.set_halign (Gtk.Align.CENTER);
        network_header.add_css_class (MainWindowCssClasses.DETAILS_HEADER);

        var network_icon = new Gtk.Image.from_icon_name ("network-wireless-signal-excellent-symbolic");
        MainWindowCssClassResolver.add_best_class (network_icon, {MainWindowCssClasses.ICON_SIZE_28,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (
            network_icon,
            {MainWindowCssClasses.DETAILS_NETWORK_ICON, MainWindowCssClasses.WIFI_ICON,
                MainWindowCssClasses.SIGNAL_ICON}
        );
        network_header.append (network_icon);

        this.details_title = new Gtk.Label ("Network");
        this.details_title.set_xalign (0.5f);
        this.details_title.set_halign (Gtk.Align.CENTER);
        this.details_title.add_css_class (MainWindowCssClasses.DETAILS_NETWORK_TITLE);
        network_header.append (this.details_title);

        this.action_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        this.action_row.set_halign (Gtk.Align.CENTER);
        this.action_row.add_css_class (MainWindowCssClasses.DETAILS_ACTION_ROW);

        this.forget_button = new Gtk.Button.with_label ("Forget");
        this.forget_button.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (
            this.forget_button,
            {MainWindowCssClasses.FORGET_BUTTON, MainWindowCssClasses.DETAILS_ACTION_BUTTON,
                MainWindowCssClasses.ACTION_BUTTON, MainWindowCssClasses.BUTTON}
        );
        this.forget_button.clicked.connect (() => {
            this.forget ();
        });
        this.action_row.append (this.forget_button);

        this.edit_button = new Gtk.Button.with_label ("Edit");
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

        network_header.append (this.action_row);
        this.append (network_header);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);

        var body = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        body.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        Gtk.ListBox b_rows, a_rows, i_rows;
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
