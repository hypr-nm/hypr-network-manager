using Gtk;
using Gdk;

[CCode (cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
private extern void gtk_style_provider_add_for_display(
    Gdk.Display display,
    Gtk.StyleProvider provider,
    uint priority
);

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

    private void debug_log(string message) {
        if (debug_enabled) {
            stderr.printf("[rebuild] %s\n", message);
        }
    }

    private string get_local_base_css_path() {
        return Path.build_filename(
            Environment.get_home_dir(),
            ".config",
            "hypr-network-manager",
            "base.css"
        );
    }

    private string get_system_base_css_path() {
        return Path.build_filename(
            "/etc",
            "xdg",
            "hypr-network-manager",
            "base.css"
        );
    }

    private string get_bundled_base_css_path() {
        return Path.build_filename(Environment.get_current_dir(), "themes", "base.css");
    }

    private string? resolve_base_css_path() {
        string local_css = get_local_base_css_path();
        if (FileUtils.test(local_css, FileTest.EXISTS)) {
            return local_css;
        }

        string system_css = get_system_base_css_path();
        if (FileUtils.test(system_css, FileTest.EXISTS)) {
            return system_css;
        }

        string bundled_css = get_bundled_base_css_path();
        if (FileUtils.test(bundled_css, FileTest.EXISTS)) {
            return bundled_css;
        }

        return null;
    }

    private bool load_css(string css_path, uint priority) {
        if (!FileUtils.test(css_path, FileTest.EXISTS)) {
            return false;
        }

        var provider = new Gtk.CssProvider();
        provider.load_from_path(css_path);
        var display = Gdk.Display.get_default();
        if (display == null) {
            return false;
        }
        gtk_style_provider_add_for_display(display, provider, priority);
        debug_log("loaded CSS: " + css_path);
        return true;
    }

    private void load_theme_css() {
        string? css_path = resolve_base_css_path();
        if (css_path == null) {
            debug_log("no base.css found in local/system/bundled locations");
            return;
        }

        if (!load_css(css_path, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)) {
            debug_log("failed to load base.css: " + css_path);
        }
    }

    protected override void activate() {
        if (window != null) {
            window.present();
            return;
        }

        load_theme_css();

        window = new MainWindow(this, config, fullscreen, debug_enabled);
        window.close_request.connect(() => {
            window = null;
            quit();
            return false;
        });
        window.present();
    }
}
