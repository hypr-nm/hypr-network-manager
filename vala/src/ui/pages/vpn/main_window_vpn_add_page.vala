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

public class MainWindowVpnAddPage : Gtk.Box {
    public signal void back ();
    public signal void type_selected (string type);
    
    public MainWindowVpnAddPage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: MainWindowUiMetrics.SPACING_ROW);

        this.set_hexpand (true);
        this.set_vexpand (true);
        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        this.add_css_class (MainWindowCssClasses.PAGE_VPN_ADD);
        this.add_css_class (MainWindowCssClasses.PAGE_NETWORK_ADD);
        this.add_css_class (MainWindowCssClasses.PAGE_NETWORK_EDIT);
        
        var header = new Gtk.CenterBox ();
        header.set_margin_bottom (MainWindowUiMetrics.SPACING_HEADER);

        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        
        var start_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        start_box.append (back_btn);
        header.set_start_widget (start_box);

        var title = new Gtk.Label (_("Add VPN"));
        title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.set_center_widget (title);
        
        this.append (header);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);

        var body = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        body.add_css_class (MainWindowCssClasses.ADD_NETWORK_FORM);
        body.add_css_class (MainWindowCssClasses.EDIT_NETWORK_FORM);
        body.add_css_class (MainWindowCssClasses.EDIT_FORM);
        body.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        var lbl = new Gtk.Label (_("Choose a VPN type:"));
        lbl.set_xalign (0.0f);
        lbl.add_css_class (MainWindowCssClasses.FORM_LABEL);
        body.append (lbl);

        var listbox = new Gtk.ListBox ();
        listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        listbox.add_css_class ("boxed-list");
        listbox.add_css_class (MainWindowCssClasses.DATA_LIST);
        listbox.add_css_class (MainWindowCssClasses.DETAILS_ROWS);

        listbox.row_activated.connect ((row) => {
            string? id = row.get_data ("vpn-type-id");
            if (id != null) {
                this.type_selected (id);
            }
        });

        add_type_row (listbox, "WireGuard", "wireguard", "network-vpn-symbolic");
        add_type_row (listbox, "OpenVPN", "openvpn", "network-vpn-symbolic");

        body.append (listbox);
        scroll.set_child (body);
        this.append (scroll);
    }

    private void add_type_row (Gtk.ListBox listbox, string label, string id, string icon_name) {
        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        row.set_margin_top (MainWindowUiMetrics.SPACING_SECTION);
        row.set_margin_bottom (MainWindowUiMetrics.SPACING_SECTION);
        row.set_margin_start (16);
        row.set_margin_end (16);

        var icon = new Gtk.Image.from_icon_name (icon_name);
        icon.add_css_class (MainWindowCssClasses.ICON_SIZE_24);
        row.append (icon);

        var lbl = new Gtk.Label (label);
        lbl.set_xalign (0.0f);
        lbl.set_hexpand (true);
        row.append (lbl);

        var arrow = new Gtk.Image.from_icon_name ("go-next-symbolic");
        arrow.add_css_class (MainWindowCssClasses.ICON_SIZE_16);
        arrow.add_css_class (MainWindowCssClasses.VPN_TYPE_ARROW);
        row.append (arrow);

        var list_row = new Gtk.ListBoxRow ();
        list_row.add_css_class (MainWindowCssClasses.DATA_ROW);
        list_row.set_child (row);
        list_row.set_data ("vpn-type-id", id);

        listbox.append (list_row);
    }
}
