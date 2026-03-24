using GLib;

public class AppConfig : Object {
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
    public bool close_on_connect = true;
    public bool show_bssid = false;
    public bool show_frequency = true;
    public bool show_band = false;

    private static string? extract_json_string(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return null;
        }
        return obj.get_string_member(key);
    }

    private static int? extract_json_int(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return null;
        }
        return (int) obj.get_int_member(key);
    }

    private static bool? extract_json_bool(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
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

    public static AppConfig load(string? explicit_path, bool debug_enabled) {
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
            if (debug_enabled) {
                if (explicit_path != null) {
                    stderr.printf("[hypr-nm] config file not found: %s\n", effective_config_path);
                } else {
                    stderr.printf(
                        "[hypr-nm] config file not found in local/system paths: %s, %s\n",
                        local_config_path,
                        system_config_path
                    );
                }
            }
            return cfg;
        }

        try {
            string content;
            FileUtils.get_contents(effective_config_path, out content);

            var parser = new Json.Parser();
            parser.load_from_data(content, content.length);

            Json.Node? root = parser.get_root();
            if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
                if (debug_enabled) {
                    stderr.printf("[hypr-nm] config root must be a JSON object: %s\n", effective_config_path);
                }
                return cfg;
            }

            Json.Object obj = root.get_object();

            int? cfg_width = extract_json_int(obj, "window_width");
            if (cfg_width != null && cfg_width > 0) {
                cfg.window_width = cfg_width;
            }

            int? cfg_height = extract_json_int(obj, "window_height");
            if (cfg_height != null && cfg_height > 0) {
                cfg.window_height = cfg_height;
            }

            string? cfg_layer = extract_json_string(obj, "layer_shell_layer");
            if (cfg_layer != null) {
                cfg.layer = cfg_layer;
            }

            string position = "top-right";
            string? cfg_position = extract_json_string(obj, "position");
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

            int? cfg_margin_top = extract_json_int(obj, "layer_shell_margin_top");
            if (cfg_margin_top != null) {
                cfg.margin_top = cfg_margin_top;
            }
            int? cfg_margin_right = extract_json_int(obj, "layer_shell_margin_right");
            if (cfg_margin_right != null) {
                cfg.margin_right = cfg_margin_right;
            }
            int? cfg_margin_bottom = extract_json_int(obj, "layer_shell_margin_bottom");
            if (cfg_margin_bottom != null) {
                cfg.margin_bottom = cfg_margin_bottom;
            }
            int? cfg_margin_left = extract_json_int(obj, "layer_shell_margin_left");
            if (cfg_margin_left != null) {
                cfg.margin_left = cfg_margin_left;
            }

            int? cfg_scan_interval = extract_json_int(obj, "scan_interval");
            if (cfg_scan_interval != null && cfg_scan_interval > 0) {
                cfg.scan_interval = cfg_scan_interval;
            }

            bool? cfg_close_on_connect = extract_json_bool(obj, "close_on_connect");
            if (cfg_close_on_connect != null) {
                cfg.close_on_connect = cfg_close_on_connect;
            }

            bool? cfg_show_bssid = extract_json_bool(obj, "show_bssid");
            if (cfg_show_bssid != null) {
                cfg.show_bssid = cfg_show_bssid;
            }

            bool? cfg_show_frequency = extract_json_bool(obj, "show_frequency");
            if (cfg_show_frequency != null) {
                cfg.show_frequency = cfg_show_frequency;
            }

            bool? cfg_show_band = extract_json_bool(obj, "show_band");
            if (cfg_show_band != null) {
                cfg.show_band = cfg_show_band;
            }

            if (debug_enabled) {
                stderr.printf("[hypr-nm] loaded config: %s\n", effective_config_path);
            }
        } catch (Error e) {
            if (debug_enabled) {
                stderr.printf("[hypr-nm] could not read config %s: %s\n", effective_config_path, e.message);
            }
        }

        return cfg;
    }
}
