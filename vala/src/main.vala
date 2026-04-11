int main (string[] args) {
    string? config_path = null;
    bool debug_enabled = false;
    bool status = false;
    bool toggle_wifi = false;
    bool daemon_mode = false;

    configure_global_logging (false);

    OptionEntry[] entries = {
        {"config", 'c', 0, OptionArg.STRING, ref config_path, "Config JSON path", "PATH"},
        {"status", 0, 0, OptionArg.NONE, ref status, "Print JSON status for waybar/eww", null},
        {"toggle-wifi", 0, 0, OptionArg.NONE, ref toggle_wifi, "Toggle Wi-Fi and exit", null},
        {"debug", 0, 0, OptionArg.NONE, ref debug_enabled, "Enable debug logs", null},
        {"daemon", 0, 0, OptionArg.NONE, ref daemon_mode, "Run as a background daemon", null},
        {null}
    };

    var context = new OptionContext ("- hypr-network-manager rebuild");
    context.add_main_entries (entries, null);

    try {
        context.parse (ref args);
    } catch (OptionError e) {
        log_error ("cli", e.message);
        return 1;
    }

    configure_global_logging (debug_enabled);
    log_info ("cli", "startup: initialized logging and parsed options");

    var config = AppConfig.load (config_path);

    if (status) {
        log_info ("cli", "mode_select: status mode");
        NetworkManagerClient nm;
        try {
            nm = new NetworkManagerClient ();
        } catch (Error e) {
            log_error ("cli", "status: failed to initialize network manager client error=" + e.message);
            return 1;
        }
        string status_json = "";
        var loop = new MainLoop ();
        nm.get_status_json_dbus.begin (null, (obj, res) => {
            status_json = nm.get_status_json_dbus.end (res);
            loop.quit ();
        });
        loop.run ();

        stdout.printf ("%s\n", status_json);
        return 0;
    }

    if (toggle_wifi) {
        log_info ("cli", "mode_select: toggle-wifi mode");
        NetworkManagerClient nm;
        try {
            nm = new NetworkManagerClient ();
        } catch (Error e) {
            log_error ("cli", "toggle_wifi: failed to initialize network manager client error=" + e.message);
            return 1;
        }
        bool enabled_after_toggle = false;
        int toggle_exit_code = 0;
        string toggle_error = "";
        var loop = new MainLoop ();
        nm.toggle_wifi_dbus.begin (null, (obj, res) => {
            try {
                enabled_after_toggle = nm.toggle_wifi_dbus.end (res);
            } catch (Error e) {
                toggle_exit_code = 1;
                toggle_error = e.message;
            }
            loop.quit ();
        });
        loop.run ();

        if (toggle_exit_code != 0) {
            log_error ("cli", "toggle_wifi: failed error=" + toggle_error);
            return toggle_exit_code;
        }
        stdout.printf ("Wi-Fi %s\n", enabled_after_toggle ? "enabled" : "disabled");
        return 0;
    }

    if (!daemon_mode && !status && !toggle_wifi) {
        bool daemon_running = false;
        try {
            var conn = Bus.get_sync(BusType.SESSION);
            var msg = new DBusMessage.method_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner");
            msg.set_body(new Variant("(s)", "yeab212.hypr-network-manager"));
            var reply = conn.send_message_with_reply_sync(msg, DBusSendMessageFlags.NONE, -1);
            reply.get_body().get("(b)", out daemon_running);
        } catch (Error e) {}

        if (!daemon_running) {
            log_info ("cli", "daemon not running, spawning background instance.");
            try {
                string[] spawn_args = { args[0], "--daemon" };
                Process.spawn_async(null, spawn_args, null, SpawnFlags.SEARCH_PATH | SpawnFlags.STDOUT_TO_DEV_NULL | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
                
                var loop = new MainLoop ();
                uint watch_id = Bus.watch_name (BusType.SESSION, "yeab212.hypr-network-manager", BusNameWatcherFlags.NONE,
                    (conn, name, owner) => {
                        if (owner != null && owner != "") {
                            log_info ("cli", "Daemon grabbed DBus name dynamically!");
                            loop.quit ();
                        }
                    },
                    (conn, name) => {
                        // ignore completely
                    });

                // Fail-safe to avoid blocking indefinitely if the daemon fails to start
                Timeout.add (NM_DAEMON_TIMEOUT_MS, () => {
                    log_warn ("cli", "Timeout waiting for daemon to acquire DBus name");
                    loop.quit ();
                    return false;
                });
                
                loop.run ();
                Bus.unwatch_name (watch_id);
            } catch (Error e) {
                log_error ("cli", "Failed to spawn daemon: " + e.message);
            }
        }
    }

    var app = new NetworkManager (config, daemon_mode);
    log_info ("cli", "mode_select: gui mode");
    return app.run (args);
}
