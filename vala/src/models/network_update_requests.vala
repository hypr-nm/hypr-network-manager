/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Constants;
using GLib;

private static string[] copy_string_array (string[] values) {
    string[] copied = {};
    foreach (var value in values) {
        copied += value;
    }
    return copied;
}

private static string normalize_ip_method (string method, bool allow_ignore) {
    string m = method.strip ().down ();
    if (m == "" || m == "auto") return "auto";
    if (m == "manual") return "manual";
    if (m == "link-local") return "link-local";
    if (m == "shared") return "shared";
    if (m == "disabled") return "disabled";
    if (allow_ignore && m == "ignore") return "ignore";
    return "auto";
}

private static string[] clean_dns_array (string[] dns_servers) {
    string[] cleaned = {};
    foreach (var item in dns_servers) {
        if (item != null && item.strip () != "") {
            cleaned += item;
        }
    }
    return cleaned;
}

public interface Eap8021xFields : Object {
    public abstract string identity { get; set; }
    public abstract string anonymous_identity { get; set; }
    public abstract string domain_suffix_match { get; set; }
    public abstract string ca_cert { get; set; }
    public abstract string ca_cert_password { get; set; }
    public abstract string eap_method { get; set; }
    public abstract string phase2_auth { get; set; }
    public abstract string user_cert { get; set; }
    public abstract string user_cert_password { get; set; }
    public abstract string user_private_key { get; set; }
    public abstract string user_private_key_password { get; set; }
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
        return normalize_ip_method (method, false);
    }

    public void clean_dns () {
        dns_servers = clean_dns_array (dns_servers);
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
        return normalize_ip_method (method, true);
    }

    public void clean_dns () {
        dns_servers = clean_dns_array (dns_servers);
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

public class WifiNetworkUpdateRequest : NetworkIpUpdateRequest, Eap8021xFields {
    public string password { get; set; default = ""; }
    public string identity { get; set; default = ""; }
    public string anonymous_identity { get; set; default = ""; }
    public string domain_suffix_match { get; set; default = ""; }
    public string ca_cert { get; set; default = ""; }
    public string ca_cert_password { get; set; default = ""; }
    public string eap_method { get; set; default = EapMethod.PEAP; }
    public string phase2_auth { get; set; default = Phase2Auth.MSCHAPV2; }
    public string user_cert { get; set; default = ""; }
    public string user_cert_password { get; set; default = ""; }
    public string user_private_key { get; set; default = ""; }
    public string user_private_key_password { get; set; default = ""; }
}

public class WifiSavedProfileUpdateRequest : Object, Eap8021xFields {
    public string profile_name { get; set; default = ""; }
    public string ssid { get; set; default = ""; }
    public string bssid { get; set; default = ""; }
    public string security_mode { get; set; default = WifiSecurity.OPEN; }
    public bool autoconnect { get; set; default = true; }
    public bool available_to_all_users { get; set; default = true; }
    public string identity { get; set; default = ""; }
    public string anonymous_identity { get; set; default = ""; }
    public string domain_suffix_match { get; set; default = ""; }
    public string ca_cert { get; set; default = ""; }
    public string ca_cert_password { get; set; default = ""; }
    public string eap_method { get; set; default = EapMethod.PEAP; }
    public string phase2_auth { get; set; default = Phase2Auth.MSCHAPV2; }
    public string user_cert { get; set; default = ""; }
    public string user_cert_password { get; set; default = ""; }
    public string user_private_key { get; set; default = ""; }
    public string user_private_key_password { get; set; default = ""; }
}

public class VpnUpdateRequest : Object {
    public string name { get; set; default = ""; }
    public string interface_name { get; set; default = ""; }
    public string vpn_type { get; set; default = "vpn"; }
    public NetworkIpUpdateRequest ip_request { get; set; }

    public VpnUpdateRequest () {
        ip_request = new NetworkIpUpdateRequest ();
    }

    public virtual bool validate (out string? error_message) {
        error_message = null;
        if (ip_request == null) {
            error_message = _("IP settings are required.");
            return false;
        }
        return true;
    }
}

public class GenericVpnUpdateRequest : VpnUpdateRequest {
    public string gateway { get; set; default = ""; }
    public string user { get; set; default = ""; }
    public string password { get; set; default = ""; }

    public GenericVpnUpdateRequest (string vpn_type = "vpn") {
        this.vpn_type = vpn_type.strip () != "" ? vpn_type.strip () : "vpn";
    }
}

public class WireGuardVpnUpdateRequest : VpnUpdateRequest {
    public string wg_private_key { get; set; default = ""; }
    public uint32 wg_listen_port { get; set; default = 0; }
    public uint32 wg_fwmark { get; set; default = 0; }
    public bool wg_peer_routes { get; set; default = true; }
    public WireGuardPeerModel[] peers = {};

    public WireGuardVpnUpdateRequest () {
        vpn_type = "wireguard";
    }

    public override bool validate (out string? error_message) {
        if (!base.validate (out error_message)) {
            return false;
        }
        if (interface_name.strip () == "") {
            error_message = _("WireGuard interface name is required (e.g. wg0).");
            return false;
        }
        foreach (var p in peers) {
            if (p.public_key.strip () == "" || p.endpoint_host.strip () == "") {
                error_message = _("WireGuard requires public key and endpoint host for all peers.");
                return false;
            }
        }
        error_message = null;
        return true;
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

    public override bool validate (out string? error_message) {
        if (!base.validate (out error_message)) {
            return false;
        }
        if (ovpn_remote.strip () == "") {
            error_message = _("OpenVPN remote is required.");
            return false;
        }
        error_message = null;
        return true;
    }
}
