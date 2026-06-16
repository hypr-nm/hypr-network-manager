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
using GLib;
using Gtk;
using HyprNetworkManager.Models;
using HyprNetworkManager.UI.Interfaces;
using HyprNetworkManager.UI.Widgets;

namespace HyprNetworkManager.UI.Views {
    public class HotspotSectionView : Object {
        public Gtk.Widget widget { get; private set; }
        
        private NetworkManagerClient nm;
        private IWindowHost window_host;

        private Gtk.Switch toggle_switch;
        private Gtk.Entry ssid_entry;
        private Gtk.Entry password_entry;
        private HyprNetworkManager.UI.Widgets.TrackedDropDown security_dropdown;
        private HyprNetworkManager.UI.Widgets.TrackedDropDown band_dropdown;
        private HyprNetworkManager.UI.Widgets.TrackedDropDown timeout_dropdown;
        private Gtk.CheckButton hidden_check;
        private Gtk.Button save_button;
        
        private bool is_updating = false;

        public HotspotSectionView (NetworkManagerClient client, IWindowHost host) {
            this.nm = client;
            this.window_host = host;

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_ROW);
            box.add_css_class (MainWindowCssClasses.PAGE);
            
            // Header
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            header_box.add_css_class (MainWindowCssClasses.TOOLBAR_INSET);
            header_box.add_css_class (MainWindowCssClasses.TOOLBAR);
            
            var title_label = new Gtk.Label ("Wi-Fi Hotspot");
            title_label.halign = Gtk.Align.START;
            title_label.add_css_class (MainWindowCssClasses.SECTION_TITLE);
            
            toggle_switch = new Gtk.Switch ();
            toggle_switch.valign = Gtk.Align.CENTER;
            toggle_switch.add_css_class (MainWindowCssClasses.SWITCH);
            
            header_box.append (title_label);
            title_label.hexpand = true;
            header_box.append (toggle_switch);
            box.append (header_box);
            
            // Content Form
            var form_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
            MainWindowCssClassResolver.add_best_class (form_box, {MainWindowCssClasses.EDIT_NETWORK_FORM, MainWindowCssClasses.EDIT_FORM});
            form_box.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);
            
            // --- ROW 1 ---
            var row1_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_SECTION);
            row1_box.homogeneous = true;
            row1_box.hexpand = true;
            
            // SSID col
            var ssid_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            var ssid_label = new Gtk.Label (_("Network Name (SSID)"));
            MainWindowCssClassResolver.add_best_class (ssid_label, {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL});
            ssid_label.xalign = 0;
            ssid_entry = new Gtk.Entry ();
            ssid_entry.hexpand = true;
            MainWindowCssClassResolver.add_hook_and_best_class (
                ssid_entry,
                MainWindowCssClasses.EDIT_FIELD_ENTRY,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
            ssid_col.append (ssid_label);
            ssid_col.append (ssid_entry);
            
            // Hidden col
            var hidden_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            
            hidden_check = new Gtk.CheckButton.with_label (_("Hidden Network"));
            MainWindowCssClassResolver.add_best_class (hidden_check, {MainWindowCssClasses.FORM_LABEL});
            hidden_check.valign = Gtk.Align.CENTER;
            hidden_check.vexpand = false;
            
            hidden_col.append (hidden_check);
            ssid_col.append (hidden_col);
            
            row1_box.append (ssid_col);
            
            // Password col
            var password_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            password_col.valign = Gtk.Align.START;
            var password_label = new Gtk.Label (_("Password"));
            MainWindowCssClassResolver.add_best_class (password_label, {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL});
            password_label.xalign = 0;
            password_entry = new Gtk.Entry ();
            password_entry.hexpand = true;
            MainWindowCssClassResolver.add_hook_and_best_class (
                password_entry,
                MainWindowCssClasses.EDIT_PASSWORD_ENTRY,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL, MainWindowCssClasses.PASSWORD_ENTRY}
            );
            password_entry.visibility = false;
            password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
            password_entry.set_placeholder_text (_("Min %d chars").printf (8));
            password_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
            password_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
            MainWindowHelpers.sync_password_visibility_icon (password_entry);
            
            password_entry.icon_press.connect ((pos) => {
                if (pos == Gtk.EntryIconPosition.SECONDARY) {
                    password_entry.visibility = !password_entry.visibility;
                    MainWindowHelpers.sync_password_visibility_icon (password_entry);
                }
            });

            password_col.append (password_label);
            password_col.append (password_entry);
            
            row1_box.append (password_col);
            form_box.append (row1_box);
            
            // --- ROW 2 ---
            var row2_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_SECTION);
            row2_box.homogeneous = true;
            row2_box.hexpand = true;
            
            // Security Mode col
            var security_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            var security_label = new Gtk.Label (_("Security"));
            MainWindowCssClassResolver.add_best_class (security_label, {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL});
            security_label.xalign = 0;
            
            var sec_model = new Gtk.StringList (new string[] {
                _("WPA3 Personal"),
                _("WPA2/WPA3 Personal"),
                _("Open")
            });
            security_dropdown = window_host.create_tracked_dropdown (sec_model);
            security_dropdown.hexpand = true;
            MainWindowCssClassResolver.add_best_class (security_dropdown, {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL});
            security_col.append (security_label);
            security_col.append (security_dropdown);
            
            row2_box.append (security_col);
            
            // Band col
            var band_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            var band_label = new Gtk.Label (_("Band"));
            MainWindowCssClassResolver.add_best_class (band_label, {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL});
            band_label.xalign = 0;
            
            var band_model = new Gtk.StringList (new string[] {
                _("Auto"),
                _("2.4 GHz"),
                _("5 GHz")
            });
            band_dropdown = window_host.create_tracked_dropdown (band_model);
            band_dropdown.hexpand = true;
            MainWindowCssClassResolver.add_best_class (band_dropdown, {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL});
            band_col.append (band_label);
            band_col.append (band_dropdown);
            
            row2_box.append (band_col);
            form_box.append (row2_box);
            
            // --- ROW 3 ---
            var row3_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_SECTION);
            row3_box.homogeneous = true;
            row3_box.hexpand = true;
            
            // Timeout col
            var timeout_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            var timeout_label = new Gtk.Label (_("Turn off if inactive for"));
            MainWindowCssClassResolver.add_best_class (timeout_label, {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL});
            timeout_label.xalign = 0;
            
            var timeout_model = new Gtk.StringList (new string[] {
                _("Never"),
                _("5 minutes"),
                _("10 minutes"),
                _("30 minutes"),
                _("1 hour")
            });
            timeout_dropdown = window_host.create_tracked_dropdown (timeout_model);
            timeout_dropdown.hexpand = true;
            MainWindowCssClassResolver.add_best_class (timeout_dropdown, {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL});
            timeout_col.append (timeout_label);
            timeout_col.append (timeout_dropdown);
            
            row3_box.append (timeout_col);
            
            // Spacer to keep layout homogeneous
            var spacer_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            row3_box.append (spacer_col);
            
            form_box.append (row3_box);
            
            // Save Button
            var action_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            MainWindowCssClassResolver.add_hook_and_best_class (action_box, MainWindowCssClasses.EDIT_WIFI_ACTIONS,
                {MainWindowCssClasses.EDIT_ACTIONS});
                
            save_button = new Gtk.Button.with_label (_("Save Configuration"));
            save_button.add_css_class (MainWindowCssClasses.BUTTON);
            MainWindowCssClassResolver.add_hook_and_best_class (save_button, MainWindowCssClasses.EDIT_APPLY_BUTTON,
                {MainWindowCssClasses.SUGGESTED_ACTION, MainWindowCssClasses.BUTTON});
            save_button.halign = Gtk.Align.END;
            action_box.append (save_button);
            form_box.append (action_box);
            
            box.append (form_box);
            
            this.widget = box;
            
            setup_signals ();
            perform_refresh ();
        }

        private void setup_signals () {
            save_button.clicked.connect (() => {
                save_configuration.begin ((obj, res) => {
                    save_configuration.end (res);
                });
            });

            toggle_switch.notify["active"].connect (on_toggle_switch_changed);

            ssid_entry.changed.connect (validate_inputs);
            password_entry.changed.connect (validate_inputs);
            security_dropdown.notify_selected.connect (() => {
                bool is_open = security_dropdown.get_selected () == 2;
                password_entry.set_sensitive (!is_open && !toggle_switch.active);
                validate_inputs ();
            });
            band_dropdown.notify_selected.connect (validate_inputs);
            hidden_check.toggled.connect (validate_inputs);
            timeout_dropdown.notify_selected.connect (validate_inputs);
        }

        private void validate_inputs () {
            if (toggle_switch.active) {
                return;
            }

            string ssid = ssid_entry.get_text ().strip ();
            string pass = password_entry.get_text ();
            bool is_open = security_dropdown.get_selected () == 2;

            bool is_valid = ssid != "";
            if (!is_open && pass.length < 8) {
                is_valid = false;
            }

            save_button.sensitive = is_valid;
        }

        private void on_toggle_switch_changed () {
            if (is_updating) return;

            update_sensitivity (toggle_switch.active);

            if (toggle_switch.active) {
                enable_hotspot.begin ((obj, res) => {
                    enable_hotspot.end (res);
                });
            } else {
                disable_hotspot.begin ((obj, res) => {
                    disable_hotspot.end (res);
                });
            }
        }

        private void update_sensitivity (bool is_active) {
            ssid_entry.sensitive = !is_active;
            
            bool is_open = security_dropdown.get_selected () == 2;
            password_entry.sensitive = !is_active && !is_open;
            
            security_dropdown.sensitive = !is_active;
            band_dropdown.sensitive = !is_active;
            hidden_check.sensitive = !is_active;
            timeout_dropdown.sensitive = !is_active;
            
            if (is_active) {
                save_button.sensitive = false;
            } else {
                validate_inputs ();
            }
        }

        private async void save_configuration () {
            save_button.sensitive = false;
            string ssid = ssid_entry.get_text ().strip ();
            string pass = password_entry.get_text ();
            
            uint sec_index = security_dropdown.get_selected ();
            string security = "wpa-psk";
            if (sec_index == 0) security = "sae";
            else if (sec_index == 2) security = "none";
            
            uint band_index = band_dropdown.get_selected ();
            string band = "";
            if (band_index == 1) band = "bg";
            else if (band_index == 2) band = "a";
            
            bool is_hidden = hidden_check.active;
            
            uint timeout_index = timeout_dropdown.get_selected ();
            int timeout = 0;
            if (timeout_index == 1) timeout = 5;
            else if (timeout_index == 2) timeout = 10;
            else if (timeout_index == 3) timeout = 30;
            else if (timeout_index == 4) timeout = 60;
            
            if (ssid == "") {
                validate_inputs ();
                return;
            }
            if (security != "none" && pass.length < 8) {
                warning ("Password must be at least 8 characters");
                validate_inputs ();
                return;
            }
            
            try {
                yield nm.create_or_update_hotspot (ssid, pass, security, band, is_hidden, timeout);
                
                // After successful save, we don't need to refresh the entries
                // since they already contain the typed configuration.
                // We just refresh the toggle status in case anything else changed.
                var config = yield nm.get_hotspot_status ();
                is_updating = true;
                toggle_switch.active = config.is_active;
                is_updating = false;
                update_sensitivity (config.is_active);
            } catch (Error e) {
                warning ("Failed to save hotspot configuration: " + e.message);
                perform_refresh (); // Only refresh if it failed to revert to actual state
                validate_inputs ();
            }
        }
        
        private async void enable_hotspot () {
            toggle_switch.sensitive = false;
            try {
                // auto save if there are changes
                string ssid = ssid_entry.get_text ().strip ();
                string pass = password_entry.get_text ();
                
                uint sec_index = security_dropdown.get_selected ();
                string security = "wpa-psk";
                if (sec_index == 0) security = "sae";
                else if (sec_index == 2) security = "none";
                
                uint band_index = band_dropdown.get_selected ();
                string band = "";
                if (band_index == 1) band = "bg";
                else if (band_index == 2) band = "a";
                
                bool is_hidden = hidden_check.active;
                
                uint timeout_index = timeout_dropdown.get_selected ();
                int timeout = 0;
                if (timeout_index == 1) timeout = 5;
                else if (timeout_index == 2) timeout = 10;
                else if (timeout_index == 3) timeout = 30;
                else if (timeout_index == 4) timeout = 60;
                
                if (ssid == "") {
                    throw new IOError.INVALID_ARGUMENT("SSID cannot be empty");
                }
                if (security != "none" && pass.length < 8) {
                    throw new IOError.INVALID_ARGUMENT("Password must be at least 8 characters");
                }

                yield nm.enable_hotspot_async (ssid, pass, security, band, is_hidden, timeout);
            } catch (Error e) {
                warning ("Failed to enable hotspot: " + e.message);
                
                is_updating = true;
                toggle_switch.active = false;
                is_updating = false;
            }
            toggle_switch.sensitive = true;
            perform_refresh ();
        }
        
        private async void disable_hotspot () {
            toggle_switch.sensitive = false;
            try {
                yield nm.disable_hotspot_async ();
            } catch (Error e) {
                warning ("Failed to disable hotspot: " + e.message);
                
                is_updating = true;
                toggle_switch.active = true;
                is_updating = false;
            }
            toggle_switch.sensitive = true;
            perform_refresh ();
        }

        public void perform_refresh () {
            fetch_status.begin ((obj, res) => {
                fetch_status.end (res);
            });
        }

        private async void fetch_status () {
            try {
                var config = yield nm.get_hotspot_status ();
                
                if (config.ssid != "") {
                    ssid_entry.set_text (config.ssid);
                }
                if (config.password != "") {
                    password_entry.set_text (config.password);
                }
                
                if (config.security == "sae") {
                    security_dropdown.set_selected (0);
                } else if (config.security == "none") {
                    security_dropdown.set_selected (2);
                } else {
                    security_dropdown.set_selected (1);
                }
                
                if (config.band == "bg") {
                    band_dropdown.set_selected (1);
                } else if (config.band == "a") {
                    band_dropdown.set_selected (2);
                } else {
                    band_dropdown.set_selected (0);
                }
                
                hidden_check.active = config.is_hidden;
                
                if (config.timeout == 5) {
                    timeout_dropdown.set_selected (1);
                } else if (config.timeout == 10) {
                    timeout_dropdown.set_selected (2);
                } else if (config.timeout == 30) {
                    timeout_dropdown.set_selected (3);
                } else if (config.timeout == 60) {
                    timeout_dropdown.set_selected (4);
                } else {
                    timeout_dropdown.set_selected (0);
                }
                
                // Make sure to disable unsupported bands (though TrackedDropDown might not support disabling individual rows,
                // we'll just let the model handle it if it does, otherwise the user could select an unsupported band which would fail gracefully).
                // But let's at least keep the model intact.

                is_updating = true;
                toggle_switch.active = config.is_active;
                is_updating = false;

                update_sensitivity (config.is_active);
            } catch (Error e) {
                warning ("Failed to fetch hotspot status: " + e.message);
            }
        }
    }
}
