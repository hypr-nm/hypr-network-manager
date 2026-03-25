public class MainWindowVpnController : Object {
    public static Gtk.Widget build_page(
        out Gtk.ListBox vpn_listbox,
        out Gtk.Stack vpn_stack,
        MainWindowActionCallback on_refresh
    ) {
        return MainWindowVpnPageBuilder.build_page(
            out vpn_listbox,
            out vpn_stack,
            on_refresh
        );
    }

    public static void refresh(
        Gtk.ListBox vpn_listbox,
        Gtk.Stack vpn_stack,
        NetworkManagerClientVala nm,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        MainWindowVpnPageBuilder.refresh(
            vpn_listbox,
            vpn_stack,
            nm,
            on_error,
            on_refresh_after_action
        );
    }
}
