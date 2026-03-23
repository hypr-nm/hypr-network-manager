int main(string[] args) {
    string? config_path = null;
    bool fullscreen = false;
    bool debug_enabled = false;

    OptionEntry[] entries = {
        {"config", 'c', 0, OptionArg.STRING, ref config_path, "Config JSON path", "PATH"},
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

    var config = AppConfig.load(config_path, debug_enabled);
    var app = new NetworkManagerValaApp(config, fullscreen, debug_enabled);
    return app.run(args);
}
