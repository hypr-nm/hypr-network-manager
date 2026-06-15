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

using Gtk;

namespace HyprNetworkManager.UI.Views {
    public class MainWindowVpnPeerEditPage : Gtk.Box {
        public Gtk.Entry name_entry { get; private set; }
        public Gtk.Entry public_key_entry { get; private set; }
        public Gtk.Entry endpoint_host_entry { get; private set; }
        public Gtk.Entry endpoint_port_entry { get; private set; }
        public HyprNetworkManager.UI.Widgets.DynamicStringList allowed_ips_list { get; private set; }
        public Gtk.Entry preshared_key_entry { get; private set; }
        
        public signal void save_clicked (int index, WireGuardPeerModel peer);
        public signal void back_clicked ();

        private int editing_index = -1;

        public MainWindowVpnPeerEditPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);
            this.add_css_class (MainWindowCssClasses.PAGE);
            this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
            MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
                MainWindowCssClasses.PAGE});
            MainWindowCssClassResolver.add_hook_and_best_class (
                this,
                MainWindowCssClasses.PAGE_VPN_EDIT,
                {MainWindowCssClasses.PAGE_NETWORK_EDIT, MainWindowCssClasses.PAGE}
            );

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            
            var back_btn = MainWindowHelpers.build_back_button ();
            back_btn.clicked.connect (() => { back_clicked (); });
            header.append (back_btn);
            
            var title = new Gtk.Label (_("Edit WireGuard Peer"));
            title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
            title.set_xalign (0.0f);
            title.set_hexpand (true);
            header.append (title);
            
            this.append (header);

            var scroll = new Gtk.ScrolledWindow ();
            scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scroll.add_css_class (MainWindowCssClasses.SCROLL);
            scroll.set_vexpand (true);

            var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
            MainWindowCssClassResolver.add_best_class (
                form,
                {MainWindowCssClasses.EDIT_NETWORK_FORM, MainWindowCssClasses.EDIT_FORM}
            );
            form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

            var name_label = new Gtk.Label (_("Peer Name (optional)"));
            name_label.set_xalign (0.0f);
            name_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
            form.append (name_label);
            name_entry = new Gtk.Entry ();
            name_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            form.append (name_entry);

            var pub_key_label = new Gtk.Label (_("Public Key"));
            pub_key_label.set_xalign (0.0f);
            pub_key_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
            form.append (pub_key_label);
            public_key_entry = new Gtk.Entry ();
            public_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            form.append (public_key_entry);

            var endpoint_label = new Gtk.Label (_("Endpoint"));
            endpoint_label.set_xalign (0.0f);
            endpoint_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
            form.append (endpoint_label);

            var endpoint_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
            endpoint_host_entry = new Gtk.Entry ();
            endpoint_host_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            endpoint_host_entry.set_hexpand (true);
            endpoint_host_entry.set_placeholder_text (_("Host / IP"));
            var colon = new Gtk.Label (":");
            endpoint_port_entry = new Gtk.Entry ();
            endpoint_port_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            endpoint_port_entry.set_placeholder_text (_("Port"));
            endpoint_port_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
            endpoint_port_entry.set_width_chars (6);
            endpoint_box.append (endpoint_host_entry);
            endpoint_box.append (colon);
            endpoint_box.append (endpoint_port_entry);
            form.append (endpoint_box);

            allowed_ips_list = new HyprNetworkManager.UI.Widgets.DynamicStringList (_("Allowed IPs"), "0.0.0.0/0");
            form.append (allowed_ips_list);

            var psk_label = new Gtk.Label (_("Preshared Key"));
            psk_label.set_xalign (0.0f);
            psk_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
            form.append (psk_label);
            preshared_key_entry = new Gtk.Entry ();
            preshared_key_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            form.append (preshared_key_entry);

            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            actions.add_css_class (MainWindowCssClasses.EDIT_ACTIONS);
            actions.set_halign (Gtk.Align.END);

            var save_btn = new Gtk.Button.with_label (_("Save Peer"));
            save_btn.add_css_class (MainWindowCssClasses.BUTTON);
            MainWindowCssClassResolver.add_best_class (save_btn, {MainWindowCssClasses.SUGGESTED_ACTION, MainWindowCssClasses.PRIMARY_ACTION_BUTTON});
            save_btn.clicked.connect (() => { save_clicked (editing_index, get_peer ()); });
            
            actions.append (save_btn);
            form.append (actions);

            scroll.set_child (form);
            this.append (scroll);
        }
        
        public void set_peer (int index, WireGuardPeerModel peer) {
            editing_index = index;
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