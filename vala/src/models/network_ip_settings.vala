public class NetworkIpSettings : Object {
    public string configured_password { get; set; default = ""; }
    public string ipv4_method { get; set; default = "auto"; }
    public string ipv6_method { get; set; default = "auto"; }
    public bool gateway_auto { get; set; default = true; }
    public bool dns_auto { get; set; default = true; }
    public bool ipv6_gateway_auto { get; set; default = true; }
    public bool ipv6_dns_auto { get; set; default = true; }
    public bool autoconnect { get; set; default = true; }
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
    public bool available_to_all_users { get; set; default = true; }
}

public class VpnProfileDetails : NetworkIpSettings {
    public string profile_name { get; set; default = ""; }
    public string profile_uuid { get; set; default = ""; }
    public string interface_name { get; set; default = ""; }
    public string vpn_type_key { get; set; default = "vpn"; }
    public string vpn_type_display { get; set; default = "VPN"; }
    public string service_type { get; set; default = ""; }
}

public class GenericVpnProfileDetails : VpnProfileDetails {
    public string gateway { get; set; default = ""; }
    public string username { get; set; default = ""; }
    public string password { get; set; default = ""; }
}

public class WireGuardVpnProfileDetails : VpnProfileDetails {
    public string wg_private_key { get; set; default = ""; }
    public uint32 wg_listen_port { get; set; default = 0; }
    public uint32 wg_fwmark { get; set; default = 0; }
    public bool wg_peer_routes { get; set; default = true; }
    public WireGuardPeerModel[] peers { get; set; default = {}; }
}

public class OpenVpnProfileDetails : VpnProfileDetails {
    public string ovpn_remote { get; set; default = ""; }
    public uint32 ovpn_port { get; set; default = 0; }
    public string ovpn_proto { get; set; default = ""; }
    public string ovpn_username { get; set; default = ""; }
    public string ovpn_password { get; set; default = ""; }
    public string ovpn_ca_cert { get; set; default = ""; }
    public string ovpn_client_cert { get; set; default = ""; }
    public string ovpn_private_key { get; set; default = ""; }
    public string ovpn_tls_auth_key { get; set; default = ""; }
    public string ovpn_cipher { get; set; default = ""; }
    public string ovpn_auth { get; set; default = ""; }
}
