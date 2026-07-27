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
    private NetworkManagerClient nm;

    public MainWindowHotspotController (NetworkManagerClient nm) {
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
        if (index == 0) return "sae";
        if (index == 2) return "none";
        return "wpa-psk";
    }

    public static int timeout_for_index (uint index) {
        if (index == 1) return 5;
        if (index == 2) return 10;
        if (index == 3) return 30;
        if (index == 4) return 60;
        return 0;
    }

    public bool is_valid (HotspotRequest req) {
        return validation_message (req) == null;
    }

    public string? validation_message (HotspotRequest req) {
        if (req.ssid == "") {
            return "SSID cannot be empty";
        }
        if (req.security != "none" && req.password.length < 8) {
            return "Password must be at least 8 characters";
        }
        if (!nm.has_create_ap ()
            && req.ap_interface != "Auto" && req.ap_interface != ""
            && req.uplink_interface != "Auto"
            && req.uplink_interface != "None"
            && req.uplink_interface != ""
            && req.ap_interface == req.uplink_interface) {
            return "AP and Uplink interfaces cannot be the same";
        }
        return null;
    }

    public async HotspotConfig get_status () throws Error {
        return yield nm.get_hotspot_status ();
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
