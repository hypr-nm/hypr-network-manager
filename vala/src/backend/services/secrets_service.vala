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

using Constants;
using GLib;

public class SecretsService : GLib.Object {
    private NetworkManagerClient core;

    public SecretsService (NetworkManagerClient core) {
        this.core = core;
    }

    public async string? read_password_for_connection (
        NM.Connection conn,
        Cancellable? cancellable = null,
        out string? read_failure
    ) {
        read_failure = null;

        var s_sec = conn.get_setting_wireless_security ();
        if (s_sec != null && s_sec.psk != null && s_sec.psk != "") {
            return s_sec.psk;
        }

        var s_8021x = conn.get_setting_802_1x ();
        if (s_8021x != null && s_8021x.password != null && s_8021x.password != "") {
            return s_8021x.password;
        }

        if (conn is NM.RemoteConnection) {
            string? last_error = null;

            try {
                string? found = yield read_remote_secret (
                    (NM.RemoteConnection) conn, "802-1x", "password", cancellable);
                if (found != null) {
                    return found;
                }
            } catch (Error e) {
                last_error = e.message;
                log_debug ("secrets-service", "unable to read 802-1x secrets: " + e.message);
            }

            try {
                string? found = yield read_remote_secret (
                    (NM.RemoteConnection) conn, NM.SettingWirelessSecurity.SETTING_NAME, "psk", cancellable);
                if (found != null) {
                    return found;
                }
            } catch (Error e) {
                last_error = e.message;
                log_debug ("secrets-service", "unable to read wireless secrets: " + e.message);
            }

            read_failure = last_error;
        }

        return null;
    }

    private async string? read_remote_secret (
        NM.RemoteConnection conn,
        string group,
        string key,
        Cancellable? cancellable
    ) throws Error {
        var secrets = yield conn.get_secrets_async (group, cancellable);
        if (secrets == null) {
            return null;
        }
        Variant? sec_dict = secrets.lookup_value (group, new VariantType ("a{sv}"));
        if (sec_dict == null) {
            return null;
        }
        Variant? value = sec_dict.lookup_value (key, new VariantType ("s"));
        return value != null ? value.get_string () : null;
    }

    public async string? get_wifi_password (
        string connection_uuid,
        Cancellable? cancellable = null,
        out string? read_failure
    ) {
        read_failure = null;
        var conn = core.nm_client.get_connection_by_uuid (connection_uuid);
        if (conn == null) {
            return null;
        }

        string? inner_failure;
        string? password = yield read_password_for_connection (
            conn, cancellable, out inner_failure);
        read_failure = inner_failure;
        return password;
    }
}
