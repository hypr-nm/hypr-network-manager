int main(string[] args) {
    string? config_path = null;
    bool debug_enabled = false;
    bool status = false;
    bool toggle_wifi = false;

    OptionEntry[] entries = {
        {"config", 'c', 0, OptionArg.STRING, ref config_path, "Config JSON path", "PATH"},
        {"status", 0, 0, OptionArg.NONE, ref status, "Print JSON status for waybar/eww", null},
        {"toggle-wifi", 0, 0, OptionArg.NONE, ref toggle_wifi, "Toggle Wi-Fi and exit", null},
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

    var config = AppConfig.load(config_path, debug_enabled);

    if (status) {
        var nm = new NetworkManagerClientVala(debug_enabled);
        string status_json = "";
        var loop = new MainLoop();
        nm.get_status_json_dbus.begin(null, (obj, res) => {
            status_json = nm.get_status_json_dbus.end(res);
            loop.quit();
        });
        loop.run();
        stdout.printf("%s\n", status_json);
        return 0;
    }

    if (toggle_wifi) {
        var nm = new NetworkManagerClientVala(debug_enabled);
        bool enabled_after_toggle = false;
        int toggle_exit_code = 0;
        string toggle_error = "";
        var loop = new MainLoop();
        nm.toggle_wifi_dbus.begin(null, (obj, res) => {
            try {
                enabled_after_toggle = nm.toggle_wifi_dbus.end(res);
            } catch (Error e) {
                toggle_exit_code = 1;
                toggle_error = e.message;
            }
            loop.quit();
        });
        loop.run();

        if (toggle_exit_code != 0) {
            stderr.printf("toggle-wifi failed: %s\n", toggle_error);
            return toggle_exit_code;
        }
        stdout.printf("Wi-Fi %s\n", enabled_after_toggle ? "enabled" : "disabled");
        return 0;
    }

    var app = new NetworkManagerValaApp(config, debug_enabled);
    return app.run(args);
}
