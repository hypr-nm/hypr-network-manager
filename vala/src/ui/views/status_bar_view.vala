namespace NetworkManagerRebuild.UI.Views {

    public class StatusBarView : Object {
        public Gtk.Box root_widget { get; private set; }
        public Gtk.Label status_label { get; private set; }
        public Gtk.Image status_icon { get; private set; }
        public Gtk.Switch networking_switch { get; private set; }

        public signal void networking_switch_toggled ();

        public StatusBarView () {
            build_ui ();
        }

        private void build_ui () {
            root_widget = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            MainWindowCssClassResolver.add_best_class (root_widget, {"nm-toolbar-inset", "nm-page-shell-inset"});
            MainWindowCssClassResolver.add_best_class (root_widget, {"nm-status-bar", "nm-toolbar"});

            status_icon = new Gtk.Image.from_icon_name ("network-wireless-offline-symbolic");
            MainWindowCssClassResolver.add_best_class (status_icon, {"nm-icon-size-16", "nm-icon-size"});
            MainWindowCssClassResolver.add_best_class (status_icon, {"nm-status-icon", "nm-icon-size"});
            root_widget.append (status_icon);

            status_label = new Gtk.Label ("Loading networks…");
            status_label.set_xalign (0.0f);
            status_label.set_hexpand (true);
            status_label.add_css_class ("nm-status-label");
            root_widget.append (status_label);

            var switch_label = new Gtk.Label ("Networking");
            switch_label.add_css_class ("nm-toggle-label");
            networking_switch = new Gtk.Switch ();
            networking_switch.add_css_class ("nm-switch");
            networking_switch.set_valign (Gtk.Align.CENTER);

            networking_switch.notify["active"].connect (() => {
                networking_switch_toggled ();
            });

            var switch_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_COMPACT);
            switch_box.append (switch_label);
            switch_box.append (networking_switch);
            root_widget.append (switch_box);
        }
    }
}
