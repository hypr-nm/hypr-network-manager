public class WifiNetwork : Object {
    public string ssid { get; construct set; }
    public uint8 signal { get; construct set; }
    public bool connected { get; construct set; }
    public bool is_secured { get; construct set; }
    public bool saved { get; construct set; }
    public string device_path { get; construct set; }
    public string ap_path { get; construct set; }

    public string signal_label {
        owned get {
            if (signal >= 80) {
                return "Excellent";
            }
            if (signal >= 60) {
                return "Good";
            }
            if (signal >= 40) {
                return "Fair";
            }
            if (signal >= 20) {
                return "Weak";
            }
            return "Very Weak";
        }
    }

    public string signal_icon_name {
        owned get {
            if (signal >= 80) {
                return "network-wireless-signal-excellent-symbolic";
            }
            if (signal >= 60) {
                return "network-wireless-signal-good-symbolic";
            }
            if (signal >= 40) {
                return "network-wireless-signal-ok-symbolic";
            }
            if (signal >= 20) {
                return "network-wireless-signal-weak-symbolic";
            }
            return "network-wireless-signal-none-symbolic";
        }
    }
}
