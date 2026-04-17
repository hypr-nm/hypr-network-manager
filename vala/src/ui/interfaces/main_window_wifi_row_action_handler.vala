using Gtk;

public interface IMainWindowWifiRowActionHandler : Object {
    public abstract void open_details (WifiNetwork net);
    public abstract void forget_saved_network (WifiNetwork net);
    public abstract void disconnect_network (WifiNetwork net);
    public abstract void connect_network (WifiNetwork net, string? password, string? hidden_ssid);
    public abstract void set_auto_connect (WifiNetwork net, bool auto_connect);
    public abstract void show_password_prompt (WifiNetwork net, Gtk.Revealer revealer, Gtk.Entry entry);
    public abstract void hide_password_prompt (Gtk.Revealer revealer, Gtk.Entry entry, string? value);
}
