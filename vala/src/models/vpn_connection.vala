public class VpnConnection : Object {
    public string uuid { get; construct set; }
    public string name { get; construct set; }
    public string state { get; construct set; }
    public string vpn_type { get; construct set; }

    public bool is_connected {
        get {
            return state == "activated" || state == "connected";
        }
    }
}
