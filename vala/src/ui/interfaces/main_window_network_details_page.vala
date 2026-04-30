using Gtk;

public interface IMainWindowNetworkDetailsPage : Object {
    public abstract Gtk.Label details_title { get; set; }
    public abstract Gtk.ListBox basic_rows { get; set; }
    public abstract Gtk.ListBox advanced_rows { get; set; }
    public abstract Gtk.ListBox ip_rows { get; set; }
    public abstract Gtk.Button edit_button { get; set; }

    public virtual void render_ip_settings (NetworkIpSettings settings, bool is_connected) {
        MainWindowHelpers.clear_listbox (this.ip_rows);
        MainWindowIpDetailsRowBuilder.populate_ip_rows (this.ip_rows, settings, is_connected);
    }

    public virtual void show_loading_ip () {
        MainWindowHelpers.clear_listbox (this.ip_rows);
        this.ip_rows.append (MainWindowHelpers.build_details_row (_("Loading"), "Reading IP settings…"));
    }
}
