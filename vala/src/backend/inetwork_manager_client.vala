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

using GLib;
using HyprNetworkManager.Models;

namespace HyprNetworkManager.Backend {
    public interface INetworkManagerClient : GLib.Object {
        public signal void network_events_changed ();

        public abstract bool has_ethernet_profile_for_device (NetworkDevice device);
        public abstract bool is_networking_enabled ();
        public abstract async bool subscribe_network_events_dbus (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract void unsubscribe_network_events ();
        public abstract async List<NetworkDevice> get_devices (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async WifiRefreshData get_wifi_refresh_data (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async WifiSavedProfile[] get_saved_wifi_profiles (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async NetworkIpSettings get_wifi_network_ip_settings (
            WifiNetwork network,
            Cancellable? cancellable = null
        );
        public abstract async bool update_wifi_network_settings (
            WifiNetwork network,
            WifiNetworkUpdateRequest request,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async WifiSavedProfileSettings get_saved_wifi_profile_settings (
            WifiSavedProfile profile,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async string? get_wifi_password (
            string connection_uuid,
            Cancellable? cancellable = null,
            out string? read_failure
        );
        public abstract async bool update_saved_wifi_profile_settings (
            WifiSavedProfile profile,
            WifiSavedProfileUpdateRequest request,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool update_saved_wifi_profile_network_settings (
            WifiSavedProfile profile,
            WifiNetworkUpdateRequest request,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool connect_ethernet_device (
            NetworkDevice device,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool disconnect_device (
            string interface_name,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async NetworkIpSettings get_ethernet_device_ip_settings (
            NetworkDevice device,
            Cancellable? cancellable = null
        );
        public abstract async NetworkIpSettings get_ethernet_device_configured_ip_settings (
            NetworkDevice device,
            Cancellable? cancellable = null
        );
        public abstract async bool update_ethernet_device_settings (
            NetworkDevice device,
            NetworkIpUpdateRequest request,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool get_wifi_enabled_dbus (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool get_networking_enabled_dbus (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool set_wifi_enabled (
            bool enabled,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool set_networking_enabled (
            bool enabled,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool toggle_wifi_dbus (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool connect_saved_wifi (
            WifiNetwork network,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool connect_wifi (
            WifiNetwork network,
            string? password,
            bool autoconnect = true,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool connect_wifi_with_password (
            WifiNetwork network,
            string password,
            bool autoconnect = true,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool connect_hidden_wifi (
            string ssid,
            HiddenWifiSecurityMode security_mode,
            string password,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool disconnect_wifi (
            WifiNetwork network,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool forget_network (
            string profile_uuid,
            string network_key,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool set_wifi_network_autoconnect (
            WifiNetwork network,
            bool enabled,
            int32 priority = 10,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool connect_vpn (
            string name,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool disconnect_vpn (
            string name,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async List<VpnConnection> get_vpn_connections (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async VpnProfileDetails get_vpn_details (
            string id,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool update_vpn_settings (
            string id,
            VpnUpdateRequest request,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool delete_vpn (
            string id,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool create_vpn (
            VpnUpdateRequest request,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool scan_wifi (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async HotspotConfig get_hotspot_status (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async void create_or_update_hotspot (
            string ssid,
            string password,
            string security,
            string band,
            bool is_hidden,
            int timeout,
            string ap_interface,
            string uplink_interface,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async bool enable_hotspot_async (
            string ssid,
            string password,
            string security,
            string band,
            bool is_hidden,
            int timeout,
            string ap_interface,
            string uplink_interface,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract string[] get_all_interfaces ();
        public abstract string[] get_wifi_interfaces ();
        public abstract async WifiBandSupport get_wifi_band_support_async (
            string iface,
            Cancellable? cancellable = null
        ) throws Error;
        public abstract bool has_create_ap ();
        public abstract async bool disable_hotspot_async (
            Cancellable? cancellable = null
        ) throws Error;
        public abstract async string get_status_json_dbus (
            Cancellable? cancellable = null
        ) throws Error;
    }
}
