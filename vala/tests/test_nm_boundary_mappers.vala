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

    assert (open.network_key == "Example:open");
    assert (psk.network_key == "Example:secured");
    assert (transition.network_key == psk.network_key);
}

private static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/nm-boundary/device-state", test_device_state_mapping);
    Test.add_func ("/nm-boundary/device-state-groups", test_device_state_groups);
    Test.add_func ("/nm-boundary/device-kind", test_device_kind_mapping);
    Test.add_func ("/nm-boundary/wifi-security", test_wifi_security_capabilities);
    Test.add_func ("/nm-boundary/wifi-mode", test_wifi_mode_mapping);
    Test.add_func ("/nm-boundary/network-key", test_network_key_stability);
    return Test.run ();
}
