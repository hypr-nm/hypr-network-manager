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
using HyprNetworkManager.Backend.Mappers;

private static void test_device_state_mapping () {
    assert (DeviceMapper.map_device_state (NM.DeviceState.UNKNOWN) == DeviceState.UNKNOWN);
    assert (DeviceMapper.map_device_state (NM.DeviceState.UNMANAGED) == DeviceState.UNMANAGED);
    assert (DeviceMapper.map_device_state (NM.DeviceState.UNAVAILABLE) == DeviceState.UNAVAILABLE);
    assert (DeviceMapper.map_device_state (NM.DeviceState.DISCONNECTED) == DeviceState.DISCONNECTED);
    assert (DeviceMapper.map_device_state (NM.DeviceState.PREPARE) == DeviceState.PREPARE);
    assert (DeviceMapper.map_device_state (NM.DeviceState.CONFIG) == DeviceState.CONFIG);
    assert (DeviceMapper.map_device_state (NM.DeviceState.NEED_AUTH) == DeviceState.NEED_AUTH);
    assert (DeviceMapper.map_device_state (NM.DeviceState.IP_CONFIG) == DeviceState.IP_CONFIG);
    assert (DeviceMapper.map_device_state (NM.DeviceState.IP_CHECK) == DeviceState.IP_CHECK);
    assert (DeviceMapper.map_device_state (NM.DeviceState.SECONDARIES) == DeviceState.SECONDARIES);
    assert (DeviceMapper.map_device_state (NM.DeviceState.ACTIVATED) == DeviceState.ACTIVATED);
    assert (DeviceMapper.map_device_state (NM.DeviceState.DEACTIVATING) == DeviceState.DEACTIVATING);
    assert (DeviceMapper.map_device_state (NM.DeviceState.FAILED) == DeviceState.FAILED);
}

private static void test_device_state_groups () {
    assert (DeviceMapper.is_connecting_state (DeviceState.PREPARE));
    assert (DeviceMapper.is_connecting_state (DeviceState.CONFIG));
    assert (DeviceMapper.is_connecting_state (DeviceState.NEED_AUTH));
    assert (DeviceMapper.is_connecting_state (DeviceState.IP_CONFIG));
    assert (DeviceMapper.is_connecting_state (DeviceState.IP_CHECK));
    assert (DeviceMapper.is_connecting_state (DeviceState.SECONDARIES));
    assert (!DeviceMapper.is_connecting_state (DeviceState.DISCONNECTED));
    assert (!DeviceMapper.is_connecting_state (DeviceState.ACTIVATED));
    assert (!DeviceMapper.is_connecting_state (DeviceState.DEACTIVATING));
    assert (!DeviceMapper.is_connecting_state (DeviceState.FAILED));
}

private static void test_device_kind_mapping () {
    assert (DeviceMapper.map_device_type (NM_DEVICE_TYPE_ETHERNET) == NetworkDeviceKind.ETHERNET);
    assert (DeviceMapper.map_device_type (NM_DEVICE_TYPE_WIFI) == NetworkDeviceKind.WIFI);
    assert (DeviceMapper.map_device_type (999) == NetworkDeviceKind.UNKNOWN);
}

private static void test_wifi_security_capabilities () {
    var open = WifiSecurityMapper.map_capabilities (0, 0, 0);
    assert (!open.is_secured);
    assert (!open.is_enterprise);
    assert (!open.supports_psk);
    assert (!open.supports_sae);

    var privacy = WifiSecurityMapper.map_capabilities (
        (uint32) NM.80211ApFlags.PRIVACY,
        0,
        0
    );
    assert (privacy.is_secured);

    var mixed = WifiSecurityMapper.map_capabilities (
        0,
        (uint32) NM.80211ApSecurityFlags.KEY_MGMT_PSK,
        (uint32) (NM.80211ApSecurityFlags.KEY_MGMT_PSK
            | NM.80211ApSecurityFlags.KEY_MGMT_SAE)
    );
    assert (mixed.is_secured);
    assert (mixed.supports_psk);
    assert (mixed.supports_sae);
    assert (!mixed.is_enterprise);

    var enterprise = WifiSecurityMapper.map_capabilities (
        0,
        0,
        (uint32) NM.80211ApSecurityFlags.KEY_MGMT_802_1X
    );
    assert (enterprise.is_secured);
    assert (enterprise.is_enterprise);
}

private static void test_wifi_mode_mapping () {
    assert (WifiSecurityMapper.map_mode (NM.80211Mode.UNKNOWN) == WifiNetworkMode.UNKNOWN);
    assert (WifiSecurityMapper.map_mode (NM.80211Mode.ADHOC) == WifiNetworkMode.ADHOC);
    assert (WifiSecurityMapper.map_mode (NM.80211Mode.INFRA) == WifiNetworkMode.INFRA);
    assert (WifiSecurityMapper.map_mode (NM.80211Mode.AP) == WifiNetworkMode.AP);
    assert (WifiSecurityMapper.map_mode (NM.80211Mode.MESH) == WifiNetworkMode.MESH);
}

private static void test_network_key_stability () {
    var open = new WifiNetwork () {
        ssid = "Example",
        security = new WifiSecurityCapabilities ()
    };
    var psk = new WifiNetwork () {
        ssid = "Example",
        security = new WifiSecurityCapabilities () {
            is_secured = true,
            supports_psk = true
        }
    };
    var transition = new WifiNetwork () {
        ssid = "Example",
        security = new WifiSecurityCapabilities () {
            is_secured = true,
            supports_psk = true,
            supports_sae = true
        }
    };
    var wpa3_only = new WifiNetwork () {
        ssid = "Example",
        security = new WifiSecurityCapabilities () {
            is_secured = true,
            supports_sae = true
        }
    };
    var enterprise = new WifiNetwork () {
        ssid = "Example",
        security = new WifiSecurityCapabilities () {
            is_secured = true,
            is_enterprise = true
        }
    };

    assert (open.network_key == "Example:open");
    assert (psk.network_key == "Example:wpa");
    assert (wpa3_only.network_key == "Example:sae");
    assert (enterprise.network_key == "Example:eap");
    assert (transition.network_key == psk.network_key);
}

private static void test_wifi_radio_candidate_lookup () {
    var radio_one = new WifiNetwork () {
        ssid = "Example",
        device_name = "wlan0",
        device_path = "/devices/wlan0",
        ap_path = "/aps/one",
        security = new WifiSecurityCapabilities ()
    };
    var radio_two = new WifiNetwork () {
        ssid = "Example",
        device_name = "wlan1",
        device_path = "/devices/wlan1",
        ap_path = "/aps/two",
        security = new WifiSecurityCapabilities ()
    };
    var grouped = new WifiNetwork () {
        ssid = "Example",
        device_name = radio_one.device_name,
        device_path = radio_one.device_path,
        ap_path = radio_one.ap_path,
        security = radio_one.security,
        radio_candidates = { radio_one, radio_two }
    };

    assert (grouped.candidate_for_device ("/devices/wlan0") == radio_one);
    assert (grouped.candidate_for_device ("/devices/wlan1") == radio_two);
    assert (grouped.candidate_for_device ("/devices/missing") == null);
}

private static void test_pending_wifi_device_tracking () {
    var state = new HyprNetworkManager.Models.NetworkStateContext ();
    // A network may already be active on one radio while a connection to the
    // same logical network is pending on another.
    state.active_wifi_connections.insert ("Example:open", true);
    state.mark_wifi_connecting ("Example:open", "/devices/wlan1");

    assert (state.active_wifi_connections.contains ("Example:open"));
    assert (state.pending_wifi_connect.contains ("Example:open"));
    assert (state.pending_wifi_device_paths.lookup ("Example:open") == "/devices/wlan1");

    state.clear_wifi_connecting ("Example:open");
    assert (!state.pending_wifi_connect.contains ("Example:open"));
    assert (!state.pending_wifi_device_paths.contains ("Example:open"));
}

private static void test_manual_multi_connect_transition () {
    var conn = (NM.SimpleConnection) NM.SimpleConnection.@new ();
    var setting = new NM.SettingConnection ();
    conn.add_setting (setting);

    assert (setting.get_multi_connect () == NM.ConnectionMultiConnect.DEFAULT);
    assert (NmWifiUtils.enable_manual_multi_connect (conn));
    assert (setting.get_multi_connect () == NM.ConnectionMultiConnect.MANUAL_MULTIPLE);
    assert (!NmWifiUtils.enable_manual_multi_connect (conn));

    setting.multi_connect = (int) NM.ConnectionMultiConnect.MULTIPLE;
    assert (!NmWifiUtils.enable_manual_multi_connect (conn));
    assert (setting.get_multi_connect () == NM.ConnectionMultiConnect.MULTIPLE);

    setting.multi_connect = (int) NM.ConnectionMultiConnect.SINGLE;
    assert (NmWifiUtils.enable_manual_multi_connect (conn));
    assert (setting.get_multi_connect () == NM.ConnectionMultiConnect.MANUAL_MULTIPLE);
}

private static void test_saved_profile_contains_only_persistent_metadata () {
    const string uuid = "00000000-0000-0000-0000-000000000001";
    var connection = (NM.SimpleConnection) NM.SimpleConnection.@new ();
    var connection_setting = new NM.SettingConnection () {
        id = "Office profile",
        uuid = uuid,
        type = NM.SettingWireless.SETTING_NAME,
        autoconnect = false
    };
    connection.add_setting (connection_setting);

    uint8[] ssid = "Office Wi-Fi".data;
    var wireless_setting = new NM.SettingWireless () {
        ssid = new Bytes (ssid),
        hidden = true
    };
    connection.add_setting (wireless_setting);

    var profile = NmWifiUtils.build_saved_profile (connection);
    assert (profile != null);
    assert (profile.profile_name == "Office profile");
    assert (profile.ssid == "Office Wi-Fi");
    assert (profile.saved_connection_uuid == uuid);
}

private static NM.Connection build_preference_test_profile (
    string uuid,
    string interface_name = "",
    string bssid = "",
    int32 autoconnect_priority = 0
) {
    var connection = (NM.SimpleConnection) NM.SimpleConnection.@new ();
    var connection_setting = new NM.SettingConnection ();
    connection_setting.id = uuid;
    connection_setting.uuid = uuid;
    connection_setting.type = NM.SettingWireless.SETTING_NAME;
    connection_setting.interface_name = interface_name;
    connection_setting.autoconnect_priority = autoconnect_priority;
    connection.add_setting (connection_setting);

    var wireless_setting = new NM.SettingWireless ();
    wireless_setting.bssid = bssid;
    connection.add_setting (wireless_setting);
    return connection;
}

private static void test_wifi_profile_preference () {
    const string active_uuid = "00000000-0000-0000-0000-000000000001";
    const string interface_uuid = "00000000-0000-0000-0000-000000000002";
    const string bssid_uuid = "00000000-0000-0000-0000-000000000003";
    const string priority_uuid = "00000000-0000-0000-0000-000000000004";

    var active = build_preference_test_profile (active_uuid);
    var interface_bound = build_preference_test_profile (interface_uuid, "wlan1");
    var bssid_bound = build_preference_test_profile (
        bssid_uuid,
        "",
        "AA:BB:CC:DD:EE:FF"
    );
    var high_priority = build_preference_test_profile (priority_uuid, "", "", 50);

    assert (NmWifiUtils.compare_profile_preference (
        active,
        interface_bound,
        active_uuid,
        "wlan1",
        "aa:bb:cc:dd:ee:ff"
    ) < 0);
    assert (NmWifiUtils.compare_profile_preference (
        interface_bound,
        bssid_bound,
        "",
        "wlan1",
        "aa:bb:cc:dd:ee:ff"
    ) < 0);
    assert (NmWifiUtils.compare_profile_preference (
        bssid_bound,
        high_priority,
        "",
        "wlan0",
        "aa:bb:cc:dd:ee:ff"
    ) < 0);
    assert (NmWifiUtils.compare_profile_preference (
        high_priority,
        active,
        "",
        "wlan0",
        ""
    ) < 0);
    assert (NmWifiUtils.compare_profile_preference (
        active,
        bssid_bound,
        "",
        "wlan0",
        ""
    ) < 0);
}

private static void test_runtime_ip_identity () {
    const string requested_uuid = "00000000-0000-0000-0000-000000000001";
    const string other_uuid = "00000000-0000-0000-0000-000000000002";

    assert (!NmWifiUtils.should_populate_runtime_ip (
        false,
        requested_uuid,
        requested_uuid
    ));
    assert (NmWifiUtils.should_populate_runtime_ip (
        true,
        requested_uuid,
        requested_uuid
    ));
    assert (!NmWifiUtils.should_populate_runtime_ip (
        true,
        requested_uuid,
        other_uuid
    ));
    assert (NmWifiUtils.should_populate_runtime_ip (true, "", other_uuid));
}

private static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/nm-boundary/device-state", test_device_state_mapping);
    Test.add_func ("/nm-boundary/device-state-groups", test_device_state_groups);
    Test.add_func ("/nm-boundary/device-kind", test_device_kind_mapping);
    Test.add_func ("/nm-boundary/wifi-security", test_wifi_security_capabilities);
    Test.add_func ("/nm-boundary/wifi-mode", test_wifi_mode_mapping);
    Test.add_func ("/nm-boundary/network-key", test_network_key_stability);
    Test.add_func ("/nm-boundary/wifi-radio-candidate", test_wifi_radio_candidate_lookup);
    Test.add_func ("/nm-boundary/pending-wifi-device", test_pending_wifi_device_tracking);
    Test.add_func ("/nm-boundary/manual-multi-connect", test_manual_multi_connect_transition);
    Test.add_func (
        "/nm-boundary/saved-profile-persistent-metadata",
        test_saved_profile_contains_only_persistent_metadata
    );
    Test.add_func ("/nm-boundary/wifi-profile-preference", test_wifi_profile_preference);
    Test.add_func ("/nm-boundary/runtime-ip-identity", test_runtime_ip_identity);
    return Test.run ();
}
