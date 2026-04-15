public class MainWindowEthernetDetailsEditController : MainWindowAbstractDetailsEditController {
    public signal void complete_profile_edit_mode ();

    public NetworkDevice? selected_device { get; set; default = null; }

    private NetworkManagerClient nm;

    public MainWindowEthernetDetailsEditController (NetworkManagerClient nm, NetworkManagerRebuild.UI.Interfaces.IWindowHost host) {
        base (host);
        this.nm = nm;
    }

    public void populate_details (
        NetworkDevice dev,
        MainWindowEthernetDetailsPage ethernet_details_page,
        MainWindowEthernetConnectionController connection_controller
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_details_request ();
        details_request_cancellable = new Cancellable ();
        var details_request = details_request_cancellable;

        bool has_profile = connection_controller.has_saved_profile (dev);
        bool pending = connection_controller.pending_action.contains (dev.name);
        bool can_connect = connection_controller.can_connect_with_profile (dev);

        ethernet_details_page.render_details (dev, has_profile, pending, can_connect);
        ethernet_details_page.show_loading_ip ();

        nm.get_ethernet_device_ip_settings.begin (dev, details_request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            if (this.selected_device == null
                || (this.selected_device.device_path != dev.device_path
                    && this.selected_device.name != dev.name)) {
                return;
            }

            NetworkIpSettings ip_settings = nm.get_ethernet_device_ip_settings.end (res);
            ethernet_details_page.render_ip_settings (ip_settings, dev.is_connected);
        });
    }

    public void open_details (
        NetworkDevice dev,
        Gtk.Stack ethernet_stack,
        MainWindowEthernetDetailsPage ethernet_details_page,
        MainWindowEthernetConnectionController connection_controller
    ) {
        this.selected_device = dev;
        populate_details (dev, ethernet_details_page, connection_controller);
        ethernet_stack.set_visible_child_name ("details");
    }

    public void open_edit (
        NetworkDevice dev,
        Gtk.Stack ethernet_stack,
        MainWindowEthernetEditPage ethernet_edit_page,
        MainWindowEthernetConnectionController connection_controller
    ) {
        if (!connection_controller.has_saved_profile (dev)) {
            host.show_error ("This interface has no saved Ethernet profile to edit.");
            return;
        }

        cancel_details_request ();
        cancel_edit_request ();
        this.selected_device = dev;
        uint epoch = capture_ui_epoch ();
        edit_request_cancellable = new Cancellable ();
        var edit_request = edit_request_cancellable;

        ethernet_edit_page.setup_edit_form (dev);

        ethernet_stack.set_visible_child_name ("edit");
        host.set_popup_text_input_mode (true);

        nm.get_ethernet_device_ip_settings.begin (dev, edit_request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            if (this.selected_device == null
                || (this.selected_device.device_path != dev.device_path
                    && this.selected_device.name != dev.name)) {
                return;
            }

            NetworkIpSettings ip_settings = nm.get_ethernet_device_ip_settings.end (res);
            ethernet_edit_page.populate_ip_settings (ip_settings);
            ethernet_edit_page.ipv4_address_entry.grab_focus ();
        });
    }

    public void apply_edit (
        MainWindowEthernetEditPage ethernet_edit_page,
        MainWindowEthernetConnectionController connection_controller,
        bool profile_edit_mode,
        MainWindowEthernetDetailsPage ethernet_details_page,
        Gtk.Stack ethernet_stack
    ) {
        if (this.selected_device == null) {
            return;
        }

        uint epoch = capture_ui_epoch ();
        NetworkDevice dev = this.selected_device;

        string? error_message = null;
        var request = ethernet_edit_page.build_ip_update_request (out error_message);
        if (request == null) {
            if (error_message != null) {
                host.show_error (error_message);
            }
            return;
        }

        nm.update_ethernet_device_settings.begin (dev, request, null, (obj, res) => {
                try {
                    nm.update_ethernet_device_settings.end (res);
                } catch (Error e) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    host.show_error ("Apply failed: " + e.message);
                    return;
                }

                if (!dev.is_connected) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    host.refresh_after_action (false);
                    host.set_popup_text_input_mode (false);
                    if (profile_edit_mode) {
                        complete_profile_edit_mode ();
                    } else {
                        // populate details will be called inside open_details, but we need
                        // selected_ethernet_device passed around safely.
                        open_details (dev, ethernet_stack, ethernet_details_page, connection_controller);
                    }
                    return;
                }

                nm.disconnect_device.begin (dev.name, null, (obj2, res2) => {
                    try {
                        nm.disconnect_device.end (res2);
                    } catch (Error e) {
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        host.show_error ("Disconnect before reconnect failed: " + e.message);
                        return;
                    }

                    nm.connect_ethernet_device.begin (dev, null, (obj3, res3) => {
                        bool reconnect_ok = true;
                        string reconnect_error = "";
                        try {
                            nm.connect_ethernet_device.end (res3);
                        } catch (Error e) {
                            reconnect_ok = false;
                            reconnect_error = e.message;
                        }

                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        connection_controller.track_pending_action (dev, true, epoch);
                        if (!reconnect_ok) {
                            host.show_error ("Reconnect after edit failed: " + reconnect_error);
                        }
                        host.refresh_after_action (false);
                        host.set_popup_text_input_mode (false);
                        if (profile_edit_mode) {
                            complete_profile_edit_mode ();
                        } else {
                            open_details (dev, ethernet_stack, ethernet_details_page, connection_controller);
                        }
                    });
                });
        });
    }
}
