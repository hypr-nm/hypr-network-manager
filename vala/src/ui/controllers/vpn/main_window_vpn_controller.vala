public class MainWindowVpnController : Object {
    private MainWindowVpnPageBuilder page_builder;

    public MainWindowVpnController (
        NetworkManagerClient nm,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        page_builder = new MainWindowVpnPageBuilder (
            nm,
            host,
            state_context
        );
    }

    public void on_page_leave () {
        page_builder.on_page_leave ();
    }

    public void dispose_controller () {
        page_builder.dispose_controller ();
    }

    public Gtk.Widget build_page (
        out Gtk.ListBox vpn_listbox,
        out Gtk.Stack vpn_stack
    ) {
        return page_builder.build_page (
            out vpn_listbox,
            out vpn_stack
        );
    }

    public void refresh () {
        page_builder.refresh ();
    }
}
