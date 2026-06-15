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

namespace MainWindowIpSensitivityRules {
    public bool should_show_manual_fields (uint selected_method) {
        return selected_method == 1;
    }

    public bool should_show_override_fields (uint selected_method) {
        return selected_method == 0 || selected_method == 1;
    }

    public bool should_force_ipv4_dns_auto_from_dropdown (uint selected_method) {
        return selected_method == 2;
    }

    public bool should_force_ipv6_dns_auto_from_dropdown (uint selected_method) {
        return selected_method == 2 || selected_method == 3;
    }

    public bool is_dns_entry_sensitive (bool dns_auto_enabled) {
        return !dns_auto_enabled;
    }

    public bool should_force_ipv4_dns_auto_from_method (string method) {
        return method == "disabled";
    }

    public bool should_force_ipv6_dns_auto_from_method (string method) {
        return method == "disabled" || method == "ignore";
    }
}
