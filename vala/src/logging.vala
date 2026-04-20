using GLib;

private const string APP_LOG_DOMAIN_PREFIX = "hypr-nm";
private const string APP_LOG_FILE_NAME = "hypr-network-manager.log";
private const int APP_LOG_DIRECTORY_MODE = 0700;

private class LoggingState : Object {
    public static bool writer_installed = false;
    public static bool writer_uses_journald = false;
    public static bool file_logging_checked = false;
    public static string? active_log_file_path = null;
}

private string scoped_domain (string component) {
    return "%s.%s".printf (APP_LOG_DOMAIN_PREFIX, component);
}

private bool should_use_journald_writer () {
    return GLib.Log.writer_is_journald (1) || GLib.Log.writer_is_journald (2);
}

private string get_log_file_path () {
    return Path.build_filename (
        Environment.get_user_state_dir (),
        "hypr-network-manager",
        APP_LOG_FILE_NAME
    );
}

private void ensure_log_directory_exists (string directory_path, int mode) {
    if (directory_path == "" || directory_path == ".") {
        return;
    }

    if (FileUtils.test (directory_path, FileTest.IS_DIR)) {
        return;
    }

    DirUtils.create_with_parents (directory_path, mode);
}

private FileOutputStream open_log_file_stream (string path) throws Error {
    string directory_path = Path.get_dirname (path);
    ensure_log_directory_exists (directory_path, APP_LOG_DIRECTORY_MODE);

    var file = File.new_for_path (path);
    if (FileUtils.test (path, FileTest.EXISTS)) {
        return file.append_to (FileCreateFlags.NONE);
    }

    return file.create (FileCreateFlags.PRIVATE);
}

private bool activate_log_file_target (string path) {
    try {
        var stream = open_log_file_stream (path);
        stream.close ();
        LoggingState.active_log_file_path = path;
        return true;
    } catch (Error e) {
        return false;
    }
}

private void reset_log_file_target () {
    LoggingState.file_logging_checked = false;
    LoggingState.active_log_file_path = null;
}

private void ensure_log_file_target () {
    if (LoggingState.file_logging_checked) {
        return;
    }

    LoggingState.file_logging_checked = true;

    activate_log_file_target (get_log_file_path ());
}

private bool append_formatted_log_line_to_path (string path, string formatted_line) {
    try {
        var stream = open_log_file_stream (path);
        size_t bytes_written = 0;
        stream.write_all ((uint8[]) formatted_line.data, out bytes_written);
        stream.flush ();
        stream.close ();
        return true;
    } catch (Error e) {
        return false;
    }
}

private bool append_formatted_log_line (string formatted_line) {
    ensure_log_file_target ();

    if (LoggingState.active_log_file_path == null) {
        return false;
    }

    if (append_formatted_log_line_to_path (LoggingState.active_log_file_path, formatted_line)) {
        return true;
    }

    reset_log_file_target ();
    ensure_log_file_target ();
    if (LoggingState.active_log_file_path == null) {
        return false;
    }

    return append_formatted_log_line_to_path (LoggingState.active_log_file_path, formatted_line);
}

private GLib.LogWriterOutput app_log_writer (
    GLib.LogLevelFlags log_level,
    GLib.LogField[] fields
) {
    if (LoggingState.writer_uses_journald) {
        GLib.Log.writer_journald (log_level, fields);
    } else {
        GLib.Log.writer_standard_streams (log_level, fields);
    }

    string formatted_line = GLib.Log.writer_format_fields (log_level, fields, false);
    if (!formatted_line.has_suffix ("\n")) {
        formatted_line += "\n";
    }

    append_formatted_log_line (formatted_line);
    return GLib.LogWriterOutput.HANDLED;
}

private string mask_middle (string value, int keep_start = 2, int keep_end = 2) {
    string trimmed = value.strip ();
    if (trimmed == "") {
        return "";
    }

    if (trimmed.length <= keep_start + keep_end) {
        return "***";
    }

    return trimmed.substring (0, keep_start)
        + "***"
        + trimmed.substring (trimmed.length - keep_end);
}

public void configure_global_logging (bool debug_enabled) {
    GLib.Log.set_debug_enabled (debug_enabled);
    GLib.Log.writer_default_set_use_stderr (true);

    if (!LoggingState.writer_installed) {
        LoggingState.writer_uses_journald = should_use_journald_writer ();
        ensure_log_file_target ();
        GLib.Log.set_writer_func (app_log_writer);
        LoggingState.writer_installed = true;

        log_info (
            "logging",
            "global logger initialized base=%s file=%s".printf (
                LoggingState.writer_uses_journald ? "journald" : "standard-streams",
                LoggingState.active_log_file_path ?? "<disabled>"
            )
        );

        if (LoggingState.active_log_file_path == null) {
            log_warn (
                "logging",
                "file logging unavailable path=%s; continuing with base writer only"
                    .printf (get_log_file_path ())
            );
        }
    }
}

public void log_debug (string component, string message) {
    GLib.log (scoped_domain (component), GLib.LogLevelFlags.LEVEL_DEBUG, "%s", message);
}

public void log_info (string component, string message) {
    GLib.log (scoped_domain (component), GLib.LogLevelFlags.LEVEL_INFO, "%s", message);
}

public void log_warn (string component, string message) {
    GLib.log (scoped_domain (component), GLib.LogLevelFlags.LEVEL_WARNING, "%s", message);
}

public void log_error (string component, string message) {
    GLib.log (scoped_domain (component), GLib.LogLevelFlags.LEVEL_CRITICAL, "%s", message);
}

public string redact_ssid (string ssid) {
    string normalized = ssid.strip ();
    if (normalized == "") {
        return "<empty-ssid>";
    }
    return "%s (len=%u)".printf (mask_middle (normalized, 2, 1), (uint) normalized.length);
}

public string redact_bssid (string bssid) {
    string normalized = bssid.strip ().down ();
    if (normalized.length == 17) {
        return normalized.substring (0, 8) + ":**:**:**";
    }
    return mask_middle (normalized, 3, 2);
}

public string redact_uuid (string uuid) {
    string normalized = uuid.strip ().down ();
    if (normalized == "") {
        return "<none>";
    }
    if (normalized.length >= 8) {
        return normalized.substring (0, 8) + "-****";
    }
    return mask_middle (normalized, 2, 1);
}

public string redact_object_path (string object_path) {
    string normalized = object_path.strip ();
    if (normalized == "" || normalized == "/") {
        return normalized == "" ? "<none>" : "/";
    }

    int idx = normalized.last_index_of_char ('/');
    if (idx < 0 || idx >= normalized.length - 1) {
        return mask_middle (normalized, 6, 4);
    }

    return "…/" + normalized.substring (idx + 1);
}

public string redact_fs_path (string path) {
    string normalized = path.strip ();
    if (normalized == "") {
        return "<none>";
    }

    int idx = normalized.last_index_of_char ('/');
    if (idx < 0 || idx >= normalized.length - 1) {
        return mask_middle (normalized, 4, 4);
    }

    string parent = normalized.substring (0, idx);
    int parent_idx = parent.last_index_of_char ('/');
    string parent_name = parent_idx >= 0 && parent_idx < parent.length - 1
        ? parent.substring (parent_idx + 1)
        : parent;
    return "%s/%s".printf (parent_name, normalized.substring (idx + 1));
}

public string redact_network_key (string network_key) {
    int sep = network_key.last_index_of_char (':');
    if (sep <= 0 || sep >= network_key.length - 1) {
        return mask_middle (network_key, 3, 3);
    }

    string ssid = network_key.substring (0, sep);
    string sec = network_key.substring (sep + 1);
    return "%s:%s".printf (redact_ssid (ssid), sec);
}
