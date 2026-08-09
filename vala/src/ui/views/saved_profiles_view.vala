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
    public class SavedProfilesView : Object {
        public Gtk.Stack stack { get; private set; }

        private MainWindowProfilesPage profiles_page;
        private MainWindowProfilesDetailsPage profiles_details_page;
        private MainWindowWifiSavedEditPage wifi_saved_edit_page;
        private IUiHost window_host;
        private MainWindowEthernetController ethernet_controller;
        private MainWindowProfilesController profiles_controller;
        private Gtk.Stack main_content_stack;
        private Gtk.Stack main_wifi_stack;
        private Gtk.Notebook main_notebook;

        private WifiSavedProfile? selected_saved_wifi_profile = null;
        private NetworkDevice? selected_saved_ethernet_profile = null;

        public signal void refresh_requested ();

        public SavedProfilesView (
            MainWindowEthernetController ethernet_controller,
            MainWindowProfilesController profiles_controller,
            IUiHost window_host,
            Gtk.Stack main_content_stack,
            Gtk.Stack main_wifi_stack,
            Gtk.Notebook main_notebook
        ) {
            this.ethernet_controller = ethernet_controller;
            this.profiles_controller = profiles_controller;
            this.window_host = window_host;
            this.main_content_stack = main_content_stack;
            this.main_wifi_stack = main_wifi_stack;
            this.main_notebook = main_notebook;

            profiles_page = new MainWindowProfilesPage ();
            profiles_details_page = new MainWindowProfilesDetailsPage ();
            wifi_saved_edit_page = new MainWindowWifiSavedEditPage (window_host);

            stack = new Gtk.Stack ();
            stack.set_vexpand (true);
            stack.add_css_class (MainWindowCssClasses.CONTENT_STACK);
            stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);
            stack.add_named (profiles_page, "list");
            stack.add_named (profiles_details_page, "details");
            stack.add_named (wifi_saved_edit_page, "edit");
            stack.set_visible_child_name ("list");

            wire_profiles_page_signals ();
            wire_profiles_details_page_signals ();
            wire_profiles_edit_page_signals ();
            wire_ethernet_controller_signals ();
            wire_profiles_controller_signals ();
        }

        private void wire_profiles_controller_signals () {
            profiles_controller.wifi_profiles_loaded.connect ((profiles) => {
                profiles_page.set_wifi_networks (profiles);
            });
            profiles_controller.ethernet_profiles_loaded.connect ((devices) => {
                profiles_page.set_ethernet_profiles (devices);
            });
            profiles_controller.wifi_profile_settings_loaded.connect ((connection_uuid, settings) => {
                if (selected_saved_wifi_profile == null
                    || selected_saved_wifi_profile.saved_connection_uuid != connection_uuid) {
                    return;
                }
                if (stack.get_visible_child_name () == "edit") {
                    wifi_saved_edit_page.apply_settings_to_edit_page (settings);
                    wifi_saved_edit_page.sync_edit_gateway_dns_sensitivity ();
                } else {
                    profiles_details_page.apply_wifi_ip_settings (settings);
                }
            });
            profiles_controller.ethernet_settings_loaded.connect ((device_path, device_name, settings) => {
                if (selected_saved_ethernet_profile == null
                    || (selected_saved_ethernet_profile.device_path != device_path
                        && selected_saved_ethernet_profile.name != device_name)) {
                    return;
                }
                profiles_details_page.apply_ethernet_ip_settings (settings);
            });
            profiles_controller.wifi_profile_update_succeeded.connect (() => {
                window_host.refresh_after_action (false);
                stack.set_visible_child_name ("list");
                profiles_page.restore_scroll_position ();
            });
            profiles_controller.wifi_profile_deleted.connect ((connection_uuid) => {
                if (selected_saved_wifi_profile != null
                    && selected_saved_wifi_profile.saved_connection_uuid == connection_uuid) {
                    selected_saved_wifi_profile = null;
                }
                stack.set_visible_child_name ("list");
                profiles_page.restore_scroll_position ();
                window_host.refresh_after_action (true);
            });
        }

        private void wire_ethernet_controller_signals () {
            ethernet_controller.profile_edit_completed.connect (() => {
                main_content_stack.set_visible_child_name ("profiles");
                stack.set_visible_child_name ("list");
                profiles_page.restore_scroll_position ();
            });
        }

        private void wire_profiles_page_signals () {
            profiles_page.back.connect (() => {
                main_content_stack.set_visible_child_name ("main");
                main_wifi_stack.set_visible_child_name ("list");
            });

            profiles_page.open_profile.connect (open_saved_wifi_profile_details);

            profiles_page.delete_profile.connect ((net) => {
                profiles_controller.delete_wifi_profile (net);
            });

            profiles_page.open_ethernet_profile.connect (open_saved_ethernet_profile_details);
        }

        private void wire_profiles_details_page_signals () {
            profiles_details_page.back.connect (() => {
                stack.set_visible_child_name ("list");
                profiles_page.restore_scroll_position ();
            });

            profiles_details_page.edit.connect (() => {
                if (selected_saved_wifi_profile != null) {
                    open_saved_wifi_edit (selected_saved_wifi_profile);
                    return;
                }

                if (selected_saved_ethernet_profile != null) {
                    var selected_dev = selected_saved_ethernet_profile;
                    main_notebook.set_current_page (1);
                    main_content_stack.set_visible_child_name ("main");
                    ethernet_controller.open_profile_edit (selected_dev);
                }
            });

            profiles_details_page.delete_profile.connect (() => {
                if (selected_saved_wifi_profile != null) {
                    var selected_profile = selected_saved_wifi_profile;
                    profiles_controller.delete_wifi_profile (selected_profile);
                    stack.set_visible_child_name ("list");
                    profiles_page.restore_scroll_position ();
                }
            });
        }

        private void wire_profiles_edit_page_signals () {
            wifi_saved_edit_page.back.connect (() => {
                stack.set_visible_child_name ("list");
                profiles_page.restore_scroll_position ();
            });

            wifi_saved_edit_page.save.connect (() => {
                apply_saved_wifi_edit ();
            });
        }

        private void refresh_saved_ethernet_profiles () {
            if (profiles_page == null) {
                return;
            }
            profiles_controller.refresh_saved_ethernet_profiles ();
        }

        private void refresh_saved_networks () {
            profiles_controller.refresh_saved_wifi_profiles ();
        }

        public void refresh_saved_profiles () {
            refresh_saved_networks ();
            refresh_saved_ethernet_profiles ();
        }

        public void reset_view_state () {
            profiles_controller.on_page_leave ();
            selected_saved_wifi_profile = null;
            selected_saved_ethernet_profile = null;
            if (stack != null) {
                stack.set_visible_child_name ("list");
            }
        }

        public void open_profiles_page (bool focus_ethernet_section = false) {
            main_content_stack.set_visible_child_name ("profiles");
            selected_saved_wifi_profile = null;
            selected_saved_ethernet_profile = null;
            refresh_saved_profiles ();
            stack.set_visible_child_name ("list");
            if (focus_ethernet_section) {
                profiles_page.focus_ethernet_section ();
            } else {
                profiles_page.focus_wifi_section ();
            }
        }

        private void open_saved_wifi_edit (WifiSavedProfile profile) {
            selected_saved_wifi_profile = profile;

            string title_name = MainWindowHelpers.safe_text (profile.profile_name).strip ();
            if (title_name == "") {
                title_name = MainWindowHelpers.safe_text (profile.ssid).strip ();
            }
            wifi_saved_edit_page.title_label.set_text (_("Saved Profile: %s").printf (title_name));
            stack.set_visible_child_name ("edit");
            profiles_controller.load_wifi_profile_settings (profile);
        }

        private void open_saved_wifi_profile_details (WifiSavedProfile profile) {
            selected_saved_wifi_profile = profile;
            selected_saved_ethernet_profile = null;
            profiles_page.remember_scroll_position ();
            profiles_details_page.set_wifi_profile (profile);
            stack.set_visible_child_name ("details");
            load_saved_wifi_profile_details_settings (profile);
        }

        private void open_saved_ethernet_profile_details (NetworkDevice device) {
            selected_saved_wifi_profile = null;
            selected_saved_ethernet_profile = device;
            profiles_page.remember_scroll_position ();
            profiles_details_page.set_ethernet_profile (device);
            stack.set_visible_child_name ("details");
            load_saved_ethernet_profile_ip_settings (device);
        }

        private void load_saved_wifi_profile_details_settings (WifiSavedProfile profile) {
            profiles_controller.load_wifi_profile_settings (profile);
        }

        private void load_saved_ethernet_profile_ip_settings (NetworkDevice device) {
            profiles_controller.load_ethernet_profile_settings (device);
        }

        public bool apply_saved_wifi_edit () {
            if (selected_saved_wifi_profile == null) {
                return false;
            }

            wifi_saved_edit_page.show_error ("");

            WifiSavedProfileUpdateRequest profile_request;
            WifiNetworkUpdateRequest network_request;
            string error_message;
            if (!wifi_saved_edit_page.build_update_requests (
                out profile_request,
                out network_request,
                out error_message
            )) {
                wifi_saved_edit_page.show_error (error_message);
                return false;
            }

            profiles_controller.apply_saved_wifi_profile_updates (
                selected_saved_wifi_profile,
                profile_request,
                network_request
            );
            return true;
        }

        public void show_edit_error (string message) {
            if (wifi_saved_edit_page != null) {
                wifi_saved_edit_page.show_error (message);
            }
        }
        }
        }
