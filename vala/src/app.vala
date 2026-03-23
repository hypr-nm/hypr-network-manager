using Gtk;

public class NetworkManagerValaApp : Gtk.Application {
    private AppConfig config;
    private bool fullscreen;
    private bool debug_enabled;
    private MainWindow? window;

    public NetworkManagerValaApp(AppConfig config, bool fullscreen, bool debug_enabled) {
        Object(application_id: "io.github.hypr-network-manager.rebuild");
        this.config = config;
        this.fullscreen = fullscreen;
        this.debug_enabled = debug_enabled;
    }

    protected override void activate() {
        if (window != null) {
            window.present();
            return;
        }

        window = new MainWindow(this, config, fullscreen, debug_enabled);
        window.close_request.connect(() => {
            window = null;
            quit();
            return false;
        });
        window.present();
    }
}
