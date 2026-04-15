public class MainWindowWifiPasswordUIController : Object {
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;

    public MainWindowWifiPasswordUIController (NetworkManagerRebuild.UI.Interfaces.IWindowHost host) {
        this.host = host;
    }

    public void show_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry
    ) {
        if (active_wifi_password_revealer != null && active_wifi_password_revealer != revealer) {
            active_wifi_password_revealer.set_reveal_child (false);
        }

        if (active_wifi_password_entry != null && active_wifi_password_entry != entry) {
            active_wifi_password_entry.set_text ("");
        }

        active_wifi_password_revealer = revealer;
        active_wifi_password_entry = entry;
        entry.set_text ("");
        entry.set_visibility (false);
        entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        MainWindowIconResources.set_password_visibility_icon (entry, false);
        entry.set_icon_tooltip_text (Gtk.EntryIconPosition.SECONDARY, "Show password");
        host.set_popup_text_input_mode (true);
        revealer.set_reveal_child (true);
        entry.grab_focus ();
    }

    public void hide_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry,
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        string? value
    ) {
        revealer.set_reveal_child (false);
        if (value == null) {
            entry.set_text ("");
        }

        if (active_wifi_password_revealer == revealer) {
            active_wifi_password_revealer = null;
            active_wifi_password_entry = null;
            host.set_popup_text_input_mode (false);
        }
    }

    public void hide_active_wifi_password_prompt (
        ref Gtk.Revealer? active_wifi_password_revealer,
        ref Gtk.Entry? active_wifi_password_entry
    ) {
        if (active_wifi_password_revealer != null) {
            active_wifi_password_revealer.set_reveal_child (false);
        }
        if (active_wifi_password_entry != null) {
            active_wifi_password_entry.set_text ("");
        }
        active_wifi_password_revealer = null;
        active_wifi_password_entry = null;
        host.set_popup_text_input_mode (false);
    }
}
