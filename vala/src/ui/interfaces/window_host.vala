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

namespace HyprNetworkManager.UI.Interfaces {
    public delegate HyprNetworkManager.UI.Widgets.TrackedDropDown TrackedDropDownFactory (
        owned Gtk.StringList model
    );

    /**
     * Interface that provides window operations back to the controllers.
     */
    public interface IWindowHost : Object {
        public abstract HyprNetworkManager.UI.Widgets.TrackedDropDown create_tracked_dropdown (
            owned Gtk.StringList model
        );
        public abstract void set_popup_text_input_mode (bool enabled);
        public abstract void show_error (string message);
        public abstract void show_wifi_error (string net_key, string message);
        public abstract void show_ethernet_error (string iface_name, string message);
        public abstract void show_vpn_error (string vpn_name, string message);
        public abstract void show_edit_page_error (string message);
        public abstract void show_add_page_error (string message);
        public abstract void refresh_after_action (bool request_wifi_scan);
        public abstract void refresh_all ();
        public abstract void refresh_switch_states ();
        public abstract void hide_active_wifi_password_prompt ();
        public abstract void debug_log (string message);
        public abstract void close_window ();
    }
}
