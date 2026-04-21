using GLib;

public class AppConfig : Object {
    private const int64 MAX_CONFIG_FILE_BYTES = 1024 * 1024;

    public int window_width = 480;
    public int window_height = 560;
    public bool anchor_top = true;
    public bool anchor_right = true;
    public bool anchor_bottom = false;
    public bool anchor_left = false;
    public int margin_top = 8;
    public int margin_right = 8;
    public int margin_bottom = 8;
    public int margin_left = 8;
    public string layer = "overlay";
    public AppLogLevel log_level = AppLogLevel.INFO;
    public int scan_interval = 30;
    public int pending_wifi_connect_timeout_ms = 45000;
    public bool close_on_connect = true;
    public bool show_bssid = false;
    public bool show_frequency = true;
    public bool show_band = false;

    private static string describe_json_node_type (Json.Node? node) {
        if (node == null) {
            return "missing";
        }

        switch (node.get_node_type ()) {
        case Json.NodeType.ARRAY:
            return "array";
        case Json.NodeType.OBJECT:
            return "object";
        case Json.NodeType.NULL:
            return "null";
        case Json.NodeType.VALUE:
            Type value_type = node.get_value_type ();
            if (value_type == typeof (string)) {
                return "string";
            }
            if (value_type == typeof (bool)) {
                return "boolean";
            }
            if (value_type == typeof (int)
                || value_type == typeof (int64)
                || value_type == typeof (uint)
                || value_type == typeof (uint64)
                || value_type == typeof (long)
                || value_type == typeof (ulong)
                || value_type == typeof (double)
                || value_type == typeof (float)) {
                return "number";
            }
            return value_type.name ();
        default:
            return "unknown";
        }
    }

    private static void warn_invalid_config_type (
        string config_path,
        string key,
        string expected_type,
        Json.Node? node
    ) {
        log_debug (
            "config",
            "ignoring config key '%s' in %s: expected %s, got %s".printf (
                key,
                config_path,
                expected_type,
                describe_json_node_type (node)
            )
        );
    }

    private static void warn_invalid_config_value (
        string config_path,
        string key,
        string value,
        string expected_values
    ) {
        log_warn (
            "config",
            "ignoring config key '%s' in %s: invalid value='%s'; expected %s".printf (
                key,
                redact_fs_path (config_path),
                value,
                expected_values
            )
        );
    }

    private static string? extract_json_string (
        Json.Object obj,
        string key,
        string config_path
    ) {
        if (!obj.has_member (key)) {
            return null;
        }

        Json.Node? node = obj.get_member (key);
        if (node == null
            || node.get_node_type () != Json.NodeType.VALUE
            || node.get_value_type () != typeof (string)) {
            warn_invalid_config_type (config_path, key, "string", node);
            return null;
        }

        return obj.get_string_member (key);
    }

    private static int? extract_json_int (
        Json.Object obj,
        string key,
        string config_path
    ) {
        if (!obj.has_member (key)) {
            return null;
        }

        Json.Node? node = obj.get_member (key);
        if (node == null || node.get_node_type () != Json.NodeType.VALUE) {
            warn_invalid_config_type (config_path, key, "integer", node);
            return null;
        }

        Type value_type = node.get_value_type ();
        bool is_integral = value_type == typeof (int)
            || value_type == typeof (int64)
            || value_type == typeof (uint)
            || value_type == typeof (uint64)
            || value_type == typeof (long)
            || value_type == typeof (ulong);
        bool is_float = value_type == typeof (double) || value_type == typeof (float);

        if (is_integral) {
            return (int) obj.get_int_member (key);
        }

        if (is_float) {
            double value = obj.get_double_member (key);
            int64 whole = (int64) value;
            if ((double) whole != value
                || value < (double) int.MIN
                || value > (double) int.MAX) {
                warn_invalid_config_type (config_path, key, "integer", node);
                return null;
            }
            return (int) value;
        }

        warn_invalid_config_type (config_path, key, "integer", node);
        return null;
    }

    private static bool? extract_json_bool (
        Json.Object obj,
        string key,
        string config_path
    ) {
        if (!obj.has_member (key)) {
            return null;
        }

        Json.Node? node = obj.get_member (key);
        if (node == null
            || node.get_node_type () != Json.NodeType.VALUE
            || node.get_value_type () != typeof (bool)) {
            warn_invalid_config_type (config_path, key, "boolean", node);
            return null;
        }

        return obj.get_boolean_member (key);
    }

    private static void apply_position (
        string position,
        out bool anchor_top,
        out bool anchor_right,
        out bool anchor_bottom,
        out bool anchor_left
    ) {
        anchor_top = false;
        anchor_right = false;
        anchor_bottom = false;
        anchor_left = false;

        switch (position.down ().strip ()) {
        case "top-left":
            anchor_top = true;
            anchor_left = true;
            break;
        case "top-right":
            anchor_top = true;
            anchor_right = true;
            break;
        case "bottom-left":
            anchor_bottom = true;
            anchor_left = true;
            break;
        case "bottom-right":
            anchor_bottom = true;
            anchor_right = true;
            break;
        case "top":
            anchor_top = true;
            break;
        case "right":
            anchor_right = true;
            break;
        case "bottom":
            anchor_bottom = true;
            break;
        case "left":
            anchor_left = true;
            break;
        default:
            anchor_top = true;
            anchor_right = true;
            break;
        }
    }

    private static string get_default_config_path () {
        return Path.build_filename (
            Environment.get_home_dir (),
            ".config",
            "hypr-network-manager",
            "config.json"
        );
    }

    private static string get_system_config_path () {
        return Path.build_filename (
            "/etc",
            "xdg",
            "hypr-network-manager",
            "config.json"
        );
    }

    private static bool resolve_config_path (
        string? explicit_path,
        out string effective_path
    ) {
        string local = get_default_config_path ();
        string system = get_system_config_path ();

        if (explicit_path != null) {
            effective_path = explicit_path;
            return FileUtils.test (effective_path, FileTest.EXISTS);
        }

        if (FileUtils.test (local, FileTest.EXISTS)) {
            effective_path = local;
            return true;
        }

        if (FileUtils.test (system, FileTest.EXISTS)) {
            effective_path = system;
            return true;
        }

        effective_path = local; // fallback for logging
        return false;
    }

    private static string? load_config_file (string path) {
        try {
            string content;
            size_t len = 0;

            FileUtils.get_contents (path, out content, out len);

            if ((int64) len > MAX_CONFIG_FILE_BYTES) {
                log_warn (
                    "config",
                    "load_config: rejected oversize file path=%s size=%s max=%s"
                        .printf (
                            redact_fs_path (path),
                            len.to_string (),
                            MAX_CONFIG_FILE_BYTES.to_string ()
                        )
                );
                return null;
            }

            return content;
        } catch (Error e) {
            log_debug (
                "config",
                "load_config: read failed path=%s error=%s"
                    .printf (redact_fs_path (path), e.message)
            );
            return null;
        }
    }

    private static Json.Object? parse_config_json (string content, string path) {
        try {
            var parser = new Json.Parser ();
            parser.load_from_data (content, content.length);

            Json.Node? root = parser.get_root ();

            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                log_debug (
                    "config",
                    "load_config: invalid JSON root path=%s expected=object"
                        .printf (redact_fs_path (path))
                );
                return null;
            }

            return root.get_object ();
        } catch (Error e) {
            log_debug (
                "config",
                "load_config: parse failed path=%s error=%s"
                    .printf (redact_fs_path (path), e.message)
            );
            return null;
        }
    }

    private void apply_position_config (Json.Object obj, string path) {
        string position = "top-right";

        string? cfg_position = extract_json_string (obj, "position", path);
        if (cfg_position != null) {
            position = cfg_position;
        }

        bool top, right, bottom, left;
        apply_position (position, out top, out right, out bottom, out left);

        this.anchor_top = top;
        this.anchor_right = right;
        this.anchor_bottom = bottom;
        this.anchor_left = left;
    }

    private void apply_window_config (Json.Object obj, string path) {
        int? w = extract_json_int (obj, "window_width", path);
        if (w != null && w > 0) this.window_width = w;

        int? h = extract_json_int (obj, "window_height", path);
        if (h != null && h > 0) this.window_height = h;
    }

    private void apply_log_config (Json.Object obj, string path) {
        string? lvl = extract_json_string (obj, "log_level", path);

        if (lvl == null) return;

        AppLogLevel parsed;
        if (parse_app_log_level (lvl, out parsed)) {
            this.log_level = parsed;
        } else {
            warn_invalid_config_value (
                path,
                "log_level",
                lvl,
                "debug|info|warn|error"
            );
        }
    }

    private void apply_margin_config (Json.Object obj, string path) {
        int? top = extract_json_int (obj, "layer_shell_margin_top", path);
        if (top != null) {
            this.margin_top = top;
        }

        int? right = extract_json_int (obj, "layer_shell_margin_right", path);
        if (right != null) {
            this.margin_right = right;
        }

        int? bottom = extract_json_int (obj, "layer_shell_margin_bottom", path);
        if (bottom != null) {
            this.margin_bottom = bottom;
        }

        int? left = extract_json_int (obj, "layer_shell_margin_left", path);
        if (left != null) {
            this.margin_left = left;
        }
    }

    private void apply_behavior_config (Json.Object obj, string path) {
        int? scan_interval = extract_json_int (obj, "scan_interval", path);
        if (scan_interval != null && scan_interval > 0) {
            this.scan_interval = scan_interval;
        }

        int? timeout = extract_json_int (
            obj,
            "pending_wifi_connect_timeout_ms",
            path
        );
        if (timeout != null && timeout > 0) {
            this.pending_wifi_connect_timeout_ms = timeout;
        }

        bool? close_on_connect = extract_json_bool (
            obj,
            "close_on_connect",
            path
        );
        if (close_on_connect != null) {
            this.close_on_connect = close_on_connect;
        }

        bool? show_bssid = extract_json_bool (
            obj,
            "show_bssid",
            path
        );
        if (show_bssid != null) {
            this.show_bssid = show_bssid;
        }

        bool? show_frequency = extract_json_bool (
            obj,
            "show_frequency",
            path
        );
        if (show_frequency != null) {
            this.show_frequency = show_frequency;
        }

        bool? show_band = extract_json_bool (
            obj,
            "show_band",
            path
        );
        if (show_band != null) {
            this.show_band = show_band;
        }
    }
    private void apply_config_fields (
        Json.Object obj,
        string path
    ) {
        apply_window_config (obj, path);
        apply_log_config (obj, path);
        apply_position_config (obj, path);
        apply_margin_config (obj, path);
        apply_behavior_config (obj, path);
    }

    public static AppConfig load (string? explicit_path) {
        var cfg = new AppConfig ();

        string path;
        bool found = resolve_config_path (explicit_path, out path);

        if (!found) {
            log_debug ("config", "load_config: not found; using defaults");
            return cfg;
        }

        string? content = load_config_file (path);
        if (content == null) return cfg;

        Json.Object? obj = parse_config_json (content, path);
        if (obj == null) return cfg;

        cfg.apply_config_fields (obj, path);

        log_debug (
            "config",
            "load_config: loaded path=%s"
                .printf (redact_fs_path (path))
        );

        return cfg;
    }
}
