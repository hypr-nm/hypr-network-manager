using Gtk;

public class NetworkManagerValaApp : Gtk.Application {
    public NetworkManagerValaApp() {
        Object(application_id: "io.github.hypr-network-manager.rebuild");
    }

    protected override void activate() {
        var window = new Gtk.ApplicationWindow(this);
        window.set_title("hypr-network-manager");
        window.set_default_size(360, 460);

        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        root.set_margin_top(16);
        root.set_margin_bottom(16);
        root.set_margin_start(16);
        root.set_margin_end(16);

        var title = new Gtk.Label("hypr-network-manager rebuild baseline");
        title.set_wrap(true);
        root.append(title);

        window.set_child(root);
        window.present();
    }
}
