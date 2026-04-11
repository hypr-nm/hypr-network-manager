using Gtk;
using Gdk;

[CCode (cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
private extern void gtk_style_provider_add_for_display (
    Gdk.Display display,
    Gtk.StyleProvider provider,
    uint priority
);

public class NetworkManager : Gtk.Application {
    private AppConfig config;
    private MainWindow? window;
    private BlankWindow? dismiss_overlay;
    private bool is_daemon;
    private bool initial_activation_skipped = false;

    public NetworkManager (AppConfig config, bool daemon_mode) {
        Object (application_id: "yeab212.hypr-network-manager");
        this.config = config;
        this.is_daemon = daemon_mode;
    }

    private void debug_log (string message) {
        log_debug ("app", message);
    }

    private string get_local_base_css_path () {
        return Path.build_filename (
            Environment.get_home_dir (),
            ".config",
            "hypr-network-manager",
            "themes",
            "base.css"
        );
    }

    private string get_system_base_css_path () {
        return Path.build_filename (
            "/etc",
            "xdg",
            "hypr-network-manager",
            "themes",
            "base.css"
        );
    }

    private string get_bundled_base_css_path () {
        return Path.build_filename (Environment.get_current_dir (), "themes", "base.css");
    }

    private string? resolve_base_css_path () {
        string local_css = get_local_base_css_path ();
        if (FileUtils.test (local_css, FileTest.EXISTS)) {
            return local_css;
        }

        string system_css = get_system_base_css_path ();
        if (FileUtils.test (system_css, FileTest.EXISTS)) {
            return system_css;
        }

        string bundled_css = get_bundled_base_css_path ();
        if (FileUtils.test (bundled_css, FileTest.EXISTS)) {
            return bundled_css;
        }

        return null;
    }

    private bool load_css (string css_path, uint priority) {
        if (!FileUtils.test (css_path, FileTest.EXISTS)) {
            return false;
        }

        var provider = new Gtk.CssProvider ();
        provider.load_from_path (css_path);
        var display = Gdk.Display.get_default ();
        if (display == null) {
            return false;
        }
        gtk_style_provider_add_for_display (display, provider, priority);
        log_info (
            "app",
            "load_theme_css: loaded stylesheet path=%s"
                .printf (redact_fs_path (css_path))
        );
        return true;
    }

    private void load_theme_css () {
        string? css_path = resolve_base_css_path ();
        if (css_path == null) {
            debug_log ("load_theme_css: no stylesheet found in local/system/bundled paths; outcome=skipping");
            return;
        }

        MainWindowCssClassResolver.initialize (css_path);

        if (!load_css (css_path, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)) {
            log_warn (
                "app",
                "load_theme_css: failed to apply stylesheet path=%s; outcome=continuing"
                    .printf (redact_fs_path (css_path))
            );
        }
    }

    private void register_app_icon_resources () {
        var display = Gdk.Display.get_default ();
        if (display == null) {
            return;
        }

        var icon_theme = Gtk.IconTheme.get_for_display (display);
        icon_theme.add_resource_path ("/yeab212/hypr-network-manager/icons/hicolor/symbolic/actions");
    }

    private void hide_dismiss_overlay () {
        if (dismiss_overlay == null) {
            return;
        }
        dismiss_overlay.close ();
        dismiss_overlay = null;
    }

    private void show_dismiss_overlay_for_monitor (Gdk.Monitor? monitor) {
        if (window == null || dismiss_overlay != null || monitor == null) {
            return;
        }

        dismiss_overlay = new BlankWindow (this, monitor);
        dismiss_overlay.present ();
    }

    public void request_close () {
        if (window != null) {
            window.close ();
        }
    }

    protected override void startup () {
        base.startup ();
        // Always hold the process so it becomes a resident daemon automatically
        this.hold (); 
    }

    private void on_main_window_mapped () {
        if (window == null) {
            return;
        }

        unowned Gdk.Surface surface = window.get_surface ();
        var display = Gdk.Display.get_default ();
        if (display != null) {
            show_dismiss_overlay_for_monitor (display.get_monitor_at_surface (surface));
        }

        ulong id = 0;
        id = surface.enter_monitor.connect ((monitor) => {
            surface.disconnect (id);
            show_dismiss_overlay_for_monitor (monitor);
        });
    }

    protected override void activate () {
        if (window != null) {
            if (window.visible) {
                 request_close ();
            } else {
                 window.prepare_for_presentation ();
                 window.present ();
            }
            return;
        }

        register_app_icon_resources ();
        load_theme_css ();

        try {
            window = new MainWindow (
                this,
                config
            );
        } catch (Error e) {
            log_error ("app", "window_init: failed to initialize network manager client error=" + e.message);
            quit ();
            return;
        }
        window.close_request.connect (() => {
            hide_dismiss_overlay ();
            
            // We are always a daemon, just conceal the window when dismissed
            window.visible = false;
            return true;
        });
        window.map.connect (() => {
            on_main_window_mapped ();
        });
        window.unmap.connect (() => {
            hide_dismiss_overlay ();
        });
        
        if (is_daemon && !initial_activation_skipped) {
            initial_activation_skipped = true;
            // Load application logic in background to pre-warm the rendering pipeline
            // but keep the window totally hidden untoggled!
            return;
        }

        window.present ();
    }
}
