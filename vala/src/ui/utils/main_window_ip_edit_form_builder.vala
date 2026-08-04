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
using HyprNetworkManager.UI.Interfaces;

namespace MainWindowIpEditFormBuilder {
    private Gtk.Label build_label (string text, bool with_extra_classes, string? extra_class = null) {
        var label = new Gtk.Label (text);
        label.set_xalign (0.0f);
        if (with_extra_classes) {
            label.add_css_class (MainWindowCssClasses.EDIT_FIELD_LABEL);
            label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        } else {
            label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        }
        if (extra_class != null && extra_class != "") {
            label.add_css_class (extra_class);
        }
        return label;
    }

    private void apply_control_classes (Gtk.Widget widget, bool with_extra_classes, string? extra_class = null) {
        if (!with_extra_classes) {
            return;
        }

        if (extra_class != null && extra_class != "") {
            widget.add_css_class (extra_class);
            widget.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
            return;
        }

        widget.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
    }

    private void set_collapsible_state (
        Gtk.Box container,
        Gtk.Button toggle_button,
        Gtk.Revealer content_revealer,
        Gtk.Image toggle_icon,
        bool expanded
    ) {
        content_revealer.set_reveal_child (expanded);
        MainWindowIconResources.set_expand_indicator_icon (toggle_icon, expanded);
        if (expanded) {
            container.add_css_class ("is-expanded");
            container.remove_css_class ("is-collapsed");
            toggle_button.set_tooltip_text (_("Collapse section"));
        } else {
            container.add_css_class ("is-collapsed");
            container.remove_css_class ("is-expanded");
            toggle_button.set_tooltip_text (_("Expand section"));
        }
    }

    private Gtk.Box build_collapsible_section (
        string title,
        bool with_extra_classes,
        string css_class,
        out Gtk.Box content_box
    ) {
        var container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        if (with_extra_classes) {
            container.add_css_class (css_class);
            container.add_css_class (MainWindowCssClasses.EDIT_COLLAPSIBLE);
        } else {
            container.add_css_class (MainWindowCssClasses.EDIT_COLLAPSIBLE);
        }

        var toggle_button = new Gtk.Button ();
        toggle_button.set_has_frame (false);
        toggle_button.set_halign (Gtk.Align.FILL);
        toggle_button.set_hexpand (true);
        if (with_extra_classes) {
            toggle_button.add_css_class (css_class + "-toggle");
            toggle_button.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE);
        } else {
            toggle_button.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE);
        }

        var toggle_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        toggle_row.set_halign (Gtk.Align.FILL);
        toggle_row.set_hexpand (true);
        toggle_row.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_ROW);

        var toggle_icon = new Gtk.Image ();
        MainWindowIconResources.set_expand_indicator_icon (toggle_icon, false);
        if (with_extra_classes) {
            toggle_icon.add_css_class (css_class + "-toggle-icon");
            toggle_icon.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_ICON);
        } else {
            toggle_icon.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_ICON);
        }
        toggle_row.append (toggle_icon);

        var toggle_label = new Gtk.Label (title);
        toggle_label.set_xalign (0.0f);
        toggle_label.set_hexpand (true);
        if (with_extra_classes) {
            toggle_label.add_css_class (css_class + "-toggle-label");
            toggle_label.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_LABEL);
        } else {
            toggle_label.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_LABEL);
        }
        toggle_row.append (toggle_label);

        toggle_button.set_child (toggle_row);
        container.append (toggle_button);

        content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            content_box.add_css_class (css_class + "-content");
            content_box.add_css_class (MainWindowCssClasses.EDIT_SECTION_CONTENT);
        } else {
            content_box.add_css_class (MainWindowCssClasses.EDIT_SECTION_CONTENT);
        }

        var content_revealer = new Gtk.Revealer ();
        content_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        content_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_MS);
        content_revealer.set_child (content_box);
        if (with_extra_classes) {
            content_revealer.add_css_class (css_class + "-revealer");
            content_revealer.add_css_class (MainWindowCssClasses.EDIT_SECTION_REVEALER);
        } else {
            content_revealer.add_css_class (MainWindowCssClasses.EDIT_SECTION_REVEALER);
        }
        container.append (content_revealer);

        set_collapsible_state (container, toggle_button, content_revealer, toggle_icon, true);

        toggle_button.clicked.connect (() => {
            bool expanded = !content_revealer.get_reveal_child ();
            set_collapsible_state (container, toggle_button, content_revealer, toggle_icon, expanded);
        });

        return container;
    }

    private void sync_ip_section_sensitivity (
        bool is_ipv6,
        HyprNetworkManager.UI.Widgets.TrackedDropDown method_dropdown,
        Gtk.Revealer manual_revealer,
        Gtk.Revealer override_revealer,
        Gtk.Switch dns_auto_switch,
        Gtk.Entry dns_entry
    ) {
        uint selected = method_dropdown.get_selected ();
        manual_revealer.set_reveal_child (
            MainWindowIpSensitivityRules.should_show_manual_fields (selected)
        );
        override_revealer.set_reveal_child (
            MainWindowIpSensitivityRules.should_show_override_fields (selected)
        );

        bool force_dns_auto = is_ipv6
            ? MainWindowIpSensitivityRules.should_force_ipv6_dns_auto_from_dropdown (selected)
            : MainWindowIpSensitivityRules.should_force_ipv4_dns_auto_from_dropdown (selected);
        if (force_dns_auto && !dns_auto_switch.get_active ()) {
            dns_auto_switch.set_active (true);
        }

        dns_entry.set_sensitive (
            MainWindowIpSensitivityRules.is_dns_entry_sensitive (dns_auto_switch.get_active ())
        );
    }

    private static string ip_class (bool is_ipv6, string suffix) {
        return "nm-edit-ipv%s-%s".printf (is_ipv6 ? "6" : "4", suffix);
    }

    private class IpSectionWidgets {
        public HyprNetworkManager.UI.Widgets.TrackedDropDown method_dropdown;
        public Gtk.Entry address_entry;
        public Gtk.Entry prefix_entry;
        public Gtk.Entry gateway_entry;
        public Gtk.Switch dns_auto_switch;
        public Gtk.Entry dns_entry;
    }

    private IpSectionWidgets append_ip_section (
        Gtk.Box form,
        bool is_ipv6,
        TrackedDropDownFactory create_dropdown,
        bool with_extra_classes
    ) {
        var widgets = new IpSectionWidgets ();

        Gtk.Box section;
        var collapsible = build_collapsible_section (
            is_ipv6 ? _("IPv6 Settings") : _("IPv4 Settings"),
            with_extra_classes,
            ip_class (is_ipv6, "section"),
            out section
        );
        form.append (collapsible);

        if (with_extra_classes) {
            section.add_css_class (ip_class (is_ipv6, "section"));
            section.add_css_class (MainWindowCssClasses.EDIT_IP_SECTION);
        }

        section.append (build_label (
            is_ipv6 ? _("IPv6 Method") : _("IPv4 Method"),
            with_extra_classes,
            with_extra_classes ? ip_class (is_ipv6, "method-label") : null
        ));

        var method_list = new Gtk.StringList (null);
        if (is_ipv6) {
            method_list.append (_("Automatic"));
            method_list.append (_("Manual"));
            method_list.append (_("Disabled"));
            method_list.append (_("Ignore"));
        } else {
            method_list.append (_("Automatic (DHCP)"));
            method_list.append (_("Manual"));
            method_list.append (_("Disabled"));
        }
        widgets.method_dropdown = create_dropdown (method_list);
        apply_control_classes (widgets.method_dropdown, with_extra_classes, null);
        if (with_extra_classes) {
            widgets.method_dropdown.add_css_class (MainWindowCssClasses.EDIT_DROPDOWN);
            widgets.method_dropdown.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
            if (is_ipv6) {
                widgets.method_dropdown.add_css_class (ip_class (true, "method-dropdown"));
                widgets.method_dropdown.add_css_class (MainWindowCssClasses.EDIT_DROPDOWN);
            } else {
                widgets.method_dropdown.add_css_class (ip_class (false, "method-dropdown"));
                widgets.method_dropdown.add_css_class (MainWindowCssClasses.EDIT_DROPDOWN);
            }
        }
        section.append (widgets.method_dropdown);

        var manual_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            manual_fields.add_css_class (ip_class (is_ipv6, "manual"));
            manual_fields.add_css_class (MainWindowCssClasses.EDIT_IP_ADVANCED);
        }

        var manual_revealer = new Gtk.Revealer ();
        manual_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        manual_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        manual_revealer.add_css_class (ip_class (is_ipv6, "manual-revealer"));
        manual_revealer.add_css_class (MainWindowCssClasses.EDIT_IP_SUBSECTION_REVEALER);
        manual_revealer.set_child (manual_fields);
        section.append (manual_revealer);

        manual_fields.append (build_label (
            is_ipv6 ? _("IPv6 Address") : _("IPv4 Address"),
            with_extra_classes,
            with_extra_classes ? ip_class (is_ipv6, "address-label") : null
        ));

        widgets.address_entry = new Gtk.Entry ();
        widgets.address_entry.set_placeholder_text (is_ipv6 ? "2001:db8::100" : "192.168.1.100");
        apply_control_classes (
            widgets.address_entry,
            with_extra_classes,
            with_extra_classes ? ip_class (is_ipv6, "address-entry") : null
        );
        if (with_extra_classes) {
            widgets.address_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            widgets.address_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
        }
        manual_fields.append (widgets.address_entry);

        manual_fields.append (build_label (
            _("Prefix (CIDR)"),
            with_extra_classes,
            with_extra_classes ? ip_class (is_ipv6, "prefix-label") : null
        ));

        widgets.prefix_entry = new Gtk.Entry ();
        widgets.prefix_entry.set_placeholder_text (is_ipv6 ? "64" : "24");
        apply_control_classes (
            widgets.prefix_entry,
            with_extra_classes,
            with_extra_classes ? ip_class (is_ipv6, "prefix-entry") : null
        );
        if (with_extra_classes) {
            widgets.prefix_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            widgets.prefix_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
        }
        manual_fields.append (widgets.prefix_entry);

        manual_fields.append (build_label (
            _("Gateway"),
            with_extra_classes,
            with_extra_classes ? ip_class (is_ipv6, "gateway-label") : null
        ));

        widgets.gateway_entry = new Gtk.Entry ();
        widgets.gateway_entry.set_placeholder_text (is_ipv6 ? "fe80::1" : "192.168.1.1");
        apply_control_classes (
            widgets.gateway_entry,
            with_extra_classes,
            with_extra_classes ? ip_class (is_ipv6, "gateway-entry") : null
        );
        if (with_extra_classes) {
            widgets.gateway_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            widgets.gateway_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
        }
        manual_fields.append (widgets.gateway_entry);

        var override_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            override_fields.add_css_class (ip_class (is_ipv6, "overrides"));
            override_fields.add_css_class (MainWindowCssClasses.EDIT_IP_ADVANCED);
        }

        var override_revealer = new Gtk.Revealer ();
        override_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        override_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        override_revealer.add_css_class (ip_class (is_ipv6, "overrides-revealer"));
        override_revealer.add_css_class (MainWindowCssClasses.EDIT_IP_SUBSECTION_REVEALER);
        override_revealer.set_child (override_fields);
        section.append (override_revealer);

        override_fields.append (build_label (
            _("DNS Servers (comma-separated)"),
            with_extra_classes,
            with_extra_classes ? ip_class (is_ipv6, "dns-label") : null
        ));

        var dns_mode_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        dns_mode_row.set_halign (Gtk.Align.FILL);
        dns_mode_row.set_hexpand (true);
        if (with_extra_classes) {
            dns_mode_row.add_css_class (ip_class (is_ipv6, "dns-mode-row"));
            dns_mode_row.add_css_class (MainWindowCssClasses.EDIT_MODE_ROW);
        } else {
            dns_mode_row.add_css_class (MainWindowCssClasses.EDIT_MODE_ROW);
        }
        dns_mode_row.add_css_class (MainWindowCssClasses.NM_FLAT);

        var dns_mode_label = new Gtk.Label (_("Automatic DNS"));
        dns_mode_label.set_xalign (0.0f);
        dns_mode_label.set_hexpand (true);
        dns_mode_label.set_valign (Gtk.Align.CENTER);
        if (with_extra_classes) {
            dns_mode_label.add_css_class (ip_class (is_ipv6, "dns-mode-label"));
            dns_mode_label.add_css_class (MainWindowCssClasses.EDIT_MODE_LABEL);
        }
        dns_mode_row.append (dns_mode_label);

        widgets.dns_auto_switch = new Gtk.Switch ();
        widgets.dns_auto_switch.set_valign (Gtk.Align.CENTER);
        widgets.dns_auto_switch.set_active (true);
        if (with_extra_classes) {
            widgets.dns_auto_switch.add_css_class (MainWindowCssClasses.SWITCH);
            widgets.dns_auto_switch.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
            widgets.dns_auto_switch.add_css_class (MainWindowCssClasses.EDIT_MODE_SWITCH);
            widgets.dns_auto_switch.add_css_class (ip_class (is_ipv6, "dns-mode-switch"));
        }
        dns_mode_row.append (widgets.dns_auto_switch);
        override_fields.append (dns_mode_row);

        widgets.dns_entry = new Gtk.Entry ();
        widgets.dns_entry.set_placeholder_text (is_ipv6 ? "2606:4700:4700::1111, 2001:4860:4860::8888" : "1.1.1.1, 8.8.8.8");
        apply_control_classes (
            widgets.dns_entry,
            with_extra_classes,
            with_extra_classes ? ip_class (is_ipv6, "dns-entry") : null
        );
        if (with_extra_classes) {
            widgets.dns_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            widgets.dns_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
        }
        override_fields.append (widgets.dns_entry);

        var local_method_dropdown = widgets.method_dropdown;
        var local_dns_auto_switch = widgets.dns_auto_switch;
        var local_dns_entry = widgets.dns_entry;

        local_method_dropdown.notify_selected.connect (() => {
            sync_ip_section_sensitivity (
                is_ipv6,
                local_method_dropdown,
                manual_revealer,
                override_revealer,
                local_dns_auto_switch,
                local_dns_entry
            );
        });

        local_dns_auto_switch.notify["active"].connect (() => {
            sync_ip_section_sensitivity (
                is_ipv6,
                local_method_dropdown,
                manual_revealer,
                override_revealer,
                local_dns_auto_switch,
                local_dns_entry
            );
        });

        sync_ip_section_sensitivity (
            is_ipv6,
            local_method_dropdown,
            manual_revealer,
            override_revealer,
            local_dns_auto_switch,
            local_dns_entry
        );

        return widgets;
    }

    public void append_ipv4_section (
        Gtk.Box form,
        out HyprNetworkManager.UI.Widgets.TrackedDropDown ipv4_method_dropdown,
        out Gtk.Entry ipv4_address_entry,
        out Gtk.Entry ipv4_prefix_entry,
        out Gtk.Entry ipv4_gateway_entry,
        out Gtk.Switch dns_auto_switch,
        out Gtk.Entry ipv4_dns_entry,
        TrackedDropDownFactory create_dropdown,
        bool with_extra_classes
    ) {
        var widgets = append_ip_section (form, false, create_dropdown, with_extra_classes);
        ipv4_method_dropdown = widgets.method_dropdown;
        ipv4_address_entry = widgets.address_entry;
        ipv4_prefix_entry = widgets.prefix_entry;
        ipv4_gateway_entry = widgets.gateway_entry;
        dns_auto_switch = widgets.dns_auto_switch;
        ipv4_dns_entry = widgets.dns_entry;
    }

    public void append_ipv6_section (
        Gtk.Box form,
        out HyprNetworkManager.UI.Widgets.TrackedDropDown ipv6_method_dropdown,
        out Gtk.Entry ipv6_address_entry,
        out Gtk.Entry ipv6_prefix_entry,
        out Gtk.Entry ipv6_gateway_entry,
        out Gtk.Switch ipv6_dns_auto_switch,
        out Gtk.Entry ipv6_dns_entry,
        TrackedDropDownFactory create_dropdown,
        bool with_extra_classes
    ) {
        var widgets = append_ip_section (form, true, create_dropdown, with_extra_classes);
        ipv6_method_dropdown = widgets.method_dropdown;
        ipv6_address_entry = widgets.address_entry;
        ipv6_prefix_entry = widgets.prefix_entry;
        ipv6_gateway_entry = widgets.gateway_entry;
        ipv6_dns_auto_switch = widgets.dns_auto_switch;
        ipv6_dns_entry = widgets.dns_entry;
    }
}
