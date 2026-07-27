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
    public abstract Gtk.Switch? autoconnect_switch { get; set; }

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

        var v4 = MainWindowIpValidation.validate (
            MainWindowIpValidation.Family.IPV4,
            MainWindowWifiEditUtils.get_selected_ipv4_method (this.ipv4_method_dropdown),
            this.ipv4_address_entry.get_text ().strip (),
            this.ipv4_prefix_entry.get_text (),
            this.ipv4_gateway_entry.get_text ().strip (),
            this.dns_auto_switch.get_active (),
            this.ipv4_dns_entry.get_text ().strip (),
            out error_message);
        if (v4 == null) {
            return null;
        }

        string error6;
        var v6 = MainWindowIpValidation.validate (
            MainWindowIpValidation.Family.IPV6,
            MainWindowWifiEditUtils.get_selected_ipv6_method (this.ipv6_method_dropdown),
            this.ipv6_address_entry.get_text ().strip (),
            this.ipv6_prefix_entry.get_text (),
            this.ipv6_gateway_entry.get_text ().strip (),
            this.ipv6_dns_auto_switch.get_active (),
            this.ipv6_dns_entry.get_text ().strip (),
            out error6);
        if (v6 == null) {
            error_message = error6;
            return null;
        }

        return new NetworkIpUpdateRequest () {
            ipv4_method = v4.method,
            ipv4_address = v4.address,
            ipv4_prefix = v4.prefix,
            ipv4_gateway_auto = v4.gateway_auto,
            ipv4_gateway = v4.gateway,
            ipv4_dns_auto = v4.dns_auto,
            ipv4_dns_servers = v4.dns_servers,
            ipv6_method = v6.method,
            ipv6_address = v6.address,
            ipv6_prefix = v6.prefix,
            ipv6_gateway_auto = v6.gateway_auto,
            ipv6_gateway = v6.gateway,
            ipv6_dns_auto = v6.dns_auto,
            ipv6_dns_servers = v6.dns_servers
        };
    }
}
