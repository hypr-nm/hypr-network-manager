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
public class MainWindowEthernetConnectionController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};
    private HyprNetworkManager.Backend.IEthernetClient nm;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;

    public signal void refresh_requested ();

    public HashTable<string, bool> pending_action;
    public HashTable<string, bool> pending_target_connected;

    public MainWindowEthernetConnectionController (HyprNetworkManager.Backend.IEthernetClient nm,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context) {
        this.nm = nm;
        this.host = host;
        this.state_context = state_context;
        pending_action = new HashTable<string, bool> (str_hash, str_equal);
        pending_target_connected = new HashTable<string, bool> (str_hash, str_equal);
    }

    public void on_page_leave () {
        invalidate_ui_state ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        invalidate_ui_state ();
    }

    private uint capture_ui_epoch () {
        return ui_epoch;
    }

    private bool is_ui_epoch_valid (uint epoch) {
        return !is_disposed && epoch == ui_epoch;
    }

    private void invalidate_ui_state () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_all_timeout_sources ();
    }

    private void track_timeout_source (uint source_id) {
        if (source_id == 0) {
            return;
        }
        timeout_source_ids += source_id;
    }

    private void untrack_timeout_source (uint source_id) {
        if (source_id == 0 || timeout_source_ids.length == 0) {
            return;
        }

        uint[] remaining = {};
        foreach (uint id in timeout_source_ids) {
            if (id != source_id) {
                remaining += id;
            }
        }
        timeout_source_ids = remaining;
    }

    private void cancel_all_timeout_sources () {
        if (timeout_source_ids.length == 0) {
            return;
        }

        foreach (uint source_id in timeout_source_ids) {
            Source.remove (source_id);
        }
        timeout_source_ids = {};
    }

    public bool has_saved_profile (NetworkDevice dev) {
        return nm.has_ethernet_profile_for_device (dev);
    }

    public bool is_networking_enabled () {
        return nm.is_networking_enabled ();
    }

    public bool can_connect_with_profile (NetworkDevice dev) {
        return is_networking_enabled ()
            && has_saved_profile (dev)
            && dev.state != DeviceState.UNAVAILABLE;
    }

    public void track_pending_action (
        NetworkDevice dev,
        bool target_connected
    ) {
        uint epoch = capture_ui_epoch ();
        pending_action.insert (dev.name, true);
        pending_target_connected.insert (dev.name, target_connected);

        string iface_name = dev.name;
        uint timeout_id = 0;
        timeout_id = Timeout.add (20000, () => {
            untrack_timeout_source (timeout_id);
            if (!is_ui_epoch_valid (epoch)) {
                return false;
            }
            pending_action.remove (iface_name);
            pending_target_connected.remove (iface_name);
            refresh_requested ();
            return false;
        });
        track_timeout_source (timeout_id);
    }

    public void trigger_toggle (
        NetworkDevice dev
    ) {
        if (pending_action.contains (dev.name)) {
            return;
        }

        if (!dev.is_connected && !can_connect_with_profile (dev)) {
            return;
        }

        uint epoch = capture_ui_epoch ();
        bool target_connected = !dev.is_connected;
        state_context.clear_ethernet_error (dev.name);

        if (dev.is_connected) {
            nm.disconnect_device.begin (dev.name, null, (obj, res) => {
                try {
                    nm.disconnect_device.end (res);
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    track_pending_action (dev, target_connected);
                    host.refresh_after_action (false);
                } catch (Error e) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    host.show_ethernet_error (dev.name, "Ethernet disconnect failed: " + e.message);
                }
            });
            return;
        }

        nm.connect_ethernet_device.begin (dev, null, (obj, res) => {
            try {
                nm.connect_ethernet_device.end (res);
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                track_pending_action (dev, target_connected);
                host.refresh_after_action (false);
            } catch (Error e) {
                if (!is_ui_epoch_valid (epoch)) {
                    return;
                }
                host.show_ethernet_error (dev.name, "Ethernet connect failed: " + e.message);
            }
        });
    }
}
