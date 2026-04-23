// SPDX-License-Identifier: GPL-3.0-or-later
using GLib;
using Gtk;
using HyprNetworkManager.UI.Utils;

namespace HyprNetworkManager.UI.Views {
    public class EthernetSectionView : Object {
        public Gtk.Widget widget { get; private set; }
        public Gtk.Stack stack { get; private set; }
        public Gtk.ListBox listbox { get; private set; }
        public Gtk.Button refresh_button { get; private set; }

        private MainWindowEthernetController controller;
        private MainWindowEthernetEditPage ethernet_edit_page;

        public EthernetSectionView (MainWindowEthernetController controller, TransientSurfaceTracker surface_tracker) {
            this.controller = controller;

            var ethernet_details_page = new MainWindowEthernetDetailsPage ();
            this.ethernet_edit_page = new MainWindowEthernetEditPage (surface_tracker);

            ethernet_details_page.back.connect (() => {
                controller.on_details_back_requested ();
            });
            ethernet_details_page.primary_action.connect (() => {
                controller.on_details_primary_requested ();
            });
            ethernet_details_page.edit.connect (() => {
                controller.on_details_edit_requested ();
            });

            this.ethernet_edit_page.back.connect (() => {
                controller.on_edit_back_requested ();
            });
            this.ethernet_edit_page.apply.connect (() => {
                controller.on_edit_apply_requested ();
            });

            Gtk.ListBox ethernet_listbox;
            Gtk.Stack ethernet_stack_local;
            Gtk.Button ethernet_refresh_button;
            var page = MainWindowEthernetPageBuilder.build_page (
                out ethernet_listbox,
                out ethernet_stack_local,
                out ethernet_refresh_button,
                ethernet_details_page,
                this.ethernet_edit_page,
                controller
            );

            this.listbox = ethernet_listbox;
            this.stack = ethernet_stack_local;
            this.refresh_button = ethernet_refresh_button;
            this.widget = page;

            var ethernet_view_context = new MainWindowEthernetViewContext (
                page,
                ethernet_listbox,
                ethernet_stack_local,
                ethernet_details_page,
                this.ethernet_edit_page
            );

            controller.configure_page (ethernet_view_context);
        }

        public void reset_view_state () {
            if (stack != null) {
                stack.set_visible_child_name ("list");
            }
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
            if (ethernet_edit_page != null) {
                ethernet_edit_page.show_error (message);
            }
        }
    }
}
