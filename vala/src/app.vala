using Gtk;
using Gdk;

[CCode (cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
private extern void gtk_style_provider_add_for_display (
    Gdk.Display display,
    Gtk.StyleProvider provider,
    uint priority
);

[CCode (cname = "gtk_style_context_remove_provider_for_display", cheader_filename = "gtk/gtk.h")]
private extern void gtk_style_provider_remove_for_display (
    Gdk.Display display,
    Gtk.StyleProvider provider
);

public class NetworkManager : Gtk.Application {
    private AppConfig config;
    private MainWindow? window;
    private BlankWindow? dismiss_overlay;
    private bool is_daemon;
    private bool initial_activation_skipped = false;
    private Gtk.CssProvider? current_css_provider = null;

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

    private string inline_css_imports (string file_path, int depth = 0, HashTable<string, bool>? visited = null) {
        if (depth > 20) {
            log_warn ("app", "inline_css_imports: Max recursion depth reached at " + file_path);
            return "";
        }

        var _visited = visited ?? new HashTable<string, bool> (str_hash, str_equal);
        if (_visited.contains (file_path)) {
            log_warn ("app", "inline_css_imports: Circular import detected at " + file_path);
            return "";
        }
        _visited.insert (file_path, true);

        string content = "";
        if (file_path.has_prefix ("resource:///")) {
            try {
                Bytes bytes = resources_lookup_data (file_path.substring (11), ResourceLookupFlags.NONE);
                if (bytes != null) {
                    content = (string) bytes.get_data ();
                }
            } catch (Error e) {
                log_warn ("app", "inline_css_imports: Failed to load resource " + file_path);
            }
        } else {
            try {
                // Ensure the path is absolute to prevent arbitrary directory traversal from CWD
                string abs_path = Path.is_absolute (file_path) ? file_path : Path.build_filename (Environment.get_current_dir (), file_path);
                
                // Add an arbitrary sanity limit to the file size (e.g. 5MB)
                var file = File.new_for_path (abs_path);
                var info = file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE, null);
                if (info.get_size () > 5 * 1024 * 1024) {
                    log_warn ("app", "inline_css_imports: File too large " + abs_path);
                    return "";
                }

                FileUtils.get_contents (abs_path, out content);
            } catch (Error e) {
                log_warn ("app", "inline_css_imports: Failed to load file " + file_path);
            }
        }

        if (content == "") {
            return "";
        }

        try {
            var regex = new Regex ("@import\\s+(?:url\\([\"']?([^\"']+)[\"']?\\)|[\"']([^\"']+)[\"'])\\s*;");
            return regex.replace_eval (content, content.length, 0, 0, (match_info, result) => {
                string import_target = match_info.fetch (1);
                if (import_target == null || import_target == "") {
                     import_target = match_info.fetch (2);
                }
                
                if (import_target == null || import_target == "") {
                    return false;
                }

                string target_path = "";
                
                bool is_core = import_target.has_suffix ("core/structure.css") 
                    || import_target.has_suffix ("core/core-components.css");

                if (is_core && config.load_core_styles) {
                    return false; 
                }

                if (import_target.has_prefix ("resource:///")) {
                    target_path = import_target;
                } else if (Path.is_absolute (import_target)) {
                    target_path = import_target;
                } else {
                    string dir = "";
                    if (file_path.has_prefix ("resource:///")) {
                        int last_slash = file_path.last_index_of ("/");
                        if (last_slash >= 0) {
                            dir = file_path.substring (0, last_slash);
                        } else {
                            dir = "resource:///";
                        }
                    } else {
                        dir = Path.get_dirname (file_path);
                    }
                    target_path = Path.build_filename (dir, import_target);
                }
                
                string inlined = inline_css_imports (target_path, depth + 1, _visited);
                result.append (inlined);
                return false;
            });
        } catch (Error e) {
            return content;
        }
    }

    private bool load_css_from_string (string css_data, uint priority) {
        var provider = new Gtk.CssProvider ();
        provider.load_from_string (css_data);
        var display = Gdk.Display.get_default ();
        if (display == null) {
            return false;
        }

        if (current_css_provider != null) {
            gtk_style_provider_remove_for_display (display, current_css_provider);
        }
        current_css_provider = provider;

        gtk_style_provider_add_for_display (display, provider, priority);
        log_info ("app", "load_theme_css: loaded and inlined stylesheet successfully");
        return true;
    }

    private void load_theme_css (bool force_reload = false) {
        string? css_path = resolve_base_css_path ();
        if (css_path == null) {
            debug_log ("load_theme_css: no stylesheet found in local/system/bundled paths; outcome=skipping");
            return;
        }

        var master_builder = new StringBuilder ();

        if (config.load_core_styles) {
            master_builder.append (inline_css_imports ("resource:///yeab212/hypr-network-manager/styles/structure.css"));
            master_builder.append (inline_css_imports ("resource:///yeab212/hypr-network-manager/styles/core-components.css"));
        }

        master_builder.append (inline_css_imports (css_path));

        string inlined_css = master_builder.str;
        if (inlined_css == "") {
            log_warn ("app", "load_theme_css: resolved stylesheet is empty; outcome=skipping");
            return;
        }

        MainWindowCssClassResolver.initialize (inlined_css, css_path, force_reload);

        if (!load_css_from_string (inlined_css, Gtk.STYLE_PROVIDER_PRIORITY_USER)) {
            log_warn ("app", "load_theme_css: failed to apply inlined stylesheet; outcome=continuing");
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

        dismiss_overlay = new BlankWindow (this, monitor, window.current_layer_mode);
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

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            log_info ("app", "quit_action: received; exiting");
            this.quit ();
        });
        this.add_action (quit_action);
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
                 load_theme_css (true);
                 window.prepare_for_presentation ();
                 window.present ();
            }
            return;
        }

        register_app_icon_resources ();
        load_theme_css (true);

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
