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

// SPDX-License-Identifier: GPL-3.0-or-later
using Constants;
using GLib;
using Gtk;

namespace HyprNetworkManager.UI.Views {
    public class VpnSectionView : Object {
        public Gtk.Widget widget { get; private set; }
        public Gtk.Stack stack { get; private set; }
        public Gtk.ListBox listbox { get; private set; }

        private MainWindowVpnController controller;
        private MainWindowVpnPageBuilder page_builder;
        private VpnConnection? selected_vpn = null;
        private MainWindowVpnDetailsPage details_page;
        private MainWindowVpnEditPage edit_page;
        private MainWindowVpnAddPage add_page;
        private MainWindowVpnSetupPage setup_page;
        private MainWindowVpnPeerEditPage peer_edit_page;
        private string peer_edit_return_page = "list";

        public VpnSectionView (
            MainWindowVpnController controller,
            HyprNetworkManager.UI.Interfaces.IWidgetFactory widget_factory,
            HyprNetworkManager.Models.NetworkStateContext state_context
        ) {
            this.controller = controller;
            details_page = new MainWindowVpnDetailsPage ();
            edit_page = new MainWindowVpnEditPage (widget_factory);
            add_page = new MainWindowVpnAddPage ();
            setup_page = new MainWindowVpnSetupPage (widget_factory);
            peer_edit_page = new MainWindowVpnPeerEditPage ();
            page_builder = new MainWindowVpnPageBuilder (state_context);

            Gtk.ListBox vpn_listbox;
            Gtk.Stack vpn_stack;
            widget = page_builder.build_page (out vpn_listbox, out vpn_stack);
            listbox = vpn_listbox;
            stack = vpn_stack;

            stack.add_named (details_page, "details");
            stack.add_named (edit_page, "edit");
            stack.add_named (add_page, "add");
            stack.add_named (setup_page, "setup");
            stack.add_named (peer_edit_page, "peer_edit");

            wire_page_builder_signals ();
            wire_controller_signals ();
            wire_page_signals ();
        }

        private void wire_page_builder_signals () {
            page_builder.refresh_requested.connect (controller.refresh);
            page_builder.toggle_requested.connect (controller.toggle_list_connection);
            page_builder.open_details.connect (open_vpn_details);
            page_builder.add_clicked.connect (() => {
                stack.set_visible_child_name ("add");
            });
        }

        private void wire_controller_signals () {
            controller.refresh_started.connect (page_builder.begin_refresh);
            controller.refresh_finished.connect (page_builder.finish_refresh);
            controller.connections_loaded.connect (page_builder.render_connections);

            controller.details_loaded.connect ((connection, details) => {
                if (!is_selected (connection)) {
                    return;
                }
                details_page.render_profile_fields (connection, details);
                details_page.render_ip_settings (details, connection.is_connected);
            });

            controller.edit_details_loaded.connect ((connection, details) => {
                if (!is_selected (connection)) {
                    return;
                }
                edit_page.setup_edit_form (connection, details);
                stack.set_visible_child_name ("edit");
            });

            controller.update_succeeded.connect ((connection, close_after_apply) => {
                if (!is_selected (connection) || !close_after_apply) {
                    return;
                }
                open_vpn_details (connection);
            });

            controller.setup_succeeded.connect (() => {
                stack.set_visible_child_name ("list");
                controller.refresh ();
            });

            controller.toggle_succeeded.connect ((connection) => {
                if (is_selected (connection)) {
                    open_vpn_details (connection);
                }
            });

            controller.delete_succeeded.connect ((connection) => {
                if (is_selected (connection)) {
                    selected_vpn = null;
                }
                show_vpn_list_or_empty ();
                controller.refresh ();
            });

            controller.edit_failed.connect (edit_page.show_error);
            controller.setup_failed.connect (setup_page.show_error);
        }

        private bool is_selected (VpnConnection connection) {
            if (selected_vpn == null) {
                return false;
            }
            string selected_id = selected_vpn.uuid != "" ? selected_vpn.uuid : selected_vpn.name;
            string connection_id = connection.uuid != "" ? connection.uuid : connection.name;
            return selected_id == connection_id;
        }

        private void wire_page_signals () {
            add_page.back.connect (show_vpn_list_or_empty);
            add_page.type_selected.connect ((type) => {
                setup_page.setup_type (type);
                stack.set_visible_child_name ("setup");
            });

            setup_page.back.connect (() => {
                stack.set_visible_child_name ("add");
            });
            setup_page.apply.connect (apply_setup);
            setup_page.edit_peer_requested.connect ((index, peer) => {
                peer_edit_return_page = "setup";
                peer_edit_page.set_peer (index, peer);
                stack.set_visible_child_name ("peer_edit");
            });

            details_page.back.connect (show_vpn_list_or_empty);
            details_page.primary_action.connect (() => {
                if (selected_vpn != null) {
                    controller.toggle_vpn_connection (selected_vpn);
                }
            });
            details_page.edit.connect (() => {
                if (selected_vpn != null) {
                    open_vpn_edit (selected_vpn);
                }
            });
            details_page.delete.connect (() => {
                if (selected_vpn != null) {
                    controller.delete_vpn (selected_vpn);
                }
            });

            edit_page.back.connect (() => {
                if (selected_vpn != null) {
                    open_vpn_details (selected_vpn);
                } else {
                    show_vpn_list_or_empty ();
                }
            });
            edit_page.apply.connect (() => {
                apply_edit (true);
            });
            edit_page.edit_peer_requested.connect ((index, peer) => {
                peer_edit_return_page = "edit";
                peer_edit_page.set_peer (index, peer);
                stack.set_visible_child_name ("peer_edit");
            });

            peer_edit_page.back_clicked.connect (() => {
                stack.set_visible_child_name (peer_edit_return_page);
            });
            peer_edit_page.save_clicked.connect ((index, peer) => {
                if (peer_edit_return_page == "setup" && setup_page.wg_peers_list != null) {
                    setup_page.wg_peers_list.save_peer (index, peer);
                } else if (peer_edit_return_page == "edit" && edit_page.wg_peers_list != null) {
                    edit_page.wg_peers_list.save_peer (index, peer);
                }
                stack.set_visible_child_name (peer_edit_return_page);
            });
        }

        private void apply_setup () {
            string? error_message = null;
            var request = setup_page.build_create_request (out error_message);
            if (request == null) {
                setup_page.show_error (MainWindowHelpers.safe_text (error_message));
                return;
            }
            controller.apply_setup (request);
        }

        private void apply_edit (bool close_after_apply) {
            if (selected_vpn == null) {
                return;
            }

            string? error_message = null;
            var request = edit_page.build_update_request (out error_message);
            if (request == null) {
                edit_page.show_error (MainWindowHelpers.safe_text (error_message));
                return;
            }
            controller.apply_edit (selected_vpn, request, close_after_apply);
        }

        private void open_vpn_details (VpnConnection connection) {
            selected_vpn = connection;
            details_page.render_details (connection, false);
            details_page.show_loading_ip ();
            stack.set_visible_child_name ("details");
            controller.load_details (connection);
        }

        private void open_vpn_edit (VpnConnection connection) {
            selected_vpn = connection;
            controller.load_edit_details (connection);
        }

        private void show_vpn_list_or_empty () {
            bool has_profiles = listbox.get_first_child () != null;
            stack.set_visible_child_name (has_profiles ? "list" : "empty");
        }

        public void reset_view_state () {
            page_builder.finish_refresh ();
            show_vpn_list_or_empty ();
        }
    }
}
