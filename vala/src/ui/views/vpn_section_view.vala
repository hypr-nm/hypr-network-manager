// SPDX-License-Identifier: GPL-3.0-or-later
using GLib;
using Gtk;

namespace NetworkManagerRebuild.UI.Views {
    public class VpnSectionView : Object {
        public Gtk.Widget widget { get; private set; }
        public Gtk.Stack stack { get; private set; }
        public Gtk.ListBox listbox { get; private set; }

        private MainWindowVpnController controller;

        public VpnSectionView (MainWindowVpnController controller) {
            this.controller = controller;

            Gtk.ListBox vpn_listbox;
            Gtk.Stack vpn_stack_local;

            var page = controller.build_page (
                out vpn_listbox,
                out vpn_stack_local,
                () => {
                    controller.refresh ();
                }
            );

            this.listbox = vpn_listbox;
            this.stack = vpn_stack_local;
            this.widget = page;
        }

        public void reset_view_state () {
            if (stack != null) {
                stack.set_visible_child_name ("list");
            }
        }
    }
}
