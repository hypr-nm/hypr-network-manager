// SPDX-License-Identifier: GPL-3.0-or-later
using GLib;
using Gtk;

namespace HyprNetworkManager.UI.Views {
    public class VpnSectionView : Object {
        public Gtk.Widget widget { get; private set; }
        public Gtk.Stack stack { get; private set; }
        public Gtk.ListBox listbox { get; private set; }

        private NetworkManagerClient nm;
        private MainWindowVpnController controller;
        private HyprNetworkManager.UI.Interfaces.IWindowHost window_host;
        private VpnConnection? selected_vpn = null;
        private MainWindowVpnDetailsPage details_page;
        private MainWindowVpnEditPage edit_page;
        private MainWindowVpnAddPage add_page;
        private MainWindowVpnSetupPage setup_page;
        private MainWindowVpnPeerEditPage peer_edit_page;
        
        private string peer_edit_return_page = "list";

        public VpnSectionView (
            NetworkManagerClient nm,
            MainWindowVpnController controller,
            HyprNetworkManager.UI.Interfaces.IWindowHost window_host
        ) {
            this.nm = nm;
            this.controller = controller;
            this.window_host = window_host;
            this.details_page = new MainWindowVpnDetailsPage ();
            this.edit_page = new MainWindowVpnEditPage (window_host);
            this.add_page = new MainWindowVpnAddPage ();
            this.setup_page = new MainWindowVpnSetupPage (window_host);
            this.peer_edit_page = new MainWindowVpnPeerEditPage ();

            Gtk.ListBox vpn_listbox;
            Gtk.Stack vpn_stack_local;

            var page = controller.build_page (
                out vpn_listbox,
                out vpn_stack_local
            );

            this.listbox = vpn_listbox;
            this.stack = vpn_stack_local;
            this.widget = page;

            this.stack.add_named (details_page, "details");
            this.stack.add_named (edit_page, "edit");
            this.stack.add_named (add_page, "add");
            this.stack.add_named (setup_page, "setup");
            this.stack.add_named (peer_edit_page, "peer_edit");

            wire_signals ();
        }

        private void wire_signals () {
            controller.refresh_started.connect (() => {
                // Progress is already handled by page_builder connecting to controller
            });

            controller.details_requested.connect ((conn) => {
                open_vpn_details (conn);
            });

            controller.add_requested.connect (() => {
                stack.set_visible_child_name ("add");
            });

            add_page.back.connect (() => {
                show_vpn_list_or_empty ();
            });

            add_page.type_selected.connect ((type) => {
                setup_page.setup_type (type);
                stack.set_visible_child_name ("setup");
            });

            setup_page.back.connect (() => {
                stack.set_visible_child_name ("add");
            });

            setup_page.apply.connect (() => {
                controller.apply_setup (nm, setup_page, stack);
            });
            
            setup_page.edit_peer_requested.connect ((index, peer) => {
                peer_edit_return_page = "setup";
                peer_edit_page.set_peer (index, peer);
                stack.set_visible_child_name ("peer_edit");
            });

            details_page.back.connect (() => {
                show_vpn_list_or_empty ();
            });

            details_page.primary_action.connect (() => {
                if (selected_vpn == null) return;
                
                string connection_id = selected_vpn.uuid != "" ? selected_vpn.uuid : selected_vpn.name;
                if (selected_vpn.is_connected) {
                    nm.disconnect_vpn.begin (connection_id, null, (obj, res) => {
                        try {
                            nm.disconnect_vpn.end (res);
                            open_vpn_details (selected_vpn); // Refresh details
                        } catch (Error e) {
                            window_host.show_vpn_error (selected_vpn.name, _("VPN disconnect failed: %s").printf (e.message));
                        }
                    });
                } else {
                    nm.connect_vpn.begin (connection_id, null, (obj, res) => {
                        try {
                            nm.connect_vpn.end (res);
                            open_vpn_details (selected_vpn); // Refresh details
                        } catch (Error e) {
                            window_host.show_vpn_error (selected_vpn.name, _("VPN connect failed: %s").printf (e.message));
                        }
                    });
                }
            });

            details_page.edit.connect (() => {
                if (selected_vpn == null) return;
                open_vpn_edit (selected_vpn);
            });

            details_page.delete.connect (() => {
                if (selected_vpn == null) return;
                delete_vpn_profile (selected_vpn);
            });

            edit_page.back.connect (() => {
                if (selected_vpn != null) {
                    open_vpn_details (selected_vpn);
                } else {
                    show_vpn_list_or_empty ();
                }
            });

            edit_page.apply.connect (() => {
                controller.apply_edit (ref selected_vpn, nm, edit_page, stack, details_page, true);
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

        private void open_vpn_details (VpnConnection conn) {
            controller.populate_details (nm, conn, details_page);
            controller.open_details (ref selected_vpn, conn, stack);
        }

        private void open_vpn_edit (VpnConnection conn) {
            controller.open_edit (ref selected_vpn, nm, conn, edit_page, stack);
        }

        private void delete_vpn_profile (VpnConnection conn) {
            controller.refresh_started ();
            string connection_id = conn.uuid != "" ? conn.uuid : conn.name;
            nm.delete_vpn.begin (connection_id, null, (obj, res) => {
                try {
                    nm.delete_vpn.end (res);
                    show_vpn_list_or_empty ();
                    controller.refresh ();
                } catch (Error e) {
                    controller.refresh_finished ();
                    window_host.show_vpn_error (conn.name, _("VPN delete failed: %s").printf (e.message));
                }
            });
        }

        private void show_vpn_list_or_empty () {
            bool has_profiles = listbox.get_first_child () != null;
            stack.set_visible_child_name (has_profiles ? "list" : "empty");
        }

        public void reset_view_state () {
            if (stack != null) {
                show_vpn_list_or_empty ();
            }
        }
    }
}
