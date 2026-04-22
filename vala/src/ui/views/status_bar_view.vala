namespace HyprNetworkManager.UI.Views {

    public class StatusBarView : Object {
        public Gtk.Box root_widget { get; private set; }
        public Gtk.Label status_label { get; private set; }
        public Gtk.Image status_icon { get; private set; }

        public StatusBarView () {
            build_ui ();
        }

        private void build_ui () {
            root_widget = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            MainWindowCssClassResolver.add_best_class (root_widget, {MainWindowCssClasses.TOOLBAR_INSET,
                MainWindowCssClasses.PAGE_SHELL_INSET});
            MainWindowCssClassResolver.add_best_class (root_widget, {MainWindowCssClasses.STATUS_BAR,
                MainWindowCssClasses.TOOLBAR});

            status_icon = new Gtk.Image.from_icon_name ("network-wireless-offline-symbolic");
            MainWindowCssClassResolver.add_best_class (status_icon, {MainWindowCssClasses.ICON_SIZE_16,
                MainWindowCssClasses.ICON_SIZE});
            MainWindowCssClassResolver.add_best_class (status_icon, {MainWindowCssClasses.STATUS_ICON,
                MainWindowCssClasses.ICON_SIZE});
            root_widget.append (status_icon);

            status_label = new Gtk.Label ("Loading networks…");
            status_label.set_xalign (0.0f);
            status_label.set_hexpand (true);
            status_label.add_css_class (MainWindowCssClasses.STATUS_LABEL);
            root_widget.append (status_label);
        }
    }
}
