public class NetworkIpSettings : Object {
    public string configured_password { get; set; default = ""; }
    public string ipv4_method { get; set; default = "auto"; }
    public string ipv6_method { get; set; default = "auto"; }
    public bool gateway_auto { get; set; default = true; }
    public bool dns_auto { get; set; default = true; }
    public bool ipv6_gateway_auto { get; set; default = true; }
    public bool ipv6_dns_auto { get; set; default = true; }
    public string configured_address { get; set; default = ""; }
    public uint32 configured_prefix { get; set; default = 0; }
    public string configured_gateway { get; set; default = ""; }
    public string configured_dns { get; set; default = ""; }
    public string configured_ipv6_address { get; set; default = ""; }
    public uint32 configured_ipv6_prefix { get; set; default = 0; }
    public string configured_ipv6_gateway { get; set; default = ""; }
    public string configured_ipv6_dns { get; set; default = ""; }

    public string current_address { get; set; default = ""; }
    public uint32 current_prefix { get; set; default = 0; }
    public string current_gateway { get; set; default = ""; }
    public string current_dns { get; set; default = ""; }
    public string current_ipv6_address { get; set; default = ""; }
    public uint32 current_ipv6_prefix { get; set; default = 0; }
    public string current_ipv6_gateway { get; set; default = ""; }
    public string current_ipv6_dns { get; set; default = ""; }
}

public class WifiSavedProfileSettings : NetworkIpSettings {
    public string profile_name { get; set; default = ""; }
    public string ssid { get; set; default = ""; }
    public string bssid { get; set; default = ""; }
    public string security_mode { get; set; default = "open"; }
    public bool autoconnect { get; set; default = true; }
    public bool available_to_all_users { get; set; default = true; }
}
