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

public class MainWindowIpConfigHelper : Object {
    public static uint method_to_index (string method, bool is_ipv4 = true) {
        string m = method.down ();
        if (is_ipv4) {
            if (m == "auto") return 0;
            if (m == "manual") return 1;
            if (m == "disabled") return 2;
            return 0;
        } else {
            if (m == "auto") return 0;
            if (m == "manual") return 1;
            if (m == "disabled") return 2;
            if (m == "ignore") return 3;
            return 0;
        }
    }

    public static string index_to_method (uint index, bool is_ipv4 = true) {
        if (is_ipv4) {
            switch (index) {
                case 0: return "auto";
                case 1: return "manual";
                case 2: return "disabled";
                default: return "auto";
            }
        } else {
            switch (index) {
                case 0: return "auto";
                case 1: return "manual";
                case 2: return "disabled";
                case 3: return "ignore";
                default: return "auto";
            }
        }
    }
}
