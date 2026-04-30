using GLib;

public class WifiSignalLevels : Object {
    public const uint8 THRESHOLD_WEAK = 20;
    public const uint8 THRESHOLD_FAIR = 40;
    public const uint8 THRESHOLD_GOOD = 60;
    public const uint8 THRESHOLD_EXCELLENT = 80;

    private enum SignalLevel {
        VERY_WEAK,
        WEAK,
        FAIR,
        GOOD,
        EXCELLENT
    }

    private static SignalLevel get_level (uint8 signal) {
        if (signal >= THRESHOLD_EXCELLENT) {
            return SignalLevel.EXCELLENT;
        }
        if (signal >= THRESHOLD_GOOD) {
            return SignalLevel.GOOD;
        }
        if (signal >= THRESHOLD_FAIR) {
            return SignalLevel.FAIR;
        }
        if (signal >= THRESHOLD_WEAK) {
            return SignalLevel.WEAK;
        }
        return SignalLevel.VERY_WEAK;
    }

    public static string get_label (uint8 signal) {
        switch (get_level (signal)) {
        case SignalLevel.EXCELLENT:
            return _("Excellent");
        case SignalLevel.GOOD:
            return _("Good");
        case SignalLevel.FAIR:
            return _("Fair");
        case SignalLevel.WEAK:
            return _("Weak");
        default:
            return _("Very Weak");
        }
    }

    public static string get_icon_name (uint8 signal) {
        switch (get_level (signal)) {
        case SignalLevel.EXCELLENT:
            return "network-wireless-signal-excellent-symbolic";
        case SignalLevel.GOOD:
            return "network-wireless-signal-good-symbolic";
        case SignalLevel.FAIR:
            return "network-wireless-signal-ok-symbolic";
        case SignalLevel.WEAK:
            return "network-wireless-signal-weak-symbolic";
        default:
            return "network-wireless-signal-none-symbolic";
        }
    }

    public static string get_secured_icon_name (uint8 signal) {
        switch (get_level (signal)) {
        case SignalLevel.EXCELLENT:
            return "network-wireless-signal-excellent-secure-symbolic";
        case SignalLevel.GOOD:
            return "network-wireless-signal-good-secure-symbolic";
        case SignalLevel.FAIR:
            return "network-wireless-signal-ok-secure-symbolic";
        case SignalLevel.WEAK:
            return "network-wireless-signal-weak-secure-symbolic";
        default:
            return "network-wireless-signal-none-secure-symbolic";
        }
    }

    public static string get_bars (uint8 signal) {
        switch (get_level (signal)) {
        case SignalLevel.EXCELLENT:
            return "||||";
        case SignalLevel.GOOD:
            return "|||.";
        case SignalLevel.FAIR:
            return "||..";
        case SignalLevel.WEAK:
            return "|…";
        default:
            return "….";
        }
    }
}
