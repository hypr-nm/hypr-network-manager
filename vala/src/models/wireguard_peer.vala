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
using GLib;

public class WireGuardPeerModel : Object {
    public string name { get; set; default = ""; }
    public string public_key { get; set; default = ""; }
    public string endpoint_host { get; set; default = ""; }
    public uint32 endpoint_port { get; set; default = 0; }
    public string[] allowed_ips { get; set; default = {}; }
    public string preshared_key { get; set; default = ""; }
}
