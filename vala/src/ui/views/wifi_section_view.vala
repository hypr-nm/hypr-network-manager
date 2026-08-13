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
using HyprNetworkManager.UI.Interfaces;
using HyprNetworkManager.Models;

namespace HyprNetworkManager.UI.Views {
    public class WifiSectionView : Object, IMainWindowWifiRowActionHandler, IMainWindowWifiRowProvider,
        IMainWindowWifiPageActionHandler {
        public Gtk.Widget widget { get; private set; }
        public Gtk.Stack stack { get; private set; }
        public Gtk.ListBox listbox { get; private set; }
        public Gtk.Switch wifi_switch { get; private set; }
        public Gtk.Button refresh_button { get; private set; }
        public Gtk.Button add_button { get; private set; }

        private MainWindowWifiController controller;
        private IUiHost window_host;
        private WindowConfigContext config_context;
        private NetworkStateContext state_context;

        private WifiNetwork? selected_wifi_network = null;
        private MainWindowWifiDetailsPage details_page;
        private MainWindowWifiEditPage edit_page;
        private MainWindowWifiSharePage share_page;
        private MainWindowPasswordPromptManager password_prompt_manager;
        private MainWindowWifiRowReconciler row_reconciler;

        private Gtk.Entry add_ssid_entry;
        private HyprNetworkManager.UI.Widgets.TrackedDropDown add_security_dropdown;
        private Gtk.Entry add_password_entry;
        private Gtk.Label add_error_label;
        private Gtk.Revealer add_error_revealer;

        public Gtk.Revealer? active_wifi_password_revealer { get; private set; }
        public Gtk.Entry? active_wifi_password_entry { get; private set; }
        public string? active_wifi_password_row_id { get; private set; }

        public signal void refresh_requested ();
        public signal void go_to_hotspot_requested ();

        private Gtk.Label status_label;
        private Gtk.Image status_icon;

        public WifiSectionView (
            MainWindowWifiController controller,
            IUiHost window_host,
            NetworkStateContext state_context,
            WindowConfigContext config_context,
            Gtk.Label status_label,
            Gtk.Image status_icon
        ) {
            this.controller = controller;
            this.window_host = window_host;
            this.state_context = state_context;
            this.config_context = config_context;
            this.status_label = status_label;
            this.status_icon = status_icon;

            this.details_page = new MainWindowWifiDetailsPage ();
            this.edit_page = new MainWindowWifiEditPage (this.window_host);
            this.share_page = new MainWindowWifiSharePage ();
            this.password_prompt_manager = new MainWindowPasswordPromptManager ();
            this.row_reconciler = new MainWindowWifiRowReconciler (this.window_host);

            controller.wifi_share_ready.connect ((ssid, qr_text) => {
                share_page.set_share_data (ssid, qr_text);
                stack.set_visible_child_name ("share");
            });

            wire_details_page_signals ();
            wire_edit_page_signals ();
            wire_share_page_signals ();

            var add_page = build_add_page ();

            Gtk.Switch local_wifi_switch;
            Gtk.ListBox local_wifi_listbox;
            Gtk.Stack local_wifi_stack;
            Gtk.Button local_add_button;
            Gtk.Button local_refresh_button;
            HyprNetworkManager.UI.Widgets.MainWindowRefreshProgressController local_progress_controller;

            var page = MainWindowWifiPageBuilder.build_page (
                out local_wifi_switch,
                out local_wifi_listbox,
                out local_wifi_stack,
                out local_add_button,
                out local_refresh_button,
                out local_progress_controller,
                details_page,
                edit_page,
                add_page,
                share_page,
                this
            );

            this.wifi_switch = local_wifi_switch;
            this.refresh_button = local_refresh_button;
            this.add_button = local_add_button;
            this.listbox = local_wifi_listbox;
            this.stack = local_wifi_stack;
            this.widget = page;

            controller.networks_loaded.connect ((data, primary_connected_ssid) => {
                render_networks (data, primary_connected_ssid);
            });
            controller.wifi_switch_state_loaded.connect ((enabled) => {
                wifi_switch.set_active (enabled);
            });
            controller.hidden_network_connected.connect (() => {
                show_add_error ("");
                stack.set_visible_child_name ("list");
            });
            controller.add_network_failed.connect ((message) => {
                show_add_error (message);
            });
            controller.details_loaded.connect ((network, settings, connected) => {
                if (selected_wifi_network == null
                    || selected_wifi_network.network_key != network.network_key) {
                    return;
                }
                details_page.render_ip_settings (settings, connected);
            });
            controller.edit_settings_loaded.connect ((network, settings) => {
                if (selected_wifi_network == null
                    || selected_wifi_network.network_key != network.network_key) {
                    return;
                }
                edit_page.set_password (
                    network.is_secured
                        ? MainWindowHelpers.safe_text (settings.configured_password)
                        : ""
                );
                edit_page.populate_ip_settings (settings);
            });
            controller.edit_succeeded.connect ((network, close_after_apply) => {
                if (selected_wifi_network == null
                    || selected_wifi_network.network_key != network.network_key) {
                    return;
                }
                edit_page.show_error ("");
                if (close_after_apply) {
                    open_wifi_details (network);
                }
            });
            controller.edit_failed.connect ((message) => {
                edit_page.show_error (message);
            });

            controller.refresh_started.connect (() => {
                local_progress_controller.start ();
            });
            controller.refresh_finished.connect (() => {
                local_progress_controller.finish ();
            });
            controller.refresh_requested.connect (() => {
                refresh_requested ();
            });

            local_refresh_button.clicked.connect (() => {
                refresh_requested ();
            });

            local_add_button.clicked.connect (() => {
                open_add_network ();
            });

            wifi_switch.notify["active"].connect (() => {
                on_wifi_switch_changed ();
            });
        }

        public void request_refresh (bool request_wifi_scan) {
            refresh_requested ();
        }

        public void go_to_hotspot () {
            go_to_hotspot_requested ();
        }

        public void set_refresh_button_enabled (bool enabled, string tooltip_text) {
            refresh_button.set_sensitive (enabled);
            refresh_button.set_tooltip_text (tooltip_text);
        }

        public void set_availability_placeholder (bool wifi_enabled, bool flight_mode_active) {
            string current_page = stack.get_visible_child_name ();
            if (current_page == "details" || current_page == "edit" || current_page == "add" || current_page == "share") {
                return;
            }

            if (flight_mode_active) {
                stack.set_visible_child_name ("flight-mode");
                return;
            }

            if (!wifi_enabled) {
                stack.set_visible_child_name ("wifi-disabled");
                return;
            }

            if (current_page == "flight-mode" || current_page == "wifi-disabled") {
                stack.set_visible_child_name (listbox.get_first_child () != null ? "list" : "empty");
            }
        }

        private void wire_details_page_signals () {
            details_page.back.connect (() => {
                stack.set_visible_child_name ("list");
            });

            details_page.forget.connect (() => {
                if (selected_wifi_network == null) {
                    window_host.debug_log ("ERROR: forget clicked but selected_wifi_network is NULL!");
                    return;
                }
                forget_wifi_network (selected_wifi_network);
                stack.set_visible_child_name ("list");
            });

            details_page.edit.connect (() => {
                if (selected_wifi_network == null) {
                    window_host.debug_log ("ERROR: edit clicked but selected_wifi_network is NULL!");
                    return;
                }
                open_wifi_edit (selected_wifi_network);
            });

            details_page.share.connect (() => {
                if (selected_wifi_network == null) {
                    window_host.debug_log ("Share requested but no network is selected");
                    return;
                }

                // Snapshot the network before the async password read so the QR is
                // always built from one consistent network, even if selection changes
                // while the read is in flight.
                string share_network_key = selected_wifi_network.network_key;

                window_host.debug_log ("Share requested for network %s".printf (
                    redact_network_key (share_network_key)));

                controller.open_wifi_share (selected_wifi_network);
            });
        }

        private void wire_share_page_signals () {
            share_page.back.connect (() => {
                if (selected_wifi_network != null) {
                    open_wifi_details (selected_wifi_network);
                } else {
                    stack.set_visible_child_name ("list");
                }
            });
        }

        private void wire_edit_page_signals () {
            edit_page.back.connect (() => {
                if (selected_wifi_network != null) {
                    open_wifi_details (selected_wifi_network);
                } else {
                    stack.set_visible_child_name ("list");
                }
            });

            edit_page.apply.connect (() => {
                apply_wifi_edit (false);
            });

            edit_page.ok.connect (() => {
                apply_wifi_edit (true);
            });
        }

        private Gtk.Widget build_add_page () {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_ROW);
            page.add_css_class (MainWindowCssClasses.PAGE);
            page.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
            page.add_css_class (MainWindowCssClasses.PAGE_WIFI_ADD);
            page.add_css_class (MainWindowCssClasses.PAGE_NETWORK_EDIT);

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            var back_btn = MainWindowHelpers.build_back_button ();
            back_btn.clicked.connect (() => {
                stack.set_visible_child_name ("list");
            });
            header.append (back_btn);

            var title = new Gtk.Label (_("Add Hidden Network"));
            title.set_xalign (0.0f);
            title.set_hexpand (true);
            title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
            header.append (title);
            page.append (header);

            this.add_error_label = new Gtk.Label ("");
            this.add_error_label.set_xalign (0.0f);
            this.add_error_label.set_wrap (true);
            this.add_error_label.add_css_class (MainWindowCssClasses.ERROR_LABEL);
            this.add_error_label.add_css_class (MainWindowCssClasses.ROW_CONTENT_INSET);

            this.add_error_revealer = new Gtk.Revealer ();
            this.add_error_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
            this.add_error_revealer.set_child (this.add_error_label);
            page.append (this.add_error_revealer);

            var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
            form.add_css_class (MainWindowCssClasses.EDIT_NETWORK_FORM);
            form.add_css_class (MainWindowCssClasses.EDIT_FORM);
            form.add_css_class (MainWindowCssClasses.DETAILS_SCROLL_BODY_INSET);

            var note = new Gtk.Label (_("Manually add a hidden Wi-Fi network."));
            note.set_xalign (0.0f);
            note.set_wrap (true);
            note.add_css_class (MainWindowCssClasses.EDIT_NOTE);
            note.add_css_class (MainWindowCssClasses.SUB_LABEL);
            form.append (note);

            var ssid_label = new Gtk.Label (_("SSID"));
            ssid_label.set_xalign (0.0f);
            ssid_label.add_css_class (MainWindowCssClasses.EDIT_FIELD_LABEL);
            ssid_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
            form.append (ssid_label);

            add_ssid_entry = new Gtk.Entry ();
            add_ssid_entry.set_placeholder_text (_("Network name"));
            add_ssid_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            add_ssid_entry.add_css_class (MainWindowCssClasses.INPUT);
            add_ssid_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
            form.append (add_ssid_entry);

            var security_label = new Gtk.Label (_("Security"));
            security_label.set_xalign (0.0f);
            security_label.add_css_class (MainWindowCssClasses.EDIT_FIELD_LABEL);
            security_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
            form.append (security_label);

            var security_list = new Gtk.StringList (null);
            foreach (string label in HiddenWifiSecurityModeUtils.get_dropdown_labels ()) {
                security_list.append (label);
            }
            add_security_dropdown = window_host.create_tracked_dropdown (security_list);
            add_security_dropdown.add_css_class (MainWindowCssClasses.EDIT_DROPDOWN);
            add_security_dropdown.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
            add_security_dropdown.set_selected (
                HiddenWifiSecurityModeUtils.to_dropdown_index (HiddenWifiSecurityMode.WPA_PSK)
            );

            var save_btn = new Gtk.Button.with_label (_("Connect"));
            save_btn.add_css_class (MainWindowCssClasses.BUTTON);
            save_btn.add_css_class (MainWindowCssClasses.SUGGESTED_ACTION);

            add_security_dropdown.notify_selected.connect (() => {
                sync_add_network_sensitivity (save_btn);
            });
            form.append (add_security_dropdown);

            var password_label = new Gtk.Label (_("Password"));
            password_label.set_xalign (0.0f);
            password_label.add_css_class (MainWindowCssClasses.EDIT_FIELD_LABEL);
            password_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
            form.append (password_label);

            add_password_entry = new Gtk.Entry ();
            add_password_entry.set_visibility (false);
            add_password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
            add_password_entry.set_placeholder_text (
                _("Network password (min %d chars)").printf (HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH)
            );
            add_password_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            add_password_entry.add_css_class (MainWindowCssClasses.INPUT);
            add_password_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
            add_password_entry.add_css_class (MainWindowCssClasses.PASSWORD_ENTRY);

            add_password_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
            add_password_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
            MainWindowHelpers.sync_password_visibility_icon (add_password_entry);

            add_password_entry.icon_press.connect ((icon_pos) => {
                if (icon_pos != Gtk.EntryIconPosition.SECONDARY) {
                    return;
                }
                add_password_entry.set_visibility (!add_password_entry.get_visibility ());
                MainWindowHelpers.sync_password_visibility_icon (add_password_entry);
            });

            add_password_entry.changed.connect (() => {
                sync_add_network_sensitivity (save_btn);
            });
            add_password_entry.activate.connect (() => {
                if (!save_btn.get_sensitive ()) {
                    return;
                }
                submit_add_hidden_network ();
            });
            form.append (add_password_entry);

            sync_add_network_sensitivity (save_btn);

            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            actions.add_css_class (MainWindowCssClasses.EDIT_ACTIONS);

            save_btn.clicked.connect (submit_add_hidden_network);
            actions.append (save_btn);

            form.append (actions);

            page.append (form);
            return page;
        }

        private void submit_add_hidden_network () {
            show_add_error ("");
            controller.connect_hidden_network (
                add_ssid_entry.get_text (),
                HiddenWifiSecurityModeUtils.from_dropdown_index (
                    add_security_dropdown.get_selected ()
                ),
                add_password_entry.get_text ()
            );
        }

        private void sync_add_network_sensitivity (Gtk.Button connect_button) {
            HiddenWifiSecurityMode mode = HiddenWifiSecurityModeUtils.from_dropdown_index (
                add_security_dropdown.get_selected ()
            );
            bool secured = HiddenWifiSecurityModeUtils.requires_password (mode);
            add_password_entry.set_sensitive (secured);
            if (!secured) {
                add_password_entry.set_text ("");
            }
            connect_button.set_sensitive (
                HiddenWifiSecurityModeUtils.is_password_valid_for_mode (
                    mode,
                    add_password_entry.get_text ()
                )
            );
        }

        private void open_add_network () {
            add_ssid_entry.set_text ("");
            add_security_dropdown.set_selected (
                HiddenWifiSecurityModeUtils.to_dropdown_index (HiddenWifiSecurityMode.WPA_PSK)
            );
            add_password_entry.set_text ("");
            show_add_error ("");
            stack.set_visible_child_name ("add");
        }

        private void populate_wifi_details (WifiNetwork net) {
            details_page.render_details (
                net,
                controller.is_connected (net),
                controller.is_pending (net)
            );
            details_page.show_loading_ip ();
            controller.load_details (net);
        }

        private void open_wifi_details (WifiNetwork net) {
            selected_wifi_network = net;
            populate_wifi_details (net);
            stack.set_visible_child_name ("details");
        }

        private void open_wifi_edit (WifiNetwork net) {
            if (!net.saved) {
                window_host.debug_log ("ERROR: net.saved is false in open_wifi_edit!");
                return;
            }
            selected_wifi_network = net;
            edit_page.setup_edit_form (net);
            stack.set_visible_child_name ("edit");
            controller.load_edit_settings (net);
        }

        private bool apply_wifi_edit (bool close_after_apply) {
            if (selected_wifi_network == null) {
                return false;
            }

            string? error_message = null;
            var base_request = edit_page.build_ip_update_request (out error_message);
            if (base_request == null) {
                if (error_message != null) {
                    edit_page.show_error (error_message);
                }
                return false;
            }

            var request = new WifiNetworkUpdateRequest () {
                password = edit_page.get_password (),
                ipv4_method = base_request.ipv4_method,
                ipv4_address = base_request.ipv4_address,
                ipv4_prefix = base_request.ipv4_prefix,
                ipv4_gateway_auto = base_request.ipv4_gateway_auto,
                ipv4_gateway = base_request.ipv4_gateway,
                ipv4_dns_auto = base_request.ipv4_dns_auto,
                ipv4_dns_servers = base_request.ipv4_dns_servers,
                ipv6_method = base_request.ipv6_method,
                ipv6_address = base_request.ipv6_address,
                ipv6_prefix = base_request.ipv6_prefix,
                ipv6_gateway_auto = base_request.ipv6_gateway_auto,
                ipv6_gateway = base_request.ipv6_gateway,
                ipv6_dns_auto = base_request.ipv6_dns_auto,
                ipv6_dns_servers = base_request.ipv6_dns_servers
            };
            edit_page.show_error ("");
            controller.apply_edit (
                selected_wifi_network,
                request,
                close_after_apply,
                base_request.ipv4_method != "disabled"
            );
            return true;
        }

        private void forget_wifi_network (WifiNetwork net) {
            controller.forget_wifi_network (
                net
            );
        }

        private void disconnect_wifi_network (WifiNetwork net) {
            controller.disconnect_wifi_network (
                net
            );
        }

        public void open_details (WifiNetwork net) {
            open_wifi_details (net);
        }

        public void forget_saved_network (WifiNetwork net) {
            forget_wifi_network (net);
        }

        public void disconnect_network (WifiNetwork net) {
            disconnect_wifi_network (net);
        }

        public void connect_network (WifiNetwork net, string? password, string? hidden_ssid, bool autoconnect) {
            controller.connect_with_optional_password (
                net,
                password,
                hidden_ssid,
                autoconnect,
                config_context.pending_wifi_connect_timeout_ms,
                config_context.close_on_connect
            );
        }

        public void set_auto_connect (WifiNetwork net, bool auto_connect) {
            controller.set_wifi_network_autoconnect (
                net,
                auto_connect
            );
        }

        public void show_password_prompt (WifiNetwork net, Gtk.Revealer revealer, Gtk.Entry entry) {
            active_wifi_password_row_id = get_wifi_row_id (net);
            password_prompt_manager.show_prompt (revealer, entry);
            active_wifi_password_revealer = revealer;
            active_wifi_password_entry = entry;
        }

        public HyprNetworkManager.UI.Widgets.TrackedDropDown create_radio_dropdown (
            owned Gtk.StringList model
        ) {
            return window_host.create_tracked_dropdown ((owned) model);
        }

        public void hide_password_prompt (Gtk.Revealer revealer, Gtk.Entry entry, string? value) {
            bool was_active = password_prompt_manager.hide_prompt (revealer, entry, value);
            if (was_active) {
                active_wifi_password_revealer = null;
                active_wifi_password_entry = null;
                active_wifi_password_row_id = null;
            }
        }

        private string resolve_wifi_row_icon_name (WifiNetwork net) {
            return MainWindowHelpers.resolve_wifi_row_icon_name (net);
        }

        public Gtk.ListBoxRow build_wifi_row (WifiNetwork net) {
            string net_key = net.network_key;
            bool is_connected_now = state_context.active_wifi_connections.contains (net_key);
            bool is_connecting = state_context.pending_wifi_connect.contains (net_key);
            string? error_message = state_context.wifi_errors.lookup (net_key);

            return MainWindowWifiRowBuilder.build_row (
                net,
                is_connected_now,
                is_connecting,
                error_message,
                config_context.show_frequency,
                config_context.show_band,
                config_context.show_bssid,
                resolve_wifi_row_icon_name (net),
                this
            );
        }

        public void update_wifi_row (Gtk.ListBoxRow row, WifiNetwork net) {
            string net_key = net.network_key;
            bool is_connected_now = state_context.active_wifi_connections.contains (net_key);
            bool is_connecting = state_context.pending_wifi_connect.contains (net_key);
            string? error_message = state_context.wifi_errors.lookup (net_key);

            MainWindowWifiRowBuilder.update_row (
                row,
                net,
                is_connected_now,
                is_connecting,
                error_message,
                config_context.show_frequency,
                config_context.show_band,
                config_context.show_bssid,
                resolve_wifi_row_icon_name (net),
                this
            );
        }

        private string get_wifi_row_id (WifiNetwork net) {
            return net.network_key;
        }

        public void perform_refresh () {
            controller.refresh ();
        }

        private void render_networks (
            WifiRefreshData data,
            string? primary_connected_ssid
        ) {
            bool has_active_prompt = active_wifi_password_revealer != null
                && active_wifi_password_revealer.get_reveal_child ();
            row_reconciler.reconcile (
                listbox,
                data.networks,
                active_wifi_password_row_id,
                has_active_prompt,
                this
            );

            string current_page = stack.get_visible_child_name ();
            bool preserve_page = current_page == "details"
                || current_page == "edit"
                || current_page == "add"
                || current_page == "share"
                || current_page == "saved"
                || current_page == "saved-edit"
                || current_page == "wifi-disabled"
                || current_page == "flight-mode";
            if (!preserve_page) {
                if (data.is_hotspot_active && data.num_wifi_devices <= 1) {
                    stack.set_visible_child_name ("hotspot-active");
                } else {
                    stack.set_visible_child_name (data.networks.length > 0 ? "list" : "empty");
                }
            }

            if (data.networks.length == 0) {
                status_label.set_text (_("No Wi-Fi networks found"));
                status_icon.set_from_icon_name ("network-wireless-offline-symbolic");
                return;
            }

            WifiNetwork? connected = null;
            if (primary_connected_ssid != null) {
                foreach (var network in data.networks) {
                    if (network.ssid == primary_connected_ssid) {
                        connected = network;
                        break;
                    }
                }
            }

            if (connected != null) {
                status_label.set_text (
                    _("Wi-Fi · %s (%u%%)").printf (connected.ssid, connected.signal)
                );
                status_icon.set_from_icon_name (
                    WifiSignalLevels.get_icon_name (connected.signal)
                );
            } else if (primary_connected_ssid != null) {
                status_label.set_text (_("Wi-Fi · %s").printf (primary_connected_ssid));
                status_icon.set_from_icon_name ("network-wireless-signal-good-symbolic");
            } else {
                status_label.set_text (
                    _("Wi-Fi available (%u networks)").printf (data.networks.length)
                );
                status_icon.set_from_icon_name ("network-wireless-signal-good-symbolic");
            }
        }

        public void reset_view_state () {
            if (stack != null) {
                stack.set_visible_child_name ("list");
            }

            hide_active_wifi_password_prompt ();
            row_reconciler.reset ();

            if (listbox == null) {
                return;
            }

            for (Gtk.Widget? child = listbox.get_first_child (); child != null; child = child.get_next_sibling ()) {
                var row = child as Gtk.ListBoxRow;
                if (row == null || !row.get_data<bool> (MainWindowDataKeys.ACTIONS_EXPANDED)) {
                    continue;
                }

                var revealer = row.get_data<Gtk.Revealer> ("actions-revealer");
                if (revealer != null) {
                    revealer.set_reveal_child (false);
                }

                var expand_hint = row.get_data<Gtk.Image> ("expand-hint");
                if (expand_hint != null) {
                    MainWindowIconResources.set_expand_indicator_icon (expand_hint, false);
                }

                row.set_data<bool> (MainWindowDataKeys.ACTIONS_EXPANDED, false);
            }
        }

        private void on_wifi_switch_changed () {
            controller.set_wifi_enabled (wifi_switch.get_active ());
        }

        public void hide_active_wifi_password_prompt () {
            password_prompt_manager.hide_active_prompt ();
            active_wifi_password_revealer = null;
            active_wifi_password_entry = null;
            active_wifi_password_row_id = null;
        }

        public void show_edit_error (string message) {
            if (edit_page != null) {
                edit_page.show_error (message);
            }
        }

        public void show_add_error (string message) {
            if (add_error_label != null && add_error_revealer != null) {
                if (message == null || message == "") {
                    add_error_revealer.set_reveal_child (false);
                    return;
                }
                add_error_label.set_text (message);
                add_error_revealer.set_reveal_child (true);
            }
        }
    }
}
