public class MainWindowEthernetController : Object {
    public static Gtk.Widget build_page(
        out Gtk.ListBox ethernet_listbox,
        out Gtk.Stack ethernet_stack,
        MainWindowActionCallback on_refresh
    ) {
        return MainWindowEthernetPageBuilder.build_page(
            out ethernet_listbox,
            out ethernet_stack,
            on_refresh
        );
    }

    public static void refresh(
        Gtk.ListBox ethernet_listbox,
        Gtk.Stack ethernet_stack,
        NetworkManagerClientVala nm,
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action
    ) {
        MainWindowEthernetPageBuilder.refresh(
            ethernet_listbox,
            ethernet_stack,
            nm,
            on_error,
            on_refresh_after_action
        );
    }
}
