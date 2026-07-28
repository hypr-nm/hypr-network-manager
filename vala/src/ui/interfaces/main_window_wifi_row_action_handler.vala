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

public interface IMainWindowWifiRowActionHandler : Object {
    public abstract void open_details (WifiNetwork net);
    public abstract void forget_saved_network (WifiNetwork net);
    public abstract void disconnect_network (WifiNetwork net);
    public abstract void connect_network (WifiNetwork net, string? password, string? hidden_ssid, bool autoconnect);
    public abstract void set_auto_connect (WifiNetwork net, bool auto_connect);
    public abstract void show_password_prompt (WifiNetwork net, Gtk.Revealer revealer, Gtk.Entry entry);
    public abstract void hide_password_prompt (Gtk.Revealer revealer, Gtk.Entry entry, string? value);
}
