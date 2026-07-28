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
    private NetworkManagerClient nm;
    private MainWindowVpnPageBuilder page_builder;
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;

    public signal void refresh_started ();
    public signal void refresh_finished ();
    public signal void details_requested (VpnConnection conn);
    public signal void add_requested ();

    public MainWindowVpnController (
        NetworkManagerClient nm,
        HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context
    ) {
        page_builder = new MainWindowVpnPageBuilder (
            nm,
            host,
            state_context
        );
        this.host = host;
        this.nm = nm;

        page_builder.refresh_started.connect (() => {
            refresh_started ();
        });
        page_builder.refresh_finished.connect (() => {
            refresh_finished ();
        });
        page_builder.open_details.connect ((conn) => {
            details_requested (conn);
        });
        page_builder.add_clicked.connect (() => {
            add_requested ();
        });
    }

    public void populate_details (
        VpnConnection conn,
        MainWindowVpnDetailsPage details_page
    ) {
        details_page.render_details (conn, false);
        details_page.show_loading_ip ();

        string connection_id = conn.uuid != "" ? conn.uuid : conn.name;
        nm.get_vpn_details.begin (connection_id, null, (obj, res) => {
            try {
                var settings = nm.get_vpn_details.end (res);
                details_page.render_profile_fields (conn, settings);
                details_page.render_ip_settings (settings, conn.is_connected);
            } catch (Error e) {
                log_error ("vpn-controller", "Failed to fetch VPN details: " + e.message);
            }
        });
    }

    public void open_details (
        ref VpnConnection? selected_vpn,
        VpnConnection conn,
        Gtk.Stack stack
    ) {
        selected_vpn = conn;
        stack.set_visible_child_name ("details");
    }

    public void open_edit (
        ref VpnConnection? selected_vpn,
        VpnConnection conn,
        MainWindowVpnEditPage edit_page,
        Gtk.Stack stack
    ) {
        selected_vpn = conn;
        string connection_id = conn.uuid != "" ? conn.uuid : conn.name;
        nm.get_vpn_details.begin (connection_id, null, (obj, res) => {
            try {
                var settings = nm.get_vpn_details.end (res);
                edit_page.setup_edit_form (conn, settings);
                stack.set_visible_child_name ("edit");
            } catch (Error e) {
                log_error ("vpn-controller", "Failed to fetch VPN details for edit: " + e.message);
            }
        });
    }

    public bool apply_edit (
        ref VpnConnection? selected_vpn,
        MainWindowVpnEditPage edit_page,
        Gtk.Stack stack,
        MainWindowVpnDetailsPage details_page,
        bool close_after_apply
    ) {
        if (selected_vpn == null) return false;
        var conn = selected_vpn;

        string? request_error = null;
        var request = edit_page.build_update_request (out request_error);
        if (request == null) {
            edit_page.show_error (MainWindowHelpers.safe_text (request_error));
            return false;
        }
        request.name = conn.name;

        string connection_id = conn.uuid != "" ? conn.uuid : conn.name;
        nm.update_vpn_settings.begin (connection_id, request, null, (obj, res) => {
            try {
                nm.update_vpn_settings.end (res);
                if (close_after_apply) {
                    this.populate_details (conn, details_page);
                    stack.set_visible_child_name ("details");
                }
            } catch (Error e) {
                edit_page.show_error (_("Apply failed: %s").printf (e.message));
            }
        });

        return true;
    }

    public void apply_setup (
        MainWindowVpnSetupPage setup_page,
        Gtk.Stack stack
    ) {
        string? request_error = null;
        var request = setup_page.build_create_request (out request_error);
        if (request == null) {
            setup_page.show_error (MainWindowHelpers.safe_text (request_error));
            return;
        }

        nm.create_vpn.begin (request, null, (obj, res) => {
            try {
                nm.create_vpn.end (res);
                stack.set_visible_child_name ("list");
                this.refresh ();
            } catch (Error e) {
                setup_page.show_error (_("Setup failed: %s").printf (e.message));
            }
        });
    }

    public void toggle_vpn_connection (
        VpnConnection conn,
        MainWindowVpnDetailsPage details_page
    ) {
        string connection_id = conn.uuid != "" ? conn.uuid : conn.name;
        if (conn.is_connected) {
            nm.disconnect_vpn.begin (connection_id, null, (obj, res) => {
                try {
                    nm.disconnect_vpn.end (res);
                } catch (Error e) {
                    host.show_vpn_error (conn.name, _("VPN disconnect failed: %s").printf (e.message));
                    return;
                }
                populate_details (conn, details_page);
            });
        } else {
            nm.connect_vpn.begin (connection_id, null, (obj, res) => {
                try {
                    nm.connect_vpn.end (res);
                } catch (Error e) {
                    host.show_vpn_error (conn.name, _("VPN connect failed: %s").printf (e.message));
                    return;
                }
                populate_details (conn, details_page);
            });
        }
    }

    public void delete_vpn (
        VpnConnection conn
    ) {
        string connection_id = conn.uuid != "" ? conn.uuid : conn.name;
        nm.delete_vpn.begin (connection_id, null, (obj, res) => {
            try {
                nm.delete_vpn.end (res);
            } catch (Error e) {
                host.show_vpn_error (conn.name, _("VPN delete failed: %s").printf (e.message));
                return;
            }
            this.refresh ();
        });
    }

    public void on_page_leave () {
        page_builder.on_page_leave ();
    }

    public void dispose_controller () {
        page_builder.dispose_controller ();
    }

    public Gtk.Widget build_page (
        out Gtk.ListBox vpn_listbox,
        out Gtk.Stack vpn_stack
    ) {
        return page_builder.build_page (
            out vpn_listbox,
            out vpn_stack
        );
    }

    public void refresh () {
        page_builder.refresh ();
    }
}
