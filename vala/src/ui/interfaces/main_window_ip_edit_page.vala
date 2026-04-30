using Gtk;

public interface IMainWindowIpEditPage : Object {
    public abstract HyprNetworkManager.UI.Widgets.TrackedDropDown ipv4_method_dropdown { get; set; }
    public abstract Gtk.Entry ipv4_address_entry { get; set; }
    public abstract Gtk.Entry ipv4_prefix_entry { get; set; }
    public abstract Gtk.Entry ipv4_gateway_entry { get; set; }
    public abstract Gtk.Switch dns_auto_switch { get; set; }
    public abstract Gtk.Entry ipv4_dns_entry { get; set; }
    public abstract HyprNetworkManager.UI.Widgets.TrackedDropDown ipv6_method_dropdown { get; set; }
    public abstract Gtk.Entry ipv6_address_entry { get; set; }
    public abstract Gtk.Entry ipv6_prefix_entry { get; set; }
    public abstract Gtk.Entry ipv6_gateway_entry { get; set; }
    public abstract Gtk.Switch ipv6_dns_auto_switch { get; set; }
    public abstract Gtk.Entry ipv6_dns_entry { get; set; }

    public virtual void sync_edit_gateway_dns_sensitivity () {
        if (this.ipv4_method_dropdown != null) {
            uint selected = this.ipv4_method_dropdown.get_selected ();
            if (MainWindowIpSensitivityRules.should_force_ipv4_dns_auto_from_dropdown (selected)
                && this.dns_auto_switch != null) {
                this.dns_auto_switch.set_active (true);
            }
        }

        if (this.ipv6_method_dropdown != null) {
            uint selected = this.ipv6_method_dropdown.get_selected ();
            if (MainWindowIpSensitivityRules.should_force_ipv6_dns_auto_from_dropdown (selected)
                && this.ipv6_dns_auto_switch != null) {
                this.ipv6_dns_auto_switch.set_active (true);
            }
        }

        if (this.ipv4_dns_entry != null && this.dns_auto_switch != null) {
            this.ipv4_dns_entry.set_sensitive (
                MainWindowIpSensitivityRules.is_dns_entry_sensitive (this.dns_auto_switch.get_active ())
            );
        }

        if (this.ipv6_dns_entry != null && this.ipv6_dns_auto_switch != null) {
            this.ipv6_dns_entry.set_sensitive (
                MainWindowIpSensitivityRules.is_dns_entry_sensitive (this.ipv6_dns_auto_switch.get_active ())
            );
        }
    }

    public virtual void populate_ip_settings (NetworkIpSettings ip_settings) {
        this.ipv4_method_dropdown.set_selected (
            MainWindowHelpers.get_ipv4_method_dropdown_index (ip_settings.ipv4_method)
        );
        this.ipv4_address_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_address));
        this.ipv4_prefix_entry.set_text (
            ip_settings.configured_prefix > 0 ? "%u".printf (ip_settings.configured_prefix) : ""
        );
        this.ipv4_gateway_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_gateway));
        this.dns_auto_switch.set_active (ip_settings.dns_auto);
        this.ipv4_dns_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_dns));
        this.ipv6_method_dropdown.set_selected (
            MainWindowHelpers.get_ipv6_method_dropdown_index (ip_settings.ipv6_method)
        );
        this.ipv6_address_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_ipv6_address));
        this.ipv6_prefix_entry.set_text (
            ip_settings.configured_ipv6_prefix > 0 ? "%u".printf (ip_settings.configured_ipv6_prefix) : ""
        );
        this.ipv6_gateway_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_ipv6_gateway));
        this.ipv6_dns_auto_switch.set_active (ip_settings.ipv6_dns_auto);
        this.ipv6_dns_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_ipv6_dns));

        this.sync_edit_gateway_dns_sensitivity ();
    }

    public virtual NetworkIpUpdateRequest? build_ip_update_request (out string? error_message) {
        error_message = null;
        string method = MainWindowWifiEditUtils.get_selected_ipv4_method (this.ipv4_method_dropdown);
        string ipv4_address = this.ipv4_address_entry.get_text ().strip ();
        string ipv4_gateway = this.ipv4_gateway_entry.get_text ().strip ();
        bool gateway_auto = method != "manual";
        bool dns_auto = this.dns_auto_switch.get_active ();
        string dns_csv = this.ipv4_dns_entry.get_text ().strip ();
        string method6 = MainWindowWifiEditUtils.get_selected_ipv6_method (this.ipv6_method_dropdown);
        string ipv6_address = this.ipv6_address_entry.get_text ().strip ();
        string ipv6_gateway = this.ipv6_gateway_entry.get_text ().strip ();
        bool ipv6_gateway_auto = method6 != "manual";
        bool ipv6_dns_auto = this.ipv6_dns_auto_switch.get_active ();
        string ipv6_dns_csv = this.ipv6_dns_entry.get_text ().strip ();

        if (MainWindowIpSensitivityRules.should_force_ipv4_dns_auto_from_method (method)) {
            dns_auto = true;
        }

        if (MainWindowIpSensitivityRules.should_force_ipv6_dns_auto_from_method (method6)) {
            ipv6_dns_auto = true;
        }

        uint32 ipv4_prefix;
        string prefix_error;
        if (!MainWindowWifiEditUtils.try_parse_prefix (
            this.ipv4_prefix_entry.get_text (),
            out ipv4_prefix,
            out prefix_error
        )) {
            error_message = prefix_error;
            return null;
        }

        uint32 ipv6_prefix;
        string prefix6_error;
        if (!MainWindowWifiEditUtils.try_parse_ipv6_prefix (
            this.ipv6_prefix_entry.get_text (),
            out ipv6_prefix,
            out prefix6_error
        )) {
            error_message = prefix6_error;
            return null;
        }

        if (method == "manual") {
            if (ipv4_address == "") {
                error_message = _("Manual IPv4 requires an address.");
                return null;
            }
            if (ipv4_prefix == 0) {
                error_message = _("Manual IPv4 requires a prefix between 1 and 32.");
                return null;
            }
            if (ipv4_gateway == "") {
                error_message = _("Manual IPv4 requires a gateway address.");
                return null;
            }
        }

        string[] dns_servers = MainWindowWifiEditUtils.parse_dns_csv (dns_csv);
        if (!dns_auto && dns_servers.length == 0) {
            error_message = _("Manual DNS is enabled; provide at least one DNS server.");
            return null;
        }

        if (method6 == "manual") {
            if (ipv6_address == "") {
                error_message = _("Manual IPv6 requires an address.");
                return null;
            }
            if (ipv6_prefix == 0) {
                error_message = _("Manual IPv6 requires a prefix between 1 and 128.");
                return null;
            }
            if (ipv6_gateway == "") {
                error_message = _("Manual IPv6 requires a gateway address.");
                return null;
            }
        }

        string[] ipv6_dns_servers = MainWindowWifiEditUtils.parse_dns_csv (ipv6_dns_csv);
        if (!ipv6_dns_auto && ipv6_dns_servers.length == 0) {
            error_message = _("Manual IPv6 DNS is enabled; provide at least one DNS server.");
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
