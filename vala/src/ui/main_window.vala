using Gtk;
using Gdk;
using GtkLayerShell;

public class MainWindow : Gtk.ApplicationWindow {
    private AppConfig config;
    private bool fullscreen_mode;
    private bool debug_enabled;
    private NetworkManagerClientVala nm;
    private Gtk.Box? wifi_box = null;
    private Gtk.Label? wifi_action_status = null;
    private Gtk.Box? ethernet_box = null;
    private Gtk.Label? ethernet_action_status = null;
    private Gtk.Box? vpn_box = null;
    private Gtk.Label? vpn_action_status = null;
    private Gtk.Label? nm_probe_label = null;
    private Gtk.Label? wifi_state_label = null;
    private Gtk.Label? net_state_label = null;
    private Gtk.Image? status_icon = null;
    private Gtk.Label? status_label = null;
    private Gtk.Switch? networking_switch = null;
    private Gtk.Switch? wifi_switch = null;
    private bool updating_switches = false;
    private Gtk.EventControllerKey key_controller;

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
        configure_key_handling();
        Timeout.add_seconds(20, () => {
            refresh_all_sections();
            return true;
        });
    }

    private void configure_key_handling() {
        key_controller = new Gtk.EventControllerKey();
        key_controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
        ((Gtk.Widget) this).add_controller(key_controller);
        key_controller.key_released.connect(key_released_event_cb);
        key_controller.key_pressed.connect(key_press_event_cb);
    }

    private void key_released_event_cb(uint keyval, uint keycode, Gdk.ModifierType state) {
        if (this.get_focus() is Gtk.Entry) {
            if (Gdk.keyval_name(keyval) == "Escape") {
                this.set_focus(null);
            }
            return;
        }

        switch (Gdk.keyval_name(keyval)) {
        case "Escape":
        case "Caps_Lock":
            this.close();
            return;
        default:
            return;
        }
    }

    private bool key_press_event_cb(uint keyval, uint keycode, Gdk.ModifierType state) {
        if (get_focus() is Gtk.Editable) {
            return false;
        }

        switch (Gdk.keyval_name(keyval)) {
        case "Escape":
        case "Caps_Lock":
            this.close();
            return true;
        default:
            break;
        }

        return true;
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

        var status_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        status_icon = new Gtk.Image.from_icon_name("network-wireless-offline-symbolic");
        status_icon.set_pixel_size(16);
        status_row.append(status_icon);
        status_label = new Gtk.Label("Loading status...");
        status_label.set_xalign(0.0f);
        status_label.set_hexpand(true);
        status_row.append(status_label);
        root.append(status_row);

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

        nm_probe_label = new Gtk.Label("");
        nm_probe_label.set_xalign(0.0f);
        nm_probe_label.set_wrap(true);
        root.append(nm_probe_label);

        wifi_state_label = new Gtk.Label("");
        wifi_state_label.set_xalign(0.0f);
        wifi_state_label.set_wrap(true);
        root.append(wifi_state_label);

        net_state_label = new Gtk.Label("");
        net_state_label.set_xalign(0.0f);
        net_state_label.set_wrap(true);
        root.append(net_state_label);

        var toggle_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var networking_label = new Gtk.Label("Networking");
        networking_label.set_xalign(0.0f);
        networking_label.set_hexpand(true);
        networking_switch = new Gtk.Switch();
        networking_switch.notify["active"].connect(() => {
            on_networking_switch_changed();
        });
        toggle_row.append(networking_label);
        toggle_row.append(networking_switch);

        var wifi_toggle_label = new Gtk.Label("Wi-Fi");
        wifi_toggle_label.set_xalign(0.0f);
        wifi_toggle_label.set_hexpand(true);
        wifi_switch = new Gtk.Switch();
        wifi_switch.notify["active"].connect(() => {
            on_wifi_switch_changed();
        });
        toggle_row.append(wifi_toggle_label);
        toggle_row.append(wifi_switch);
        root.append(toggle_row);

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

        var refresh_button = new Gtk.Button.with_label("Refresh Wi-Fi");
        refresh_button.clicked.connect(() => {
            string scan_error;
            nm.scan_wifi(out scan_error);
            if (scan_error != "") {
                debug_log("wifi scan error: " + scan_error);
            }
            refresh_wifi_rows();
        });
        root.append(refresh_button);

        wifi_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        refresh_wifi_rows();
        root.append(wifi_box);

        wifi_action_status = new Gtk.Label("");
        wifi_action_status.set_xalign(0.0f);
        wifi_action_status.set_wrap(true);
        root.append(wifi_action_status);

        var ethernet_title = new Gtk.Label("Ethernet");
        ethernet_title.set_xalign(0.0f);
        root.append(ethernet_title);

        ethernet_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        refresh_ethernet_rows();
        root.append(ethernet_box);

        ethernet_action_status = new Gtk.Label("");
        ethernet_action_status.set_xalign(0.0f);
        ethernet_action_status.set_wrap(true);
        root.append(ethernet_action_status);

        var vpn_title = new Gtk.Label("VPN");
        vpn_title.set_xalign(0.0f);
        root.append(vpn_title);

        vpn_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        refresh_vpn_rows();
        root.append(vpn_box);

        vpn_action_status = new Gtk.Label("");
        vpn_action_status.set_xalign(0.0f);
        vpn_action_status.set_wrap(true);
        root.append(vpn_action_status);

        refresh_probe_labels();

        set_child(root);
    }

    private void clear_box(Gtk.Box box) {
        Gtk.Widget? child = box.get_first_child();
        while (child != null) {
            Gtk.Widget? next = child.get_next_sibling();
            box.remove(child);
            child = next;
        }
    }

    private void refresh_wifi_rows() {
        if (wifi_box == null) {
            return;
        }

        clear_box(wifi_box);

        foreach (var net in nm.get_wifi_networks()) {
            string lock = net.is_secured ? " [locked]" : "";
            string active = net.connected ? " [connected]" : "";
            string saved = net.saved ? " [saved]" : "";

            var wifi_text = new Gtk.Label(
                "%s - %u%% (%s)%s%s".printf(
                    net.ssid,
                    net.signal,
                    net.signal_label,
                    lock,
                    active
                )
            );
            wifi_text.set_xalign(0.0f);

            if (saved != "") {
                wifi_text.set_text(wifi_text.get_text() + saved);
            }

            var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            wifi_text.set_hexpand(true);
            row.append(wifi_text);

            var row_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            row_container.append(row);

            if (net.saved && !net.connected) {
                var connect_btn = new Gtk.Button.with_label("Connect");
                connect_btn.clicked.connect(() => {
                    string connect_error;
                    bool ok = nm.connect_saved_wifi(net, out connect_error);
                    if (wifi_action_status != null) {
                        if (ok) {
                            wifi_action_status.set_text("Connect requested for " + net.ssid);
                        } else {
                            wifi_action_status.set_text("Connect failed: " + connect_error);
                        }
                    }
                    refresh_wifi_rows();
                });
                row.append(connect_btn);

                var forget_btn = new Gtk.Button.with_label("Forget");
                forget_btn.clicked.connect(() => {
                    string forget_error;
                    bool ok = nm.forget_network(net.ssid, out forget_error);
                    if (wifi_action_status != null) {
                        if (ok) {
                            wifi_action_status.set_text("Forgot network " + net.ssid);
                        } else {
                            wifi_action_status.set_text("Forget failed: " + forget_error);
                        }
                    }
                    refresh_wifi_rows();
                });
                row.append(forget_btn);
            }

            if (net.connected) {
                var disconnect_btn = new Gtk.Button.with_label("Disconnect");
                disconnect_btn.clicked.connect(() => {
                    string disconnect_error;
                    bool ok = nm.disconnect_wifi(net, out disconnect_error);
                    if (wifi_action_status != null) {
                        if (ok) {
                            wifi_action_status.set_text("Disconnect requested for " + net.ssid);
                        } else {
                            wifi_action_status.set_text("Disconnect failed: " + disconnect_error);
                        }
                    }
                    refresh_wifi_rows();
                });
                row.append(disconnect_btn);
            }

            if (net.is_secured && !net.saved && !net.connected) {
                var prompt_btn = new Gtk.Button.with_label("Password...");
                row.append(prompt_btn);

                var revealer = new Gtk.Revealer();
                revealer.set_reveal_child(false);

                var prompt_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
                var pass_entry = new Gtk.Entry();
                pass_entry.set_placeholder_text("Wi-Fi password");
                pass_entry.set_visibility(false);
                pass_entry.set_hexpand(true);

                var submit_btn = new Gtk.Button.with_label("Connect");
                submit_btn.clicked.connect(() => {
                    string connect_error;
                    bool ok = nm.connect_wifi_with_password(net, pass_entry.get_text(), out connect_error);
                    if (wifi_action_status != null) {
                        if (ok) {
                            wifi_action_status.set_text("Connect requested for " + net.ssid);
                        } else {
                            wifi_action_status.set_text("Connect failed: " + connect_error);
                        }
                    }
                    refresh_wifi_rows();
                });

                prompt_box.append(pass_entry);
                prompt_box.append(submit_btn);
                revealer.set_child(prompt_box);
                row_container.append(revealer);

                prompt_btn.clicked.connect(() => {
                    revealer.set_reveal_child(!revealer.get_reveal_child());
                });
            }

            wifi_box.append(row_container);
        }

        if (wifi_box.get_first_child() == null) {
            var empty = new Gtk.Label("No Wi-Fi access points discovered");
            empty.set_xalign(0.0f);
            wifi_box.append(empty);
        }
    }

    private void refresh_all_sections() {
        refresh_status_bar();
        refresh_probe_labels();
        refresh_wifi_rows();
        refresh_ethernet_rows();
        refresh_vpn_rows();
    }

    private void refresh_status_bar() {
        if (status_icon == null || status_label == null) {
            return;
        }

        bool networking_on;
        bool wifi_on;
        string error_message;
        if (!nm.get_networking_enabled(out networking_on, out error_message)) {
            networking_on = false;
        }
        if (!nm.get_wifi_enabled(out wifi_on, out error_message)) {
            wifi_on = false;
        }

        NetworkDevice? active_wifi = null;
        NetworkDevice? active_eth = null;
        foreach (var dev in nm.get_devices()) {
            if (dev.is_wifi && dev.is_connected) {
                active_wifi = dev;
            } else if (dev.is_ethernet && dev.is_connected) {
                active_eth = dev;
            }
        }

        if (!networking_on) {
            status_icon.set_from_icon_name("network-offline-symbolic");
            status_label.set_text("Networking disabled");
            return;
        }

        if (active_eth != null) {
            status_icon.set_from_icon_name("network-wired-symbolic");
            string name = active_eth.connection != "" ? active_eth.connection : active_eth.name;
            status_label.set_text("Ethernet: " + name);
            return;
        }

        if (active_wifi != null) {
            uint signal = 0;
            foreach (var net in nm.get_wifi_networks()) {
                if (net.connected) {
                    signal = net.signal;
                    break;
                }
            }
            status_icon.set_from_icon_name("network-wireless-signal-excellent-symbolic");
            string name = active_wifi.connection != "" ? active_wifi.connection : active_wifi.name;
            status_label.set_text("Wi-Fi: %s (%u%%)".printf(name, signal));
            return;
        }

        if (!wifi_on) {
            status_icon.set_from_icon_name("network-wireless-disabled-symbolic");
            status_label.set_text("Wi-Fi disabled");
            return;
        }

        status_icon.set_from_icon_name("network-wireless-offline-symbolic");
        status_label.set_text("Disconnected");
    }

    private void refresh_probe_labels() {
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

        if (nm_probe_label != null) {
            nm_probe_label.set_text(backend_summary);
        }

        bool wifi_enabled = false;
        string wifi_error = "";
        bool wifi_ok = nm.get_wifi_enabled(out wifi_enabled, out wifi_error);
        if (wifi_state_label != null) {
            wifi_state_label.set_text(
                wifi_ok
                    ? "Wi-Fi radio enabled: %s".printf(wifi_enabled.to_string())
                    : "Wi-Fi radio read failed: " + wifi_error
            );
        }

        bool networking_enabled2 = false;
        string net_error = "";
        bool net_ok = nm.get_networking_enabled(out networking_enabled2, out net_error);
        if (net_state_label != null) {
            net_state_label.set_text(
                net_ok
                    ? "Networking enabled: %s".printf(networking_enabled2.to_string())
                    : "Networking read failed: " + net_error
            );
        }

        updating_switches = true;
        if (networking_switch != null && net_ok) {
            networking_switch.set_active(networking_enabled2);
        }
        if (wifi_switch != null && wifi_ok) {
            wifi_switch.set_active(wifi_enabled);
        }
        updating_switches = false;
    }

    private void on_networking_switch_changed() {
        if (updating_switches || networking_switch == null) {
            return;
        }

        string err;
        bool ok = nm.set_networking_enabled(networking_switch.get_active(), out err);
        if (!ok) {
            debug_log("networking toggle failed: " + err);
        }
        refresh_all_sections();
    }

    private void on_wifi_switch_changed() {
        if (updating_switches || wifi_switch == null) {
            return;
        }

        string err;
        bool ok = nm.set_wifi_enabled(wifi_switch.get_active(), out err);
        if (!ok) {
            debug_log("wifi toggle failed: " + err);
        }
        refresh_all_sections();
    }

    private void refresh_ethernet_rows() {
        if (ethernet_box == null) {
            return;
        }

        clear_box(ethernet_box);

        foreach (var dev in nm.get_devices()) {
            if (!dev.is_ethernet) {
                continue;
            }

            var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var label = new Gtk.Label("%s: %s".printf(dev.name, dev.state_label));
            label.set_xalign(0.0f);
            label.set_hexpand(true);
            row.append(label);

            if (dev.connection != "") {
                label.set_text(label.get_text() + " [" + dev.connection + "]");
            }

            if (dev.is_connected) {
                var disconnect_btn = new Gtk.Button.with_label("Disconnect");
                disconnect_btn.clicked.connect(() => {
                    string err;
                    bool ok = nm.disconnect_device(dev.name, out err);
                    if (ethernet_action_status != null) {
                        if (ok) {
                            ethernet_action_status.set_text("Disconnect requested for " + dev.name);
                        } else {
                            ethernet_action_status.set_text("Disconnect failed: " + err);
                        }
                    }
                    refresh_ethernet_rows();
                });
                row.append(disconnect_btn);
            }

            ethernet_box.append(row);
        }

        if (ethernet_box.get_first_child() == null) {
            var empty = new Gtk.Label("No ethernet devices discovered");
            empty.set_xalign(0.0f);
            ethernet_box.append(empty);
        }
    }

    private void refresh_vpn_rows() {
        if (vpn_box == null) {
            return;
        }

        clear_box(vpn_box);

        foreach (var vpn in nm.get_vpn_connections()) {
            string state = vpn.is_connected ? "connected" : "disconnected";
            var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var label = new Gtk.Label("%s (%s): %s".printf(vpn.name, vpn.vpn_type, state));
            label.set_xalign(0.0f);
            label.set_hexpand(true);
            row.append(label);

            if (vpn.is_connected) {
                var btn = new Gtk.Button.with_label("Disconnect");
                btn.clicked.connect(() => {
                    string err;
                    bool ok = nm.disconnect_vpn(vpn.name, out err);
                    if (vpn_action_status != null) {
                        if (ok) {
                            vpn_action_status.set_text("Disconnect requested for " + vpn.name);
                        } else {
                            vpn_action_status.set_text("Disconnect failed: " + err);
                        }
                    }
                    refresh_vpn_rows();
                });
                row.append(btn);
            } else {
                var btn = new Gtk.Button.with_label("Connect");
                btn.clicked.connect(() => {
                    string err;
                    bool ok = nm.connect_vpn(vpn.name, out err);
                    if (vpn_action_status != null) {
                        if (ok) {
                            vpn_action_status.set_text("Connect requested for " + vpn.name);
                        } else {
                            vpn_action_status.set_text("Connect failed: " + err);
                        }
                    }
                    refresh_vpn_rows();
                });
                row.append(btn);
            }

            vpn_box.append(row);
        }

        if (vpn_box.get_first_child() == null) {
            var empty = new Gtk.Label("No VPN profiles discovered");
            empty.set_xalign(0.0f);
            vpn_box.append(empty);
        }
    }
}
