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
