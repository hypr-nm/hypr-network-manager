public class WifiSavedProfile : Object {
    public string profile_name { get; construct set; default = ""; }
    public string ssid { get; construct set; default = ""; }
    public string saved_connection_uuid { get; construct set; default = ""; }
    public bool connected { get; construct set; default = false; }
    public bool is_secured { get; construct set; default = false; }
    public bool is_hidden { get; construct set; default = false; }
    public bool autoconnect { get; construct set; default = true; }
    public string device_path { get; construct set; default = ""; }
}