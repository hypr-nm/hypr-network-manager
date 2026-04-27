namespace HyprNetworkManager.UI.Interfaces {
    public delegate HyprNetworkManager.UI.Widgets.TrackedDropDown TrackedDropDownFactory (
        owned Gtk.StringList model
    );

    /**
     * Interface that provides window operations back to the controllers.
     */
    public interface IWindowHost : Object {
        public abstract HyprNetworkManager.UI.Widgets.TrackedDropDown create_tracked_dropdown (
            owned Gtk.StringList model
        );
        public abstract void set_popup_text_input_mode (bool enabled);
        public abstract void show_error (string message);
        public abstract void show_wifi_error (string net_key, string message);
        public abstract void show_ethernet_error (string iface_name, string message);
        public abstract void show_vpn_error (string vpn_name, string message);
        public abstract void show_edit_page_error (string message);
        public abstract void show_add_page_error (string message);
        public abstract void refresh_after_action (bool request_wifi_scan);
        public abstract void refresh_all ();
        public abstract void refresh_switch_states ();
        public abstract void hide_active_wifi_password_prompt ();
        public abstract void debug_log (string message);
        public abstract void close_window ();
    }
}
