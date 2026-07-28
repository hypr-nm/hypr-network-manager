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

namespace WifiQrBuilder {
    private const string FORMAT = "WIFI:T:%s;S:%s;P:%s;H:%s;;";
    private const string SECURITY_WPA = "WPA";
    private const string SECURITY_NONE = "nopass";
    private const string HIDDEN_TRUE = "true";
    private const string HIDDEN_FALSE = "false";
    private const string STARTING_PLACEHOLDER = "HOTSPOT:STARTING";

    private static string escape (string field) {
        return field.replace ("\\", "\\\\")
            .replace (";", "\\;")
            .replace (",", "\\,")
            .replace (":", "\\:");
    }

    public string build (string ssid, string password, bool is_secured, bool is_hidden) {
        string security = is_secured ? SECURITY_WPA : SECURITY_NONE;
        string hidden_flag = is_hidden ? HIDDEN_TRUE : HIDDEN_FALSE;
        return FORMAT.printf (security, escape (ssid), escape (password), hidden_flag);
    }

    public string starting_placeholder () {
        return STARTING_PLACEHOLDER;
    }
}
