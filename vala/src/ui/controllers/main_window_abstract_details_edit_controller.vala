using GLib;
using Gtk;

public abstract class MainWindowAbstractDetailsEditController : Object {
    protected bool is_disposed = false;
    protected uint ui_epoch = 1;
    protected Cancellable? details_request_cancellable = null;
    protected Cancellable? edit_request_cancellable = null;

    protected NetworkManagerRebuild.UI.Interfaces.IWindowHost host;

    protected MainWindowAbstractDetailsEditController (NetworkManagerRebuild.UI.Interfaces.IWindowHost host) {
        this.host = host;
    }

    public virtual void on_page_leave () {
        invalidate_ui_state ();
    }

    public virtual void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        invalidate_ui_state ();
    }

    protected uint capture_ui_epoch () {
        return ui_epoch;
    }

    protected bool is_ui_epoch_valid (uint epoch) {
        return !is_disposed && epoch == ui_epoch;
    }

    protected virtual void invalidate_ui_state () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_details_request ();
        cancel_edit_request ();
    }

    protected bool is_cancelled_error (Error e) {
        return e is IOError.CANCELLED;
    }

    protected void cancel_details_request () {
        if (details_request_cancellable != null) {
            details_request_cancellable.cancel ();
            details_request_cancellable = null;
        }
    }

    protected void cancel_edit_request () {
        if (edit_request_cancellable != null) {
            edit_request_cancellable.cancel ();
            edit_request_cancellable = null;
        }
    }

    public void sync_edit_gateway_dns_sensitivity (IMainWindowIpEditPage page) {
        if (page.ipv4_method_dropdown != null) {
            uint selected = page.ipv4_method_dropdown.get_selected ();
            if (MainWindowIpSensitivityRules.should_force_ipv4_dns_auto_from_dropdown (selected)
                && page.dns_auto_switch != null) {
                page.dns_auto_switch.set_active (true);
            }
        }

        if (page.ipv6_method_dropdown != null) {
            uint selected = page.ipv6_method_dropdown.get_selected ();
            if (MainWindowIpSensitivityRules.should_force_ipv6_dns_auto_from_dropdown (selected)
                && page.ipv6_dns_auto_switch != null) {
                page.ipv6_dns_auto_switch.set_active (true);
            }
        }

        if (page.ipv4_dns_entry != null && page.dns_auto_switch != null) {
            page.ipv4_dns_entry.set_sensitive (
                MainWindowIpSensitivityRules.is_dns_entry_sensitive (page.dns_auto_switch.get_active ())
            );
        }

        if (page.ipv6_dns_entry != null && page.ipv6_dns_auto_switch != null) {
            page.ipv6_dns_entry.set_sensitive (
                MainWindowIpSensitivityRules.is_dns_entry_sensitive (page.ipv6_dns_auto_switch.get_active ())
            );
        }
    }

    protected void populate_ip_settings_to_form (NetworkIpSettings ip_settings, IMainWindowIpEditPage page) {
        page.ipv4_method_dropdown.set_selected (
            MainWindowHelpers.get_ipv4_method_dropdown_index (ip_settings.ipv4_method)
        );
        page.ipv4_address_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_address));
        page.ipv4_prefix_entry.set_text (
            ip_settings.configured_prefix > 0 ? "%u".printf (ip_settings.configured_prefix) : ""
        );
        page.ipv4_gateway_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_gateway));
        page.dns_auto_switch.set_active (ip_settings.dns_auto);
        page.ipv4_dns_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_dns));
        page.ipv6_method_dropdown.set_selected (
            MainWindowHelpers.get_ipv6_method_dropdown_index (ip_settings.ipv6_method)
        );
        page.ipv6_address_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_ipv6_address));
        page.ipv6_prefix_entry.set_text (
            ip_settings.configured_ipv6_prefix > 0 ? "%u".printf (ip_settings.configured_ipv6_prefix) : ""
        );
        page.ipv6_gateway_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_ipv6_gateway));
        page.ipv6_dns_auto_switch.set_active (ip_settings.ipv6_dns_auto);
        page.ipv6_dns_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_ipv6_dns));

        sync_edit_gateway_dns_sensitivity (page);
    }

    protected void append_ip_details_rows (NetworkIpSettings ip_settings, bool is_connected, Gtk.Box ip_rows) {
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                "Configured IPv4 Method",
                MainWindowHelpers.get_ipv4_method_label (ip_settings.ipv4_method)
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                "Configured IPv4 Address",
                MainWindowHelpers.format_ip_with_prefix (
                    ip_settings.configured_address,
                    ip_settings.configured_prefix
                )
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                "Configured Gateway",
                MainWindowHelpers.display_text_or_na (ip_settings.configured_gateway)
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                "Configured DNS",
                MainWindowHelpers.display_text_or_na (ip_settings.configured_dns)
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                "Configured IPv6 Method",
                MainWindowHelpers.get_ipv6_method_label (ip_settings.ipv6_method)
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                "Configured IPv6 Address",
                MainWindowHelpers.format_ip_with_prefix (
                    ip_settings.configured_ipv6_address,
                    ip_settings.configured_ipv6_prefix
                )
            )
        );
        ip_rows.append (
            MainWindowHelpers.build_details_row (
                "Configured IPv6 Gateway",
                MainWindowHelpers.display_text_or_na (ip_settings.configured_ipv6_gateway)
            )
        );

        if (is_connected) {
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Current IPv4 Address",
                    MainWindowHelpers.format_ip_with_prefix (
                        ip_settings.current_address,
                        ip_settings.current_prefix
                    )
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Current Gateway",
                    MainWindowHelpers.display_text_or_na (ip_settings.current_gateway)
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Current DNS",
                    MainWindowHelpers.display_text_or_na (ip_settings.current_dns)
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Current IPv6 Address",
                    MainWindowHelpers.format_ip_with_prefix (
                        ip_settings.current_ipv6_address,
                        ip_settings.current_ipv6_prefix
                    )
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Current IPv6 Gateway",
                    MainWindowHelpers.display_text_or_na (ip_settings.current_ipv6_gateway)
                )
            );
            ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Current IPv6 DNS",
                    MainWindowHelpers.display_text_or_na (ip_settings.current_ipv6_dns)
                )
            );
        }
    }

    protected NetworkIpUpdateRequest? build_ip_update_request (IMainWindowIpEditPage page) {
        string method = MainWindowWifiEditUtils.get_selected_ipv4_method (page.ipv4_method_dropdown);
        string ipv4_address = page.ipv4_address_entry.get_text ().strip ();
        string ipv4_gateway = page.ipv4_gateway_entry.get_text ().strip ();
        bool gateway_auto = method != "manual";
        bool dns_auto = page.dns_auto_switch.get_active ();
        string dns_csv = page.ipv4_dns_entry.get_text ().strip ();
        string method6 = MainWindowWifiEditUtils.get_selected_ipv6_method (page.ipv6_method_dropdown);
        string ipv6_address = page.ipv6_address_entry.get_text ().strip ();
        string ipv6_gateway = page.ipv6_gateway_entry.get_text ().strip ();
        bool ipv6_gateway_auto = method6 != "manual";
        bool ipv6_dns_auto = page.ipv6_dns_auto_switch.get_active ();
        string ipv6_dns_csv = page.ipv6_dns_entry.get_text ().strip ();

        if (MainWindowIpSensitivityRules.should_force_ipv4_dns_auto_from_method (method)) {
            dns_auto = true;
        }

        if (MainWindowIpSensitivityRules.should_force_ipv6_dns_auto_from_method (method6)) {
            ipv6_dns_auto = true;
        }

        uint32 ipv4_prefix;
        string prefix_error;
        if (!MainWindowWifiEditUtils.try_parse_prefix (
            page.ipv4_prefix_entry.get_text (),
            out ipv4_prefix,
            out prefix_error
        )) {
            host.show_error (prefix_error);
            return null;
        }

        uint32 ipv6_prefix;
        string prefix6_error;
        if (!MainWindowWifiEditUtils.try_parse_ipv6_prefix (
            page.ipv6_prefix_entry.get_text (),
            out ipv6_prefix,
            out prefix6_error
        )) {
            host.show_error (prefix6_error);
            return null;
        }

        if (method == "manual") {
            if (ipv4_address == "") {
                host.show_error ("Manual IPv4 requires an address.");
                return null;
            }
            if (ipv4_prefix == 0) {
                host.show_error ("Manual IPv4 requires a prefix between 1 and 32.");
                return null;
            }
            if (ipv4_gateway == "") {
                host.show_error ("Manual IPv4 requires a gateway address.");
                return null;
            }
        }

        string[] dns_servers = MainWindowWifiEditUtils.parse_dns_csv (dns_csv);
        if (!dns_auto && dns_servers.length == 0) {
            host.show_error ("Manual DNS is enabled; provide at least one DNS server.");
            return null;
        }

        if (method6 == "manual") {
            if (ipv6_address == "") {
                host.show_error ("Manual IPv6 requires an address.");
                return null;
            }
            if (ipv6_prefix == 0) {
                host.show_error ("Manual IPv6 requires a prefix between 1 and 128.");
                return null;
            }
            if (ipv6_gateway == "") {
                host.show_error ("Manual IPv6 requires a gateway address.");
                return null;
            }
        }

        string[] ipv6_dns_servers = MainWindowWifiEditUtils.parse_dns_csv (ipv6_dns_csv);
        if (!ipv6_dns_auto && ipv6_dns_servers.length == 0) {
            host.show_error ("Manual IPv6 DNS is enabled; provide at least one DNS server.");
            return null;
        }

        return new NetworkIpUpdateRequest () {
            ipv4_method = method,
            ipv4_address = ipv4_address,
            ipv4_prefix = ipv4_prefix,
            ipv4_gateway_auto = gateway_auto,
            ipv4_gateway = ipv4_gateway,
            ipv4_dns_auto = dns_auto,
            ipv4_dns_servers = dns_servers,
            ipv6_method = method6,
            ipv6_address = ipv6_address,
            ipv6_prefix = ipv6_prefix,
            ipv6_gateway_auto = ipv6_gateway_auto,
            ipv6_gateway = ipv6_gateway,
            ipv6_dns_auto = ipv6_dns_auto,
            ipv6_dns_servers = ipv6_dns_servers
        };
    }
}
