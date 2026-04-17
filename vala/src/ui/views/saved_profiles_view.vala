// SPDX-License-Identifier: GPL-3.0-or-later
using GLib;
using Gtk;
using HyprNetworkManager.UI.Interfaces;
using HyprNetworkManager.Models;

namespace HyprNetworkManager.UI.Views {
    public class SavedProfilesView : Object {
        public Gtk.Stack stack { get; private set; }

        private MainWindowProfileAdapter wifi_saved_flow;
        private MainWindowProfilesPage profiles_page;
        private MainWindowProfilesDetailsPage profiles_details_page;
        private MainWindowWifiSavedEditPage wifi_saved_edit_page;
        private NetworkManagerClient nm;
        private IWindowHost window_host;
        private MainWindowEthernetController ethernet_controller;
        private Gtk.Stack main_content_stack;
        private Gtk.Stack main_wifi_stack;
        private Gtk.Notebook main_notebook;

        private WifiSavedProfile? selected_saved_wifi_profile = null;
        private NetworkDevice? selected_saved_ethernet_profile = null;

        public signal void refresh_requested ();

        public SavedProfilesView (
            NetworkManagerClient nm,
            MainWindowWifiController wifi_controller,
            MainWindowEthernetController ethernet_controller,
            IWindowHost window_host,
            NetworkStateContext state_context,
            Gtk.Stack main_content_stack,
            Gtk.Stack main_wifi_stack,
            Gtk.Notebook main_notebook
        ) {
            this.nm = nm;
            this.ethernet_controller = ethernet_controller;
            this.window_host = window_host;
            this.main_content_stack = main_content_stack;
            this.main_wifi_stack = main_wifi_stack;
            this.main_notebook = main_notebook;

            profiles_page = new MainWindowProfilesPage ();
            profiles_details_page = new MainWindowProfilesDetailsPage ();
            wifi_saved_edit_page = new MainWindowWifiSavedEditPage ();

            stack = new Gtk.Stack ();
            stack.set_vexpand (true);
            stack.add_css_class (MainWindowCssClasses.CONTENT_STACK);
            stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);
            stack.add_named (profiles_page, "list");
            stack.add_named (profiles_details_page, "details");
            stack.add_named (wifi_saved_edit_page, "edit");
            stack.set_visible_child_name ("list");

            wifi_saved_flow = new MainWindowProfileAdapter (
                nm,
                wifi_controller,
                stack,
                profiles_page,
                wifi_saved_edit_page,
                window_host,
                state_context
            );

            wire_profiles_page_signals ();
            wire_profiles_details_page_signals ();
            wire_profiles_edit_page_signals ();
            wire_ethernet_controller_signals ();
        }

        private void wire_ethernet_controller_signals () {
            ethernet_controller.profile_edit_completed.connect (() => {
                main_content_stack.set_visible_child_name ("profiles");
                stack.set_visible_child_name ("list");
                profiles_page.restore_scroll_position ();
                window_host.set_popup_text_input_mode (false);
            });
        }

        private void wire_profiles_page_signals () {
            profiles_page.back.connect (() => {
                main_content_stack.set_visible_child_name ("main");
                main_wifi_stack.set_visible_child_name ("list");
                window_host.set_popup_text_input_mode (false);
            });

            profiles_page.refresh.connect (() => {
                refresh_saved_profiles ();
            });

            profiles_page.open_profile.connect (open_saved_wifi_profile_details);

            profiles_page.delete_profile.connect ((net) => {
                if (wifi_saved_flow != null) {
                    wifi_saved_flow.delete_profile (net);
                }
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
                if (selected_saved_wifi_profile != null && wifi_saved_flow != null) {
                    var selected_profile = selected_saved_wifi_profile;
                    wifi_saved_flow.delete_profile (selected_profile);
                    stack.set_visible_child_name ("list");
                    profiles_page.restore_scroll_position ();
                }
            });
        }

        private void wire_profiles_edit_page_signals () {
            wifi_saved_edit_page.back.connect (() => {
                if (wifi_saved_flow != null) {
                    wifi_saved_flow.on_saved_edit_back ();
                }
                profiles_page.restore_scroll_position ();
            });

            wifi_saved_edit_page.save.connect (() => {
                apply_saved_wifi_edit ();
            });
        }

        private bool has_ethernet_profile (NetworkDevice dev) {
            return nm.has_ethernet_profile_for_device (dev);
        }

        private void refresh_saved_ethernet_profiles () {
            if (profiles_page == null) {
                return;
            }

            nm.get_devices.begin (null, (obj, res) => {
                try {
                    var devices = nm.get_devices.end (res);
                    var ethernet_profiles = new List<NetworkDevice> ();
                    foreach (var dev in devices) {
                        if (!dev.is_ethernet || !has_ethernet_profile (dev)) {
                            continue;
                        }
                        ethernet_profiles.append (dev);
                    }

                    var ethernet_profiles_arr = new NetworkDevice[ethernet_profiles.length ()];
                    int idx = 0;
                    foreach (var dev in ethernet_profiles) {
                        ethernet_profiles_arr[idx++] = dev;
                    }
                    profiles_page.set_ethernet_profiles (ethernet_profiles_arr);
                } catch (Error e) {
                    window_host.show_error ("Could not load ethernet profiles: " + e.message);
                }
            });
        }

        private void refresh_saved_networks () {
            if (wifi_saved_flow != null) {
                wifi_saved_flow.refresh_saved_networks ();
            }
        }

        public void refresh_saved_profiles () {
            refresh_saved_networks ();
            refresh_saved_ethernet_profiles ();
        }

        public void reset_view_state () {
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
            if (wifi_saved_flow != null) {
                wifi_saved_flow.open_saved_edit (profile);
            }
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
            nm.get_saved_wifi_profile_settings.begin (profile, null, (obj, res) => {
                try {
                    var settings = nm.get_saved_wifi_profile_settings.end (res);
                    if (selected_saved_wifi_profile == null
                        || selected_saved_wifi_profile.saved_connection_uuid != profile.saved_connection_uuid) {
                        return;
                    }
                    profiles_details_page.apply_wifi_ip_settings (settings);
                } catch (Error e) {
                    window_host.show_error ("Could not load saved profile settings: " + e.message);
                }
            });
        }

        private void load_saved_ethernet_profile_ip_settings (NetworkDevice device) {
            nm.get_ethernet_device_configured_ip_settings.begin (device, null, (obj, res) => {
                var ip_settings = nm.get_ethernet_device_configured_ip_settings.end (res);
                if (selected_saved_ethernet_profile == null
                    || (selected_saved_ethernet_profile.device_path != device.device_path
                        && selected_saved_ethernet_profile.name != device.name)) {
                    return;
                }
                profiles_details_page.apply_ethernet_ip_settings (ip_settings);
            });
        }

        private bool apply_saved_wifi_edit () {
            if (wifi_saved_flow == null) {
                return false;
            }
            return wifi_saved_flow.apply_saved_edit ();
        }
    }
}
