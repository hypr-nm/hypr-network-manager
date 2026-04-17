using Gtk;

public interface IMainWindowEthernetRowActionHandler : Object {
    public abstract void open_details (NetworkDevice dev);
    public abstract void trigger_toggle (NetworkDevice dev);
}
