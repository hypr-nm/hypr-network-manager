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

public class MainWindowVpnController : Object {
    private HyprNetworkManager.Backend.IVpnClient nm;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;
    private uint operation_epoch = 1;
    private Cancellable? current_cancellable = null;
    private bool refresh_shows_progress = false;

    public signal void refresh_started ();
    public signal void refresh_finished ();
    public signal void connections_loaded (VpnConnection[] connections);
    public signal void details_loaded (
        VpnConnection connection,
        VpnProfileDetails details
    );
    public signal void edit_details_loaded (
        VpnConnection connection,
        VpnProfileDetails details
    );
    public signal void update_succeeded (
        VpnConnection connection,
        bool close_after_apply
    );
    public signal void setup_succeeded ();
    public signal void toggle_succeeded (VpnConnection connection);
    public signal void delete_succeeded (VpnConnection connection);
    public signal void edit_failed (string message);
    public signal void setup_failed (string message);

    public MainWindowVpnController (
        HyprNetworkManager.Backend.IVpnClient nm,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        this.host = host;
        this.nm = nm;
        this.state_context = state_context;
    }

    private void advance_operation_epoch () {
        operation_epoch++;
        if (operation_epoch == 0) {
            operation_epoch = 1;
        }
    }

    private uint begin_operation (out Cancellable cancellable) {
        advance_operation_epoch ();
        finish_refresh_progress ();
        if (current_cancellable != null) {
            current_cancellable.cancel ();
        }

        cancellable = new Cancellable ();
        current_cancellable = cancellable;
        return operation_epoch;
    }

    private bool is_operation_current (uint epoch, Cancellable cancellable) {
        return epoch == operation_epoch
            && current_cancellable == cancellable
            && !cancellable.is_cancelled ();
    }

    private void finish_operation (Cancellable cancellable) {
        if (current_cancellable == cancellable) {
            current_cancellable = null;
        }
    }

    private void invalidate_current_operation () {
        advance_operation_epoch ();
        finish_refresh_progress ();
        if (current_cancellable != null) {
            current_cancellable.cancel ();
            current_cancellable = null;
        }
    }

    private void finish_refresh_progress () {
        if (!refresh_shows_progress) {
            return;
        }
        refresh_shows_progress = false;
        refresh_finished ();
    }

    private string connection_id (VpnConnection connection) {
        return connection.uuid != "" ? connection.uuid : connection.name;
    }

    public void load_details (VpnConnection connection) {
        Cancellable cancellable;
        uint epoch = begin_operation (out cancellable);

        nm.get_vpn_details.begin (connection_id (connection), cancellable, (obj, res) => {
            try {
                var details = nm.get_vpn_details.end (res);
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                details_loaded (connection, details);
            } catch (Error e) {
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                log_error ("vpn-controller", "Failed to fetch VPN details: " + e.message);
            }
        });
    }

    public void load_edit_details (VpnConnection connection) {
        Cancellable cancellable;
        uint epoch = begin_operation (out cancellable);

        nm.get_vpn_details.begin (connection_id (connection), cancellable, (obj, res) => {
            try {
                var details = nm.get_vpn_details.end (res);
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                edit_details_loaded (connection, details);
            } catch (Error e) {
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                log_error ("vpn-controller", "Failed to fetch VPN details for edit: " + e.message);
            }
        });
    }

    public void apply_edit (
        VpnConnection connection,
        VpnUpdateRequest request,
        bool close_after_apply
    ) {
        request.name = connection.name;

        Cancellable cancellable;
        uint epoch = begin_operation (out cancellable);
        nm.update_vpn_settings.begin (connection_id (connection), request, cancellable, (obj, res) => {
            try {
                nm.update_vpn_settings.end (res);
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                update_succeeded (connection, close_after_apply);
            } catch (Error e) {
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                edit_failed (_("Apply failed: %s").printf (e.message));
            }
        });
    }

    public void apply_setup (VpnUpdateRequest request) {
        Cancellable cancellable;
        uint epoch = begin_operation (out cancellable);

        nm.create_vpn.begin (request, cancellable, (obj, res) => {
            try {
                nm.create_vpn.end (res);
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                setup_succeeded ();
            } catch (Error e) {
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                setup_failed (_("Setup failed: %s").printf (e.message));
            }
        });
    }

    public void toggle_vpn_connection (VpnConnection connection) {
        Cancellable cancellable;
        uint epoch = begin_operation (out cancellable);

        if (connection.is_connected) {
            nm.disconnect_vpn.begin (connection_id (connection), cancellable, (obj, res) => {
                try {
                    nm.disconnect_vpn.end (res);
                    if (!is_operation_current (epoch, cancellable)) {
                        return;
                    }
                    finish_operation (cancellable);
                    toggle_succeeded (connection);
                } catch (Error e) {
                    if (!is_operation_current (epoch, cancellable)) {
                        return;
                    }
                    finish_operation (cancellable);
                    host.show_vpn_error (
                        connection.name,
                        _("VPN disconnect failed: %s").printf (e.message)
                    );
                }
            });
            return;
        }

        nm.connect_vpn.begin (connection_id (connection), cancellable, (obj, res) => {
            try {
                nm.connect_vpn.end (res);
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                toggle_succeeded (connection);
            } catch (Error e) {
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                host.show_vpn_error (
                    connection.name,
                    _("VPN connect failed: %s").printf (e.message)
                );
            }
        });
    }

    public void toggle_list_connection (VpnConnection connection) {
        state_context.clear_vpn_error (connection.name);
        Cancellable cancellable;
        uint epoch = begin_operation (out cancellable);

        if (connection.is_connected) {
            nm.disconnect_vpn.begin (connection_id (connection), cancellable, (obj, res) => {
                try {
                    nm.disconnect_vpn.end (res);
                    if (!is_operation_current (epoch, cancellable)) {
                        return;
                    }
                    finish_operation (cancellable);
                    host.refresh_after_action (false);
                } catch (Error e) {
                    if (!is_operation_current (epoch, cancellable)) {
                        return;
                    }
                    finish_operation (cancellable);
                    host.show_vpn_error (
                        connection.name,
                        _("VPN disconnect failed: %s").printf (e.message)
                    );
                }
            });
            return;
        }

        nm.connect_vpn.begin (connection_id (connection), cancellable, (obj, res) => {
            try {
                nm.connect_vpn.end (res);
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                host.refresh_after_action (false);
            } catch (Error e) {
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                host.show_vpn_error (
                    connection.name,
                    _("VPN connect failed: %s").printf (e.message)
                );
            }
        });
    }

    public void delete_vpn (VpnConnection connection) {
        Cancellable cancellable;
        uint epoch = begin_operation (out cancellable);

        nm.delete_vpn.begin (connection_id (connection), cancellable, (obj, res) => {
            try {
                nm.delete_vpn.end (res);
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                delete_succeeded (connection);
            } catch (Error e) {
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                host.show_vpn_error (
                    connection.name,
                    _("VPN delete failed: %s").printf (e.message)
                );
            }
        });
    }

    public void on_page_leave () {
        invalidate_current_operation ();
    }

    public void dispose_controller () {
        invalidate_current_operation ();
    }

    public void refresh (bool show_progress = true) {
        if (!show_progress && current_cancellable != null) {
            return;
        }
        Cancellable cancellable;
        uint epoch = begin_operation (out cancellable);
        refresh_shows_progress = show_progress;
        if (show_progress) {
            refresh_started ();
        }

        nm.get_vpn_connections.begin (cancellable, (obj, res) => {
            try {
                var connections = nm.get_vpn_connections.end (res);
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);

                var result = new VpnConnection[connections.length ()];
                int index = 0;
                foreach (var connection in connections) {
                    result[index++] = connection;
                }
                connections_loaded (result);
                finish_refresh_progress ();
            } catch (Error e) {
                if (!is_operation_current (epoch, cancellable)) {
                    return;
                }
                finish_operation (cancellable);
                finish_refresh_progress ();
                host.show_vpn_error ("all", _("VPN refresh failed: %s").printf (e.message));
            }
        });
    }
}
