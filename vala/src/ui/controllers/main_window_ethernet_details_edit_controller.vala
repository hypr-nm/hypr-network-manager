public class MainWindowEthernetDetailsEditController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private Cancellable? details_ip_cancellable = null;
    private Cancellable? edit_ip_cancellable = null;

    private NetworkManagerClient nm;
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;

    public signal void complete_profile_edit_mode ();

    public NetworkDevice? selected_device { get; set; default = null; }

    public MainWindowEthernetDetailsEditController (NetworkManagerClient nm, NetworkManagerRebuild.UI.Interfaces.IWindowHost host) {
        this.nm = nm;
        this.host = host;
    }

    public void on_page_leave () {
        invalidate_ui_state ();
    }

    public void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        invalidate_ui_state ();
    }

    private uint capture_ui_epoch () {
        return ui_epoch;
    }

    private bool is_ui_epoch_valid (uint epoch) {
        return !is_disposed && epoch == ui_epoch;
    }

    private void invalidate_ui_state () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_details_request ();
        cancel_edit_request ();
    }

    private void cancel_details_request () {
        if (details_ip_cancellable != null) {
            details_ip_cancellable.cancel ();
            details_ip_cancellable = null;
        }
    }

    private void cancel_edit_request () {
        if (edit_ip_cancellable != null) {
            edit_ip_cancellable.cancel ();
            edit_ip_cancellable = null;
        }
    }

    public void sync_edit_gateway_dns_sensitivity (MainWindowEthernetEditPage ethernet_edit_page) {
        if (ethernet_edit_page.ipv4_method_dropdown != null) {
            uint selected = ethernet_edit_page.ipv4_method_dropdown.get_selected ();
            if (MainWindowIpSensitivityRules.should_force_ipv4_dns_auto_from_dropdown (selected)) {
                if (ethernet_edit_page.dns_auto_switch != null) {
                    ethernet_edit_page.dns_auto_switch.set_active (true);
                }
            }
        }

        if (ethernet_edit_page.ipv6_method_dropdown != null) {
            uint selected = ethernet_edit_page.ipv6_method_dropdown.get_selected ();
            if (MainWindowIpSensitivityRules.should_force_ipv6_dns_auto_from_dropdown (selected)) {
                if (ethernet_edit_page.ipv6_dns_auto_switch != null) {
                    ethernet_edit_page.ipv6_dns_auto_switch.set_active (true);
                }
            }
        }

        if (ethernet_edit_page.ipv4_dns_entry != null && ethernet_edit_page.dns_auto_switch != null) {
            ethernet_edit_page.ipv4_dns_entry.set_sensitive (
                MainWindowIpSensitivityRules.is_dns_entry_sensitive (ethernet_edit_page.dns_auto_switch.get_active ())
            );
        }
        if (ethernet_edit_page.ipv6_dns_entry != null && ethernet_edit_page.ipv6_dns_auto_switch != null) {
            ethernet_edit_page.ipv6_dns_entry.set_sensitive (
                MainWindowIpSensitivityRules.is_dns_entry_sensitive (
                    ethernet_edit_page.ipv6_dns_auto_switch.get_active ()
                )
            );
        }
    }

    public void populate_details (
        NetworkDevice dev,
        MainWindowEthernetDetailsPage ethernet_details_page,
        MainWindowEthernetConnectionController connection_controller
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_details_request ();
        details_ip_cancellable = new Cancellable ();
        var details_request = details_ip_cancellable;
        ethernet_details_page.details_title.set_text (MainWindowHelpers.safe_text (dev.name));

        MainWindowHelpers.clear_box (ethernet_details_page.basic_rows);
        MainWindowHelpers.clear_box (ethernet_details_page.advanced_rows);
        MainWindowHelpers.clear_box (ethernet_details_page.ip_rows);

        string profile_name = MainWindowHelpers.display_text_or_na (dev.connection);
        bool has_profile = connection_controller.has_saved_profile (dev);
        bool pending = connection_controller.pending_action.contains (dev.name);

        ethernet_details_page.basic_rows.append (MainWindowHelpers.build_details_row ("Interface", dev.name));
        ethernet_details_page.basic_rows.append (MainWindowHelpers.build_details_row ("Profile", profile_name));
        ethernet_details_page.basic_rows.append (MainWindowHelpers.build_details_row ("State", dev.state_label));
        ethernet_details_page.basic_rows.append (
            MainWindowHelpers.build_details_row ("Connected", dev.is_connected ? "Yes" : "No")
        );

        ethernet_details_page.advanced_rows.append (
            MainWindowHelpers.build_details_row ("Device Path", dev.device_path)
        );
        ethernet_details_page.advanced_rows.append (
            MainWindowHelpers.build_details_row ("State Code", "%u".printf (dev.state))
        );

        ethernet_details_page.ip_rows.append (MainWindowHelpers.build_details_row ("Loading", "Reading IP settings…"));

        nm.get_ethernet_device_ip_settings.begin (dev, details_request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            if (this.selected_device == null
                || (this.selected_device.device_path != dev.device_path
                    && this.selected_device.name != dev.name)) {
                return;
            }

            NetworkIpSettings ip_settings = nm.get_ethernet_device_ip_settings.end (res);

            MainWindowHelpers.clear_box (ethernet_details_page.ip_rows);
            ethernet_details_page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv4 Method",
                    MainWindowHelpers.get_ipv4_method_label (ip_settings.ipv4_method)
                )
            );
            ethernet_details_page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv4 Address",
                    MainWindowHelpers.format_ip_with_prefix (
                        ip_settings.configured_address,
                        ip_settings.configured_prefix
                    )
                )
            );
            ethernet_details_page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured Gateway",
                    MainWindowHelpers.display_text_or_na (ip_settings.configured_gateway)
                )
            );
            ethernet_details_page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured DNS",
                    MainWindowHelpers.display_text_or_na (ip_settings.configured_dns)
                )
            );
            ethernet_details_page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv6 Method",
                    MainWindowHelpers.get_ipv6_method_label (ip_settings.ipv6_method)
                )
            );
            ethernet_details_page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv6 Address",
                    MainWindowHelpers.format_ip_with_prefix (
                        ip_settings.configured_ipv6_address,
                        ip_settings.configured_ipv6_prefix
                    )
                )
            );
            ethernet_details_page.ip_rows.append (
                MainWindowHelpers.build_details_row (
                    "Configured IPv6 Gateway",
                    MainWindowHelpers.display_text_or_na (ip_settings.configured_ipv6_gateway)
                )
            );

            if (dev.is_connected) {
                ethernet_details_page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current IPv4 Address",
                        MainWindowHelpers.format_ip_with_prefix (
                            ip_settings.current_address,
                            ip_settings.current_prefix
                        )
                    )
                );
                ethernet_details_page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current Gateway",
                        MainWindowHelpers.display_text_or_na (ip_settings.current_gateway)
                    )
                );
                ethernet_details_page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current DNS",
                        MainWindowHelpers.display_text_or_na (ip_settings.current_dns)
                    )
                );
                ethernet_details_page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current IPv6 Address",
                        MainWindowHelpers.format_ip_with_prefix (
                            ip_settings.current_ipv6_address,
                            ip_settings.current_ipv6_prefix
                        )
                    )
                );
                ethernet_details_page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current IPv6 Gateway",
                        MainWindowHelpers.display_text_or_na (ip_settings.current_ipv6_gateway)
                    )
                );
                ethernet_details_page.ip_rows.append (
                    MainWindowHelpers.build_details_row (
                        "Current IPv6 DNS",
                        MainWindowHelpers.display_text_or_na (ip_settings.current_ipv6_dns)
                    )
                );
            }
        });

        if (pending) {
            ethernet_details_page.primary_button.set_label ("Updating…");
            ethernet_details_page.primary_button.set_sensitive (false);
        } else if (dev.is_connected) {
            ethernet_details_page.primary_button.set_label ("Disconnect");
            ethernet_details_page.primary_button.set_sensitive (true);
        } else if (connection_controller.can_connect_with_profile (dev)) {
            ethernet_details_page.primary_button.set_label ("Connect");
            ethernet_details_page.primary_button.set_sensitive (true);
        } else if (has_profile) {
            ethernet_details_page.primary_button.set_label ("Unavailable");
            ethernet_details_page.primary_button.set_sensitive (false);
        } else {
            ethernet_details_page.primary_button.set_label ("No Profile");
            ethernet_details_page.primary_button.set_sensitive (false);
        }

        ethernet_details_page.edit_button.set_sensitive (has_profile && !pending);
    }

    public void open_details (
        NetworkDevice dev,
        Gtk.Stack ethernet_stack,
        MainWindowEthernetDetailsPage ethernet_details_page,
        MainWindowEthernetConnectionController connection_controller
    ) {
        this.selected_device = dev;
        populate_details (dev, ethernet_details_page, connection_controller);
        ethernet_stack.set_visible_child_name ("details");
    }

    public void open_edit (
        NetworkDevice dev,
        Gtk.Stack ethernet_stack,
        MainWindowEthernetEditPage ethernet_edit_page,
        MainWindowEthernetConnectionController connection_controller
    ) {
        if (!connection_controller.has_saved_profile (dev)) {
            host.show_error ("This interface has no saved Ethernet profile to edit.");
            return;
        }

        cancel_details_request ();
        cancel_edit_request ();
        this.selected_device = dev;
        uint epoch = capture_ui_epoch ();
        edit_ip_cancellable = new Cancellable ();
        var edit_request = edit_ip_cancellable;
        ethernet_edit_page.edit_title.set_text ("Edit: %s".printf (dev.name));
        string profile_display = MainWindowHelpers.safe_text (dev.connection).strip ();
        if (profile_display == "") {
            profile_display = "Profile %s".printf (MainWindowHelpers.safe_text (dev.connection_uuid));
        }
        ethernet_edit_page.note_label.set_text ("Update IPv4 and IPv6 settings for profile: %s".printf (profile_display));

        ethernet_stack.set_visible_child_name ("edit");
        host.set_popup_text_input_mode (true);

        nm.get_ethernet_device_ip_settings.begin (dev, edit_request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            if (this.selected_device == null
                || (this.selected_device.device_path != dev.device_path
                    && this.selected_device.name != dev.name)) {
                return;
            }

            NetworkIpSettings ip_settings = nm.get_ethernet_device_ip_settings.end (res);

            ethernet_edit_page.ipv4_method_dropdown.set_selected (
                MainWindowHelpers.get_ipv4_method_dropdown_index (ip_settings.ipv4_method)
            );
            ethernet_edit_page.ipv4_address_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_address));
            ethernet_edit_page.ipv4_prefix_entry.set_text (
                ip_settings.configured_prefix > 0 ? "%u".printf (ip_settings.configured_prefix) : ""
            );
            ethernet_edit_page.ipv4_gateway_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_gateway));
            ethernet_edit_page.dns_auto_switch.set_active (ip_settings.dns_auto);
            ethernet_edit_page.ipv4_dns_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_dns));
            ethernet_edit_page.ipv6_method_dropdown.set_selected (
                MainWindowHelpers.get_ipv6_method_dropdown_index (ip_settings.ipv6_method)
            );
            ethernet_edit_page.ipv6_address_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_ipv6_address));
            ethernet_edit_page.ipv6_prefix_entry.set_text (
                ip_settings.configured_ipv6_prefix > 0 ? "%u".printf (ip_settings.configured_ipv6_prefix) : ""
            );
            ethernet_edit_page.ipv6_gateway_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_ipv6_gateway));
            ethernet_edit_page.ipv6_dns_auto_switch.set_active (ip_settings.ipv6_dns_auto);
            ethernet_edit_page.ipv6_dns_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_ipv6_dns));

            sync_edit_gateway_dns_sensitivity (ethernet_edit_page);
            ethernet_edit_page.ipv4_address_entry.grab_focus ();
        });
    }

    public void apply_edit (
        MainWindowEthernetEditPage ethernet_edit_page,
        MainWindowEthernetConnectionController connection_controller,
        bool profile_edit_mode,
        MainWindowEthernetDetailsPage ethernet_details_page,
        Gtk.Stack ethernet_stack
    ) {
        if (this.selected_device == null) {
            return;
        }

        uint epoch = capture_ui_epoch ();
        NetworkDevice dev = this.selected_device;
        string method = MainWindowWifiEditUtils.get_selected_ipv4_method (
            ethernet_edit_page.ipv4_method_dropdown
        );
        string ipv4_address = ethernet_edit_page.ipv4_address_entry.get_text ().strip ();
        string ipv4_gateway = ethernet_edit_page.ipv4_gateway_entry.get_text ().strip ();
        bool gateway_auto = method != "manual";
        bool dns_auto = ethernet_edit_page.dns_auto_switch.get_active ();
        string dns_csv = ethernet_edit_page.ipv4_dns_entry.get_text ().strip ();
        string method6 = MainWindowWifiEditUtils.get_selected_ipv6_method (
            ethernet_edit_page.ipv6_method_dropdown
        );
        string ipv6_address = ethernet_edit_page.ipv6_address_entry.get_text ().strip ();
        string ipv6_gateway = ethernet_edit_page.ipv6_gateway_entry.get_text ().strip ();
        bool ipv6_gateway_auto = method6 != "manual";
        bool ipv6_dns_auto = ethernet_edit_page.ipv6_dns_auto_switch.get_active ();
        string ipv6_dns_csv = ethernet_edit_page.ipv6_dns_entry.get_text ().strip ();

        if (MainWindowIpSensitivityRules.should_force_ipv4_dns_auto_from_method (method)) {
            dns_auto = true;
        }

        if (MainWindowIpSensitivityRules.should_force_ipv6_dns_auto_from_method (method6)) {
            ipv6_dns_auto = true;
        }

        uint32 ipv4_prefix;
        string prefix_error;
        if (!MainWindowWifiEditUtils.try_parse_prefix (
            ethernet_edit_page.ipv4_prefix_entry.get_text (),
            out ipv4_prefix,
            out prefix_error
        )) {
            host.show_error (prefix_error);
            return;
        }

        uint32 ipv6_prefix;
        string prefix6_error;
        if (!MainWindowWifiEditUtils.try_parse_ipv6_prefix (
            ethernet_edit_page.ipv6_prefix_entry.get_text (),
            out ipv6_prefix,
            out prefix6_error
        )) {
            host.show_error (prefix6_error);
            return;
        }

        if (method == "manual") {
            if (ipv4_address == "") {
                host.show_error ("Manual IPv4 requires an address.");
                return;
            }
            if (ipv4_prefix == 0) {
                host.show_error ("Manual IPv4 requires a prefix between 1 and 32.");
                return;
            }
            if (ipv4_gateway == "") {
                host.show_error ("Manual IPv4 requires a gateway address.");
                return;
            }
        }

        string[] dns_servers = MainWindowWifiEditUtils.parse_dns_csv (dns_csv);
        if (!dns_auto && dns_servers.length == 0) {
            host.show_error ("Manual DNS is enabled; provide at least one DNS server.");
            return;
        }

        if (method6 == "manual") {
            if (ipv6_address == "") {
                host.show_error ("Manual IPv6 requires an address.");
                return;
            }
            if (ipv6_prefix == 0) {
                host.show_error ("Manual IPv6 requires a prefix between 1 and 128.");
                return;
            }
            if (ipv6_gateway == "") {
                host.show_error ("Manual IPv6 requires a gateway address.");
                return;
            }
        }

        string[] ipv6_dns_servers = MainWindowWifiEditUtils.parse_dns_csv (ipv6_dns_csv);
        if (!ipv6_dns_auto && ipv6_dns_servers.length == 0) {
            host.show_error ("Manual IPv6 DNS is enabled; provide at least one DNS server.");
            return;
        }

        var request = new NetworkIpUpdateRequest () {
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

        nm.update_ethernet_device_settings.begin (dev, request, null, (obj, res) => {
                try {
                    nm.update_ethernet_device_settings.end (res);
                } catch (Error e) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    host.show_error ("Apply failed: " + e.message);
                    return;
                }

                if (!dev.is_connected) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    host.refresh_after_action (false);
                    host.set_popup_text_input_mode (false);
                    if (profile_edit_mode) {
                        complete_profile_edit_mode ();
                    } else {
                        // populate details will be called inside open_details, but we need
                        // selected_ethernet_device passed around safely.
                        open_details (dev, ethernet_stack, ethernet_details_page, connection_controller);
                    }
                    return;
                }

                nm.disconnect_device.begin (dev.name, null, (obj2, res2) => {
                    try {
                        nm.disconnect_device.end (res2);
                    } catch (Error e) {
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        host.show_error ("Disconnect before reconnect failed: " + e.message);
                        return;
                    }

                    nm.connect_ethernet_device.begin (dev, null, (obj3, res3) => {
                        bool reconnect_ok = true;
                        string reconnect_error = "";
                        try {
                            nm.connect_ethernet_device.end (res3);
                        } catch (Error e) {
                            reconnect_ok = false;
                            reconnect_error = e.message;
                        }

                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        connection_controller.track_pending_action (dev, true, epoch);
                        if (!reconnect_ok) {
                            host.show_error ("Reconnect after edit failed: " + reconnect_error);
                        }
                        host.refresh_after_action (false);
                        host.set_popup_text_input_mode (false);
                        if (profile_edit_mode) {
                            complete_profile_edit_mode ();
                        } else {
                            open_details (dev, ethernet_stack, ethernet_details_page, connection_controller);
                        }
                    });
                });
        });
    }
}
