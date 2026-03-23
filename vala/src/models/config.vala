using GLib;

public class AppConfig : Object {
    public int window_width = 360;
    public int window_height = 460;
    public bool anchor_top = true;
    public bool anchor_right = true;
    public bool anchor_bottom = false;
    public bool anchor_left = false;
    public int margin_top = 8;
    public int margin_right = 8;
    public int margin_bottom = 8;
    public int margin_left = 8;
    public string layer = "overlay";

    private static string? extract_json_string(string content, string key) {
        try {
            var regex = new Regex("\"" + key + "\"\\s*:\\s*\"([^\"]*)\"");
            MatchInfo info;
            if (regex.match(content, 0, out info)) {
                return info.fetch(1);
            }
        } catch (RegexError e) {
        }
        return null;
    }

    private static int? extract_json_int(string content, string key) {
        try {
            var regex = new Regex("\"" + key + "\"\\s*:\\s*(-?[0-9]+)");
            MatchInfo info;
            if (regex.match(content, 0, out info)) {
                return int.parse(info.fetch(1));
            }
        } catch (Error e) {
        }
        return null;
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

            int? cfg_width = extract_json_int(content, "window_width");
            if (cfg_width != null && cfg_width > 0) {
                cfg.window_width = cfg_width;
            }

            int? cfg_height = extract_json_int(content, "window_height");
            if (cfg_height != null && cfg_height > 0) {
                cfg.window_height = cfg_height;
            }

            string? cfg_layer = extract_json_string(content, "layer_shell_layer");
            if (cfg_layer != null) {
                cfg.layer = cfg_layer;
            }

            string position = "top-right";
            string? cfg_position = extract_json_string(content, "position");
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

            int? cfg_margin_top = extract_json_int(content, "layer_shell_margin_top");
            if (cfg_margin_top != null) {
                cfg.margin_top = cfg_margin_top;
            }
            int? cfg_margin_right = extract_json_int(content, "layer_shell_margin_right");
            if (cfg_margin_right != null) {
                cfg.margin_right = cfg_margin_right;
            }
            int? cfg_margin_bottom = extract_json_int(content, "layer_shell_margin_bottom");
            if (cfg_margin_bottom != null) {
                cfg.margin_bottom = cfg_margin_bottom;
            }
            int? cfg_margin_left = extract_json_int(content, "layer_shell_margin_left");
            if (cfg_margin_left != null) {
                cfg.margin_left = cfg_margin_left;
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
