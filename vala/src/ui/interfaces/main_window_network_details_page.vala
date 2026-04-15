using Gtk;

public interface IMainWindowNetworkDetailsPage : Object {
    public abstract Gtk.Label details_title { get; set; }
    public abstract Gtk.Box basic_rows { get; set; }
    public abstract Gtk.Box advanced_rows { get; set; }
    public abstract Gtk.Box ip_rows { get; set; }
    public abstract Gtk.Button edit_button { get; set; }

    public virtual void render_ip_settings (NetworkIpSettings settings, bool is_connected) {
        MainWindowHelpers.clear_box (this.ip_rows);
        MainWindowIpDetailsRowBuilder.populate_ip_rows (this.ip_rows, settings, is_connected);
    }

    public virtual void show_loading_ip () {
        MainWindowHelpers.clear_box (this.ip_rows);
        this.ip_rows.append (MainWindowHelpers.build_details_row ("Loading", "Reading IP settings…"));
    }
}
