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
using HyprNetworkManager.Backend;
using HyprNetworkManager.UI.Interfaces;

public class MainWindowProfilesController : Object {
    private IProfilesClient nm;
    private IWindowHost host;
    private uint ui_epoch = 1;
    private Cancellable? wifi_profiles_cancellable = null;
    private Cancellable? ethernet_profiles_cancellable = null;
    private Cancellable? wifi_settings_cancellable = null;
    private Cancellable? wifi_update_cancellable = null;
    private Cancellable? wifi_delete_cancellable = null;
    private Cancellable? ethernet_settings_cancellable = null;

    public signal void wifi_profiles_loaded (WifiSavedProfile[] profiles);
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
    public signal void wifi_profile_update_succeeded ();
    public signal void wifi_profile_deleted (string connection_uuid);

    public MainWindowProfilesController (IProfilesClient nm, IWindowHost host) {
        this.nm = nm;
        this.host = host;
    }

    public void on_page_leave () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_request (ref wifi_profiles_cancellable);
        cancel_request (ref ethernet_profiles_cancellable);
        cancel_request (ref wifi_settings_cancellable);
        cancel_request (ref wifi_update_cancellable);
        cancel_request (ref wifi_delete_cancellable);
        cancel_request (ref ethernet_settings_cancellable);
    }

    public void refresh_saved_wifi_profiles () {
        uint epoch = ui_epoch;
        cancel_request (ref wifi_profiles_cancellable);
        wifi_profiles_cancellable = new Cancellable ();
        var request = wifi_profiles_cancellable;

        nm.get_saved_wifi_profiles.begin (request, (obj, res) => {
            try {
                var profiles = nm.get_saved_wifi_profiles.end (res);
                if (epoch != ui_epoch || wifi_profiles_cancellable != request) {
                    return;
                }
                wifi_profiles_cancellable = null;
                wifi_profiles_loaded (profiles);
            } catch (Error e) {
                if (epoch != ui_epoch || wifi_profiles_cancellable != request
                    || e is IOError.CANCELLED) {
                    return;
                }
                wifi_profiles_cancellable = null;
                host.show_error (_("Could not load saved networks: %s").printf (e.message));
            }
        });
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

    public void apply_saved_wifi_profile_updates (
        WifiSavedProfile profile,
        WifiSavedProfileUpdateRequest profile_request,
        WifiNetworkUpdateRequest network_request
    ) {
        uint epoch = ui_epoch;
        cancel_request (ref wifi_update_cancellable);
        wifi_update_cancellable = new Cancellable ();
        var request = wifi_update_cancellable;

        nm.update_saved_wifi_profile_settings.begin (profile, profile_request, request, (obj, res) => {
            try {
                nm.update_saved_wifi_profile_settings.end (res);
                if (epoch != ui_epoch || wifi_update_cancellable != request) {
                    return;
                }
            } catch (Error e) {
                if (epoch != ui_epoch || wifi_update_cancellable != request
                    || e is IOError.CANCELLED) {
                    return;
                }
                wifi_update_cancellable = null;
                host.show_edit_page_error (_("Save profile failed: %s").printf (e.message));
                return;
            }

            nm.update_saved_wifi_profile_network_settings.begin (
                profile,
                network_request,
                request,
                (obj2, res2) => {
                    try {
                        nm.update_saved_wifi_profile_network_settings.end (res2);
                        if (epoch != ui_epoch || wifi_update_cancellable != request) {
                            return;
                        }
                        wifi_update_cancellable = null;
                        wifi_profile_update_succeeded ();
                    } catch (Error e) {
                        if (epoch != ui_epoch || wifi_update_cancellable != request
                            || e is IOError.CANCELLED) {
                            return;
                        }
                        wifi_update_cancellable = null;
                        host.show_edit_page_error (_("Save network settings failed: %s").printf (e.message));
                    }
                }
            );
        });
    }

    public void delete_wifi_profile (WifiSavedProfile profile) {
        uint epoch = ui_epoch;
        cancel_request (ref wifi_delete_cancellable);
        wifi_delete_cancellable = new Cancellable ();
        var request = wifi_delete_cancellable;
        string connection_uuid = profile.saved_connection_uuid;
        string network_key = profile.ssid + ":" + (profile.is_secured ? "secured" : WifiSecurity.OPEN);

        nm.forget_network.begin (connection_uuid, network_key, request, (obj, res) => {
            try {
                nm.forget_network.end (res);
                if (epoch != ui_epoch || wifi_delete_cancellable != request) {
                    return;
                }
                wifi_delete_cancellable = null;
                wifi_profile_deleted (connection_uuid);
            } catch (Error e) {
                if (epoch != ui_epoch || wifi_delete_cancellable != request
                    || e is IOError.CANCELLED) {
                    return;
                }
                wifi_delete_cancellable = null;
                host.show_error (_("Could not delete saved network: %s").printf (e.message));
            }
        });
    }
}
