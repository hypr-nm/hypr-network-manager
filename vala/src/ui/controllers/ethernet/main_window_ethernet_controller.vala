using GLib;
using Gtk;

public class MainWindowEthernetController : Object, IMainWindowEthernetRowActionHandler {
    private NetworkManagerClient nm;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;

    private MainWindowEthernetRefreshController refresh_controller;
    private MainWindowEthernetConnectionController connection_controller;
    private MainWindowEthernetDetailsEditController details_edit_controller;

    private Gtk.ListBox ethernet_listbox;
    private Gtk.Stack ethernet_stack;

    private MainWindowEthernetDetailsPage ethernet_details_page;
    private MainWindowEthernetEditPage ethernet_edit_page;
    private bool profile_edit_mode = false;

    public signal void profile_edit_completed ();

    public MainWindowEthernetController (
        NetworkManagerClient nm,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        this.nm = nm;
        this.host = host;
        this.state_context = state_context;

        refresh_controller = new MainWindowEthernetRefreshController (nm, host);
        connection_controller = new MainWindowEthernetConnectionController (nm, host);
        details_edit_controller = new MainWindowEthernetDetailsEditController (nm, host);

        connection_controller.refresh_requested.connect (() => {
            refresh ();
        });

        details_edit_controller.complete_profile_edit_mode.connect (() => {
            complete_profile_edit_mode ();
        });
    }

    public void on_page_leave () {
        refresh_controller.on_page_leave ();
        connection_controller.on_page_leave ();
        details_edit_controller.on_page_leave ();
    }

    public void dispose_controller () {
        refresh_controller.dispose_controller ();
        connection_controller.dispose_controller ();
        details_edit_controller.dispose_controller ();
    }

    public void configure_page (MainWindowEthernetViewContext view_context) {
        ethernet_listbox = view_context.listbox;
        ethernet_stack = view_context.stack;
        ethernet_details_page = view_context.details_page;
        ethernet_edit_page = view_context.edit_page;
    }

    public void on_details_back_requested () {
        details_edit_controller.selected_device = null;
        host.set_popup_text_input_mode (false);
        ethernet_stack.set_visible_child_name ("list");
    }

    public void on_details_primary_requested () {
        if (details_edit_controller.selected_device != null) {
            connection_controller.trigger_toggle (details_edit_controller.selected_device);
        }
    }

    public void on_details_edit_requested () {
        if (details_edit_controller.selected_device != null) {
            profile_edit_mode = false;
            details_edit_controller.open_edit (details_edit_controller.selected_device, ethernet_stack, ethernet_edit_page, connection_controller);
        }
    }

    private void complete_profile_edit_mode () {
        profile_edit_mode = false;
        details_edit_controller.selected_device = null;
        ethernet_stack.set_visible_child_name ("list");
        profile_edit_completed ();
    }

    public void on_edit_back_requested () {
        host.set_popup_text_input_mode (false);
        if (profile_edit_mode) {
            complete_profile_edit_mode ();
            return;
        }
        if (details_edit_controller.selected_device != null) {
            details_edit_controller.open_details (details_edit_controller.selected_device, ethernet_stack, ethernet_details_page, connection_controller);
        } else {
            ethernet_stack.set_visible_child_name ("list");
        }
    }

    public void on_edit_apply_requested () {
        details_edit_controller.apply_edit (
            ethernet_edit_page,
            connection_controller,
            profile_edit_mode,
            ethernet_details_page,
            ethernet_stack
        );
    }

    public void open_profile_edit (NetworkDevice dev) {
        profile_edit_mode = true;
        details_edit_controller.open_edit (dev, ethernet_stack, ethernet_edit_page, connection_controller);
    }

    public void open_details (NetworkDevice dev) {
        profile_edit_mode = false;
        details_edit_controller.open_details (dev, ethernet_stack, ethernet_details_page, connection_controller);
    }

    public void trigger_toggle (NetworkDevice dev) {
        connection_controller.trigger_toggle (dev);
    }

    public void refresh () {
        refresh_controller.refresh (
            ethernet_stack,
            ethernet_listbox,
            connection_controller,
            details_edit_controller,
            ethernet_details_page,
            this
        );
    }
}
