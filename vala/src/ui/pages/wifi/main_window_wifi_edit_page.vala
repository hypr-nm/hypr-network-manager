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
using HyprNetworkManager.UI.Interfaces;

public class MainWindowWifiEditPage : Gtk.Box, IMainWindowIpEditPage {
    public Gtk.Label edit_title { get; set; }
    public Gtk.Entry password_entry { get; set; }
    public HyprNetworkManager.UI.Widgets.TrackedDropDown ipv4_method_dropdown { get; set; }
    public Gtk.Entry ipv4_address_entry { get; set; }
    public Gtk.Entry ipv4_prefix_entry { get; set; }
    public Gtk.Entry ipv4_gateway_entry { get; set; }
    public Gtk.Switch dns_auto_switch { get; set; }
    public Gtk.Entry ipv4_dns_entry { get; set; }
    public HyprNetworkManager.UI.Widgets.TrackedDropDown ipv6_method_dropdown { get; set; }
    public Gtk.Entry ipv6_address_entry { get; set; }
    public Gtk.Entry ipv6_prefix_entry { get; set; }
    public Gtk.Entry ipv6_gateway_entry { get; set; }
    public Gtk.Switch ipv6_dns_auto_switch { get; set; }
    public Gtk.Entry ipv6_dns_entry { get; set; }
    public Gtk.Switch? autoconnect_switch { get; set; }

    private Gtk.Label error_label;
    private Gtk.Revealer error_revealer;

    public signal void back ();
    public signal void apply ();
    public signal void ok ();

    public void setup_edit_form (WifiNetwork net) {
        this.error_revealer.set_reveal_child (false);
        this.edit_title.set_text (_("Edit: %s").printf (net.ssid));
        this.password_entry.set_text ("");
        this.password_entry.set_visibility (false);

        this.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);

        this.ipv4_method_dropdown.set_selected (0);
        this.ipv4_address_entry.set_text ("");
        this.ipv4_prefix_entry.set_text ("");
        this.ipv4_gateway_entry.set_text ("");
        this.dns_auto_switch.set_active (true);
        this.ipv4_dns_entry.set_text ("");
        this.ipv6_method_dropdown.set_selected (0);
        this.ipv6_address_entry.set_text ("");
        this.ipv6_prefix_entry.set_text ("");
        this.ipv6_gateway_entry.set_text ("");
        this.ipv6_dns_auto_switch.set_active (true);
        this.ipv6_dns_entry.set_text ("");
        this.sync_edit_gateway_dns_sensitivity ();
    }

    public void show_error (string message) {
        if (message == null || message == "") {
            this.error_revealer.set_reveal_child (false);
            return;
        }
        this.error_label.set_text (message);
        this.error_revealer.set_reveal_child (true);
    }

    public string get_password () {
        return this.password_entry.get_text ().strip ();
    }

    public void set_password (string password) {
        this.password_entry.set_text (password);
    }

    public MainWindowWifiEditPage (IWidgetFactory widget_factory) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: MainWindowUiMetrics.SPACING_ROW);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        this.add_css_class (MainWindowCssClasses.PAGE_WIFI_EDIT);
        this.add_css_class (MainWindowCssClasses.PAGE_NETWORK_EDIT);

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        header.append (back_btn);

        this.edit_title = new Gtk.Label (_("Edit Network"));
        this.edit_title.set_xalign (0.0f);
        this.edit_title.set_hexpand (true);
        this.edit_title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.append (this.edit_title);
        this.append (header);

        this.error_label = new Gtk.Label ("");
        this.error_label.set_xalign (0.0f);
        this.error_label.set_wrap (true);
        this.error_label.add_css_class (MainWindowCssClasses.ERROR_LABEL);
        this.error_label.add_css_class (MainWindowCssClasses.ROW_CONTENT_INSET);

        this.error_revealer = new Gtk.Revealer ();
        this.error_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        this.error_revealer.set_child (this.error_label);
        this.append (this.error_revealer);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        form.add_css_class (MainWindowCssClasses.EDIT_WIFI_FORM);
        form.add_css_class (MainWindowCssClasses.EDIT_NETWORK_FORM);
        form.add_css_class (MainWindowCssClasses.EDIT_FORM);
        form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        var password_label = new Gtk.Label (_("Password"));
        password_label.set_xalign (0.0f);
        password_label.add_css_class (MainWindowCssClasses.EDIT_PASSWORD_LABEL);
        password_label.add_css_class (MainWindowCssClasses.EDIT_FIELD_LABEL);
        password_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        form.append (password_label);

        this.password_entry = new Gtk.Entry ();
        this.password_entry.set_visibility (false);
        this.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        this.password_entry.set_placeholder_text (_("Password"));
        this.password_entry.add_css_class (MainWindowCssClasses.EDIT_PASSWORD_ENTRY);
        this.password_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        this.password_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
        this.password_entry.add_css_class (MainWindowCssClasses.PASSWORD_ENTRY);
        this.password_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
        this.password_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
        MainWindowHelpers.sync_password_visibility_icon (this.password_entry);

        this.password_entry.icon_press.connect ((icon_pos) => {
            if (icon_pos != Gtk.EntryIconPosition.SECONDARY) {
                return;
            }
            this.password_entry.set_visibility (!this.password_entry.get_visibility ());
            MainWindowHelpers.sync_password_visibility_icon (this.password_entry);
        });
        this.password_entry.activate.connect (() => {
            this.ok ();
        });
        form.append (this.password_entry);

        HyprNetworkManager.UI.Widgets.TrackedDropDown v4_method;
        Gtk.Entry v4_address, v4_prefix, v4_gw, v4_dns;
        Gtk.Switch v4_dns_auto;

        MainWindowIpEditFormBuilder.append_ipv4_section (
            form,
            out v4_method,
            out v4_address,
            out v4_prefix,
            out v4_gw,
            out v4_dns_auto,
            out v4_dns,
            widget_factory.create_tracked_dropdown,
            true
        );

        this.ipv4_method_dropdown = v4_method;
        this.ipv4_address_entry = v4_address;
        this.ipv4_prefix_entry = v4_prefix;
        this.ipv4_gateway_entry = v4_gw;
        this.dns_auto_switch = v4_dns_auto;
        this.ipv4_dns_entry = v4_dns;

        HyprNetworkManager.UI.Widgets.TrackedDropDown v6_method;
        Gtk.Entry v6_address, v6_prefix, v6_gw, v6_dns;
        Gtk.Switch v6_dns_auto;

        MainWindowIpEditFormBuilder.append_ipv6_section (
            form,
            out v6_method,
            out v6_address,
            out v6_prefix,
            out v6_gw,
            out v6_dns_auto,
            out v6_dns,
            widget_factory.create_tracked_dropdown,
            true
        );

        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_entry = v6_gw;
        this.ipv6_dns_auto_switch = v6_dns_auto;
        this.ipv6_dns_entry = v6_dns;

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        actions.add_css_class (MainWindowCssClasses.EDIT_WIFI_ACTIONS);
        actions.add_css_class (MainWindowCssClasses.EDIT_ACTIONS);

        var apply_btn = new Gtk.Button.with_label (_("Apply"));
        apply_btn.add_css_class (MainWindowCssClasses.BUTTON);
        apply_btn.add_css_class (MainWindowCssClasses.EDIT_APPLY_BUTTON);
        apply_btn.clicked.connect (() => {
            this.apply ();
        });
        actions.append (apply_btn);

        var ok_btn = new Gtk.Button.with_label (_("OK"));
        ok_btn.add_css_class (MainWindowCssClasses.BUTTON);
        ok_btn.add_css_class (MainWindowCssClasses.SUGGESTED_ACTION);
        ok_btn.clicked.connect (() => {
            this.ok ();
        });
        actions.append (ok_btn);

        form.append (actions);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);
        scroll.set_child (form);

        this.append (scroll);
    }
}
