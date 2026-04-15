using Gtk;

public class MainWindowEthernetViewContext : Object {
    public Gtk.Widget page { get; set; }
    public Gtk.ListBox listbox { get; set; }
    public Gtk.Stack stack { get; set; }
    public MainWindowEthernetDetailsPage details_page { get; set; }
    public MainWindowEthernetEditPage edit_page { get; set; }

    public MainWindowEthernetViewContext (
        Gtk.Widget page,
        Gtk.ListBox listbox,
        Gtk.Stack stack,
        MainWindowEthernetDetailsPage details_page,
        MainWindowEthernetEditPage edit_page
    ) {
        this.page = page;
        this.listbox = listbox;
        this.stack = stack;
        this.details_page = details_page;
        this.edit_page = edit_page;
    }
}
