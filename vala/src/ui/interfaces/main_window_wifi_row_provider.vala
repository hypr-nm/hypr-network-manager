using Gtk;

public interface IMainWindowWifiRowProvider : Object {
    public abstract Gtk.ListBoxRow build_wifi_row (WifiNetwork net);
    public abstract void update_wifi_row (Gtk.ListBoxRow row, WifiNetwork net);
}
