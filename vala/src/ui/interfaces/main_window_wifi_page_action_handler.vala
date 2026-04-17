using Gtk;

public interface IMainWindowWifiPageActionHandler : Object {
    public abstract void request_refresh (bool request_wifi_scan);
}
