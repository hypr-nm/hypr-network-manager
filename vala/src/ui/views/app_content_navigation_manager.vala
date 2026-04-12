using Gtk;

namespace NetworkManagerRebuild.UI.Views {
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
            content_stack.add_css_class ("nm-content-stack");
            content_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            content_stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);

            notebook.set_show_border (false);
            notebook.add_css_class ("nm-notebook");
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
                return wifi_page == "details" || wifi_page == "edit" || wifi_page == "add";
            }

            if (current_tab == 1 && ethernet_stack != null) {
                string ethernet_page = ethernet_stack.get_visible_child_name ();
                return ethernet_page == "details" || ethernet_page == "edit";
            }

            return false;
        }

        public void evaluate_focus_mode () {
            focus_mode_changed (is_focus_mode_active ());
        }
    }
}
