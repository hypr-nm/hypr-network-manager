using Gtk;

namespace HyprNetworkManager.UI.Widgets {
    public class WireGuardPeerWidget : Gtk.Box {
        public Gtk.Entry name_entry { get; private set; }
        public Gtk.Entry public_key_entry { get; private set; }
        public Gtk.Entry endpoint_host_entry { get; private set; }
        public Gtk.Entry endpoint_port_entry { get; private set; }
        public StringChipList allowed_ips_list { get; private set; }
        public Gtk.Entry preshared_key_entry { get; private set; }
        
        public signal void save_clicked ();
        public signal void back_clicked ();

        public WireGuardPeerWidget () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);
            this.add_css_class ("content");

            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var back_btn = new Gtk.Button.from_icon_name ("go-previous-symbolic");
            back_btn.add_css_class ("flat");
            back_btn.clicked.connect (() => { back_clicked (); });
            header_box.append (back_btn);
            var title = new Gtk.Label (_("Edit Peer"));
            title.add_css_class ("heading");
            title.set_hexpand (true);
            title.set_xalign (0.0f);
            header_box.append (title);
            this.append (header_box);

            var name_label = new Gtk.Label (_("Peer Name (optional)"));
            name_label.set_xalign (0.0f);
            this.append (name_label);
            name_entry = new Gtk.Entry ();
            this.append (name_entry);

            var pub_key_label = new Gtk.Label (_("Public Key"));
            pub_key_label.set_xalign (0.0f);
            this.append (pub_key_label);
            public_key_entry = new Gtk.Entry ();
            this.append (public_key_entry);

            var endpoint_label = new Gtk.Label (_("Endpoint"));
            endpoint_label.set_xalign (0.0f);
            this.append (endpoint_label);

            var endpoint_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            endpoint_host_entry = new Gtk.Entry ();
            endpoint_host_entry.set_hexpand (true);
            endpoint_host_entry.set_placeholder_text (_("Host / IP"));
            var colon = new Gtk.Label (":");
            endpoint_port_entry = new Gtk.Entry ();
            endpoint_port_entry.set_placeholder_text (_("Port"));
            endpoint_port_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
            endpoint_port_entry.set_width_chars (6);
            endpoint_box.append (endpoint_host_entry);
            endpoint_box.append (colon);
            endpoint_box.append (endpoint_port_entry);
            this.append (endpoint_box);

            var allowed_ips_label = new Gtk.Label (_("Allowed IPs"));
            allowed_ips_label.set_xalign (0.0f);
            this.append (allowed_ips_label);
            allowed_ips_list = new StringChipList ("0.0.0.0/0");
            this.append (allowed_ips_list);

            var advanced_expander = new Gtk.Expander (_("Advanced"));
            var advanced_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            advanced_box.set_margin_top (6);
            
            var psk_label = new Gtk.Label (_("Preshared Key"));
            psk_label.set_xalign (0.0f);
            advanced_box.append (psk_label);
            preshared_key_entry = new Gtk.Entry ();
            advanced_box.append (preshared_key_entry);
            
            advanced_expander.set_child (advanced_box);
            this.append (advanced_expander);

            var save_btn = new Gtk.Button.with_label (_("Save Peer"));
            save_btn.add_css_class ("suggested-action");
            save_btn.set_halign (Gtk.Align.CENTER);
            save_btn.clicked.connect (() => { save_clicked (); });
            this.append (save_btn);
        }
        
        public void set_peer (WireGuardPeerModel peer) {
            name_entry.set_text (peer.name);
            public_key_entry.set_text (peer.public_key);
            endpoint_host_entry.set_text (peer.endpoint_host);
            if (peer.endpoint_port > 0) {
                endpoint_port_entry.set_text ("%u".printf (peer.endpoint_port));
            } else {
                endpoint_port_entry.set_text ("");
            }
            allowed_ips_list.set_values (peer.allowed_ips);
            preshared_key_entry.set_text (peer.preshared_key);
        }
        
        public WireGuardPeerModel get_peer () {
            var p = new WireGuardPeerModel ();
            p.name = name_entry.get_text ().strip ();
            p.public_key = public_key_entry.get_text ().strip ();
            p.endpoint_host = endpoint_host_entry.get_text ().strip ();
            
            string port_str = endpoint_port_entry.get_text ().strip ();
            uint parsed_port;
            if (uint.try_parse (port_str, out parsed_port) && parsed_port <= 65535) {
                p.endpoint_port = (uint32) parsed_port;
            }

            p.allowed_ips = allowed_ips_list.get_values ();
            p.preshared_key = preshared_key_entry.get_text ().strip ();
            return p;
        }
    }
}
