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

public class MainWindowIpFields : Object {
    public string method;
    public string address;
    public uint32 prefix;
    public string gateway;
    public bool gateway_auto;
    public bool dns_auto;
    public string[] dns_servers;
}

namespace MainWindowIpValidation {
    public enum Family {
        IPV4,
        IPV6
    }

    public MainWindowIpFields? validate (
        Family family,
        string method,
        string address,
        string prefix_text,
        string gateway,
        bool dns_auto,
        string dns_csv,
        out string error_message
    ) {
        error_message = "";
        bool is_ipv4 = family == Family.IPV4;

        uint32 prefix;
        string prefix_error;
        bool prefix_ok = is_ipv4
            ? MainWindowWifiEditUtils.try_parse_prefix (prefix_text, out prefix, out prefix_error)
            : MainWindowWifiEditUtils.try_parse_ipv6_prefix (prefix_text, out prefix, out prefix_error);
        if (!prefix_ok) {
            error_message = prefix_error;
            return null;
        }

        bool effective_dns_auto = dns_auto;
        if (is_ipv4) {
            if (MainWindowIpSensitivityRules.should_force_ipv4_dns_auto_from_method (method)) {
                effective_dns_auto = true;
            }
        } else {
            if (MainWindowIpSensitivityRules.should_force_ipv6_dns_auto_from_method (method)) {
                effective_dns_auto = true;
            }
        }

        if (method == "manual") {
            string label = is_ipv4 ? "IPv4" : "IPv6";
            if (address == "") {
                error_message = _("Manual %s requires an address.").printf (label);
                return null;
            }
            if (prefix == 0) {
                int max = is_ipv4 ? 32 : 128;
                error_message = _("Manual %s requires a prefix between 1 and %d.").printf (label, max);
                return null;
            }
            if (gateway == "") {
                error_message = _("Manual %s requires a gateway address.").printf (label);
                return null;
            }
        }

        string[] dns_servers = MainWindowWifiEditUtils.parse_dns_csv (dns_csv);
        if (!effective_dns_auto && dns_servers.length == 0) {
            error_message = is_ipv4
                ? _("Manual DNS is enabled; provide at least one DNS server.")
                : _("Manual IPv6 DNS is enabled; provide at least one DNS server.");
            return null;
        }

        return new MainWindowIpFields () {
            method = method,
            address = address,
            prefix = prefix,
            gateway = gateway,
            gateway_auto = method != "manual",
            dns_auto = effective_dns_auto,
            dns_servers = dns_servers
        };
    }
}
