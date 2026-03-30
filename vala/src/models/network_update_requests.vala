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
        return NetworkManagerClient.normalize_ipv4_method (method);
    }

    public void normalize_fields () {
        address = address.strip ();
        gateway = gateway.strip ();

        string[] cleaned = {};
        foreach (var dns in dns_servers) {
            string item = dns.strip ();
            if (item != "") {
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
        return NetworkManagerClient.normalize_ipv6_method (method);
    }

    public void normalize_fields () {
        address = address.strip ();
        gateway = gateway.strip ();

        string[] cleaned = {};
        foreach (var dns in dns_servers) {
            string item = dns.strip ();
            if (item != "") {
                cleaned += item;
            }
        }
        dns_servers = cleaned;
    }
}

public class NetworkIpUpdateRequest : Object {
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
        var section = new Ipv4UpdateSection ();
        section.method = ipv4_method;
        section.address = ipv4_address;
        section.prefix = ipv4_prefix;
        section.gateway_auto = ipv4_gateway_auto;
        section.gateway = ipv4_gateway;
        section.dns_auto = ipv4_dns_auto;
        section.dns_servers = copy_string_array (ipv4_dns_servers);
        section.normalize_fields ();
        return section;
    }

    public Ipv6UpdateSection get_ipv6_section () {
        var section = new Ipv6UpdateSection ();
        section.method = ipv6_method;
        section.address = ipv6_address;
        section.prefix = ipv6_prefix;
        section.gateway_auto = ipv6_gateway_auto;
        section.gateway = ipv6_gateway;
        section.dns_auto = ipv6_dns_auto;
        section.dns_servers = copy_string_array (ipv6_dns_servers);
        section.normalize_fields ();
        return section;
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
