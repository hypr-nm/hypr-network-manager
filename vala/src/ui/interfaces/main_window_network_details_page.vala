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

public interface IMainWindowNetworkDetailsPage : Object {
    public abstract Gtk.Label details_title { get; set; }
    public abstract Gtk.ListBox basic_rows { get; set; }
    public abstract Gtk.ListBox advanced_rows { get; set; }
    public abstract Gtk.ListBox ip_rows { get; set; }
    public abstract Gtk.Button edit_button { get; set; }

    public virtual void render_ip_settings (NetworkIpSettings settings, bool is_connected) {
        MainWindowHelpers.clear_listbox (this.ip_rows);
        MainWindowIpDetailsRowBuilder.populate_ip_rows (this.ip_rows, settings, is_connected);
    }

    public virtual void show_loading_ip () {
        MainWindowHelpers.clear_listbox (this.ip_rows);
        this.ip_rows.append (MainWindowHelpers.build_details_row (_("Loading"), "Reading IP settings…"));
    }
}
