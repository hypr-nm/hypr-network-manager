public class MainWindowEthernetRefreshController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private Cancellable? refresh_cancellable = null;
    private NetworkManagerClient nm;
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;

    public MainWindowEthernetRefreshController (NetworkManagerClient nm, NetworkManagerRebuild.UI.Interfaces.IWindowHost host) {
        this.nm = nm;
        this.host = host;
    }

    public void on_page_leave () {
        invalidate_ui_state ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        invalidate_ui_state ();
    }

    private uint capture_ui_epoch () {
        return ui_epoch;
    }

    private bool is_ui_epoch_valid (uint epoch) {
        return !is_disposed && epoch == ui_epoch;
    }

    private void invalidate_ui_state () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_refresh_request ();
    }

    private bool is_cancelled_error (Error e) {
        return e is IOError.CANCELLED;
    }

    private void cancel_refresh_request () {
        if (refresh_cancellable != null) {
            refresh_cancellable.cancel ();
            refresh_cancellable = null;
        }
    }

    public void refresh (
        Gtk.Stack ethernet_stack,
        Gtk.ListBox ethernet_listbox,
        MainWindowEthernetConnectionController connection_controller,
        MainWindowEthernetDetailsEditController details_edit_controller,
        MainWindowEthernetDetailsPage ethernet_details_page
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_refresh_request ();
        refresh_cancellable = new Cancellable ();
        var refresh_request = refresh_cancellable;
        string current_view = ethernet_stack.get_visible_child_name ();
        nm.get_devices.begin (refresh_request, (obj, res) => {
            try {
                var devices = nm.get_devices.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }

                var ethernet_devices = new List<NetworkDevice> ();
                MainWindowHelpers.clear_listbox (ethernet_listbox);

                foreach (var dev in devices) {
                    if (!dev.is_ethernet) {
                        continue;
                    }

                    if (connection_controller.pending_action.contains (dev.name)
                        && connection_controller.pending_target_connected.contains (dev.name)) {
                        bool target_connected = connection_controller.pending_target_connected.get (dev.name);
                        if (dev.is_connected == target_connected) {
                            connection_controller.pending_action.remove (dev.name);
                            connection_controller.pending_target_connected.remove (dev.name);
                        }
                    }

                    ethernet_devices.append (dev);
                    
                    bool is_pending = connection_controller.pending_action.contains (dev.name);
                    bool can_connect = connection_controller.can_connect_with_profile (dev);
                    bool has_profile = connection_controller.has_saved_profile (dev);
                    
                    ethernet_listbox.append (MainWindowEthernetRowBuilder.build_row (
                        dev,
                        is_pending,
                        can_connect,
                        has_profile,
                        (d) => { details_edit_controller.open_details (d, ethernet_stack, ethernet_details_page, connection_controller); },
                        (d) => { connection_controller.trigger_toggle (d); }
                    ));
                }

                if (current_view == "details" || current_view == "edit") {
                    if (details_edit_controller.selected_device != null) {
                        NetworkDevice? updated = null;
                        foreach (var dev in ethernet_devices) {
                            if (dev.device_path == details_edit_controller.selected_device.device_path
                                || dev.name == details_edit_controller.selected_device.name) {
                                updated = dev;
                                break;
                            }
                        }

                        if (updated != null) {
                            details_edit_controller.selected_device = updated;
                            if (current_view == "details") {
                                details_edit_controller.populate_details (updated, ethernet_details_page, connection_controller);
                            }
                            ethernet_stack.set_visible_child_name (current_view);
                        } else {
                            details_edit_controller.selected_device = null;
                            host.set_popup_text_input_mode (false);
                            ethernet_stack.set_visible_child_name (
                                ethernet_devices.length () > 0 ? "list" : "empty"
                            );
                        }
                    } else {
                        ethernet_stack.set_visible_child_name (
                            ethernet_devices.length () > 0 ? "list" : "empty"
                        );
                    }
                    return;
                }

                ethernet_stack.set_visible_child_name (ethernet_devices.length () > 0 ? "list" : "empty");
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                if (is_cancelled_error (e)) {
                    return;
                }
                host.show_error ("Ethernet refresh failed: " + e.message);
            }
        });
    }
}
