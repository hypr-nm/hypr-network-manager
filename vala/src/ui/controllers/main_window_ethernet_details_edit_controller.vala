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
        ethernet_details_page.details_title.set_text (MainWindowHelpers.safe_text (dev.name));

        MainWindowHelpers.clear_box (ethernet_details_page.basic_rows);
        MainWindowHelpers.clear_box (ethernet_details_page.advanced_rows);
        MainWindowHelpers.clear_box (ethernet_details_page.ip_rows);

        string profile_name = MainWindowHelpers.display_text_or_na (dev.connection);
        bool has_profile = connection_controller.has_saved_profile (dev);
        bool pending = connection_controller.pending_action.contains (dev.name);

        ethernet_details_page.basic_rows.append (MainWindowHelpers.build_details_row ("Interface", dev.name));
        ethernet_details_page.basic_rows.append (MainWindowHelpers.build_details_row ("Profile", profile_name));
        ethernet_details_page.basic_rows.append (MainWindowHelpers.build_details_row ("State", dev.state_label));
        ethernet_details_page.basic_rows.append (
            MainWindowHelpers.build_details_row ("Connected", dev.is_connected ? "Yes" : "No")
        );

        ethernet_details_page.advanced_rows.append (
            MainWindowHelpers.build_details_row ("Device Path", dev.device_path)
        );
        ethernet_details_page.advanced_rows.append (
            MainWindowHelpers.build_details_row ("State Code", "%u".printf (dev.state))
        );

        ethernet_details_page.ip_rows.append (MainWindowHelpers.build_details_row ("Loading", "Reading IP settings…"));

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

            MainWindowHelpers.clear_box (ethernet_details_page.ip_rows);
            append_ip_details_rows (ip_settings, dev.is_connected, ethernet_details_page.ip_rows);
        });

        if (pending) {
            ethernet_details_page.primary_button.set_label ("Updating…");
            ethernet_details_page.primary_button.set_sensitive (false);
        } else if (dev.is_connected) {
            ethernet_details_page.primary_button.set_label ("Disconnect");
            ethernet_details_page.primary_button.set_sensitive (true);
        } else if (connection_controller.can_connect_with_profile (dev)) {
            ethernet_details_page.primary_button.set_label ("Connect");
            ethernet_details_page.primary_button.set_sensitive (true);
        } else if (has_profile) {
            ethernet_details_page.primary_button.set_label ("Unavailable");
            ethernet_details_page.primary_button.set_sensitive (false);
        } else {
            ethernet_details_page.primary_button.set_label ("No Profile");
            ethernet_details_page.primary_button.set_sensitive (false);
        }

        ethernet_details_page.edit_button.set_sensitive (has_profile && !pending);
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
        ethernet_edit_page.edit_title.set_text ("Edit: %s".printf (dev.name));
        string profile_display = MainWindowHelpers.safe_text (dev.connection).strip ();
        if (profile_display == "") {
            profile_display = "Profile %s".printf (MainWindowHelpers.safe_text (dev.connection_uuid));
        }
        ethernet_edit_page.note_label.set_text ("Update IPv4 and IPv6 settings for profile: %s".printf (profile_display));

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
            populate_ip_settings_to_form (ip_settings, ethernet_edit_page);
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

        var request = build_ip_update_request (ethernet_edit_page);
        if (request == null) {
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
