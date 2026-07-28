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
using Constants;
using GLib;
using Gtk;
using HyprNetworkManager.Models;
using HyprNetworkManager.UI.Interfaces;
using HyprNetworkManager.UI.Widgets;

namespace HyprNetworkManager.UI.Views {
    public class HotspotSectionView : Object {
        public signal void back ();

        public Gtk.Widget widget { get; private set; }
        
        private MainWindowHotspotController controller;
        private IWindowHost window_host;

        private Gtk.Switch toggle_switch;
        private Gtk.Entry ssid_entry;
        private Gtk.Entry password_entry;
        private HyprNetworkManager.UI.Widgets.TrackedDropDown security_dropdown;
        private HyprNetworkManager.UI.Widgets.TrackedDropDown band_dropdown;
        private HyprNetworkManager.UI.Widgets.TrackedDropDown timeout_dropdown;
        private HyprNetworkManager.UI.Widgets.TrackedDropDown ap_interface_dropdown;
        private HyprNetworkManager.UI.Widgets.TrackedDropDown uplink_interface_dropdown;
        private Gtk.StringList ap_model;
        private Gtk.StringList uplink_model;
        private Gtk.StringList band_model;
        private Gtk.CheckButton hidden_check;
        private Gtk.Button save_button;
        private Gtk.Box qr_container;
        private Gtk.Revealer qr_revealer;
        private Gtk.ScrolledWindow scroll;
        
        private bool is_updating = false;
        private bool is_dirty = false;
        private uint scroll_tick_id = 0;
        private uint poll_source_id = 0;
        private uint band_query_generation = 0;

        public HotspotSectionView (MainWindowHotspotController controller, IWindowHost host) {
            this.controller = controller;
            this.window_host = host;

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_ROW);
            box.add_css_class (MainWindowCssClasses.PAGE);
            box.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
            MainWindowCssClassResolver.add_best_class (box, {MainWindowCssClasses.PAGE_NETWORK_DETAILS,
                MainWindowCssClasses.PAGE_SHELL_INSET, MainWindowCssClasses.PAGE});
            
            // Header
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            header_box.add_css_class (MainWindowCssClasses.DETAILS_NAV_ROW);
            
            var back_btn = MainWindowHelpers.build_back_button ();
            back_btn.clicked.connect (() => {
                this.back ();
            });
            header_box.append (back_btn);
            
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
            
            // --- ROW 0 (Interfaces) ---
            var row0_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_SECTION);
            row0_box.homogeneous = true;
            row0_box.hexpand = true;
            
            // AP Interface col
            var ap_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            var ap_label = new Gtk.Label (_("Wi-Fi Interface"));
            MainWindowCssClassResolver.add_best_class (ap_label, {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL});
            ap_label.xalign = 0;
            
            this.ap_model = new Gtk.StringList (new string[] { _("Auto") });
            foreach (var iface in controller.get_wifi_interfaces ()) {
                this.ap_model.append (iface);
            }
            ap_interface_dropdown = window_host.create_tracked_dropdown (this.ap_model);
            ap_interface_dropdown.hexpand = true;
            MainWindowCssClassResolver.add_best_class (ap_interface_dropdown, {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL});
            ap_col.append (ap_label);
            ap_col.append (ap_interface_dropdown);
            
            row0_box.append (ap_col);

            // Timeout col
            var timeout_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            var timeout_label = new Gtk.Label (_("Turn off if inactive for"));
            MainWindowCssClassResolver.add_best_class (timeout_label, {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL});
            timeout_label.xalign = 0;
            
            var timeout_model = new Gtk.StringList (new string[] {
                _("Never"),
                _("%d minutes").printf (5),
                _("%d minutes").printf (10),
                _("%d minutes").printf (30),
                _("%d hour").printf (1)
            });
            timeout_dropdown = window_host.create_tracked_dropdown (timeout_model);
            timeout_dropdown.hexpand = true;
            MainWindowCssClassResolver.add_best_class (timeout_dropdown, {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL});
            timeout_col.append (timeout_label);
            timeout_col.append (timeout_dropdown);

            if (controller.has_create_ap ()) {
                // Uplink Interface col
                var uplink_col = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
                var uplink_label = new Gtk.Label (_("Share Internet From"));
                MainWindowCssClassResolver.add_best_class (uplink_label, {MainWindowCssClasses.EDIT_FIELD_LABEL, MainWindowCssClasses.FORM_LABEL});
                uplink_label.xalign = 0;

                this.uplink_model = new Gtk.StringList (new string[] { _("Auto"), _("None") });
                foreach (var iface in controller.get_all_interfaces ()) {
                    this.uplink_model.append (iface);
                }
                uplink_interface_dropdown = window_host.create_tracked_dropdown (this.uplink_model);
                uplink_interface_dropdown.hexpand = true;
                MainWindowCssClassResolver.add_best_class (uplink_interface_dropdown, {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL});
                uplink_col.append (uplink_label);
                uplink_col.append (uplink_interface_dropdown);
                row0_box.append (uplink_col);
            } else {
                row0_box.append (timeout_col);
            }
            
            form_box.append (row0_box);
            
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
            
            this.band_model = new Gtk.StringList (new string[] { _("Auto") });
            band_dropdown = window_host.create_tracked_dropdown (this.band_model);
            rebuild_band_options (get_ap_interface_token ());
            band_dropdown.hexpand = true;
            MainWindowCssClassResolver.add_best_class (band_dropdown, {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL});
            band_col.append (band_label);
            band_col.append (band_dropdown);
            
            row2_box.append (band_col);
            form_box.append (row2_box);
            
            if (controller.has_create_ap ()) {
                // --- ROW 3 ---
                var row3_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_SECTION);
                row3_box.homogeneous = true;
                row3_box.hexpand = true;
                
                row3_box.append (timeout_col);
                
                var placeholder = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                row3_box.append (placeholder);
                
                form_box.append (row3_box);
            }
            
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
            
            this.scroll = new Gtk.ScrolledWindow ();
            this.scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            this.scroll.add_css_class (MainWindowCssClasses.SCROLL);
            this.scroll.set_vexpand (true);

            var scroll_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            scroll_content.append (form_box);
            
            // QR Code section
            qr_revealer = new Gtk.Revealer ();
            qr_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
            qr_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_MS);
            
            qr_container = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
            qr_container.halign = Gtk.Align.CENTER;
            qr_container.margin_top = 20;
            qr_revealer.set_child (qr_container);
            
            scroll_content.append (qr_revealer);
            this.scroll.set_child (scroll_content);
            
            box.append (this.scroll);
            
            this.widget = box;
            
            setup_signals ();
            perform_refresh ();
        }

        private void update_qr_code (HotspotConfig config) {
            // Clear existing
            var child = qr_container.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                qr_container.remove (child);
                child = next;
            }
            
            if ((!config.is_active && !config.is_starting)
                || config.ssid == "") {
                qr_revealer.set_reveal_child (false);
                return;
            }

            string qr_text;
            if (config.is_starting) {
                // Placeholder grid so the animation can render before the
                // hotspot is verified, without exposing real credentials.
                qr_text = WifiQrBuilder.starting_placeholder ();
            } else {
                bool is_open = config.security == WifiKeyMgmt.NONE;
                qr_text = WifiQrBuilder.build (config.ssid, config.password, !is_open, config.is_hidden);
            }

            var qr_widget = new HyprNetworkManager.UI.Widgets.QrCodeWidget (qr_text);
            qr_widget.set_size_request (MainWindowUiMetrics.QR_CODE_SIZE, MainWindowUiMetrics.QR_CODE_SIZE);
            qr_widget.halign = Gtk.Align.CENTER;
            qr_widget.valign = Gtk.Align.CENTER;
            qr_widget.is_loading = config.is_starting;

            var qr_code_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            qr_code_box.halign = Gtk.Align.CENTER;
            qr_code_box.valign = Gtk.Align.CENTER;
            qr_code_box.add_css_class ("nm-qr-share-code-box");
            qr_code_box.margin_bottom = 4;
            qr_code_box.append (qr_widget);
            
            qr_container.append (qr_code_box);
            
            if (!config.is_starting) {
                var pass_text = config.password != "" ? config.password : _("None");

                var info_label = new Gtk.Label ("");
                info_label.set_markup ("<b>" + GLib.Markup.escape_text(config.ssid) + "</b> • " + _("Password") + ": " + GLib.Markup.escape_text(pass_text));
                info_label.selectable = true;
                info_label.wrap = true;
                info_label.wrap_mode = Pango.WrapMode.CHAR;
                info_label.max_width_chars = 35;
                info_label.justify = Gtk.Justification.CENTER;
                MainWindowCssClassResolver.add_best_class (info_label, {MainWindowCssClasses.FORM_LABEL});

                qr_container.append (info_label);
                
                string connected_text = _("Connected Users: %d").printf (config.connected_clients);
                var connected_label = new Gtk.Label (connected_text);
                MainWindowCssClassResolver.add_best_class (connected_label, {MainWindowCssClasses.SUB_LABEL});
                qr_container.append (connected_label);
            }
            
            bool was_revealed = qr_revealer.get_reveal_child ();
            qr_revealer.set_reveal_child (true);
            
            if (!was_revealed) {
                smooth_scroll_to_bottom ();
            }
        }

        private void smooth_scroll_to_bottom () {
            if (scroll_tick_id != 0) {
                this.scroll.remove_tick_callback (scroll_tick_id);
                scroll_tick_id = 0;
            }
            
            var adj = this.scroll.get_vadjustment ();
            
            scroll_tick_id = this.scroll.add_tick_callback ((w, clock) => {
                double target = adj.upper - adj.page_size;
                if (target < 0) target = 0;
                
                double current = adj.value;
                
                bool is_revealing = qr_revealer.child_revealed != qr_revealer.reveal_child;
                
                if (!is_revealing && GLib.Math.fabs (target - current) < 1.0) {
                    adj.set_value (target);
                    scroll_tick_id = 0;
                    return false;
                }
                
                double new_val = current + (target - current) * 0.15;
                if (!is_revealing && GLib.Math.fabs (target - new_val) < 0.5) {
                    new_val = target;
                }
                
                adj.set_value (new_val);
                return true;
            });
        }

        private void setup_signals () {
            this.widget.map.connect (() => {
                if (poll_source_id == 0) {
                    poll_source_id = GLib.Timeout.add_seconds (3, () => {
                        perform_refresh ();
                        return true;
                    });
                }
            });

            this.widget.unmap.connect (() => {
                if (poll_source_id != 0) {
                    GLib.Source.remove (poll_source_id);
                    poll_source_id = 0;
                }
            });

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
            if (ap_interface_dropdown != null) {
                ap_interface_dropdown.notify_selected.connect (validate_inputs);
                ap_interface_dropdown.notify_selected.connect (() => {
                    string tok = get_ap_interface_token ();
                    log_debug ("hotspot-ui",
                        "ap_interface notify_selected: token='%s' -> rebuilding band".printf (tok));
                    rebuild_band_options (tok);
                });
            }
            if (uplink_interface_dropdown != null) uplink_interface_dropdown.notify_selected.connect (validate_inputs);
        }

        // Map the selected AP-interface dropdown row to a locale-independent
        // token ("Auto" for the synthetic first row, otherwise the raw kernel
        // interface name) so the backend never has to match translated labels.
        private string get_ap_interface_token () {
            if (ap_interface_dropdown == null || this.ap_model == null) {
                return "";
            }
            uint idx = ap_interface_dropdown.get_selected ();
            if (idx == Constants.DropdownIndex.AUTO) {
                return "Auto";
            }
            return this.ap_model.get_string (idx);
        }

        private void rebuild_band_options (string ap_iface) {
            if (this.band_model == null || band_dropdown == null) {
                return;
            }

            uint generation = ++band_query_generation;
            controller.get_band_support.begin (ap_iface, (obj, res) => {
                WifiBandSupport support;

                try {
                    support = controller.get_band_support.end (res);
                } catch (Error e) {
                    log_warn ("hotspot-ui",
                        "rebuild_band_options: band query failed: " + e.message);
                    return;
                }

                if (generation != band_query_generation ||
                    ap_iface != get_ap_interface_token ()) {
                    log_debug ("hotspot-ui",
                        "rebuild_band_options: ignoring stale result for '%s'".printf (ap_iface));
                    return;
                }

                apply_band_options (
                    support.supports_2ghz,
                    support.supports_5ghz);
            });
        }

        private void apply_band_options (bool supports_2ghz, bool supports_5ghz) {
            string previous_token = band_value_token ();
            bool was_updating = is_updating;
            is_updating = true;

            while (this.band_model.get_n_items () > 0) {
                this.band_model.remove (0);
            }
            this.band_model.append (_("Auto"));
            if (supports_2ghz) {
                this.band_model.append ("2.4 GHz");
            }
            if (supports_5ghz) {
                this.band_model.append ("5 GHz");
            }

            band_dropdown.set_selected (band_index_for_value (previous_token));
            is_updating = was_updating;
        }

        private string band_value_token () {
            if (band_dropdown == null || this.band_model == null) {
                return "";
            }
            uint idx = band_dropdown.get_selected ();
            if (idx >= this.band_model.get_n_items ()) {
                return "";
            }
            return token_to_band_value (this.band_model.get_string (idx));
        }

        private static string token_to_band_value (string label) {
            if (label == "2.4 GHz") {
                return WifiBand.BAND_2GHZ;
            }
            if (label == "5 GHz") {
                return WifiBand.BAND_5GHZ;
            }
            return "";
        }

        private uint band_index_for_value (string band_value) {
            if (this.band_model == null) {
                return 0;
            }
            for (uint i = 0; i < this.band_model.get_n_items (); i++) {
                if (token_to_band_value (this.band_model.get_string (i)) == band_value) {
                    return i;
                }
            }
            return 0;
        }

        // Map the selected uplink dropdown row to a locale-independent token
        // ("Auto" / "None" for the synthetic rows, otherwise the raw interface
        // name). Indices are fixed: 0 = Auto, 1 = None, 2+ = interfaces.
        private string get_uplink_token () {
            if (uplink_interface_dropdown == null || this.uplink_model == null) {
                return "";
            }
            uint idx = uplink_interface_dropdown.get_selected ();
            if (idx == Constants.DropdownIndex.AUTO) {
                return "Auto";
            }
            if (idx == Constants.DropdownIndex.NONE) {
                return "None";
            }
            return this.uplink_model.get_string (idx);
        }

        private HotspotRequest build_current_request () {
            return controller.build_request (
                ssid_entry.get_text ().strip (),
                password_entry.get_text (),
                security_dropdown.get_selected (),
                band_value_token (),
                hidden_check.active,
                timeout_dropdown.get_selected (),
                get_ap_interface_token (),
                get_uplink_token ());
        }

        private void validate_inputs () {
            if (is_updating) {
                return;
            }

            if (toggle_switch.active) {
                return;
            }

            is_dirty = true;

            save_button.sensitive = controller.is_valid (build_current_request ());
        }

        private void on_toggle_switch_changed () {
            if (is_updating) return;

            // Lock all inputs while the state is transitioning
            update_sensitivity (true);

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
            if (ap_interface_dropdown != null) ap_interface_dropdown.sensitive = !is_active;
            if (uplink_interface_dropdown != null) uplink_interface_dropdown.sensitive = !is_active;
            
            if (is_active) {
                save_button.sensitive = false;
            } else {
                validate_inputs ();
            }
        }

        private async void save_configuration () {
            save_button.sensitive = false;
            HotspotRequest req = build_current_request ();

            if (!controller.is_valid (req)) {
                window_host.show_error (controller.validation_message (req));
                validate_inputs ();
                return;
            }

            try {
                yield controller.save_configuration (req);

                var config = yield controller.get_status ();
                is_dirty = false;
                is_updating = true;
                toggle_switch.active = config.is_active;
                is_updating = false;
                update_sensitivity (config.is_active);
                update_qr_code (config);
            } catch (Error e) {
                window_host.show_error (_("Failed to save hotspot configuration: %s").printf (e.message));
                perform_refresh ();
                validate_inputs ();
            }
        }
        
        private async void enable_hotspot () {
            toggle_switch.sensitive = false;
            try {
                yield controller.enable_hotspot (build_current_request ());
                is_dirty = false;
            } catch (Error e) {
                window_host.show_error (_("Failed to enable hotspot: %s").printf (e.message));
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
                yield controller.disable_hotspot ();
            } catch (Error e) {
                window_host.show_error (_("Failed to disable hotspot: %s").printf (e.message));
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
                var config = yield controller.get_status ();

                is_updating = true;

                if (!is_dirty) {
                    if (config.ssid != "") {
                        ssid_entry.set_text (config.ssid);
                    }
                    if (config.password != "") {
                        password_entry.set_text (config.password);
                    }

                    if (config.security == WifiKeyMgmt.SAE) {
                        security_dropdown.set_selected (0);
                    } else if (config.security == WifiKeyMgmt.NONE) {
                        security_dropdown.set_selected (2);
                    } else {
                        security_dropdown.set_selected (1);
                    }

                    if (config.band == WifiBand.BAND_2GHZ || config.band == WifiBand.BAND_5GHZ) {
                        band_dropdown.set_selected (band_index_for_value (config.band));
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

                    if (ap_interface_dropdown != null && this.ap_model != null) {
                        // "Auto" / "" maps to the synthetic first row; any other
                        // stored value is a raw interface name matched from 1+.
                        if (config.ap_interface == "" || config.ap_interface == "Auto") {
                            ap_interface_dropdown.set_selected (0);
                        } else {
                            bool found = false;
                            for (uint i = 1; i < this.ap_model.get_n_items (); i++) {
                                if (this.ap_model.get_string (i) == config.ap_interface) {
                                    ap_interface_dropdown.set_selected (i);
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                ap_interface_dropdown.set_selected (0);
                            }
                        }
                    }

                    if (uplink_interface_dropdown != null && this.uplink_model != null) {
                        // Fixed semantics: 0 = Auto, 1 = None, 2+ = interfaces.
                        if (config.uplink_interface == "" || config.uplink_interface == "Auto") {
                            uplink_interface_dropdown.set_selected (0);
                        } else if (config.uplink_interface == "None") {
                            uplink_interface_dropdown.set_selected (1);
                        } else {
                            bool found = false;
                            for (uint i = 2; i < this.uplink_model.get_n_items (); i++) {
                                if (this.uplink_model.get_string (i) == config.uplink_interface) {
                                    uplink_interface_dropdown.set_selected (i);
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                uplink_interface_dropdown.set_selected (0);
                            }
                        }
                    }
                }

                // Make sure to disable unsupported bands (though TrackedDropDown might not support disabling individual rows,
                // we'll just let the model handle it if it does, otherwise the user could select an unsupported band which would fail gracefully).
                // But let's at least keep the model intact.

                bool active_or_starting =
                    config.is_active || config.is_starting;
                toggle_switch.active = active_or_starting;
                is_updating = false;

                update_sensitivity (active_or_starting);
                toggle_switch.sensitive = !config.is_starting;

                update_qr_code (config);
            } catch (Error e) {
                warning ("Failed to fetch hotspot status: " + e.message);
                is_updating = false;
            }
        }
    }
}
