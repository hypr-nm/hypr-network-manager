namespace NetworkManagerRebuild.UI.Interfaces {

    /**
     * Interface that provides window operations back to the controllers.
     */
    public interface IWindowHost : Object {
        public abstract void set_popup_text_input_mode (bool enabled);
        public abstract void show_error (string message);
        public abstract void refresh_after_action (bool request_wifi_scan);
        public abstract void refresh_all ();
        public abstract void refresh_switch_states ();
        public abstract void debug_log (string message);
        public abstract void close_window ();
    }
}
