int main(string[] args) {
    string? config_path = null;
    bool fullscreen = false;
    bool debug_enabled = false;
    bool status = false;
    bool toggle_wifi = false;

    OptionEntry[] entries = {
        {"config", 'c', 0, OptionArg.STRING, ref config_path, "Config JSON path", "PATH"},
        {"status", 0, 0, OptionArg.NONE, ref status, "Print JSON status for waybar/eww", null},
        {"toggle-wifi", 0, 0, OptionArg.NONE, ref toggle_wifi, "Toggle Wi-Fi and exit", null},
        {"fullscreen", 'f', 0, OptionArg.NONE, ref fullscreen, "Launch fullscreen", null},
        {"debug", 0, 0, OptionArg.NONE, ref debug_enabled, "Enable debug logs", null},
        {null}
    };

    var context = new OptionContext("- hypr-network-manager rebuild");
    context.add_main_entries(entries, null);

    try {
        context.parse(ref args);
    } catch (OptionError e) {
        stderr.printf("%s\n", e.message);
        return 1;
    }

    if (status) {
        var nm = new NetworkManagerClientVala(debug_enabled);
        stdout.printf("%s\n", nm.get_status_json());
        return 0;
    }

    if (toggle_wifi) {
        var nm = new NetworkManagerClientVala(debug_enabled);
        bool enabled_after_toggle;
        string err;
        if (!nm.toggle_wifi(out enabled_after_toggle, out err)) {
            stderr.printf("toggle-wifi failed: %s\n", err);
            return 1;
        }
        stdout.printf("wifi-enabled=%s\n", enabled_after_toggle.to_string());
        return 0;
    }

    var config = AppConfig.load(config_path, debug_enabled);
    var app = new NetworkManagerValaApp(config, fullscreen, debug_enabled);
    return app.run(args);
}
