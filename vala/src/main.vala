/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "");

    string localedir = Constants.LOCALEDIR;
    string? env_localedir = Environment.get_variable ("HYPR_NETWORK_MANAGER_LOCALEDIR");
    if (env_localedir != null && env_localedir != "") {
        localedir = env_localedir;
    }

    Intl.bindtextdomain (Constants.GETTEXT_PACKAGE, localedir);
    Intl.bind_textdomain_codeset (Constants.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Constants.GETTEXT_PACKAGE);

    string? config_path = null;
    bool debug_enabled = false;
    bool status = false;
    bool toggle_wifi = false;
    bool daemon_mode = false;
    bool quit_mode = false;
    bool version_mode = false;

    configure_global_logging (AppLogLevel.INFO);

    OptionEntry[] entries = {
        {"config", 'c', 0, OptionArg.STRING, ref config_path, _("Config JSON path"), "PATH"},
        {"status", 0, 0, OptionArg.NONE, ref status, _("Print JSON status for waybar/eww"), null},
        {"toggle-wifi", 0, 0, OptionArg.NONE, ref toggle_wifi, _("Toggle Wi-Fi and exit"), null},
        {"debug", 0, 0, OptionArg.NONE, ref debug_enabled, _("Override log level to debug"), null},
        {"daemon", 0, 0, OptionArg.NONE, ref daemon_mode, _("Run without showing the window initially"), null},
        {"quit", 'q', 0, OptionArg.NONE, ref quit_mode, _("Quit the running application"), null},
        {"version", 'v', 0, OptionArg.NONE, ref version_mode, _("Print version information"), null},
        {null}
    };

    var context = new OptionContext (_("- hypr-network-manager: A network manager for Hyprland"));
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
            stdout.printf ("NetworkManager %s\n", nm.get_version ());
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
            try {
                status_json = nm.get_status_json_dbus.end (res);
            } catch (Error e) {
                status_json = "{\"error\": \"" + e.message + "\"}";
            }
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
            log_info ("cli", "Sent quit signal to running application");
            stdout.printf ("Terminating running application.\n");
        } catch (Error e) {
            log_error ("cli", "Failed to send quit signal: " + e.message);
            stdout.printf ("Failed to send quit signal: %s\n", e.message);
            return 1;
        }
        return 0;
    }

    var app = new NetworkManager (config, daemon_mode);
    log_info ("cli", "mode_select: gui mode");
    return app.run (args);
}
