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

namespace HyprNetworkManager.UI.Views {
    public class EthernetSectionView : Object, IMainWindowEthernetRowActionHandler {
        public Gtk.Widget widget { get; private set; }
        public Gtk.Stack stack { get; private set; }
        public Gtk.ListBox listbox { get; private set; }
        public Gtk.Button refresh_button { get; private set; }

        private MainWindowEthernetController controller;
        private IUiHost window_host;
        private MainWindowEthernetDetailsPage details_page;
        private MainWindowEthernetEditPage edit_page;
        private NetworkDevice? selected_device = null;
        private bool profile_edit_mode = false;

        public EthernetSectionView (
            MainWindowEthernetController controller,
            IUiHost window_host
        ) {
            this.controller = controller;
            this.window_host = window_host;
            details_page = new MainWindowEthernetDetailsPage ();
            edit_page = new MainWindowEthernetEditPage (window_host);

            Gtk.ListBox ethernet_listbox;
            Gtk.Stack ethernet_stack;
            Gtk.Button ethernet_refresh_button;
            HyprNetworkManager.UI.Widgets.MainWindowRefreshProgressController progress_controller;
            widget = MainWindowEthernetPageBuilder.build_page (
                out ethernet_listbox,
                out ethernet_stack,
                out ethernet_refresh_button,
                out progress_controller,
                details_page,
                edit_page,
                controller
            );

            listbox = ethernet_listbox;
            stack = ethernet_stack;
            refresh_button = ethernet_refresh_button;

            controller.refresh_started.connect (progress_controller.start);
            controller.refresh_finished.connect (progress_controller.finish);
            controller.devices_loaded.connect (render_devices);
            controller.details_loaded.connect (render_ip_details);
            controller.edit_settings_loaded.connect (populate_edit_settings);
            controller.edit_succeeded.connect (finish_edit);
            controller.edit_failed.connect (edit_page.show_error);
            controller.profile_edit_requested.connect ((device) => {
                profile_edit_mode = true;
                open_edit (device);
            });

            wire_page_signals ();
        }

        private void wire_page_signals () {
            details_page.back.connect (() => {
                selected_device = null;
                stack.set_visible_child_name ("list");
            });
            details_page.primary_action.connect (() => {
                if (selected_device != null) {
                    controller.trigger_toggle (selected_device);
                }
            });
            details_page.edit.connect (() => {
                if (selected_device != null) {
                    profile_edit_mode = false;
                    open_edit (selected_device);
                }
            });

            edit_page.back.connect (() => {
                if (profile_edit_mode) {
                    profile_edit_mode = false;
                    selected_device = null;
                    stack.set_visible_child_name ("list");
                } else if (selected_device != null) {
                    open_details (selected_device);
                } else {
                    stack.set_visible_child_name ("list");
                }
            });
            edit_page.apply.connect (apply_edit);
        }

        private bool is_selected (NetworkDevice device) {
            return selected_device != null
                && (selected_device.device_path == device.device_path
                    || selected_device.name == device.name);
        }

        private void render_devices (NetworkDevice[] devices) {
            string current_view = stack.get_visible_child_name ();
            MainWindowHelpers.clear_listbox (listbox);

            foreach (var device in devices) {
                listbox.append (MainWindowEthernetRowBuilder.build_row (
                    device,
                    controller.is_action_pending (device),
                    controller.can_connect_with_profile (device),
                    controller.has_saved_profile (device),
                    controller.error_for_device (device),
                    this
                ));
            }

            if (current_view == "flight-mode") {
                return;
            }

            if ((current_view == "details" || current_view == "edit")
                && selected_device != null) {
                NetworkDevice? updated = null;
                foreach (var device in devices) {
                    if (is_selected (device)) {
                        updated = device;
                        break;
                    }
                }

                if (updated != null) {
                    selected_device = updated;
                    if (current_view == "details") {
                        open_details (updated);
                    } else {
                        stack.set_visible_child_name ("edit");
                    }
                    return;
                }

                selected_device = null;
            }

            stack.set_visible_child_name (devices.length > 0 ? "list" : "empty");
        }

        private void render_ip_details (NetworkDevice device, NetworkIpSettings settings) {
            if (!is_selected (device) || stack.get_visible_child_name () != "details") {
                return;
            }
            details_page.render_ip_settings (settings, device.is_connected);
        }

        private void populate_edit_settings (NetworkDevice device, NetworkIpSettings settings) {
            if (!is_selected (device) || stack.get_visible_child_name () != "edit") {
                return;
            }
            edit_page.populate_ip_settings (settings);
        }

        private void open_edit (NetworkDevice device) {
            if (!controller.has_saved_profile (device)) {
                window_host.show_error (_("This interface has no saved Ethernet profile to edit."));
                return;
            }

            selected_device = device;
            edit_page.setup_edit_form (device);
            stack.set_visible_child_name ("edit");
            controller.load_edit_settings (device);
        }

        private void apply_edit () {
            if (selected_device == null) {
                return;
            }

            edit_page.show_error ("");
            string? error_message = null;
            var request = edit_page.build_ip_update_request (out error_message);
            if (request == null) {
                edit_page.show_error (MainWindowHelpers.safe_text (error_message));
                return;
            }
            controller.apply_edit (selected_device, request, profile_edit_mode);
        }

        private void finish_edit (NetworkDevice device, bool was_profile_edit) {
            if (!is_selected (device)) {
                return;
            }
            if (was_profile_edit) {
                profile_edit_mode = false;
                selected_device = null;
                stack.set_visible_child_name ("list");
            } else {
                open_details (device);
            }
        }

        public void open_details (NetworkDevice device) {
            profile_edit_mode = false;
            selected_device = device;
            details_page.render_details (
                device,
                controller.has_saved_profile (device),
                controller.is_action_pending (device),
                controller.can_connect_with_profile (device)
            );
            details_page.show_loading_ip ();
            stack.set_visible_child_name ("details");
            controller.load_details (device);
        }

        public void trigger_toggle (NetworkDevice device) {
            controller.trigger_toggle (device);
        }

        public void reset_view_state () {
            selected_device = null;
            profile_edit_mode = false;
            stack.set_visible_child_name ("list");
        }

        public void set_refresh_button_enabled (bool enabled, string tooltip_text) {
            refresh_button.set_sensitive (enabled);
            refresh_button.set_tooltip_text (tooltip_text);
        }

        public void set_flight_mode_placeholder (bool flight_mode_active) {
            string current_page = stack.get_visible_child_name ();
            if (current_page == "details" || current_page == "edit") {
                return;
            }

            if (flight_mode_active) {
                stack.set_visible_child_name ("flight-mode");
                return;
            }

            if (current_page == "flight-mode") {
                stack.set_visible_child_name (listbox.get_first_child () != null ? "list" : "empty");
            }
        }

        public void show_edit_error (string message) {
            edit_page.show_error (message);
        }
    }
}
