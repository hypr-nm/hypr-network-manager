using Gtk;
using GtkLayerShell;

public class MainWindow : Gtk.ApplicationWindow {
    private AppConfig config;
    private bool fullscreen_mode;
    private bool debug_enabled;

    public MainWindow(Gtk.Application app, AppConfig config, bool fullscreen, bool debug_enabled) {
        Object(application: app, title: "Network Manager");

        this.config = config;
        this.fullscreen_mode = fullscreen;
        this.debug_enabled = debug_enabled;

        set_default_size(config.window_width, config.window_height);
        set_resizable(false);

        configure_layer_shell();
        build_ui();
    }

    private void debug_log(string message) {
        if (debug_enabled) {
            stderr.printf("[rebuild] %s\n", message);
        }
    }

    private GtkLayerShell.Layer map_layer(string value) {
        switch (value.down().strip()) {
        case "background":
            return GtkLayerShell.Layer.BACKGROUND;
        case "bottom":
            return GtkLayerShell.Layer.BOTTOM;
        case "top":
            return GtkLayerShell.Layer.TOP;
        default:
            return GtkLayerShell.Layer.OVERLAY;
        }
    }

    private GtkLayerShell.KeyboardMode map_keyboard_mode(string value) {
        switch (value.down().strip()) {
        case "none":
            return GtkLayerShell.KeyboardMode.NONE;
        case "exclusive":
            return GtkLayerShell.KeyboardMode.EXCLUSIVE;
        default:
            return GtkLayerShell.KeyboardMode.ON_DEMAND;
        }
    }

    private void configure_layer_shell() {
        if (!GtkLayerShell.is_supported()) {
            stderr.printf("Warning: layer-shell support not detected; attempting init anyway.\n");
        }

        GtkLayerShell.init_for_window(this);
        GtkLayerShell.set_namespace(this, "hypr-network-manager");
        GtkLayerShell.set_layer(this, map_layer(config.layer));

        if (fullscreen_mode) {
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.RIGHT, true);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_margin(this, GtkLayerShell.Edge.TOP, 0);
            GtkLayerShell.set_margin(this, GtkLayerShell.Edge.RIGHT, 0);
            GtkLayerShell.set_margin(this, GtkLayerShell.Edge.BOTTOM, 0);
            GtkLayerShell.set_margin(this, GtkLayerShell.Edge.LEFT, 0);
        } else {
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.TOP, config.anchor_top);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.RIGHT, config.anchor_right);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.BOTTOM, config.anchor_bottom);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.LEFT, config.anchor_left);
            GtkLayerShell.set_margin(this, GtkLayerShell.Edge.TOP, config.margin_top);
            GtkLayerShell.set_margin(this, GtkLayerShell.Edge.RIGHT, config.margin_right);
            GtkLayerShell.set_margin(this, GtkLayerShell.Edge.BOTTOM, config.margin_bottom);
            GtkLayerShell.set_margin(this, GtkLayerShell.Edge.LEFT, config.margin_left);
        }

        GtkLayerShell.set_keyboard_mode(this, map_keyboard_mode(config.keyboard_mode));
        GtkLayerShell.auto_exclusive_zone_enable(this);

        debug_log("layer-shell configured");
    }

    private void build_ui() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        root.set_margin_top(16);
        root.set_margin_bottom(16);
        root.set_margin_start(16);
        root.set_margin_end(16);

        var title = new Gtk.Label("hypr-network-manager phase 2");
        title.set_xalign(0.0f);
        root.append(title);

        var subtitle = new Gtk.Label("Layer-shell + config loading is active.");
        subtitle.set_xalign(0.0f);
        root.append(subtitle);

        var geometry = new Gtk.Label("Size: %dx%d".printf(config.window_width, config.window_height));
        geometry.set_xalign(0.0f);
        root.append(geometry);

        var anchors = new Gtk.Label(
            "Anchors T:%s R:%s B:%s L:%s".printf(
                config.anchor_top.to_string(),
                config.anchor_right.to_string(),
                config.anchor_bottom.to_string(),
                config.anchor_left.to_string()
            )
        );
        anchors.set_xalign(0.0f);
        root.append(anchors);

        set_child(root);
    }
}
