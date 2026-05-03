using GLib;

private static string[] copy_string_array (string[] values) {
    string[] copied = {};
    foreach (var value in values) {
        copied += value;
    }
    return copied;
}

public class Ipv4UpdateSection : Object {
    public string method { get; set; default = "auto"; }
    public string address { get; set; default = ""; }
    public uint32 prefix { get; set; default = 0; }
    public bool gateway_auto { get; set; default = true; }
    public string gateway { get; set; default = ""; }
    public bool dns_auto { get; set; default = true; }
    public string[] dns_servers { get; set; default = {}; }

    public string normalized_method () {
        string m = method.strip ().down ();
        if (m == "" || m == "auto") return "auto";
        if (m == "manual") return "manual";
        if (m == "link-local") return "link-local";
        if (m == "shared") return "shared";
        if (m == "disabled") return "disabled";
        return "auto";
    }

    public void clean_dns () {
        string[] cleaned = {};
        foreach (var item in dns_servers) {
            if (item != null && item.strip () != "") {
                cleaned += item;
            }
        }
        dns_servers = cleaned;
    }
}

public class Ipv6UpdateSection : Object {
    public string method { get; set; default = "auto"; }
    public string address { get; set; default = ""; }
    public uint32 prefix { get; set; default = 0; }
    public bool gateway_auto { get; set; default = true; }
    public string gateway { get; set; default = ""; }
    public bool dns_auto { get; set; default = true; }
    public string[] dns_servers { get; set; default = {}; }

    public string normalized_method () {
        string m = method.strip ().down ();
        if (m == "" || m == "auto") return "auto";
        if (m == "manual") return "manual";
        if (m == "link-local") return "link-local";
        if (m == "shared") return "shared";
        if (m == "disabled") return "disabled";
        if (m == "ignore") return "ignore";
        return "auto";
    }

    public void clean_dns () {
        string[] cleaned = {};
        foreach (var item in dns_servers) {
            if (item != null && item.strip () != "") {
                cleaned += item;
            }
        }
        dns_servers = cleaned;
    }
}

public class NetworkIpUpdateRequest : Object {
    public bool autoconnect { get; set; default = true; }
    public string ipv4_method { get; set; default = "auto"; }
    public string ipv4_address { get; set; default = ""; }
    public uint32 ipv4_prefix { get; set; default = 0; }
    public bool ipv4_gateway_auto { get; set; default = true; }
    public string ipv4_gateway { get; set; default = ""; }
    public bool ipv4_dns_auto { get; set; default = true; }
    public string[] ipv4_dns_servers { get; set; default = {}; }

    public string ipv6_method { get; set; default = "auto"; }
    public string ipv6_address { get; set; default = ""; }
    public uint32 ipv6_prefix { get; set; default = 0; }
    public bool ipv6_gateway_auto { get; set; default = true; }
    public string ipv6_gateway { get; set; default = ""; }
    public bool ipv6_dns_auto { get; set; default = true; }
    public string[] ipv6_dns_servers { get; set; default = {}; }

    public Ipv4UpdateSection get_ipv4_section () {
        return new Ipv4UpdateSection () {
            method = ipv4_method,
            address = ipv4_address,
            prefix = ipv4_prefix,
            gateway_auto = ipv4_gateway_auto,
            gateway = ipv4_gateway,
            dns_auto = ipv4_dns_auto,
            dns_servers = copy_string_array (ipv4_dns_servers)
        };
    }

    public Ipv6UpdateSection get_ipv6_section () {
        return new Ipv6UpdateSection () {
            method = ipv6_method,
            address = ipv6_address,
            prefix = ipv6_prefix,
            gateway_auto = ipv6_gateway_auto,
            gateway = ipv6_gateway,
            dns_auto = ipv6_dns_auto,
            dns_servers = copy_string_array (ipv6_dns_servers)
        };
    }
}

public class WifiNetworkUpdateRequest : NetworkIpUpdateRequest {
    public string password { get; set; default = ""; }
}

public class WifiSavedProfileUpdateRequest : Object {
    public string profile_name { get; set; default = ""; }
    public string ssid { get; set; default = ""; }
    public string bssid { get; set; default = ""; }
    public string security_mode { get; set; default = "open"; }
    public bool autoconnect { get; set; default = true; }
    public bool available_to_all_users { get; set; default = true; }
}

public class VpnUpdateRequest : Object {
    public string name { get; set; default = ""; }
    public string vpn_type { get; set; default = "vpn"; }
    public NetworkIpUpdateRequest ip_request { get; set; }

    public VpnUpdateRequest () {
        ip_request = new NetworkIpUpdateRequest ();
    }
}

public class GenericVpnUpdateRequest : VpnUpdateRequest {
    public string gateway { get; set; default = ""; }
    public string user { get; set; default = ""; }
    public string password { get; set; default = ""; }

    public GenericVpnUpdateRequest () {
        vpn_type = "vpn";
    }
}

public class WireGuardVpnUpdateRequest : VpnUpdateRequest {
    public string wg_private_key { get; set; default = ""; }
    public string wg_peer_public_key { get; set; default = ""; }
    public string wg_peer_endpoint { get; set; default = ""; }
    public string wg_peer_allowed_ips { get; set; default = ""; }
    public string wg_preshared_key { get; set; default = ""; }
    public uint32 wg_listen_port { get; set; default = 0; }
    public uint32 wg_fwmark { get; set; default = 0; }
    public bool wg_peer_routes { get; set; default = true; }

    public WireGuardVpnUpdateRequest () {
        vpn_type = "wireguard";
    }
}

public class OpenVpnUpdateRequest : VpnUpdateRequest {
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

    public OpenVpnUpdateRequest () {
        vpn_type = "openvpn";
    }
}
