int main (string[] args) {
    string? config_path = null;
    bool debug_enabled = false;
    bool status = false;
    bool toggle_wifi = false;
    bool daemon_mode = false;
    bool quit_mode = false;
    bool version_mode = false;

    configure_global_logging (AppLogLevel.INFO);

    OptionEntry[] entries = {
        {"config", 'c', 0, OptionArg.STRING, ref config_path, "Config JSON path", "PATH"},
        {"status", 0, 0, OptionArg.NONE, ref status, "Print JSON status for waybar/eww", null},
        {"toggle-wifi", 0, 0, OptionArg.NONE, ref toggle_wifi, "Toggle Wi-Fi and exit", null},
        {"debug", 0, 0, OptionArg.NONE, ref debug_enabled, "Override log level to debug", null},
        {"daemon", 0, 0, OptionArg.NONE, ref daemon_mode, "Run as a background daemon", null},
        {"quit", 'q', 0, OptionArg.NONE, ref quit_mode, "Quit the running daemon", null},
        {"version", 'v', 0, OptionArg.NONE, ref version_mode, "Print version information", null},
        {null}
    };

    var context = new OptionContext ("- hypr-network-manager: A network manager for Hyprland");
    context.add_main_entries (entries, null);

    try {
        context.parse (ref args);
    } catch (OptionError e) {
        log_error ("cli", e.message);
        return 1;
    }

    if (version_mode) {
        stdout.printf ("hypr-network-manager %s\n", APP_VERSION);
        try {
            var nm = new NetworkManagerClient ();
            stdout.printf ("NetworkManager %s\n", nm.nm_client.get_version ());
        } catch (Error e) {
            stdout.printf ("NetworkManager <unavailable>\n");
        }
        return 0;
    }

    var config = AppConfig.load (config_path);
    AppLogLevel effective_log_level = config.log_level;
    if (debug_enabled) {
        effective_log_level = AppLogLevel.DEBUG;
    }

    configure_global_logging (effective_log_level);
    string? active_log_file_path = get_active_runtime_log_file_path ();
    if (active_log_file_path != null) {
        log_info (
            "cli",
            "startup: initialized logging and parsed options log_level=%s log_file=%s".printf (
                app_log_level_to_string (effective_log_level),
                redact_fs_path (active_log_file_path)
            )
        );
    } else {
        log_warn (
            "cli",
            "startup: file logging unavailable path=%s; continuing with base writer only"
                .printf (redact_fs_path (get_runtime_log_file_path ()))
        );
    }

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

    if (quit_mode) {
        log_info ("cli", "mode_select: quit mode");
        try {
            var conn = Bus.get_sync (BusType.SESSION);
            
            var builder = new VariantBuilder (new VariantType ("(sava{sv})"));
            builder.add ("s", "quit");
            
            // parameter_array (av)
            builder.open (new VariantType ("av"));
            builder.close ();
            
            // platform_data (a{sv})
            builder.open (new VariantType ("a{sv}"));
            builder.close ();

            var msg = new DBusMessage.method_call (
                "yeab212.hypr-network-manager",
                "/yeab212/hypr_network_manager",
                "org.freedesktop.Application",
                "ActivateAction"
            );
            msg.set_body (builder.end ());

            conn.send_message_with_reply_sync (msg, DBusSendMessageFlags.NONE, -1);
            log_info ("cli", "Sent quit signal to daemon");
            stdout.printf ("Terminating daemon.\n");
        } catch (Error e) {
            log_error ("cli", "Failed to send quit signal: " + e.message);
            stdout.printf ("Failed to send quit signal: %s\n", e.message);
            return 1;
        }
        return 0;
    }

    if (!daemon_mode && !status && !toggle_wifi && !quit_mode) {
        bool daemon_running = false;
        try {
            var conn = Bus.get_sync (BusType.SESSION);
            var msg = new DBusMessage.method_call ("org.freedesktop.DBus", "/org/freedesktop/DBus",
                "org.freedesktop.DBus", "NameHasOwner");
            msg.set_body (new Variant ("(s)", "yeab212.hypr-network-manager"));
            var reply = conn.send_message_with_reply_sync (msg, DBusSendMessageFlags.NONE, -1);
            reply.get_body ().get ("(b)", out daemon_running);
        } catch (Error e) {
            log_warn ("cli", "daemon ownership check failed; assuming daemon is not running error=" + e.message);
        }

        if (!daemon_running) {
            log_info ("cli", "daemon not running, spawning background instance.");
            try {
                string[] spawn_args = { args[0], "--daemon" };
                Process.spawn_async (null, spawn_args, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.STDOUT_TO_DEV_NULL | SpawnFlags.STDERR_TO_DEV_NULL, null, null);

                var loop = new MainLoop ();
                uint watch_id = Bus.watch_name (BusType.SESSION, "yeab212.hypr-network-manager",
                    BusNameWatcherFlags.NONE,
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
