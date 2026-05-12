using GLib;

public class WireGuardPeerModel : Object {
    public string name { get; set; default = ""; }
    public string public_key { get; set; default = ""; }
    public string endpoint_host { get; set; default = ""; }
    public uint32 endpoint_port { get; set; default = 0; }
    public string[] allowed_ips { get; set; default = {}; }
    public string preshared_key { get; set; default = ""; }
}
