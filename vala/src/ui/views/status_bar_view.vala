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
namespace HyprNetworkManager.UI.Views {

    public class StatusBarView : Object {
        public Gtk.Box root_widget { get; private set; }
        public Gtk.Label status_label { get; private set; }
        public Gtk.Image status_icon { get; private set; }

        public StatusBarView () {
            build_ui ();
        }

        private void build_ui () {
            root_widget = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            MainWindowCssClassResolver.add_best_class (root_widget, {MainWindowCssClasses.TOOLBAR_INSET,
                MainWindowCssClasses.PAGE_SHELL_INSET});
            MainWindowCssClassResolver.add_best_class (root_widget, {MainWindowCssClasses.STATUS_BAR,
                MainWindowCssClasses.TOOLBAR});

            status_icon = new Gtk.Image.from_icon_name ("network-wireless-offline-symbolic");
            MainWindowCssClassResolver.add_best_class (status_icon, {MainWindowCssClasses.ICON_SIZE_16,
                MainWindowCssClasses.ICON_SIZE});
            MainWindowCssClassResolver.add_best_class (status_icon, {MainWindowCssClasses.STATUS_ICON,
                MainWindowCssClasses.ICON_SIZE});
            root_widget.append (status_icon);

            status_label = new Gtk.Label (_("Loading networks…"));
            status_label.set_xalign (0.0f);
            status_label.set_hexpand (true);
            status_label.add_css_class (MainWindowCssClasses.STATUS_LABEL);
            root_widget.append (status_label);
        }
    }
}
