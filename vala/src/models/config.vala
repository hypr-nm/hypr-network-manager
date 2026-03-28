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
    public int scan_interval = 30;
    public int pending_wifi_connect_timeout_ms = 45000;
    public bool close_on_connect = true;
    public bool show_bssid = false;
    public bool show_frequency = true;
    public bool show_band = false;

    private static string describe_json_node_type(Json.Node? node) {
        if (node == null) {
            return "missing";
        }

        switch (node.get_node_type()) {
        case Json.NodeType.ARRAY:
            return "array";
        case Json.NodeType.OBJECT:
            return "object";
        case Json.NodeType.NULL:
            return "null";
        case Json.NodeType.VALUE:
            Type value_type = node.get_value_type();
            if (value_type == typeof(string)) {
                return "string";
            }
            if (value_type == typeof(bool)) {
                return "boolean";
            }
            if (value_type == typeof(int)
                || value_type == typeof(int64)
                || value_type == typeof(uint)
                || value_type == typeof(uint64)
                || value_type == typeof(long)
                || value_type == typeof(ulong)
                || value_type == typeof(double)
                || value_type == typeof(float)) {
                return "number";
            }
            return value_type.name();
        default:
            return "unknown";
        }
    }

    private static void warn_invalid_config_type(
        string config_path,
        string key,
        string expected_type,
        Json.Node? node
    ) {
        log_debug(
            "config",
            "ignoring config key '%s' in %s: expected %s, got %s".printf(
                key,
                config_path,
                expected_type,
                describe_json_node_type(node)
            )
        );
    }

    private static string? extract_json_string(
        Json.Object obj,
        string key,
        string config_path
    ) {
        if (!obj.has_member(key)) {
            return null;
        }

        Json.Node? node = obj.get_member(key);
        if (node == null
            || node.get_node_type() != Json.NodeType.VALUE
            || node.get_value_type() != typeof(string)) {
            warn_invalid_config_type(config_path, key, "string", node);
            return null;
        }

        return obj.get_string_member(key);
    }

    private static int? extract_json_int(
        Json.Object obj,
        string key,
        string config_path
    ) {
        if (!obj.has_member(key)) {
            return null;
        }

        Json.Node? node = obj.get_member(key);
        if (node == null || node.get_node_type() != Json.NodeType.VALUE) {
            warn_invalid_config_type(config_path, key, "integer", node);
            return null;
        }

        Type value_type = node.get_value_type();
        bool is_integral = value_type == typeof(int)
            || value_type == typeof(int64)
            || value_type == typeof(uint)
            || value_type == typeof(uint64)
            || value_type == typeof(long)
            || value_type == typeof(ulong);
        bool is_float = value_type == typeof(double) || value_type == typeof(float);

        if (is_integral) {
            return (int) obj.get_int_member(key);
        }

        if (is_float) {
            double value = obj.get_double_member(key);
            int64 whole = (int64) value;
            if ((double) whole != value
                || value < (double) int.MIN
                || value > (double) int.MAX) {
                warn_invalid_config_type(config_path, key, "integer", node);
                return null;
            }
            return (int) value;
        }

        warn_invalid_config_type(config_path, key, "integer", node);
        return null;
    }

    private static bool? extract_json_bool(
        Json.Object obj,
        string key,
        string config_path
    ) {
        if (!obj.has_member(key)) {
            return null;
        }

        Json.Node? node = obj.get_member(key);
        if (node == null
            || node.get_node_type() != Json.NodeType.VALUE
            || node.get_value_type() != typeof(bool)) {
            warn_invalid_config_type(config_path, key, "boolean", node);
            return null;
        }

        return obj.get_boolean_member(key);
    }

    private static void apply_position(
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

        switch (position.down().strip()) {
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

    private static string get_default_config_path() {
        return Path.build_filename(
            Environment.get_home_dir(),
            ".config",
            "hypr-network-manager",
            "config.json"
        );
    }

    private static string get_system_config_path() {
        return Path.build_filename(
            "/etc",
            "xdg",
            "hypr-network-manager",
            "config.json"
        );
    }

    public static AppConfig load(string? explicit_path) {
        var cfg = new AppConfig();

        string local_config_path = get_default_config_path();
        string system_config_path = get_system_config_path();
        string effective_config_path = local_config_path;
        bool has_config = false;

        if (explicit_path != null) {
            effective_config_path = explicit_path;
            has_config = FileUtils.test(effective_config_path, FileTest.EXISTS);
        } else if (FileUtils.test(local_config_path, FileTest.EXISTS)) {
            effective_config_path = local_config_path;
            has_config = true;
        } else if (FileUtils.test(system_config_path, FileTest.EXISTS)) {
            effective_config_path = system_config_path;
            has_config = true;
        }

        if (!has_config) {
            if (explicit_path != null) {
                log_debug(
                    "config",
                    "load_config: file not found path=%s; outcome=using defaults"
                        .printf(redact_fs_path(effective_config_path))
                );
            } else {
                log_debug(
                    "config",
                    "load_config: file not found in search paths local=%s system=%s; outcome=using defaults"
                        .printf(
                        redact_fs_path(local_config_path),
                        redact_fs_path(system_config_path)
                    )
                );
            }
            return cfg;
        }

        try {
            string content;
            size_t content_length = 0;
            FileUtils.get_contents(effective_config_path, out content, out content_length);
            if ((int64) content_length > MAX_CONFIG_FILE_BYTES) {
                log_warn(
                    "config",
                    "load_config: rejected oversize file path=%s size=%s max=%s; outcome=using defaults"
                        .printf(
                            redact_fs_path(effective_config_path),
                            content_length.to_string(),
                            MAX_CONFIG_FILE_BYTES.to_string()
                        )
                );
                return cfg;
            }

            var parser = new Json.Parser();
            parser.load_from_data(content, content.length);

            Json.Node? root = parser.get_root();
            if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
                log_debug(
                    "config",
                    "load_config: invalid JSON root path=%s expected=object; outcome=using defaults"
                        .printf(redact_fs_path(effective_config_path))
                );
                return cfg;
            }

            Json.Object obj = root.get_object();

            int? cfg_width = extract_json_int(obj, "window_width", effective_config_path);
            if (cfg_width != null && cfg_width > 0) {
                cfg.window_width = cfg_width;
            }

            int? cfg_height = extract_json_int(obj, "window_height", effective_config_path);
            if (cfg_height != null && cfg_height > 0) {
                cfg.window_height = cfg_height;
            }

            string? cfg_layer = extract_json_string(
                obj,
                "layer_shell_layer",
                effective_config_path
            );
            if (cfg_layer != null) {
                cfg.layer = cfg_layer;
            }

            string position = "top-right";
            string? cfg_position = extract_json_string(
                obj,
                "position",
                effective_config_path
            );
            if (cfg_position != null) {
                position = cfg_position;
            }

            bool pos_top;
            bool pos_right;
            bool pos_bottom;
            bool pos_left;
            apply_position(position, out pos_top, out pos_right, out pos_bottom, out pos_left);
            cfg.anchor_top = pos_top;
            cfg.anchor_right = pos_right;
            cfg.anchor_bottom = pos_bottom;
            cfg.anchor_left = pos_left;

            int? cfg_margin_top = extract_json_int(
                obj,
                "layer_shell_margin_top",
                effective_config_path
            );
            if (cfg_margin_top != null) {
                cfg.margin_top = cfg_margin_top;
            }
            int? cfg_margin_right = extract_json_int(
                obj,
                "layer_shell_margin_right",
                effective_config_path
            );
            if (cfg_margin_right != null) {
                cfg.margin_right = cfg_margin_right;
            }
            int? cfg_margin_bottom = extract_json_int(
                obj,
                "layer_shell_margin_bottom",
                effective_config_path
            );
            if (cfg_margin_bottom != null) {
                cfg.margin_bottom = cfg_margin_bottom;
            }
            int? cfg_margin_left = extract_json_int(
                obj,
                "layer_shell_margin_left",
                effective_config_path
            );
            if (cfg_margin_left != null) {
                cfg.margin_left = cfg_margin_left;
            }

            int? cfg_scan_interval = extract_json_int(
                obj,
                "scan_interval",
                effective_config_path
            );
            if (cfg_scan_interval != null && cfg_scan_interval > 0) {
                cfg.scan_interval = cfg_scan_interval;
            }

            int? cfg_pending_wifi_connect_timeout_ms = extract_json_int(
                obj,
                "pending_wifi_connect_timeout_ms",
                effective_config_path
            );
            if (cfg_pending_wifi_connect_timeout_ms != null && cfg_pending_wifi_connect_timeout_ms > 0) {
                cfg.pending_wifi_connect_timeout_ms = cfg_pending_wifi_connect_timeout_ms;
            }

            bool? cfg_close_on_connect = extract_json_bool(
                obj,
                "close_on_connect",
                effective_config_path
            );
            if (cfg_close_on_connect != null) {
                cfg.close_on_connect = cfg_close_on_connect;
            }

            bool? cfg_show_bssid = extract_json_bool(
                obj,
                "show_bssid",
                effective_config_path
            );
            if (cfg_show_bssid != null) {
                cfg.show_bssid = cfg_show_bssid;
            }

            bool? cfg_show_frequency = extract_json_bool(
                obj,
                "show_frequency",
                effective_config_path
            );
            if (cfg_show_frequency != null) {
                cfg.show_frequency = cfg_show_frequency;
            }

            bool? cfg_show_band = extract_json_bool(
                obj,
                "show_band",
                effective_config_path
            );
            if (cfg_show_band != null) {
                cfg.show_band = cfg_show_band;
            }

            log_debug(
                "config",
                "load_config: loaded path=%s"
                    .printf(redact_fs_path(effective_config_path))
            );
        } catch (Error e) {
            log_debug(
                "config",
                "load_config: read/parse failed path=%s error=%s; outcome=using defaults"
                    .printf(redact_fs_path(effective_config_path), e.message)
            );
        }

        return cfg;
    }
}
