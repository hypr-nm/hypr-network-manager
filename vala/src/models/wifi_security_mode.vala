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

public enum HiddenWifiSecurityMode {
    OPEN,
    WPA_PSK,
    SAE,
    WPA_PSK_SAE,
    WEP
}

public class HiddenWifiSecurityModeUtils : Object {
    public const int MIN_PASSWORD_LENGTH = 8;

    public static HiddenWifiSecurityMode[] get_dropdown_modes () {
        return {
            HiddenWifiSecurityMode.OPEN,
            HiddenWifiSecurityMode.WPA_PSK,
            HiddenWifiSecurityMode.SAE,
            HiddenWifiSecurityMode.WPA_PSK_SAE,
            HiddenWifiSecurityMode.WEP
        };
    }

    public static string get_label (HiddenWifiSecurityMode mode) {
        switch (mode) {
        case HiddenWifiSecurityMode.OPEN:
            return _("Open");
        case HiddenWifiSecurityMode.WPA_PSK:
            return _("WPA/WPA2 Personal");
        case HiddenWifiSecurityMode.SAE:
            return _("WPA3 Personal");
        case HiddenWifiSecurityMode.WPA_PSK_SAE:
            return _("WPA2/WPA3 Personal");
        case HiddenWifiSecurityMode.WEP:
            return _("WEP (Legacy)");
        default:
            return _("WPA/WPA2 Personal");
        }
    }

    public static string[] get_dropdown_labels () {
        string[] labels = {};
        foreach (var mode in get_dropdown_modes ()) {
            labels += get_label (mode);
        }
        return labels;
    }

    public static HiddenWifiSecurityMode from_dropdown_index (uint index) {
        var modes = get_dropdown_modes ();
        if (index < modes.length) {
            return modes[(int) index];
        }
        return HiddenWifiSecurityMode.WPA_PSK;
    }

    public static uint to_dropdown_index (HiddenWifiSecurityMode mode) {
        var modes = get_dropdown_modes ();
        for (int i = 0; i < modes.length; i++) {
            if (modes[i] == mode) {
                return (uint) i;
            }
        }
        return 1;
    }

    public static bool requires_password (HiddenWifiSecurityMode mode) {
        return mode != HiddenWifiSecurityMode.OPEN;
    }

    public static bool is_password_valid (string password) {
        return password.strip ().char_count () >= MIN_PASSWORD_LENGTH;
    }

    public static bool is_password_valid_for_mode (HiddenWifiSecurityMode mode, string password) {
        if (!requires_password (mode)) {
            return true;
        }
        return is_password_valid (password);
    }

    public static string to_nm_key_mgmt (HiddenWifiSecurityMode mode) {
        switch (mode) {
        case HiddenWifiSecurityMode.OPEN:
            return "";
        case HiddenWifiSecurityMode.WPA_PSK:
            return "wpa-psk";
        case HiddenWifiSecurityMode.SAE:
            return "sae";
        case HiddenWifiSecurityMode.WPA_PSK_SAE:
            return "wpa-psk";
        case HiddenWifiSecurityMode.WEP:
            return "none";
        default:
            return "wpa-psk";
        }
    }
}
