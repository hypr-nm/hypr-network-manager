public class MainWindowVpnController : Object {
    private MainWindowVpnPageBuilder page_builder;

    public MainWindowVpnController(
        NetworkManagerClientVala nm,
        owned MainWindowErrorCallback on_error,
        owned MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        page_builder = new MainWindowVpnPageBuilder(
            nm,
            (owned) on_error,
            (owned) on_refresh_after_action
        );
    }

    public void on_page_leave() {
        page_builder.on_page_leave();
    }

    public void dispose_controller() {
        page_builder.dispose_controller();
    }

    public Gtk.Widget build_page(
        out Gtk.ListBox vpn_listbox,
        out Gtk.Stack vpn_stack,
        MainWindowActionCallback on_refresh
    ) {
        return page_builder.build_page(
            out vpn_listbox,
            out vpn_stack,
            on_refresh
        );
    }

    public void refresh() {
        page_builder.refresh();
    }
}
