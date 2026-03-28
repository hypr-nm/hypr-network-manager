using GLib;

private const string APP_LOG_DOMAIN_PREFIX = "hypr-nm";

private class LoggingState : Object {
    public static bool writer_installed = false;
    public static bool writer_uses_journald = false;
}

private string scoped_domain (string component) {
    return "%s.%s".printf (APP_LOG_DOMAIN_PREFIX, component);
}

private bool should_use_journald_writer () {
    return GLib.Log.writer_is_journald (1) || GLib.Log.writer_is_journald (2);
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
        if (LoggingState.writer_uses_journald) {
            GLib.Log.set_writer_func (GLib.Log.writer_journald);
        } else {
            GLib.Log.set_writer_func (GLib.Log.writer_standard_streams);
        }
        LoggingState.writer_installed = true;

        log_info (
            "logging",
            "global logger initialized (%s writer)".printf (
                LoggingState.writer_uses_journald ? "journald" : "standard-streams"
            )
        );
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
