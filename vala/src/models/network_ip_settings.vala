public class NetworkIpSettings : Object {
    public string ipv4_method { get; set; default = "auto"; }
    public string configured_address { get; set; default = ""; }
    public uint32 configured_prefix { get; set; default = 0; }
    public string configured_gateway { get; set; default = ""; }
    public string configured_dns { get; set; default = ""; }

    public string current_address { get; set; default = ""; }
    public uint32 current_prefix { get; set; default = 0; }
    public string current_gateway { get; set; default = ""; }
    public string current_dns { get; set; default = ""; }
}
