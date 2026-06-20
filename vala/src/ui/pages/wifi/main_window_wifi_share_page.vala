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

public class MainWindowWifiSharePage : Gtk.Box {
    private Gtk.Label ssid_label;
    private Gtk.Box qr_container;
    private Gtk.Label description_label;
    private string current_qr_text;

    public signal void back ();

    public MainWindowWifiSharePage () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 10);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET, MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            "nm-page-wifi-share",
            {MainWindowCssClasses.PAGE_NETWORK_DETAILS, MainWindowCssClasses.PAGE}
        );

        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_NONE);
        nav_row.add_css_class (MainWindowCssClasses.DETAILS_NAV_ROW);

        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        back_btn.set_halign (Gtk.Align.START);
        nav_row.append (back_btn);
        this.append (nav_row);

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        content_box.set_halign (Gtk.Align.CENTER);
        content_box.set_valign (Gtk.Align.CENTER);
        content_box.set_vexpand (true);
        content_box.add_css_class ("nm-qr-share-content");

        this.ssid_label = new Gtk.Label ("");
        this.ssid_label.set_xalign (0.5f);
        this.ssid_label.set_halign (Gtk.Align.CENTER);
        this.ssid_label.add_css_class ("nm-qr-share-title");
        content_box.append (this.ssid_label);

        this.qr_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.qr_container.set_halign (Gtk.Align.CENTER);
        this.qr_container.set_valign (Gtk.Align.CENTER);
        this.qr_container.add_css_class ("nm-qr-share-code-box");
        content_box.append (this.qr_container);

        this.description_label = new Gtk.Label ("");
        this.description_label.set_xalign (0.5f);
        this.description_label.set_halign (Gtk.Align.CENTER);
        this.description_label.set_wrap (true);
        this.description_label.set_justify (Gtk.Justification.CENTER);
        this.description_label.add_css_class ("nm-qr-share-description");
        content_box.append (this.description_label);

        this.append (content_box);
    }

    public void set_share_data (string ssid, string qr_text) {
        this.ssid_label.set_text (ssid);
        this.current_qr_text = qr_text;
        
        this.show_obfuscator ();

        string text1 = _("Scan this QR code on another device to connect to %s without entering the password.").printf(ssid);
        string text2 = _("This QR code includes the network password and it isn't encrypted. Anyone with access to this QR code can find out this network's password.");
        this.description_label.set_text (text1 + "\n" + text2);
    }

    private void show_obfuscator () {
        MainWindowHelpers.clear_box (this.qr_container);

        var reveal_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        reveal_box.set_halign (Gtk.Align.CENTER);
        reveal_box.set_valign (Gtk.Align.CENTER);
        reveal_box.set_size_request (180, 180);
        reveal_box.add_css_class ("nm-qr-reveal-box");

        var reveal_icon = new Gtk.Image.from_icon_name ("view-reveal-symbolic");
        reveal_icon.set_pixel_size (48);
        reveal_box.append (reveal_icon);

        var reveal_btn = new Gtk.Button.with_label (_("Click to Reveal"));
        reveal_btn.add_css_class (MainWindowCssClasses.BUTTON);
        reveal_btn.add_css_class ("nm-qr-reveal-button");
        reveal_btn.clicked.connect (() => {
            this.reveal_qr_code ();
        });
        reveal_box.append (reveal_btn);

        this.qr_container.append (reveal_box);
    }

    private void reveal_qr_code () {
        MainWindowHelpers.clear_box (this.qr_container);

        var revealed_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        revealed_box.set_halign (Gtk.Align.CENTER);
        revealed_box.set_valign (Gtk.Align.CENTER);

        var qr_widget = new HyprNetworkManager.UI.Widgets.QrCodeWidget (this.current_qr_text);
        qr_widget.set_size_request (180, 180);
        revealed_box.append (qr_widget);

        var hide_btn = new Gtk.Button.with_label (_("Hide QR Code"));
        hide_btn.add_css_class (MainWindowCssClasses.BUTTON);
        hide_btn.add_css_class ("nm-qr-hide-button");
        hide_btn.clicked.connect (() => {
            this.show_obfuscator ();
        });
        revealed_box.append (hide_btn);

        this.qr_container.append (revealed_box);
    }
}
