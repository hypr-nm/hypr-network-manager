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

public class SavedProfileService : GLib.Object {
    private NetworkManagerClient core;
    private SecretsService secrets;

    public SavedProfileService (NetworkManagerClient core, SecretsService secrets) {
        this.core = core;
        this.secrets = secrets;
    }

    public async WifiSavedProfile[] get_saved_profiles (Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var connections = client.get_connections ();
        var devices = client.get_devices ();

        string wifi_device_path = "";
        string active_uuid = "";
        foreach (var dev in devices) {
            if (dev is NM.DeviceWifi == false) {
                continue;
            }

            wifi_device_path = ((NM.Object)dev).get_path ();
            var ac = dev.get_active_connection ();
            if (ac != null) {
                active_uuid = ac.get_uuid ();
            }
            break;
        }

        var out_list = new List<WifiSavedProfile> ();
        foreach (var conn in connections) {
            var profile = NmWifiUtils.build_saved_profile (conn, wifi_device_path, active_uuid);
            if (profile != null) {
                out_list.append (profile);
            }
        }

        var profiles_arr = new WifiSavedProfile[out_list.length ()];
        int i = 0;
        foreach (var profile in out_list) {
            profiles_arr[i++] = profile;
        }

        return profiles_arr;
    }

    public async WifiSavedProfileSettings get_saved_profile_settings (
        WifiSavedProfile profile,
        Cancellable? cancellable = null
    ) throws Error {
        var settings = new WifiSavedProfileSettings ();
        var client = core.nm_client;

        var conn = client.get_connection_by_uuid (profile.saved_connection_uuid);
        if (conn == null) {
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            settings.profile_name = s_conn.id != null ? s_conn.id : "";
            settings.autoconnect = s_conn.autoconnect;
            settings.available_to_all_users = s_conn.get_num_permissions () == 0;
        }

        var s_wireless = conn.get_setting_wireless ();
        if (s_wireless != null) {
            settings.ssid = NmWifiUtils.bytes_to_ssid (s_wireless.ssid).strip ();
            settings.bssid = s_wireless.bssid != null ? s_wireless.bssid : "";
        }

        settings.security_mode = NmWifiUtils.infer_security_mode (conn.get_setting_wireless_security ());

        var s_8021x = conn.get_setting_802_1x ();
        if (s_8021x != null) {
            settings.identity = s_8021x.identity != null ? s_8021x.identity : "";
            settings.anonymous_identity = s_8021x.anonymous_identity != null ? s_8021x.anonymous_identity : "";
            settings.domain_suffix_match = s_8021x.domain_suffix_match != null ? s_8021x.domain_suffix_match : "";
            settings.ca_cert = s_8021x.get_ca_cert_path () != null ? s_8021x.get_ca_cert_path () : "";
            settings.ca_cert_password = s_8021x.get_ca_cert_password () != null ? s_8021x.get_ca_cert_password () : "";
            if (s_8021x.get_num_eap_methods () > 0) {
                settings.eap_method = s_8021x.get_eap_method (0);
            }
            settings.phase2_auth = s_8021x.phase2_auth != null ? s_8021x.phase2_auth : "";
            settings.user_cert = s_8021x.get_client_cert_path () != null ? s_8021x.get_client_cert_path () : "";
            settings.user_cert_password = s_8021x.get_client_cert_password () != null ? s_8021x.get_client_cert_password () : "";
            settings.user_private_key = s_8021x.get_private_key_path () != null ? s_8021x.get_private_key_path () : "";
            settings.user_private_key_password = s_8021x.get_private_key_password () != null ? s_8021x.get_private_key_password () : "";
        }

        var ip_settings = yield get_ip_settings_by_connection_uuid_and_device_path (
            profile.saved_connection_uuid,
            profile.device_path,
            cancellable
        );
        settings.configured_password = ip_settings.configured_password;
        settings.ipv4_method = ip_settings.ipv4_method;
        settings.ipv6_method = ip_settings.ipv6_method;
        settings.gateway_auto = ip_settings.gateway_auto;
        settings.dns_auto = ip_settings.dns_auto;
        settings.ipv6_gateway_auto = ip_settings.ipv6_gateway_auto;
        settings.ipv6_dns_auto = ip_settings.ipv6_dns_auto;
        settings.configured_address = ip_settings.configured_address;
        settings.configured_prefix = ip_settings.configured_prefix;
        settings.configured_gateway = ip_settings.configured_gateway;
        settings.configured_dns = ip_settings.configured_dns;
        settings.configured_ipv6_address = ip_settings.configured_ipv6_address;
        settings.configured_ipv6_prefix = ip_settings.configured_ipv6_prefix;
        settings.configured_ipv6_gateway = ip_settings.configured_ipv6_gateway;
        settings.configured_ipv6_dns = ip_settings.configured_ipv6_dns;

        return settings;
    }

    private void apply_8021x_certificates (NM.Setting8021x s, Eap8021xFields eap) throws Error {
        if (eap.ca_cert != null && eap.ca_cert.strip () != "") {
            s.set_ca_cert (eap.ca_cert.strip (), NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
        } else {
            s.set_ca_cert ((string?) null, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
        }
        if (eap.user_cert != null && eap.user_cert.strip () != "") {
            s.set_client_cert (eap.user_cert.strip (), NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
        } else {
            s.set_client_cert ((string?) null, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
        }
        if (eap.user_private_key != null && eap.user_private_key.strip () != "") {
            s.set_private_key (eap.user_private_key.strip (), eap.user_private_key_password, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
        } else {
            s.set_private_key ((string?) null, eap.user_private_key_password, NM.Setting8021xCKScheme.PATH, NM.Setting8021xCKFormat.UNKNOWN);
        }
    }

    public async bool update_saved_profile_settings (
        WifiSavedProfile profile,
        WifiSavedProfileUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (profile.saved_connection_uuid);
        if (conn == null) {
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        var s_conn = conn.get_setting_connection ();
        if (s_conn == null) {
            s_conn = new NM.SettingConnection ();
            conn.add_setting (s_conn);
        }

        string profile_name = request.profile_name.strip () != ""
            ? request.profile_name.strip ()
            : request.ssid.strip ();
        if (profile_name != "") {
            s_conn.id = profile_name;
        }
        s_conn.autoconnect = request.autoconnect;

        while (s_conn.get_num_permissions () > 0) {
            s_conn.remove_permission (0);
        }
        if (!request.available_to_all_users) {
            string username = Environment.get_user_name ();
            if (username.strip () == "") {
                username = "user";
            }
            s_conn.add_permission ("user", username, null);
        }

        var s_wireless = conn.get_setting_wireless ();
        if (s_wireless == null) {
            s_wireless = new NM.SettingWireless ();
            conn.add_setting (s_wireless);
        }

        string ssid = request.ssid.strip ();
        if (ssid != "") {
            uint8[] ssid_arr = ssid.data;
            s_wireless.ssid = new Bytes (ssid_arr);
        }
        s_wireless.bssid = request.bssid.strip ();

        NmWifiUtils.apply_security_mode (conn, request.security_mode);
        if (request.security_mode == WifiKeyMgmt.WPA_EAP) {
            var s_8021x = conn.get_setting_802_1x ();
            if (s_8021x != null) {
                s_8021x.clear_eap_methods ();
                s_8021x.add_eap_method (request.eap_method);
                s_8021x.phase2_auth = request.phase2_auth;
                s_8021x.identity = request.identity;
                s_8021x.anonymous_identity = request.anonymous_identity;
                s_8021x.domain_suffix_match = request.domain_suffix_match;
                s_8021x.ca_cert_password = request.ca_cert_password;
                s_8021x.client_cert_password = request.user_cert_password;
                apply_8021x_certificates (s_8021x, request);
            }
        }

        if (conn is NM.RemoteConnection) {
            yield ((NM.RemoteConnection)conn).commit_changes_async (true, cancellable);
        }
        return true;
    }

    private async void apply_network_update_request (
        NM.Connection conn,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var s_ip4 = NmIpConfigHelper.ensure_ip4_setting (conn);
        NmIpConfigHelper.apply_ipv4_settings (s_ip4, request.get_ipv4_section ());

        var s_ip6 = NmIpConfigHelper.ensure_ip6_setting (conn);
        NmIpConfigHelper.apply_ipv6_settings (s_ip6, request.get_ipv6_section ());

        var s_sec = conn.get_setting_wireless_security ();
        if (s_sec != null && s_sec.key_mgmt == WifiKeyMgmt.WPA_EAP) {
            var s_8021x = conn.get_setting_802_1x ();
            if (s_8021x == null) {
                s_8021x = new NM.Setting8021x ();
                conn.add_setting (s_8021x);
            }
            s_8021x.clear_eap_methods ();
            s_8021x.add_eap_method (request.eap_method);
            s_8021x.phase2_auth = request.phase2_auth;
            if (request.identity != null && request.identity != "") {
                s_8021x.identity = request.identity;
            }
            if (request.anonymous_identity != null && request.anonymous_identity != "") {
                s_8021x.anonymous_identity = request.anonymous_identity;
            }
            if (request.domain_suffix_match != null && request.domain_suffix_match != "") {
                s_8021x.domain_suffix_match = request.domain_suffix_match;
            }
            s_8021x.ca_cert_password = request.ca_cert_password;
            s_8021x.client_cert_password = request.user_cert_password;
                apply_8021x_certificates (s_8021x, request);
                if (request.password != null && request.password != "") {
                    s_8021x.password = request.password;
                }
        } else {
            if (request.password != null && request.password != "") {
                if (s_sec != null) {
                    s_sec.psk = request.password;
                }
            }
        }

        if (conn is NM.RemoteConnection) {
            yield ((NM.RemoteConnection)conn).commit_changes_async (true, cancellable);
        }
    }

    public async bool update_saved_profile_network_settings (
        WifiSavedProfile profile,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (profile.saved_connection_uuid);
        if (conn == null) {
            log_warn ("saved-profile-service", "Connection not found for UUID: " + profile.saved_connection_uuid);
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        yield apply_network_update_request (conn, request, cancellable);
        return true;
    }

    public async NetworkIpSettings get_ip_settings_by_connection_uuid_and_device_path (
        string connection_uuid,
        string device_path,
        Cancellable? cancellable = null
    ) {
        var ip_settings = new NetworkIpSettings ();
        var client = core.nm_client;

        NM.Connection? conn = null;
        if (connection_uuid != "") {
            conn = client.get_connection_by_uuid (connection_uuid);
        }

        if (conn != null) {
            string? read_failure;
            string? password = yield secrets.read_password_for_connection (
                conn, cancellable, out read_failure);
            ip_settings.configured_password = password ?? "";

            NmIpConfigHelper.populate_configured_ip_settings (ip_settings, conn);
        }

        var dev = client.get_device_by_path (device_path);
        NmIpConfigHelper.populate_runtime_ip_settings (ip_settings, dev);
        return ip_settings;
    }

    public async NetworkIpSettings get_network_ip_settings (
        WifiNetwork network,
        Cancellable? cancellable = null
    ) {
        return yield get_ip_settings_by_connection_uuid_and_device_path (
            network.saved_connection_uuid,
            network.device_path,
            cancellable
        );
    }

    public async bool update_network_settings (
        WifiNetwork network,
        WifiNetworkUpdateRequest request,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (network.saved_connection_uuid);
        if (conn == null) {
            log_warn ("saved-profile-service", "Connection not found for UUID: " + network.saved_connection_uuid);
             throw new IOError.NOT_FOUND ("Connection not found");
        }

        yield apply_network_update_request (conn, request, cancellable);
        return true;
    }


    public async bool set_network_autoconnect (
        WifiNetwork network,
        bool enabled,
        int32 priority = 10,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (network.saved_connection_uuid);
        if (conn == null) {
            log_warn ("saved-profile-service", "Connection not found for UUID: " + network.saved_connection_uuid);
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        var s_conn = conn.get_setting_connection ();
        if (s_conn != null) {
            s_conn.autoconnect = enabled;
            s_conn.autoconnect_priority = priority;

            if (conn is NM.RemoteConnection) {
                yield ((NM.RemoteConnection)conn).commit_changes_async (true, cancellable);
            }
        }
        return true;
    }

    public async bool connect_saved (WifiNetwork network, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (network.saved_connection_uuid);
        if (conn == null) {
            log_warn ("saved-profile-service", "Connection not found for UUID: " + network.saved_connection_uuid);
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        var dev = client.get_device_by_path (network.device_path);
        if (dev == null) {
            log_warn ("saved-profile-service", "Device not found for path: " + network.device_path);
            throw new IOError.NOT_FOUND ("Device not found");
        }

        string? specific_object = NmWifiUtils.is_valid_specific_object (network.ap_path) ? network.ap_path : null;
        yield client.activate_connection_async (conn, dev, specific_object, cancellable);
        return true;
    }

    private void apply_connection_autoconnect (
        NM.Connection conn,
        string ssid,
        bool autoconnect
    ) {
        var s_conn = conn.get_setting_connection ();
        if (s_conn == null) {
            s_conn = new NM.SettingConnection ();
            conn.add_setting (s_conn);
        }

        if (s_conn.id == null || s_conn.id.strip () == "") {
            s_conn.id = ssid;
        }
        if (s_conn.type == null || s_conn.type.strip () == "") {
            s_conn.type = NM.SettingWireless.SETTING_NAME;
        }
        if (s_conn.uuid == null || s_conn.uuid.strip () == "") {
            s_conn.uuid = NM.Utils.uuid_generate ();
        }
        s_conn.autoconnect = autoconnect;
    }

    public new async bool connect (
        WifiNetwork network,
        string? password,
        bool autoconnect = true,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        log_debug (
            "saved-profile-service",
            "connect_decision: ssid='%s' hidden=%s saved=%s uuid=%s password_supplied=%s"
                .printf (
                    redact_ssid (network.ssid),
                    network.is_hidden ? "true" : "false",
                    network.saved ? "true" : "false",
                    redact_uuid (network.saved_connection_uuid),
                    (password != null && password.strip () != "") ? "true" : "false"
                )
        );

        var dev = client.get_device_by_path (network.device_path);
        if (dev == null) {
            log_warn ("saved-profile-service", "Device not found for path: " + network.device_path);
            throw new IOError.NOT_FOUND ("Device not found");
        }

        if (network.saved && network.saved_connection_uuid != "") {
            var existing_conn = client.get_connection_by_uuid (network.saved_connection_uuid);
            if (existing_conn != null) {
                apply_connection_autoconnect (existing_conn, network.ssid, autoconnect);
                if (password != null && password != "") {
                    var s_sec = existing_conn.get_setting_wireless_security ();
                    if (s_sec != null && s_sec.key_mgmt == WifiKeyMgmt.WPA_EAP) {
                        var s_8021x = existing_conn.get_setting_802_1x ();
                        if (s_8021x == null) {
                            s_8021x = new NM.Setting8021x ();
                            existing_conn.add_setting (s_8021x);
                        }
                        s_8021x.add_eap_method (EapMethod.PEAP);
                        s_8021x.phase2_auth = Phase2Auth.MSCHAPV2;
                        if (password.contains ("\x1f")) {
                            string[] parts = password.split ("\x1f", 2);
                            s_8021x.identity = parts[0];
                            if (parts.length > 1) {
                                s_8021x.password = parts[1];
                            }
                        } else {
                            s_8021x.password = password;
                        }
                    } else {
                        if (s_sec == null) {
                            s_sec = new NM.SettingWirelessSecurity ();
                            existing_conn.add_setting (s_sec);
                        }
                        s_sec.psk = password;
                    }
                }
                if (existing_conn is NM.RemoteConnection) {
                    yield ((NM.RemoteConnection)existing_conn).commit_changes_async (true, cancellable);
                }
                string? specific_object = (NmWifiUtils.is_valid_specific_object (network.ap_path)
                 ? network.ap_path : null);
                yield client.activate_connection_async (existing_conn, dev, specific_object, cancellable);
                log_info (
                    "saved-profile-service",
                    "connect_path: activated existing saved profile for ssid='%s'"
                        .printf (redact_ssid (network.ssid))
                );
                return true;
            }
        }

        if (network.is_hidden && network.ssid.strip () == "") {
            throw new IOError.FAILED ("Hidden network requires an SSID.");
        }

        bool is_enterprise = network.security != null && network.security.is_enterprise;

        NM.Connection? partial = null;

        if (network.is_hidden || (password != null && password != "") || is_enterprise) {
            partial = (NM.SimpleConnection) NM.SimpleConnection.@new ();

            if (network.is_hidden) {
                var s_wifi = new NM.SettingWireless ();
                uint8[] ssid_arr = network.ssid.data;
                s_wifi.ssid = new Bytes (ssid_arr);
                s_wifi.hidden = true;
                partial.add_setting (s_wifi);
            }

            if (is_enterprise) {
                var s_sec = new NM.SettingWirelessSecurity ();
                s_sec.key_mgmt = WifiKeyMgmt.WPA_EAP;
                partial.add_setting (s_sec);

                var s_8021x = new NM.Setting8021x ();
                s_8021x.add_eap_method (EapMethod.PEAP);
                s_8021x.phase2_auth = Phase2Auth.MSCHAPV2;
                if (password != null) {
                    if (password.contains ("\x1f")) {
                        string[] parts = password.split ("\x1f", 2);
                        s_8021x.identity = parts[0];
                        if (parts.length > 1) {
                            s_8021x.password = parts[1];
                        }
                    } else {
                        s_8021x.password = password;
                    }
                }
                partial.add_setting (s_8021x);
            } else if (password != null && password != "") {
                var s_sec = new NM.SettingWirelessSecurity ();
                s_sec.psk = password;
                partial.add_setting (s_sec);
            }
        }

        string? specific_object = network.is_hidden ? null : network.ap_path;

        if (network.is_hidden && specific_object == null) {
            // For hidden networks, we must build a full connection manually
            // because specific_object is null and NM cannot infer settings.
            HiddenWifiSecurityMode mode = HiddenWifiSecurityMode.OPEN;
            if (password != null && password != "") {
                bool supports_sae = network.security != null && network.security.supports_sae;
                bool supports_psk = network.security != null && network.security.supports_psk;

                if (supports_sae && supports_psk) {
                    mode = HiddenWifiSecurityMode.WPA_PSK_SAE;
                } else if (supports_sae) {
                    mode = HiddenWifiSecurityMode.SAE;
                } else if (supports_psk) {
                    mode = HiddenWifiSecurityMode.WPA_PSK;
                } else {
                    mode = HiddenWifiSecurityMode.WPA_PSK;
                }
            }
            partial = NmWifiUtils.create_hidden_wifi_connection (network.ssid, password, mode);
        }

        if (partial != null || !autoconnect) {
            if (partial == null) {
                partial = (NM.SimpleConnection) NM.SimpleConnection.@new ();
            }
            apply_connection_autoconnect (partial, network.ssid, autoconnect);
        }

        yield client.add_and_activate_connection_async (partial, dev, specific_object, cancellable);

        log_info (
            "saved-profile-service",
            "connect_path: add-and-activate for ssid='%s' hidden=%s specific_object=%s"
                .printf (
                    redact_ssid (network.ssid),
                    network.is_hidden ? "true" : "false",
                    specific_object != null ? redact_object_path (specific_object) : "<none>"
                )
        );
        return true;
    }

    public async bool connect_with_password (
        WifiNetwork network,
        string password,
        bool autoconnect = true,
        Cancellable? cancellable = null
    ) throws Error {
        return yield connect (network, password, autoconnect, cancellable);
    }

    public async bool connect_hidden_network (
        string ssid,
        HiddenWifiSecurityMode security_mode,
        string password,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var wifi_dev = NmWifiUtils.primary_wifi_device (client);
        if (wifi_dev == null) throw new IOError.NOT_FOUND ("No Wi-Fi device found");

        var conn = NmWifiUtils.create_hidden_wifi_connection (ssid, password, security_mode);
        yield client.add_and_activate_connection_async (conn, wifi_dev, null, cancellable);
        return true;
    }

    public new async bool disconnect (WifiNetwork network, Cancellable? cancellable = null) throws Error {
        var client = core.nm_client;
        var dev = client.get_device_by_path (network.device_path);
        if (dev == null) {
            log_warn ("saved-profile-service", "Device not found for path: " + network.device_path);
            throw new IOError.NOT_FOUND ("Device not found");
        }

        yield dev.disconnect_async (cancellable);
        return true;
    }

    public async bool forget_network (
        string profile_uuid,
        string network_key,
        Cancellable? cancellable = null
    ) throws Error {
        var client = core.nm_client;
        var conn = client.get_connection_by_uuid (profile_uuid);
        if (conn == null) {
            log_warn ("saved-profile-service", "Connection not found for UUID: " + profile_uuid);
            throw new IOError.NOT_FOUND ("Connection not found");
        }

        yield conn.delete_async (cancellable);
        return true;
    }
}
