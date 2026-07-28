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

public class MainWindowIpDetailsRowBuilder {
    public static void populate_ip_rows (Gtk.ListBox ip_rows, NetworkIpSettings ip_settings, bool is_connected) {
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                _("Configured IPv4 Method"),
                MainWindowHelpers.get_ipv4_method_label (ip_settings.ipv4_method)
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                _("Configured IPv4 Address"),
                MainWindowHelpers.format_ip_with_prefix (
                    ip_settings.configured_address,
                    ip_settings.configured_prefix
                )
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                _("Configured Gateway"),
                MainWindowHelpers.display_text_or_na (ip_settings.configured_gateway)
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                _("Configured DNS"),
                MainWindowHelpers.display_text_or_na (ip_settings.configured_dns)
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                _("Configured IPv6 Method"),
                MainWindowHelpers.get_ipv6_method_label (ip_settings.ipv6_method)
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                _("Configured IPv6 Address"),
                MainWindowHelpers.format_ip_with_prefix (
                    ip_settings.configured_ipv6_address,
                    ip_settings.configured_ipv6_prefix
                )
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                _("Configured IPv6 Gateway"),
                MainWindowHelpers.display_text_or_na (ip_settings.configured_ipv6_gateway)
            )
        );

        if (is_connected) {
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    _("Current IPv4 Address"),
                    MainWindowHelpers.format_ip_with_prefix (
                        ip_settings.current_address,
                        ip_settings.current_prefix
                    )
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    _("Current Gateway"),
                    MainWindowHelpers.display_text_or_na (ip_settings.current_gateway)
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    _("Current DNS"),
                    MainWindowHelpers.display_text_or_na (ip_settings.current_dns)
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    _("Current IPv6 Address"),
                    MainWindowHelpers.format_ip_with_prefix (
                        ip_settings.current_ipv6_address,
                        ip_settings.current_ipv6_prefix
                    )
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    _("Current IPv6 Gateway"),
                    MainWindowHelpers.display_text_or_na (ip_settings.current_ipv6_gateway)
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    _("Current IPv6 DNS"),
                    MainWindowHelpers.display_text_or_na (ip_settings.current_ipv6_dns)
                )
            );
        }
    }
}
