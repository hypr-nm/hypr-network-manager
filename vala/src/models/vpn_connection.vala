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
public class VpnConnection : Object {
    public string uuid { get; construct set; }
    public string name { get; construct set; }
    public string state { get; construct set; }
    public string vpn_type { get; construct set; }
    public bool autoconnect { get; set; default = true; }

    public bool is_connected {
        get {
            return state == "activated" || state == "connected";
        }
    }
}
