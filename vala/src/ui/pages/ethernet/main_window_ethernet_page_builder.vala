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

using Constants;
using Gtk;

namespace MainWindowEthernetPageBuilder {
    private Gtk.Widget build_placeholder (MainWindowIconResources.NetworkPlaceholderIcon icon_type, string label_text) {
        var placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        placeholder.set_halign (Gtk.Align.CENTER);
        placeholder.set_valign (Gtk.Align.CENTER);
        placeholder.add_css_class (MainWindowCssClasses.EMPTY_STATE);

        var icon = MainWindowIconResources.create_network_placeholder_icon (icon_type);
        icon.add_css_class (MainWindowCssClasses.ICON_SIZE_24);
        icon.add_css_class (MainWindowCssClasses.ICON_SIZE);
        icon.add_css_class (MainWindowCssClasses.ETHERNET_PLACEHOLDER_ICON);
        icon.add_css_class (MainWindowCssClasses.PLACEHOLDER_ICON);

        var label = new Gtk.Label (label_text);
        label.add_css_class (MainWindowCssClasses.PLACEHOLDER_LABEL);

        placeholder.append (icon);
        placeholder.append (label);
        return placeholder;
    }

    public Gtk.Widget build_page (
        out Gtk.ListBox ethernet_listbox,
        out Gtk.Stack ethernet_stack,
        out Gtk.Button refresh_button,
        out HyprNetworkManager.UI.Widgets.MainWindowRefreshProgressController progress_controller,
        Gtk.Widget details_page,
        Gtk.Widget edit_page,
        MainWindowEthernetController controller
    ) {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        page.add_css_class (MainWindowCssClasses.PAGE);
        page.add_css_class (MainWindowCssClasses.PAGE_ETHERNET);

        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        toolbar.add_css_class (MainWindowCssClasses.TOOLBAR_INSET);
        toolbar.add_css_class (MainWindowCssClasses.PAGE_SHELL_INSET);
        toolbar.add_css_class (MainWindowCssClasses.TOOLBAR);
        toolbar.add_css_class (MainWindowCssClasses.STATUS_BAR);

        var title = new Gtk.Label (_("Ethernet"));
        title.set_xalign (0.0f);
        title.set_valign (Gtk.Align.CENTER);
        title.set_hexpand (true);
        title.add_css_class (MainWindowCssClasses.SECTION_TITLE);
        toolbar.append (title);

        var refresh_btn = new Gtk.Button.with_label (_("Refresh"));
        refresh_btn.add_css_class (MainWindowCssClasses.BUTTON);
        refresh_btn.add_css_class (MainWindowCssClasses.TOOLBAR_ACTION);
        refresh_btn.add_css_class (MainWindowCssClasses.REFRESH_BUTTON);
        refresh_btn.set_valign (Gtk.Align.CENTER);
        refresh_btn.set_tooltip_text (_("Refresh Ethernet devices"));
        refresh_btn.clicked.connect (() => {
            controller.refresh ();
        });
        toolbar.append (refresh_btn);
        refresh_button = refresh_btn;

        page.append (toolbar);

        var prog = new Gtk.ProgressBar ();
        page.append (prog);
        progress_controller = new HyprNetworkManager.UI.Widgets.MainWindowRefreshProgressController (prog);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class (MainWindowCssClasses.SCROLL);

        ethernet_listbox = new Gtk.ListBox ();
        ethernet_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
        ethernet_listbox.add_css_class (MainWindowCssClasses.LIST);
        scroll.set_child (ethernet_listbox);

        ethernet_stack = new Gtk.Stack ();
        ethernet_stack.set_vexpand (true);
        ethernet_stack.add_css_class (MainWindowCssClasses.CONTENT_STACK);
        ethernet_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        ethernet_stack.set_transition_duration (MainWindowUiMetrics.TRANSITION_STACK_MS);
        ethernet_stack.add_named (scroll, "list");
        ethernet_stack.add_named (
            build_placeholder (
                MainWindowIconResources.NetworkPlaceholderIcon.ETHERNET_EMPTY,
                _("No Ethernet devices found")
            ),
            "empty"
        );
        ethernet_stack.add_named (
            build_placeholder (
                MainWindowIconResources.NetworkPlaceholderIcon.FLIGHT_MODE,
                _("Flight mode is on")
            ),
            "flight-mode"
        );
        ethernet_stack.add_named (details_page, "details");
        ethernet_stack.add_named (edit_page, "edit");
        ethernet_stack.set_visible_child_name ("empty");
        var ethernet_stack_ref = ethernet_stack;

        ethernet_stack_ref.notify["visible-child-name"].connect (() => {
            string page_name = ethernet_stack_ref.get_visible_child_name ();
            bool show_toolbar = page_name == "list" || page_name == "empty" || page_name == "flight-mode";
            toolbar.set_visible (show_toolbar);
        });

        string initial_page_name = ethernet_stack_ref.get_visible_child_name ();
        bool show_toolbar_initial = initial_page_name == "list" || initial_page_name == "empty"
            || initial_page_name == "flight-mode";
        toolbar.set_visible (show_toolbar_initial);

        page.append (ethernet_stack);
        return page;
    }
}
