using Gtk;
using GtkLayerShell;

public class MainWindow : Gtk.ApplicationWindow {
    private AppConfig config;
    private bool fullscreen_mode;
    private bool debug_enabled;
    private NetworkManagerClientVala nm;

    public MainWindow(Gtk.Application app, AppConfig config, bool fullscreen, bool debug_enabled) {
        Object(application: app, title: "Network Manager");

        this.config = config;
        this.fullscreen_mode = fullscreen;
        this.debug_enabled = debug_enabled;
        this.nm = new NetworkManagerClientVala(debug_enabled);

        set_default_size(config.window_width, config.window_height);
        set_resizable(false);
        add_css_class("nm-window");

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
        root.add_css_class("nm-root");
        root.set_margin_top(16);
        root.set_margin_bottom(16);
        root.set_margin_start(16);
        root.set_margin_end(16);

        var title = new Gtk.Label("hypr-network-manager phase 2");
        title.add_css_class("nm-title");
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

        string error_message;
        bool networking_enabled = nm.is_networking_enabled(out error_message);
        uint device_count = nm.get_device_paths().length();
        string backend_summary = "NM read probe: networking=%s, devices=%u".printf(
            networking_enabled.to_string(),
            device_count
        );
        if (error_message != "") {
            backend_summary = "NM read probe failed: " + error_message;
        }

        var nm_label = new Gtk.Label(backend_summary);
        nm_label.set_xalign(0.0f);
        nm_label.set_wrap(true);
        root.append(nm_label);

        bool wifi_enabled = false;
        string wifi_error = "";
        bool wifi_ok = nm.get_wifi_enabled(out wifi_enabled, out wifi_error);
        var wifi_state = new Gtk.Label(
            wifi_ok
                ? "Wi-Fi radio enabled: %s".printf(wifi_enabled.to_string())
                : "Wi-Fi radio read failed: " + wifi_error
        );
        wifi_state.set_xalign(0.0f);
        wifi_state.set_wrap(true);
        root.append(wifi_state);

        bool networking_enabled2 = false;
        string net_error = "";
        bool net_ok = nm.get_networking_enabled(out networking_enabled2, out net_error);
        var net_state = new Gtk.Label(
            net_ok
                ? "Networking enabled: %s".printf(networking_enabled2.to_string())
                : "Networking read failed: " + net_error
        );
        net_state.set_xalign(0.0f);
        net_state.set_wrap(true);
        root.append(net_state);

        var device_title = new Gtk.Label("Discovered devices");
        device_title.set_xalign(0.0f);
        root.append(device_title);

        var devices_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        foreach (var dev in nm.get_devices()) {
            string kind = "other";
            if (dev.is_wifi) {
                kind = "wifi";
            } else if (dev.is_ethernet) {
                kind = "ethernet";
            }

            string text = "%s (%s): %s".printf(dev.name, kind, dev.state_label);
            if (dev.connection != "") {
                text += " [" + dev.connection + "]";
            }

            var row = new Gtk.Label(text);
            row.set_xalign(0.0f);
            devices_box.append(row);
        }

        root.append(devices_box);

        var wifi_title = new Gtk.Label("Wi-Fi networks");
        wifi_title.set_xalign(0.0f);
        root.append(wifi_title);

        var wifi_placeholder = new Gtk.Label("Wi-Fi list scaffold ready");
        wifi_placeholder.set_xalign(0.0f);
        root.append(wifi_placeholder);

        set_child(root);
    }
}
