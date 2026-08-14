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
using Gtk;

namespace HyprNetworkManager.UI.Widgets {
    public class DynamicPeerList : Gtk.Box {
        private Gtk.ListBox listbox;
        private WireGuardPeerModel[] peers = {};

        public signal void edit_peer_requested (int index, WireGuardPeerModel peer);

        public DynamicPeerList () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: MainWindowUiMetrics.SPACING_HEADER);

            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
            header_box.add_css_class (MainWindowCssClasses.EDIT_MODE_ROW);
            header_box.add_css_class (MainWindowCssClasses.NM_FLAT);
            var title = new Gtk.Label (_("Peers"));
            title.set_hexpand (true);
            title.set_xalign (0.0f);
            title.add_css_class (MainWindowCssClasses.EDIT_MODE_LABEL);
            header_box.append (title);

            var add_btn = new Gtk.Button.with_label (_("Add Peer"));
            add_btn.add_css_class (MainWindowCssClasses.BUTTON);
            add_btn.add_css_class (MainWindowCssClasses.ACTION);
            add_btn.add_css_class (MainWindowCssClasses.ROW_ACTION);
            add_btn.add_css_class (MainWindowCssClasses.EDIT_MODE_SWITCH);
            add_btn.set_valign (Gtk.Align.CENTER);
            add_btn.clicked.connect (() => {
                edit_peer_requested (-1, new WireGuardPeerModel ());
            });
            header_box.append (add_btn);
            this.append (header_box);

            listbox = new Gtk.ListBox ();
            listbox.set_selection_mode (Gtk.SelectionMode.NONE);
            listbox.add_css_class ("boxed-list");
            listbox.add_css_class (MainWindowCssClasses.DATA_LIST);
            listbox.add_css_class (MainWindowCssClasses.DETAILS_ROWS);
            listbox.set_vexpand (false);
            listbox.set_valign (Gtk.Align.START);
            listbox.set_visible (false);
            this.append (listbox);
        }

        private void update_listbox_visibility () {
            listbox.set_visible (listbox.get_first_child () != null);
        }

        public void save_peer (int index, WireGuardPeerModel peer) {
            if (index >= 0 && index < peers.length) {
                peers[index] = peer;
            } else {
                peers += peer;
            }
            refresh_list ();
        }

        private void delete_peer (int index) {
            if (index >= 0 && index < peers.length) {
                WireGuardPeerModel[] new_peers = {};
                for (int i = 0; i < peers.length; i++) {
                    if (i != index) new_peers += peers[i];
                }
                peers = new_peers;
                refresh_list ();
            }
        }

        private void refresh_list () {
            var child = listbox.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                listbox.remove (child);
                child = next;
            }

            for (int i = 0; i < peers.length; i++) {
                var p = peers[i];
                int index = i;

                var row = new Gtk.ListBoxRow ();
                row.set_selectable (false);
                row.add_css_class (MainWindowCssClasses.DATA_ROW);

                var card = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
                card.add_css_class (MainWindowCssClasses.ROW_CONTENT_INSET);

                var info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
                info_box.add_css_class (MainWindowCssClasses.ROW_INFO);
                info_box.set_hexpand (true);

                string title_text = p.name != "" ? p.name : p.public_key;
                if (title_text == "") title_text = _("Unnamed Peer");
                var name_lbl = new Gtk.Label (title_text);
                name_lbl.set_xalign (0.0f);
                name_lbl.add_css_class (MainWindowCssClasses.SSID_LABEL);

                // Truncate public key if used as title
                if (p.name == "" && title_text.length > 16) {
                    name_lbl.set_text (title_text.substring (0, 16) + "…");
                }

                info_box.append (name_lbl);

                if (p.endpoint_host != "") {
                    string ep_text = p.endpoint_host;
                    if (p.endpoint_port > 0) {
                        ep_text += ":%u".printf (p.endpoint_port);
                    }
                    var ep_lbl = new Gtk.Label (ep_text);
                    ep_lbl.set_xalign (0.0f);
                    ep_lbl.add_css_class (MainWindowCssClasses.SUB_LABEL);
                    info_box.append (ep_lbl);
                }

                if (p.allowed_ips.length > 0) {
                    string ips_text = string.joinv (", ", p.allowed_ips);
                    var ips_lbl = new Gtk.Label (ips_text);
                    ips_lbl.set_xalign (0.0f);
                    ips_lbl.add_css_class (MainWindowCssClasses.SUB_LABEL);
                    ips_lbl.set_ellipsize (Pango.EllipsizeMode.END);
                    info_box.append (ips_lbl);
                }

                card.append (info_box);

                var actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
                actions_box.add_css_class (MainWindowCssClasses.ROW_ACTION_BUTTONS);
                actions_box.set_valign (Gtk.Align.CENTER);

                var edit_btn = new Gtk.Button.from_icon_name ("document-edit-symbolic");
                edit_btn.add_css_class (MainWindowCssClasses.BUTTON);
                edit_btn.add_css_class (MainWindowCssClasses.ACTION);
                edit_btn.add_css_class (MainWindowCssClasses.ROW_ICON_ACTION);
                edit_btn.clicked.connect (() => {
                    edit_peer_requested (index, p);
                });
                actions_box.append (edit_btn);

                var del_btn = new Gtk.Button.from_icon_name ("user-trash-symbolic");
                del_btn.add_css_class (MainWindowCssClasses.BUTTON);
                del_btn.add_css_class (MainWindowCssClasses.ACTION);
                del_btn.add_css_class (MainWindowCssClasses.ROW_ICON_ACTION);
                del_btn.add_css_class (MainWindowCssClasses.ACTION_DESTRUCTIVE);
                del_btn.clicked.connect (() => {
                    delete_peer (index);
                });
                actions_box.append (del_btn);

                card.append (actions_box);

                row.set_child (card);
                listbox.append (row);
            }
            update_listbox_visibility ();
        }

        public WireGuardPeerModel[] get_peers () {
            return peers;
        }

        public void set_peers (WireGuardPeerModel[] p_peers) {
            peers = p_peers;
            refresh_list ();
        }

        public void add_peer (WireGuardPeerModel peer) {
            peers += peer;
            refresh_list ();
        }
    }
}
