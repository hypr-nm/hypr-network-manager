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
using HyprNetworkManager.Backend;
using HyprNetworkManager.UI.Interfaces;

public class MainWindowProfilesController : Object {
    private INetworkManagerClient nm;
    private IWindowHost host;
    private uint ui_epoch = 1;
    private Cancellable? ethernet_profiles_cancellable = null;
    private Cancellable? wifi_settings_cancellable = null;
    private Cancellable? ethernet_settings_cancellable = null;

    public signal void ethernet_profiles_loaded (NetworkDevice[] devices);
    public signal void wifi_profile_settings_loaded (
        string connection_uuid,
        WifiSavedProfileSettings settings
    );
    public signal void ethernet_settings_loaded (
        string device_path,
        string device_name,
        NetworkIpSettings settings
    );

    public MainWindowProfilesController (INetworkManagerClient nm, IWindowHost host) {
        this.nm = nm;
        this.host = host;
    }

    public void on_page_leave () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_request (ref ethernet_profiles_cancellable);
        cancel_request (ref wifi_settings_cancellable);
        cancel_request (ref ethernet_settings_cancellable);
    }

    private void cancel_request (ref Cancellable? request) {
        if (request != null) {
            request.cancel ();
            request = null;
        }
    }

    public void refresh_saved_ethernet_profiles () {
        uint epoch = ui_epoch;
        cancel_request (ref ethernet_profiles_cancellable);
        ethernet_profiles_cancellable = new Cancellable ();
        var request = ethernet_profiles_cancellable;

        nm.get_devices.begin (request, (obj, res) => {
            try {
                var devices = nm.get_devices.end (res);
                if (epoch != ui_epoch || ethernet_profiles_cancellable != request) {
                    return;
                }
                ethernet_profiles_cancellable = null;

                var profiles = new List<NetworkDevice> ();
                foreach (var device in devices) {
                    if (device.is_ethernet && nm.has_ethernet_profile_for_device (device)) {
                        profiles.append (device);
                    }
                }

                var result = new NetworkDevice[profiles.length ()];
                int index = 0;
                foreach (var device in profiles) {
                    result[index++] = device;
                }
                ethernet_profiles_loaded (result);
            } catch (Error e) {
                if (epoch != ui_epoch || ethernet_profiles_cancellable != request
                    || e is IOError.CANCELLED) {
                    return;
                }
                ethernet_profiles_cancellable = null;
                host.show_error (_("Could not load ethernet profiles: %s").printf (e.message));
            }
        });
    }

    public void load_wifi_profile_settings (WifiSavedProfile profile) {
        uint epoch = ui_epoch;
        cancel_request (ref wifi_settings_cancellable);
        wifi_settings_cancellable = new Cancellable ();
        var request = wifi_settings_cancellable;

        nm.get_saved_wifi_profile_settings.begin (profile, request, (obj, res) => {
            try {
                var settings = nm.get_saved_wifi_profile_settings.end (res);
                if (epoch != ui_epoch || wifi_settings_cancellable != request) {
                    return;
                }
                wifi_settings_cancellable = null;
                wifi_profile_settings_loaded (profile.saved_connection_uuid, settings);
            } catch (Error e) {
                if (epoch != ui_epoch || wifi_settings_cancellable != request
                    || e is IOError.CANCELLED) {
                    return;
                }
                wifi_settings_cancellable = null;
                host.show_error (_("Could not load saved profile settings: %s").printf (e.message));
            }
        });
    }

    public void load_ethernet_profile_settings (NetworkDevice device) {
        uint epoch = ui_epoch;
        cancel_request (ref ethernet_settings_cancellable);
        ethernet_settings_cancellable = new Cancellable ();
        var request = ethernet_settings_cancellable;

        nm.get_ethernet_device_configured_ip_settings.begin (device, request, (obj, res) => {
            var settings = nm.get_ethernet_device_configured_ip_settings.end (res);
            if (epoch != ui_epoch || ethernet_settings_cancellable != request) {
                return;
            }
            ethernet_settings_cancellable = null;
            ethernet_settings_loaded (device.device_path, device.name, settings);
        });
    }
}
