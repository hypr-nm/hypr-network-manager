public class WifiNetwork : Object {
    public string ssid { get; construct set; }
    public string saved_connection_uuid { get; construct set; }
    public uint8 signal { get; construct set; }
    public bool connected { get; construct set; }
    public bool is_secured { get; construct set; }
    public bool is_hidden { get; construct set; default = false; }
    public bool saved { get; construct set; }
    public bool autoconnect { get; construct set; }
    public string device_path { get; construct set; }
    public string ap_path { get; construct set; }
    public string bssid { get; construct set; }
    public uint32 frequency_mhz { get; construct set; }
    public uint32 max_bitrate_kbps { get; construct set; }
    public uint32 mode { get; construct set; }
    public uint32 flags { get; construct set; }
    public uint32 wpa_flags { get; construct set; }
    public uint32 rsn_flags { get; construct set; }

    public string network_key {
        owned get {
            return ssid + ":" + (is_secured ? "secured" : "open");
        }
    }

    public string signal_label {
        owned get {
            return WifiSignalLevels.get_label (signal);
        }
    }

    public string signal_icon_name {
        owned get {
            return WifiSignalLevels.get_icon_name (signal);
        }
    }
}
