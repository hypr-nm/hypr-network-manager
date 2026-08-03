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
using HyprNetworkManager.Models;

public class HotspotRequest : Object {
    public string ssid;
    public string password;
    public string security;
    public string band;
    public bool is_hidden;
    public int timeout_minutes;
    public string ap_interface;
    public string uplink_interface;
}

public class MainWindowHotspotController : Object {
    private HyprNetworkManager.Backend.INetworkManagerClient nm;

    public MainWindowHotspotController (HyprNetworkManager.Backend.INetworkManagerClient nm) {
        this.nm = nm;
    }

    public string[] get_wifi_interfaces () {
        return nm.get_wifi_interfaces ();
    }

    public string[] get_all_interfaces () {
        return nm.get_all_interfaces ();
    }

    public bool has_create_ap () {
        return nm.has_create_ap ();
    }

    public HotspotRequest build_request (
        string ssid,
        string password,
        uint security_index,
        string band_token,
        bool is_hidden,
        uint timeout_index,
        string ap_token,
        string uplink_token
    ) {
        return new HotspotRequest () {
            ssid = ssid,
            password = password,
            security = security_for_index (security_index),
            band = band_token,
            is_hidden = is_hidden,
            timeout_minutes = timeout_for_index (timeout_index),
            ap_interface = ap_token,
            uplink_interface = uplink_token
        };
    }

    public static string security_for_index (uint index) {
        if (index == HotspotSecurityIndex.SAE) return WifiKeyMgmt.SAE;
        if (index == HotspotSecurityIndex.NONE) return WifiKeyMgmt.NONE;
        return WifiKeyMgmt.WPA_PSK;
    }

    public static int timeout_for_index (uint index) {
        if (index == HotspotTimeoutIndex.FIVE_MINUTES) {
            return HotspotTimeout.FIVE_MINUTES;
        }
        if (index == HotspotTimeoutIndex.TEN_MINUTES) {
            return HotspotTimeout.TEN_MINUTES;
        }
        if (index == HotspotTimeoutIndex.THIRTY_MINUTES) {
            return HotspotTimeout.THIRTY_MINUTES;
        }
        if (index == HotspotTimeoutIndex.SIXTY_MINUTES) {
            return HotspotTimeout.SIXTY_MINUTES;
        }
        return HotspotTimeout.DISABLED;
    }

    public bool is_valid (HotspotRequest req) {
        return validation_message (req) == null;
    }

    public string? validation_message (HotspotRequest req) {
        if (req.ssid == "") {
            return _("SSID cannot be empty");
        }
        if (req.ssid.length > HotspotCredential.SSID_MAX_BYTES) {
            return _("SSID cannot exceed %d bytes").printf (
                HotspotCredential.SSID_MAX_BYTES
            );
        }
        if (req.security != WifiKeyMgmt.NONE) {
            bool is_raw_wpa_psk = req.security == WifiKeyMgmt.WPA_PSK
                && req.password.length == HotspotCredential.WPA_PSK_HEX_BYTES;
            if (is_raw_wpa_psk && !is_hex_string (req.password)) {
                return _("A 64-character WPA-PSK must contain only hexadecimal digits");
            }
            if (!is_raw_wpa_psk
                && req.password.length < HotspotCredential.PASSPHRASE_MIN_BYTES) {
                return _("Password must be at least %d characters").printf (
                    HotspotCredential.PASSPHRASE_MIN_BYTES
                );
            }
            if (!is_raw_wpa_psk
                && req.password.length > HotspotCredential.PASSPHRASE_MAX_BYTES) {
                return _("Password cannot exceed %d characters").printf (
                    HotspotCredential.PASSPHRASE_MAX_BYTES
                );
            }
            for (int i = 0; i < req.password.length; i++) {
                char c = req.password[i];
                if (c < HotspotCredential.PRINTABLE_ASCII_MIN
                    || c > HotspotCredential.PRINTABLE_ASCII_MAX) {
                    return _("Password contains invalid characters");
                }
            }
        }
        if (!nm.has_create_ap ()
            && req.ap_interface != NetworkInterface.AUTO
            && req.ap_interface != ""
            && req.uplink_interface != NetworkInterface.AUTO
            && req.uplink_interface != NetworkInterface.NONE
            && req.uplink_interface != ""
            && req.ap_interface == req.uplink_interface) {
            return _("AP and uplink interfaces cannot be the same");
        }
        return null;
    }

    private static bool is_hex_string (string value) {
        for (int i = 0; i < value.length; i++) {
            char c = value[i];
            if (!((c >= '0' && c <= '9')
                || (c >= 'a' && c <= 'f')
                || (c >= 'A' && c <= 'F'))) {
                return false;
            }
        }
        return true;
    }

    public async HotspotConfig get_status (Cancellable? cancellable = null) throws Error {
        return yield nm.get_hotspot_status (cancellable);
    }

    public async WifiBandSupport get_band_support (string ap_iface) throws Error {
        return yield nm.get_wifi_band_support_async (ap_iface);
    }

    public async void save_configuration (HotspotRequest req) throws Error {
        yield nm.create_or_update_hotspot (
            req.ssid,
            req.password,
            req.security,
            req.band,
            req.is_hidden,
            req.timeout_minutes,
            req.ap_interface,
            req.uplink_interface);
    }

    public async bool enable_hotspot (HotspotRequest req) throws Error {
        if (!is_valid (req)) {
            throw new IOError.INVALID_ARGUMENT (validation_message (req));
        }
        yield nm.enable_hotspot_async (
            req.ssid,
            req.password,
            req.security,
            req.band,
            req.is_hidden,
            req.timeout_minutes,
            req.ap_interface,
            req.uplink_interface);
        return true;
    }

    public async bool disable_hotspot () throws Error {
        return yield nm.disable_hotspot_async ();
    }
}
