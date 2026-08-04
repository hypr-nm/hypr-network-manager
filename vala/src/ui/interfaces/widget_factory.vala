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
namespace HyprNetworkManager.UI.Interfaces {
    public delegate HyprNetworkManager.UI.Widgets.TrackedDropDown TrackedDropDownFactory (
        owned Gtk.StringList model
    );

    /**
     * Provides GTK widget construction for views and pages.
     *
     * Deliberately kept separate from IWindowHost so that the host interface
     * exposed to controllers carries no GTK types.
     */
    public interface IWidgetFactory : Object {
        public abstract HyprNetworkManager.UI.Widgets.TrackedDropDown create_tracked_dropdown (
            owned Gtk.StringList model
        );
        public abstract void set_popup_text_input_mode (bool enabled);
    }

    /**
     * Combined host + widget factory for views that need both.
     *
     * View-only: controllers must depend on IWindowHost, never IUiHost, so the
     * GTK surface stays out of the controller layer.
     */
    public interface IUiHost : IWindowHost, IWidgetFactory {
    }
}
