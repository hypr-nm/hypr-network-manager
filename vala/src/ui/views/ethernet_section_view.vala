// SPDX-License-Identifier: GPL-3.0-or-later
using GLib;
using Gtk;
using NetworkManagerRebuild.UI.Interfaces;

namespace NetworkManagerRebuild.UI.Views {
    public class EthernetSectionView : Object {
        public Gtk.Widget widget { get; private set; }
        public Gtk.Stack stack { get; private set; }
        public Gtk.ListBox listbox { get; private set; }

        private MainWindowEthernetController controller;

        public EthernetSectionView (MainWindowEthernetController controller) {
            this.controller = controller;

            var ethernet_details_page = new MainWindowEthernetDetailsPage ();
            var ethernet_edit_page = new MainWindowEthernetEditPage ();

            ethernet_details_page.back.connect (() => {
                controller.on_details_back_requested ();
            });
            ethernet_details_page.primary_action.connect (() => {
                controller.on_details_primary_requested ();
            });
            ethernet_details_page.edit.connect (() => {
                controller.on_details_edit_requested ();
            });

            ethernet_edit_page.back.connect (() => {
                controller.on_edit_back_requested ();
            });
            ethernet_edit_page.apply.connect (() => {
                controller.on_edit_apply_requested ();
            });

            Gtk.ListBox ethernet_listbox;
            Gtk.Stack ethernet_stack_local;
            var page = MainWindowEthernetPageBuilder.build_page (
                out ethernet_listbox,
                out ethernet_stack_local,
                ethernet_details_page,
                ethernet_edit_page,
                controller
            );

            this.listbox = ethernet_listbox;
            this.stack = ethernet_stack_local;
            this.widget = page;

            var ethernet_view_context = new MainWindowEthernetViewContext (
                page,
                ethernet_listbox,
                ethernet_stack_local,
                ethernet_details_page,
                ethernet_edit_page
            );

            controller.configure_page (ethernet_view_context);
        }

        public void reset_view_state () {
            if (stack != null) {
                stack.set_visible_child_name ("list");
            }
        }
    }
}
