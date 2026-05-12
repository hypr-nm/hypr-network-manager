using Gtk;

namespace HyprNetworkManager.UI.Widgets {
    public class DynamicPeerList : Gtk.Box {
        private Gtk.Stack stack;
        private Gtk.Box list_page;
        private Gtk.ListBox listbox;
        private WireGuardPeerWidget editor_page;
        private WireGuardPeerModel[] peers = {};
        private int editing_index = -1;

        public DynamicPeerList () {
            Object (orientation: Gtk.Orientation.VERTICAL);

            stack = new Gtk.Stack ();
            stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            stack.set_vhomogeneous (false);
            stack.set_hhomogeneous (false);
            stack.set_vexpand (false);
            stack.set_valign (Gtk.Align.START);
            this.append (stack);

            // --- List Page ---
            list_page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            list_page.set_vexpand (false);
            list_page.set_valign (Gtk.Align.START);
            
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var title = new Gtk.Label (_("Peers"));
            title.set_hexpand (true);
            title.set_xalign (0.0f);
            title.add_css_class ("heading");
            header_box.append (title);

            var add_btn = new Gtk.Button.with_label (_("+ Add Peer"));
            add_btn.add_css_class ("flat");
            add_btn.add_css_class ("suggested-action");
            add_btn.clicked.connect (() => {
                open_editor (-1, new WireGuardPeerModel ());
            });
            header_box.append (add_btn);
            list_page.append (header_box);

            listbox = new Gtk.ListBox ();
            listbox.set_selection_mode (Gtk.SelectionMode.NONE);
            listbox.add_css_class ("content");
            listbox.set_vexpand (false);
            listbox.set_valign (Gtk.Align.START);
            list_page.append (listbox);

            stack.add_named (list_page, "list");

            // --- Editor Page ---
            editor_page = new WireGuardPeerWidget ();
            editor_page.set_vexpand (false);
            editor_page.set_valign (Gtk.Align.START);
            editor_page.back_clicked.connect (() => {
                stack.set_visible_child_name ("list");
            });
            editor_page.save_clicked.connect (() => {
                save_current_editor ();
                stack.set_visible_child_name ("list");
            });

            stack.add_named (editor_page, "editor");
        }

        private void open_editor (int index, WireGuardPeerModel peer) {
            editing_index = index;
            editor_page.set_peer (peer);
            stack.set_visible_child_name ("editor");
        }

        private void save_current_editor () {
            var peer = editor_page.get_peer ();
            if (editing_index >= 0 && editing_index < peers.length) {
                peers[editing_index] = peer;
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
                
                var card = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                card.set_margin_start (12);
                card.set_margin_end (12);
                card.set_margin_top (12);
                card.set_margin_bottom (12);

                var info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
                info_box.set_hexpand (true);

                string title_text = p.name != "" ? p.name : p.public_key;
                if (title_text == "") title_text = _("Unnamed Peer");
                var name_lbl = new Gtk.Label (title_text);
                name_lbl.set_xalign (0.0f);
                name_lbl.add_css_class ("heading");
                
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
                    ep_lbl.add_css_class ("dim-label");
                    info_box.append (ep_lbl);
                }

                if (p.allowed_ips.length > 0) {
                    string ips_text = string.joinv (", ", p.allowed_ips);
                    var ips_lbl = new Gtk.Label (ips_text);
                    ips_lbl.set_xalign (0.0f);
                    ips_lbl.add_css_class ("dim-label");
                    ips_lbl.set_ellipsize (Pango.EllipsizeMode.END);
                    info_box.append (ips_lbl);
                }

                card.append (info_box);

                var actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
                actions_box.set_valign (Gtk.Align.CENTER);
                
                var edit_btn = new Gtk.Button.from_icon_name ("document-edit-symbolic");
                edit_btn.add_css_class ("flat");
                edit_btn.clicked.connect (() => {
                    open_editor (index, p);
                });
                actions_box.append (edit_btn);

                var del_btn = new Gtk.Button.from_icon_name ("user-trash-symbolic");
                del_btn.add_css_class ("flat");
                del_btn.add_css_class ("destructive-action");
                del_btn.clicked.connect (() => {
                    delete_peer (index);
                });
                actions_box.append (del_btn);

                card.append (actions_box);

                row.set_child (card);
                listbox.append (row);
            }
        }

        public WireGuardPeerModel[] get_peers () {
            return peers;
        }

        public void set_peers (WireGuardPeerModel[] p_peers) {
            peers = p_peers;
            refresh_list ();
            stack.set_visible_child_name ("list");
        }
        
        public void add_peer (WireGuardPeerModel peer) {
            peers += peer;
            refresh_list ();
        }
    }
}
