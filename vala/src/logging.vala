using GLib;

private const string APP_LOG_DOMAIN_PREFIX = "hypr-nm";

private string scoped_domain(string component) {
    return "%s.%s".printf(APP_LOG_DOMAIN_PREFIX, component);
}

public void configure_global_logging(bool debug_enabled) {
    GLib.Log.set_debug_enabled(debug_enabled);
    GLib.Log.writer_default_set_use_stderr(true);
    GLib.Log.set_writer_func((log_level, fields) => {
        bool use_color = GLib.Log.writer_supports_color(2);
        string formatted = GLib.Log.writer_format_fields(log_level, fields, use_color);
        stderr.printf("%s\n", formatted);
        return GLib.LogWriterOutput.HANDLED;
    });
}

public void log_debug(string component, string message) {
    GLib.log(scoped_domain(component), GLib.LogLevelFlags.LEVEL_DEBUG, "%s", message);
}

public void log_info(string component, string message) {
    GLib.log(scoped_domain(component), GLib.LogLevelFlags.LEVEL_INFO, "%s", message);
}

public void log_warn(string component, string message) {
    GLib.log(scoped_domain(component), GLib.LogLevelFlags.LEVEL_WARNING, "%s", message);
}

public void log_error(string component, string message) {
    GLib.log(scoped_domain(component), GLib.LogLevelFlags.LEVEL_CRITICAL, "%s", message);
}
