using Gtk;

public interface IMainWindowWifiRowProvider : Object {
    public abstract Gtk.ListBoxRow build_wifi_row (WifiNetwork net);
}
