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

namespace HyprNetworkManager.UI.Views {
    public class AppContentNavigationManager : GLib.Object {
        private Gtk.Stack content_stack;
        private Gtk.Notebook notebook;
        private Gtk.Stack? wifi_stack;
        private Gtk.Stack? ethernet_stack;
        private Gtk.Stack? vpn_stack;

        public signal void focus_mode_changed (bool focus_mode);
        public signal void page_changed (int page_num);

        public AppContentNavigationManager (
            Gtk.Stack content_stack,
            Gtk.Notebook notebook,
            Gtk.Stack? wifi_stack,
            Gtk.Stack? ethernet_stack,
            Gtk.Stack? vpn_stack
        ) {
            this.content_stack = content_stack;
            this.notebook = notebook;
            this.wifi_stack = wifi_stack;
            this.ethernet_stack = ethernet_stack;
            this.vpn_stack = vpn_stack;

            setup_widgets ();
            wire_signals ();
        }

        private void setup_widgets () {
            content_stack.set_vexpand (true);
            content_stack.add_css_class (MainWindowCssClasses.CONTENT_STACK);
            content_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            content_stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);

            notebook.set_show_border (false);
            notebook.add_css_class (MainWindowCssClasses.NOTEBOOK);
        }

        private void wire_signals () {
            content_stack.notify["visible-child-name"].connect (() => {
                evaluate_focus_mode ();
            });

            notebook.switch_page.connect ((page, page_num) => {
                page_changed ((int) page_num);
                evaluate_focus_mode ();
            });

            if (wifi_stack != null) {
                wifi_stack.notify["visible-child-name"].connect (() => {
                    evaluate_focus_mode ();
                });
            }

            if (ethernet_stack != null) {
                ethernet_stack.notify["visible-child-name"].connect (() => {
                    evaluate_focus_mode ();
                });
            }

            if (vpn_stack != null) {
                vpn_stack.notify["visible-child-name"].connect (() => {
                    evaluate_focus_mode ();
                });
            }
        }

        public bool is_focus_mode_active () {
            string root_page = content_stack.get_visible_child_name ();
            if (root_page == "profiles") {
                return true;
            }

            int current_tab = notebook.get_current_page ();
            if (current_tab == 0 && wifi_stack != null) {
                string wifi_page = wifi_stack.get_visible_child_name ();
                return wifi_page == "details" || wifi_page == "edit" || wifi_page == "add" || wifi_page == "share";
            }

            if (current_tab == 1 && ethernet_stack != null) {
                string ethernet_page = ethernet_stack.get_visible_child_name ();
                return ethernet_page == "details" || ethernet_page == "edit";
            }

            if (current_tab == 2 && vpn_stack != null) {
                string vpn_page = vpn_stack.get_visible_child_name ();
                return vpn_page == "details"
                    || vpn_page == "edit"
                    || vpn_page == "add"
                    || vpn_page == "setup"
                    || vpn_page == "peer_edit";
            }

            return false;
        }

        public void evaluate_focus_mode () {
            focus_mode_changed (is_focus_mode_active ());
        }
    }
}
