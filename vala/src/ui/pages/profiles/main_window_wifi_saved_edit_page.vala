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

public class MainWindowWifiSavedEditPage : Gtk.Box, IMainWindowIpEditPage {
    private static string[] security_mode_keys = {
        WifiSecurity.OPEN,
        WifiKeyMgmt.WPA_PSK,
        WifiKeyMgmt.SAE,
        WifiKeyMgmt.OWE,
        WifiSecurity.WEP,
        WifiKeyMgmt.WPA_EAP
    };

    private static string[] eap_method_keys = {
        EapMethod.PEAP,
        EapMethod.TLS,
        EapMethod.TTLS,
        EapMethod.PWD
    };

    private static string[] phase2_auth_keys = {
        Phase2Auth.MSCHAPV2,
        Phase2Auth.MD5,
        Phase2Auth.GTC,
        Phase2Auth.PAP,
        Phase2Auth.CHAP
    };

    public Gtk.Label title_label { get; set; }
    public Gtk.Entry profile_name_entry { get; set; }
    public Gtk.Entry ssid_entry { get; set; }
    public Gtk.Entry bssid_entry { get; set; }
    public HyprNetworkManager.UI.Widgets.TrackedDropDown security_mode_dropdown { get; set; }
    public Gtk.CheckButton autoconnect_check { get; set; }
    public Gtk.CheckButton all_users_check { get; set; }
    public Gtk.Label identity_label { get; set; }
    public Gtk.Entry identity_entry { get; set; }
    public Gtk.Label anonymous_identity_label { get; set; }
    public Gtk.Entry anonymous_identity_entry { get; set; }
    public Gtk.Label domain_label { get; set; }
    public Gtk.Entry domain_entry { get; set; }
    public Gtk.Label ca_cert_label { get; set; }
    public Gtk.Entry ca_cert_entry { get; set; }
    public Gtk.Label ca_cert_password_label { get; set; }
    public Gtk.Entry ca_cert_password_entry { get; set; }
    public Gtk.Label user_cert_label { get; set; }
    public Gtk.Entry user_cert_entry { get; set; }
    public Gtk.Label user_cert_password_label { get; set; }
    public Gtk.Entry user_cert_password_entry { get; set; }
    public Gtk.Label user_private_key_label { get; set; }
    public Gtk.Entry user_private_key_entry { get; set; }
    public Gtk.Label user_private_key_password_label { get; set; }
    public Gtk.Entry user_private_key_password_entry { get; set; }
    public Gtk.Label eap_method_label { get; set; }
    public HyprNetworkManager.UI.Widgets.TrackedDropDown eap_method_dropdown { get; set; }
    public Gtk.Label phase2_auth_label { get; set; }
    public HyprNetworkManager.UI.Widgets.TrackedDropDown phase2_auth_dropdown { get; set; }
    public Gtk.Label password_label { get; set; }
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
    public Gtk.Switch? autoconnect_switch { get; set; default = null; }

    private Gtk.Label error_label;
    private Gtk.Revealer error_revealer;

    public signal void back ();
    public signal void save ();

    public override void sync_edit_gateway_dns_sensitivity () {
        bool ipv4_disabled = this.ipv4_method_dropdown.get_selected () == 2;
        if (ipv4_disabled) {
            this.dns_auto_switch.set_active (true);
        }

        uint ipv6_selected = this.ipv6_method_dropdown.get_selected ();
        bool ipv6_disabled_or_ignore = ipv6_selected == 2 || ipv6_selected == 3;
        if (ipv6_disabled_or_ignore) {
            this.ipv6_dns_auto_switch.set_active (true);
        }

        this.ipv4_dns_entry.set_sensitive (!this.dns_auto_switch.get_active ());
        this.ipv6_dns_entry.set_sensitive (!this.ipv6_dns_auto_switch.get_active ());
    }

    public void apply_settings_to_edit_page (WifiSavedProfileSettings settings) {
        this.error_revealer.set_reveal_child (false);
        this.profile_name_entry.set_text (settings.profile_name);
        this.ssid_entry.set_text (settings.ssid);
        this.bssid_entry.set_text (settings.bssid);
        this.set_selected_security_mode_key (settings.security_mode);
        this.autoconnect_check.set_active (settings.autoconnect);
        this.all_users_check.set_active (settings.available_to_all_users);
        this.identity_entry.set_text (settings.identity);
        this.anonymous_identity_entry.set_text (settings.anonymous_identity);
        this.domain_entry.set_text (settings.domain_suffix_match);
        this.ca_cert_entry.set_text (settings.ca_cert);
        this.ca_cert_password_entry.set_text (settings.ca_cert_password);
        this.user_cert_entry.set_text (settings.user_cert);
        this.user_cert_password_entry.set_text (settings.user_cert_password);
        this.user_private_key_entry.set_text (settings.user_private_key);
        this.user_private_key_password_entry.set_text (settings.user_private_key_password);
        this.set_selected_eap_method_key (settings.eap_method);
        this.set_selected_phase2_auth_key (settings.phase2_auth);
        this.password_entry.set_text (settings.configured_password);

        this.ipv4_method_dropdown.set_selected (
            MainWindowHelpers.get_ipv4_method_dropdown_index (settings.ipv4_method)
        );
        this.ipv4_address_entry.set_text (settings.configured_address);
        this.ipv4_prefix_entry.set_text (
            settings.configured_prefix > 0 ? "%u".printf (settings.configured_prefix) : ""
        );
        this.ipv4_gateway_entry.set_text (settings.configured_gateway);
        this.dns_auto_switch.set_active (settings.dns_auto);
        this.ipv4_dns_entry.set_text (settings.configured_dns);

        this.ipv6_method_dropdown.set_selected (
            MainWindowHelpers.get_ipv6_method_dropdown_index (settings.ipv6_method)
        );
        this.ipv6_address_entry.set_text (settings.configured_ipv6_address);
        this.ipv6_prefix_entry.set_text (
            settings.configured_ipv6_prefix > 0 ? "%u".printf (settings.configured_ipv6_prefix) : ""
        );
        this.ipv6_gateway_entry.set_text (settings.configured_ipv6_gateway);
        this.ipv6_dns_auto_switch.set_active (settings.ipv6_dns_auto);
        this.ipv6_dns_entry.set_text (settings.configured_ipv6_dns);
    }

    public void show_error (string message) {
        if (message == null || message == "") {
            this.error_revealer.set_reveal_child (false);
            return;
        }
        this.error_label.set_text (message);
        this.error_revealer.set_reveal_child (true);
    }

    public bool build_update_requests (
        out WifiSavedProfileUpdateRequest profile_request,
        out WifiNetworkUpdateRequest network_request,
        out string error_message
    ) {
        error_message = "";

        string password = this.password_entry.get_text ().strip ();

        var v4 = MainWindowIpValidation.validate (
            MainWindowIpValidation.Family.IPV4,
            MainWindowWifiEditUtils.get_selected_ipv4_method (this.ipv4_method_dropdown),
            this.ipv4_address_entry.get_text ().strip (),
            this.ipv4_prefix_entry.get_text (),
            this.ipv4_gateway_entry.get_text ().strip (),
            this.dns_auto_switch.get_active (),
            this.ipv4_dns_entry.get_text ().strip (),
            out error_message);
        if (v4 == null) {
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        string error6;
        var v6 = MainWindowIpValidation.validate (
            MainWindowIpValidation.Family.IPV6,
            MainWindowWifiEditUtils.get_selected_ipv6_method (this.ipv6_method_dropdown),
            this.ipv6_address_entry.get_text ().strip (),
            this.ipv6_prefix_entry.get_text (),
            this.ipv6_gateway_entry.get_text ().strip (),
            this.ipv6_dns_auto_switch.get_active (),
            this.ipv6_dns_entry.get_text ().strip (),
            out error6);
        if (v6 == null) {
            error_message = error6;
            profile_request = new WifiSavedProfileUpdateRequest ();
            network_request = new WifiNetworkUpdateRequest ();
            return false;
        }

        profile_request = new WifiSavedProfileUpdateRequest () {
            profile_name = this.profile_name_entry.get_text ().strip (),
            ssid = this.ssid_entry.get_text ().strip (),
            bssid = this.bssid_entry.get_text ().strip (),
            security_mode = this.get_selected_security_mode_key (),
            autoconnect = this.autoconnect_check.get_active (),
            available_to_all_users = this.all_users_check.get_active (),
            identity = this.identity_entry.get_text ().strip (),
            anonymous_identity = this.anonymous_identity_entry.get_text ().strip (),
            domain_suffix_match = this.domain_entry.get_text ().strip (),
            ca_cert = this.ca_cert_entry.get_text ().strip (),
            ca_cert_password = this.ca_cert_password_entry.get_text (),
            eap_method = this.get_selected_eap_method_key (),
            phase2_auth = this.get_selected_phase2_auth_key (),
            user_cert = this.user_cert_entry.get_text ().strip (),
            user_cert_password = this.user_cert_password_entry.get_text (),
            user_private_key = this.user_private_key_entry.get_text ().strip (),
            user_private_key_password = this.user_private_key_password_entry.get_text ()
        };

        network_request = new WifiNetworkUpdateRequest () {
            password = password,
            identity = this.identity_entry.get_text ().strip (),
            anonymous_identity = this.anonymous_identity_entry.get_text ().strip (),
            domain_suffix_match = this.domain_entry.get_text ().strip (),
            ca_cert = this.ca_cert_entry.get_text ().strip (),
            ca_cert_password = this.ca_cert_password_entry.get_text (),
            eap_method = this.get_selected_eap_method_key (),
            phase2_auth = this.get_selected_phase2_auth_key (),
            user_cert = this.user_cert_entry.get_text ().strip (),
            user_cert_password = this.user_cert_password_entry.get_text (),
            user_private_key = this.user_private_key_entry.get_text ().strip (),
            user_private_key_password = this.user_private_key_password_entry.get_text (),
            ipv4_method = v4.method,
            ipv4_address = v4.address,
            ipv4_prefix = v4.prefix,
            ipv4_gateway_auto = v4.gateway_auto,
            ipv4_gateway = v4.gateway,
            ipv4_dns_auto = v4.dns_auto,
            ipv4_dns_servers = v4.dns_servers,
            ipv6_method = v6.method,
            ipv6_address = v6.address,
            ipv6_prefix = v6.prefix,
            ipv6_gateway_auto = v6.gateway_auto,
            ipv6_gateway = v6.gateway,
            ipv6_dns_auto = v6.dns_auto,
            ipv6_dns_servers = v6.dns_servers
        };

        return true;
    }

    public string get_selected_security_mode_key () {
        uint idx = this.security_mode_dropdown.get_selected ();
        if (idx >= security_mode_keys.length) {
            return WifiSecurity.OPEN;
        }
        return security_mode_keys[idx];
    }

    public void set_selected_security_mode_key (string mode_key) {
        string key = mode_key.strip ().down ();
        for (uint i = 0; i < security_mode_keys.length; i++) {
            if (security_mode_keys[i] == key) {
                this.security_mode_dropdown.set_selected (i);
                this.sync_eap_field_visibilities ();
                return;
            }
        }
        this.security_mode_dropdown.set_selected (0);
        this.sync_eap_field_visibilities ();
    }

    public string get_selected_eap_method_key () {
        uint idx = this.eap_method_dropdown.get_selected ();
        if (idx >= eap_method_keys.length) {
            return EapMethod.PEAP;
        }
        return eap_method_keys[idx];
    }

    public void set_selected_eap_method_key (string eap_key) {
        string key = eap_key.strip ().down ();
        for (uint i = 0; i < eap_method_keys.length; i++) {
            if (eap_method_keys[i] == key) {
                this.eap_method_dropdown.set_selected (i);
                this.sync_eap_field_visibilities ();
                return;
            }
        }
        this.eap_method_dropdown.set_selected (0);
        this.sync_eap_field_visibilities ();
    }

    public string get_selected_phase2_auth_key () {
        uint idx = this.phase2_auth_dropdown.get_selected ();
        if (idx >= phase2_auth_keys.length) {
            return Phase2Auth.MSCHAPV2;
        }
        return phase2_auth_keys[idx];
    }

    public void set_selected_phase2_auth_key (string phase2_key) {
        string key = phase2_key.strip ().down ();
        for (uint i = 0; i < phase2_auth_keys.length; i++) {
            if (phase2_auth_keys[i] == key) {
                this.phase2_auth_dropdown.set_selected (i);
                this.sync_eap_field_visibilities ();
                return;
            }
        }
        this.phase2_auth_dropdown.set_selected (0);
        this.sync_eap_field_visibilities ();
    }

    public void sync_eap_field_visibilities () {
        string selected_mode = this.get_selected_security_mode_key ();
        bool is_eap = selected_mode == WifiKeyMgmt.WPA_EAP;

        if (!is_eap) {
            if (this.identity_label != null) this.identity_label.set_visible (false);
            if (this.identity_entry != null) this.identity_entry.set_visible (false);
            if (this.anonymous_identity_label != null) this.anonymous_identity_label.set_visible (false);
            if (this.anonymous_identity_entry != null) this.anonymous_identity_entry.set_visible (false);
            if (this.domain_label != null) this.domain_label.set_visible (false);
            if (this.domain_entry != null) this.domain_entry.set_visible (false);
            if (this.ca_cert_label != null) this.ca_cert_label.set_visible (false);
            if (this.ca_cert_entry != null) this.ca_cert_entry.set_visible (false);
            if (this.ca_cert_password_label != null) this.ca_cert_password_label.set_visible (false);
            if (this.ca_cert_password_entry != null) this.ca_cert_password_entry.set_visible (false);
            if (this.user_cert_label != null) this.user_cert_label.set_visible (false);
            if (this.user_cert_entry != null) this.user_cert_entry.set_visible (false);
            if (this.user_cert_password_label != null) this.user_cert_password_label.set_visible (false);
            if (this.user_cert_password_entry != null) this.user_cert_password_entry.set_visible (false);
            if (this.user_private_key_label != null) this.user_private_key_label.set_visible (false);
            if (this.user_private_key_entry != null) this.user_private_key_entry.set_visible (false);
            if (this.user_private_key_password_label != null) this.user_private_key_password_label.set_visible (false);
            if (this.user_private_key_password_entry != null) this.user_private_key_password_entry.set_visible (false);
            if (this.eap_method_label != null) this.eap_method_label.set_visible (false);
            if (this.eap_method_dropdown != null) this.eap_method_dropdown.set_visible (false);
            if (this.phase2_auth_label != null) this.phase2_auth_label.set_visible (false);
            if (this.phase2_auth_dropdown != null) this.phase2_auth_dropdown.set_visible (false);
            if (this.password_label != null) this.password_label.set_visible (true);
            if (this.password_entry != null) this.password_entry.set_visible (true);
            return;
        }

        string eap_method = this.get_selected_eap_method_key ();
        
        bool show_identity = eap_method == EapMethod.PEAP || eap_method == EapMethod.TLS || eap_method == EapMethod.TTLS || eap_method == EapMethod.PWD;
        bool show_anonymous_identity = eap_method == EapMethod.PEAP || eap_method == EapMethod.TTLS;
        bool show_domain = eap_method == EapMethod.PEAP || eap_method == EapMethod.TLS;
        bool show_ca_cert = eap_method == EapMethod.PEAP || eap_method == EapMethod.TLS || eap_method == EapMethod.TTLS;
        bool show_user_cert = eap_method == EapMethod.TLS;
        bool show_user_private_key = eap_method == EapMethod.TLS;
        bool show_user_private_key_password = eap_method == EapMethod.TLS;
        bool show_phase2_auth = eap_method == EapMethod.PEAP || eap_method == EapMethod.TTLS;
        bool show_password = eap_method == EapMethod.PEAP || eap_method == EapMethod.TTLS || eap_method == EapMethod.PWD;

        if (this.identity_label != null) {
            this.identity_label.set_text (eap_method == EapMethod.TLS ? _("Identity") : _("Username"));
            this.identity_label.set_visible (show_identity);
        }
        if (this.identity_entry != null) this.identity_entry.set_visible (show_identity);
        
        if (this.anonymous_identity_label != null) this.anonymous_identity_label.set_visible (show_anonymous_identity);
        if (this.anonymous_identity_entry != null) this.anonymous_identity_entry.set_visible (show_anonymous_identity);
        
        if (this.domain_label != null) this.domain_label.set_visible (show_domain);
        if (this.domain_entry != null) this.domain_entry.set_visible (show_domain);
        
        if (this.ca_cert_label != null) this.ca_cert_label.set_visible (show_ca_cert);
        if (this.ca_cert_entry != null) this.ca_cert_entry.set_visible (show_ca_cert);
        if (this.ca_cert_password_label != null) this.ca_cert_password_label.set_visible (show_ca_cert);
        if (this.ca_cert_password_entry != null) this.ca_cert_password_entry.set_visible (show_ca_cert);
        
        if (this.user_cert_label != null) this.user_cert_label.set_visible (show_user_cert);
        if (this.user_cert_entry != null) this.user_cert_entry.set_visible (show_user_cert);
        if (this.user_cert_password_label != null) this.user_cert_password_label.set_visible (show_user_cert);
        if (this.user_cert_password_entry != null) this.user_cert_password_entry.set_visible (show_user_cert);
        
        if (this.user_private_key_label != null) this.user_private_key_label.set_visible (show_user_private_key);
        if (this.user_private_key_entry != null) this.user_private_key_entry.set_visible (show_user_private_key);
        
        if (this.user_private_key_password_label != null) this.user_private_key_password_label.set_visible (show_user_private_key_password);
        if (this.user_private_key_password_entry != null) this.user_private_key_password_entry.set_visible (show_user_private_key_password);
        
        if (this.eap_method_label != null) this.eap_method_label.set_visible (true);
        if (this.eap_method_dropdown != null) this.eap_method_dropdown.set_visible (true);
        
        if (this.phase2_auth_label != null) this.phase2_auth_label.set_visible (show_phase2_auth);
        if (this.phase2_auth_dropdown != null) this.phase2_auth_dropdown.set_visible (show_phase2_auth);
        
        if (this.password_label != null) this.password_label.set_visible (show_password);
        if (this.password_entry != null) this.password_entry.set_visible (show_password);
    }

    private Gtk.Box build_section (string title, out Gtk.Box section_content) {
        var section = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        section.add_css_class (MainWindowCssClasses.EDIT_COLLAPSIBLE);

        var heading = new Gtk.Label (title);
        heading.set_xalign (0.0f);
        MainWindowCssClassResolver.add_best_class (heading, {MainWindowCssClasses.EDIT_FIELD_LABEL,
            MainWindowCssClasses.FORM_LABEL});
        section.append (heading);

        section_content = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        section_content.add_css_class (MainWindowCssClasses.EDIT_SECTION_CONTENT);
        section.append (section_content);

        return section;
    }

    private void set_collapsible_state (
        Gtk.Box container,
        Gtk.Button toggle_button,
        Gtk.Revealer content_revealer,
        Gtk.Image toggle_icon,
        bool expanded
    ) {
        content_revealer.set_reveal_child (expanded);
        MainWindowIconResources.set_expand_indicator_icon (toggle_icon, expanded);
        if (expanded) {
            container.add_css_class ("is-expanded");
            container.remove_css_class ("is-collapsed");
            toggle_button.set_tooltip_text (_("Collapse section"));
        } else {
            container.add_css_class ("is-collapsed");
            container.remove_css_class ("is-expanded");
            toggle_button.set_tooltip_text (_("Expand section"));
        }
    }

    private Gtk.Box build_collapsible_section (
        string title,
        out Gtk.Box content_box,
        bool expanded = true
    ) {
        var container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        container.add_css_class (MainWindowCssClasses.EDIT_COLLAPSIBLE);

        var toggle_button = new Gtk.Button ();
        toggle_button.set_has_frame (false);
        toggle_button.set_halign (Gtk.Align.FILL);
        toggle_button.set_hexpand (true);
        toggle_button.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE);

        var toggle_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        toggle_row.set_halign (Gtk.Align.FILL);
        toggle_row.set_hexpand (true);
        toggle_row.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_ROW);

        var toggle_icon = new Gtk.Image ();
        MainWindowIconResources.set_expand_indicator_icon (toggle_icon, false);
        toggle_icon.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_ICON);
        toggle_row.append (toggle_icon);

        var toggle_label = new Gtk.Label (title);
        toggle_label.set_xalign (0.0f);
        toggle_label.set_hexpand (true);
        toggle_label.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_LABEL);
        toggle_row.append (toggle_label);

        toggle_button.set_child (toggle_row);
        container.append (toggle_button);

        content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        content_box.add_css_class (MainWindowCssClasses.EDIT_SECTION_CONTENT);

        var content_revealer = new Gtk.Revealer ();
        content_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        content_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_MS);
        content_revealer.set_child (content_box);
        content_revealer.add_css_class (MainWindowCssClasses.EDIT_SECTION_REVEALER);
        container.append (content_revealer);

        set_collapsible_state (container, toggle_button, content_revealer, toggle_icon, expanded);

        toggle_button.clicked.connect (() => {
            bool current_expanded = !content_revealer.get_reveal_child ();
            set_collapsible_state (container, toggle_button, content_revealer, toggle_icon, current_expanded);
        });

        return container;
    }

    public MainWindowWifiSavedEditPage (IWindowHost window_host) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: MainWindowUiMetrics.SPACING_ROW);

        this.add_css_class (MainWindowCssClasses.PAGE);
        this.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        MainWindowCssClassResolver.add_best_class (this, {MainWindowCssClasses.PAGE_SHELL_INSET,
            MainWindowCssClasses.PAGE});
        MainWindowCssClassResolver.add_hook_and_best_class (
            this,
            MainWindowCssClasses.PAGE_WIFI_EDIT,
            {MainWindowCssClasses.PAGE_NETWORK_EDIT, MainWindowCssClasses.PAGE}
        );

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        var back_btn = MainWindowHelpers.build_back_button ();
        back_btn.clicked.connect (() => {
            this.back ();
        });
        header.append (back_btn);

        this.title_label = new Gtk.Label (_("Edit Saved Profile"));
        this.title_label.set_xalign (0.0f);
        this.title_label.set_hexpand (true);
        this.title_label.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        header.append (this.title_label);
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

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);
        scroll.set_vexpand (true);

        var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_SECTION);
        MainWindowCssClassResolver.add_best_class (form, {MainWindowCssClasses.EDIT_NETWORK_FORM,
            MainWindowCssClasses.EDIT_FORM});
        form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

        Gtk.Box profile_content;
        var profile_section = build_section (_("Profile"), out profile_content);

        var profile_name_label = new Gtk.Label (_("Profile Name"));
        profile_name_label.set_xalign (0.0f);
        profile_name_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        profile_content.append (profile_name_label);

        this.profile_name_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.profile_name_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        profile_content.append (this.profile_name_entry);

        var ssid_label = new Gtk.Label (_("SSID"));
        ssid_label.set_xalign (0.0f);
        ssid_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        profile_content.append (ssid_label);

        this.ssid_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.ssid_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        profile_content.append (this.ssid_entry);

        var bssid_label = new Gtk.Label (_("BSSID"));
        bssid_label.set_xalign (0.0f);
        bssid_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        profile_content.append (bssid_label);

        this.bssid_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.bssid_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        profile_content.append (this.bssid_entry);

        var security_label = new Gtk.Label (_("Security Mode"));
        security_label.set_xalign (0.0f);
        security_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        profile_content.append (security_label);

        var security_modes = new Gtk.StringList (null);
        security_modes.append (_("Open"));
        security_modes.append (_("WPA/WPA2 Personal (PSK)"));
        security_modes.append (_("WPA3 Personal (SAE)"));
        security_modes.append (_("Enhanced Open (OWE)"));
        security_modes.append (_("WEP"));
        security_modes.append (_("WPA/WPA2 Enterprise (802.1X)"));
        this.security_mode_dropdown = window_host.create_tracked_dropdown (security_modes);
        MainWindowCssClassResolver.add_best_class (
            this.security_mode_dropdown,
            {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        profile_content.append (this.security_mode_dropdown);

        this.identity_label = new Gtk.Label (_("Username"));
        this.identity_label.set_xalign (0.0f);
        this.identity_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.identity_label.set_visible (false);

        this.identity_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.identity_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        this.identity_entry.set_visible (false);

        this.anonymous_identity_label = new Gtk.Label (_("Anonymous identity"));
        this.anonymous_identity_label.set_xalign (0.0f);
        this.anonymous_identity_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.anonymous_identity_label.set_visible (false);

        this.anonymous_identity_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.anonymous_identity_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        this.anonymous_identity_entry.set_visible (false);

        this.domain_label = new Gtk.Label (_("Domain"));
        this.domain_label.set_xalign (0.0f);
        this.domain_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.domain_label.set_visible (false);

        this.domain_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.domain_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        this.domain_entry.set_visible (false);

        this.ca_cert_label = new Gtk.Label (_("CA cert"));
        this.ca_cert_label.set_xalign (0.0f);
        this.ca_cert_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.ca_cert_label.set_visible (false);

        this.ca_cert_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.ca_cert_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        this.ca_cert_entry.set_visible (false);

        this.ca_cert_password_label = new Gtk.Label (_("CA cert password"));
        this.ca_cert_password_label.set_xalign (0.0f);
        this.ca_cert_password_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.ca_cert_password_label.set_visible (false);

        this.ca_cert_password_entry = new Gtk.Entry ();
        this.ca_cert_password_entry.set_visibility (false);
        this.ca_cert_password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        MainWindowCssClassResolver.add_best_class (
            this.ca_cert_password_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL,
                MainWindowCssClasses.PASSWORD_ENTRY}
        );
        this.ca_cert_password_entry.set_visible (false);

        this.user_cert_label = new Gtk.Label (_("User cert"));
        this.user_cert_label.set_xalign (0.0f);
        this.user_cert_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.user_cert_label.set_visible (false);

        this.user_cert_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.user_cert_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        this.user_cert_entry.set_visible (false);

        this.user_cert_password_label = new Gtk.Label (_("User cert password"));
        this.user_cert_password_label.set_xalign (0.0f);
        this.user_cert_password_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.user_cert_password_label.set_visible (false);

        this.user_cert_password_entry = new Gtk.Entry ();
        this.user_cert_password_entry.set_visibility (false);
        this.user_cert_password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        MainWindowCssClassResolver.add_best_class (
            this.user_cert_password_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL,
                MainWindowCssClasses.PASSWORD_ENTRY}
        );
        this.user_cert_password_entry.set_visible (false);

        this.user_private_key_label = new Gtk.Label (_("User private key"));
        this.user_private_key_label.set_xalign (0.0f);
        this.user_private_key_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.user_private_key_label.set_visible (false);

        this.user_private_key_entry = new Gtk.Entry ();
        MainWindowCssClassResolver.add_best_class (
            this.user_private_key_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        this.user_private_key_entry.set_visible (false);

        this.user_private_key_password_label = new Gtk.Label (_("User privkey password"));
        this.user_private_key_password_label.set_xalign (0.0f);
        this.user_private_key_password_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.user_private_key_password_label.set_visible (false);

        this.user_private_key_password_entry = new Gtk.Entry ();
        this.user_private_key_password_entry.set_visibility (false);
        this.user_private_key_password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        MainWindowCssClassResolver.add_best_class (
            this.user_private_key_password_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL,
                MainWindowCssClasses.PASSWORD_ENTRY}
        );
        this.user_private_key_password_entry.set_visible (false);

        this.eap_method_label = new Gtk.Label (_("Method"));
        this.eap_method_label.set_xalign (0.0f);
        this.eap_method_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.eap_method_label.set_visible (false);

        var eap_methods = new Gtk.StringList (null);
        eap_methods.append (_("PEAP"));
        eap_methods.append (_("TLS"));
        eap_methods.append (_("TTLS"));
        eap_methods.append (_("PWD"));
        this.eap_method_dropdown = window_host.create_tracked_dropdown (eap_methods);
        MainWindowCssClassResolver.add_best_class (
            this.eap_method_dropdown,
            {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        this.eap_method_dropdown.set_visible (false);

        this.phase2_auth_label = new Gtk.Label (_("Inner authentication"));
        this.phase2_auth_label.set_xalign (0.0f);
        this.phase2_auth_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        this.phase2_auth_label.set_visible (false);

        var phase2_auths = new Gtk.StringList (null);
        phase2_auths.append (_("MSCHAPv2"));
        phase2_auths.append (_("MD5"));
        phase2_auths.append (_("GTC"));
        phase2_auths.append (_("PAP"));
        phase2_auths.append (_("CHAP"));
        this.phase2_auth_dropdown = window_host.create_tracked_dropdown (phase2_auths);
        MainWindowCssClassResolver.add_best_class (
            this.phase2_auth_dropdown,
            {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL}
        );
        this.phase2_auth_dropdown.set_visible (false);

        this.security_mode_dropdown.notify_selected.connect (() => {
            this.sync_eap_field_visibilities ();
        });

        this.eap_method_dropdown.notify_selected.connect (() => {
            this.sync_eap_field_visibilities ();
        });

        form.append (profile_section);

        Gtk.Box access_content;
        var access_section = build_section (_("Access"), out access_content);

        this.autoconnect_check = new Gtk.CheckButton.with_label (_("Connect automatically"));
        this.autoconnect_check.add_css_class (MainWindowCssClasses.ROW_AUTOCONNECT_CHECK);
        access_content.append (this.autoconnect_check);

        this.all_users_check = new Gtk.CheckButton.with_label (_("Available to all users"));
        this.all_users_check.add_css_class (MainWindowCssClasses.ROW_AUTOCONNECT_CHECK);
        access_content.append (this.all_users_check);

        form.append (access_section);

        Gtk.Box auth_content;
        var auth_section = build_collapsible_section (_("Authentication"), out auth_content, false);

        auth_content.append (this.eap_method_label);
        auth_content.append (this.eap_method_dropdown);
        auth_content.append (this.phase2_auth_label);
        auth_content.append (this.phase2_auth_dropdown);
        auth_content.append (this.anonymous_identity_label);
        auth_content.append (this.anonymous_identity_entry);
        auth_content.append (this.domain_label);
        auth_content.append (this.domain_entry);
        auth_content.append (this.ca_cert_label);
        auth_content.append (this.ca_cert_entry);
        auth_content.append (this.ca_cert_password_label);
        auth_content.append (this.ca_cert_password_entry);
        auth_content.append (this.user_cert_label);
        auth_content.append (this.user_cert_entry);
        auth_content.append (this.user_cert_password_label);
        auth_content.append (this.user_cert_password_entry);
        auth_content.append (this.user_private_key_label);
        auth_content.append (this.user_private_key_entry);
        auth_content.append (this.user_private_key_password_label);
        auth_content.append (this.user_private_key_password_entry);
        auth_content.append (this.identity_label);
        auth_content.append (this.identity_entry);

        this.password_label = new Gtk.Label (_("Password"));
        this.password_label.set_xalign (0.0f);
        this.password_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        auth_content.append (this.password_label);

        this.password_entry = new Gtk.Entry ();
        this.password_entry.set_visibility (false);
        this.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        MainWindowCssClassResolver.add_best_class (
            this.password_entry,
            {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL,
                MainWindowCssClasses.PASSWORD_ENTRY}
        );
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
        auth_content.append (this.password_entry);

        form.append (auth_section);

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
            window_host.create_tracked_dropdown,
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
            window_host.create_tracked_dropdown,
            true
        );

        this.ipv6_method_dropdown = v6_method;
        this.ipv6_address_entry = v6_address;
        this.ipv6_prefix_entry = v6_prefix;
        this.ipv6_gateway_entry = v6_gw;
        this.ipv6_dns_auto_switch = v6_dns_auto;
        this.ipv6_dns_entry = v6_dns;

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        actions.add_css_class (MainWindowCssClasses.EDIT_ACTIONS);

        var save_btn = new Gtk.Button.with_label (_("Save"));
        save_btn.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_best_class (save_btn, {MainWindowCssClasses.SUGGESTED_ACTION,
            MainWindowCssClasses.BUTTON});
        save_btn.clicked.connect (() => {
            this.save ();
        });
        actions.append (save_btn);

        form.append (actions);

        scroll.set_child (form);
        this.append (scroll);
    }
}
