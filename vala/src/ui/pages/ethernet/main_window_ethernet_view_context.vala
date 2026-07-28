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

public class MainWindowEthernetViewContext : Object {
    public Gtk.Widget page { get; set; }
    public Gtk.ListBox listbox { get; set; }
    public Gtk.Stack stack { get; set; }
    public MainWindowEthernetDetailsPage details_page { get; set; }
    public MainWindowEthernetEditPage edit_page { get; set; }

    public MainWindowEthernetViewContext (
        Gtk.Widget page,
        Gtk.ListBox listbox,
        Gtk.Stack stack,
        MainWindowEthernetDetailsPage details_page,
        MainWindowEthernetEditPage edit_page
    ) {
        this.page = page;
        this.listbox = listbox;
        this.stack = stack;
        this.details_page = details_page;
        this.edit_page = edit_page;
    }
}
