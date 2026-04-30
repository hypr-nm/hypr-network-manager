public class MainWindowWifiHiddenNetworkController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private Cancellable? add_network_cancellable = null;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private MainWindowWifiConnectionController connection_controller;

    public MainWindowWifiHiddenNetworkController (HyprNetworkManager.UI.Interfaces.IWindowHost host,
        MainWindowWifiConnectionController connection_controller) {
        this.host = host;
        this.connection_controller = connection_controller;
    }

    public void on_page_leave () {
        cancel_add_network_request ();
        invalidate_ui_state ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        cancel_add_network_request ();
        invalidate_ui_state ();
    }

    private void cancel_add_network_request () {
        if (add_network_cancellable != null) {
            add_network_cancellable.cancel ();
            add_network_cancellable = null;
        }
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
    }

    private bool is_cancelled_error (Error e) {
        return e is IOError.CANCELLED;
    }

    public void sync_add_network_sensitivity (
        HyprNetworkManager.UI.Widgets.TrackedDropDown? wifi_add_security_dropdown,
        Gtk.Entry? wifi_add_password_entry,
        Gtk.Button? wifi_add_connect_button = null
    ) {
        if (wifi_add_security_dropdown == null || wifi_add_password_entry == null) {
            return;
        }

        HiddenWifiSecurityMode mode = HiddenWifiSecurityModeUtils.from_dropdown_index (
            wifi_add_security_dropdown.get_selected ()
        );
        bool secured = HiddenWifiSecurityModeUtils.requires_password (mode);
        wifi_add_password_entry.set_sensitive (secured);
        if (!secured) {
            wifi_add_password_entry.set_text ("");
        }

        if (wifi_add_connect_button != null) {
            bool can_connect = HiddenWifiSecurityModeUtils.is_password_valid_for_mode (
                mode,
                wifi_add_password_entry.get_text ()
            );
            wifi_add_connect_button.set_sensitive (can_connect);
        }
    }

    public void open_add_network (
        Gtk.Stack wifi_stack,
        Gtk.Entry wifi_add_ssid_entry,
        HyprNetworkManager.UI.Widgets.TrackedDropDown wifi_add_security_dropdown,
        Gtk.Entry wifi_add_password_entry
    ) {
        cancel_add_network_request ();
        wifi_add_ssid_entry.set_text ("");
        wifi_add_security_dropdown.set_selected (
            HiddenWifiSecurityModeUtils.to_dropdown_index (HiddenWifiSecurityMode.WPA_PSK)
        );
        wifi_add_password_entry.set_text ("");
        sync_add_network_sensitivity (
            wifi_add_security_dropdown,
            wifi_add_password_entry
        );

        wifi_stack.set_visible_child_name ("add");
        host.set_popup_text_input_mode (true);
        wifi_add_ssid_entry.grab_focus ();
    }

    public void apply_add_network (
        NetworkManagerClient nm,
        Gtk.Stack wifi_stack,
        Gtk.Entry wifi_add_ssid_entry,
        HyprNetworkManager.UI.Widgets.TrackedDropDown wifi_add_security_dropdown,
        Gtk.Entry wifi_add_password_entry
    ) {
        string ssid = wifi_add_ssid_entry.get_text ().strip ();
        HiddenWifiSecurityMode security_mode = HiddenWifiSecurityModeUtils.from_dropdown_index (
            wifi_add_security_dropdown.get_selected ()
        );
        string password = wifi_add_password_entry.get_text ().strip ();

        host.show_add_page_error ("");

        if (ssid == "") {
            host.show_add_page_error (_("SSID is required."));
            return;
        }

        if (!HiddenWifiSecurityModeUtils.is_password_valid_for_mode (security_mode, password)) {
            host.show_add_page_error (
                _("Password must be at least %d characters for the selected security mode.").printf (
                    HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH
                )
            );
            return;
        }

        uint epoch = capture_ui_epoch ();
        cancel_add_network_request ();
        add_network_cancellable = new Cancellable ();
        var add_request = add_network_cancellable;

        nm.connect_hidden_wifi.begin (ssid, security_mode, password, add_request, (obj, res) => {
            try {
                nm.connect_hidden_wifi.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                connection_controller.refresh_after_action (nm, true, epoch);
                wifi_stack.set_visible_child_name ("list");
                host.set_popup_text_input_mode (false);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch) || is_cancelled_error (e)) {
                    return;
                }
                host.show_add_page_error (_("Add hidden network failed: %s").printf (e.message));
            }
        });
    }
}
