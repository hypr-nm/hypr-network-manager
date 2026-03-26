public enum HiddenWifiSecurityMode {
    OPEN,
    WPA_PSK,
    SAE,
    WPA_PSK_SAE,
    WEP
}

public class HiddenWifiSecurityModeUtils : Object {
    public const int MIN_PASSWORD_LENGTH = 8;

    public static HiddenWifiSecurityMode[] get_dropdown_modes() {
        return {
            HiddenWifiSecurityMode.OPEN,
            HiddenWifiSecurityMode.WPA_PSK,
            HiddenWifiSecurityMode.SAE,
            HiddenWifiSecurityMode.WPA_PSK_SAE,
            HiddenWifiSecurityMode.WEP
        };
    }

    public static string get_label(HiddenWifiSecurityMode mode) {
        switch (mode) {
        case HiddenWifiSecurityMode.OPEN:
            return "Open";
        case HiddenWifiSecurityMode.WPA_PSK:
            return "WPA/WPA2 Personal";
        case HiddenWifiSecurityMode.SAE:
            return "WPA3 Personal";
        case HiddenWifiSecurityMode.WPA_PSK_SAE:
            return "WPA2/WPA3 Personal";
        case HiddenWifiSecurityMode.WEP:
            return "WEP (Legacy)";
        default:
            return "WPA/WPA2 Personal";
        }
    }

    public static string[] get_dropdown_labels() {
        string[] labels = {};
        foreach (var mode in get_dropdown_modes()) {
            labels += get_label(mode);
        }
        return labels;
    }

    public static HiddenWifiSecurityMode from_dropdown_index(uint index) {
        var modes = get_dropdown_modes();
        if (index < modes.length) {
            return modes[(int) index];
        }
        return HiddenWifiSecurityMode.WPA_PSK;
    }

    public static uint to_dropdown_index(HiddenWifiSecurityMode mode) {
        var modes = get_dropdown_modes();
        for (int i = 0; i < modes.length; i++) {
            if (modes[i] == mode) {
                return (uint) i;
            }
        }
        return 1;
    }

    public static bool requires_password(HiddenWifiSecurityMode mode) {
        return mode != HiddenWifiSecurityMode.OPEN;
    }

    public static bool is_password_valid(string password) {
        return password.strip().char_count() >= MIN_PASSWORD_LENGTH;
    }

    public static bool is_password_valid_for_mode(HiddenWifiSecurityMode mode, string password) {
        if (!requires_password(mode)) {
            return true;
        }
        return is_password_valid(password);
    }

    public static string to_nm_key_mgmt(HiddenWifiSecurityMode mode) {
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