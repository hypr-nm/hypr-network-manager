using Gtk;

public class MainWindowIpEditFormBuilder : Object {
    private static Gtk.Label build_label(string text, bool with_extra_classes, string? extra_class = null) {
        var label = new Gtk.Label(text);
        label.set_xalign(0.0f);
        label.add_css_class("nm-form-label");
        if (with_extra_classes) {
            label.add_css_class("nm-edit-field-label");
        }
        if (extra_class != null && extra_class != "") {
            label.add_css_class(extra_class);
        }
        return label;
    }

    private static void apply_control_classes(Gtk.Widget widget, bool with_extra_classes, string? extra_class = null) {
        if (!with_extra_classes) {
            return;
        }

        widget.add_css_class("nm-edit-field-control");
        if (extra_class != null && extra_class != "") {
            widget.add_css_class(extra_class);
        }
    }

    private static void set_collapsible_state(
        Gtk.Box container,
        Gtk.Button toggle_button,
        Gtk.Revealer content_revealer,
        bool expanded
    ) {
        content_revealer.set_reveal_child(expanded);
        if (expanded) {
            container.add_css_class("is-expanded");
            container.remove_css_class("is-collapsed");
            toggle_button.set_tooltip_text("Collapse section");
        } else {
            container.add_css_class("is-collapsed");
            container.remove_css_class("is-expanded");
            toggle_button.set_tooltip_text("Expand section");
        }
    }

    private static Gtk.Box build_collapsible_section(
        string title,
        bool with_extra_classes,
        string css_class,
        out Gtk.Box content_box
    ) {
        var container = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        container.add_css_class("nm-edit-collapsible");
        if (with_extra_classes) {
            container.add_css_class(css_class);
        }

        var toggle_button = new Gtk.Button();
        toggle_button.set_has_frame(false);
        toggle_button.set_halign(Gtk.Align.FILL);
        toggle_button.set_hexpand(true);
        toggle_button.add_css_class("nm-edit-section-toggle");
        if (with_extra_classes) {
            toggle_button.add_css_class(css_class + "-toggle");
        }

        var toggle_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        toggle_row.set_halign(Gtk.Align.FILL);
        toggle_row.set_hexpand(true);
        toggle_row.add_css_class("nm-edit-section-toggle-row");

        var toggle_icon = new Gtk.Image.from_icon_name("pan-down-symbolic");
        toggle_icon.add_css_class("nm-edit-section-toggle-icon");
        if (with_extra_classes) {
            toggle_icon.add_css_class(css_class + "-toggle-icon");
        }
        toggle_row.append(toggle_icon);

        var toggle_label = new Gtk.Label(title);
        toggle_label.set_xalign(0.0f);
        toggle_label.set_hexpand(true);
        toggle_label.add_css_class("nm-edit-section-toggle-label");
        if (with_extra_classes) {
            toggle_label.add_css_class(css_class + "-toggle-label");
        }
        toggle_row.append(toggle_label);

        toggle_button.set_child(toggle_row);
        container.append(toggle_button);

        content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        content_box.add_css_class("nm-edit-section-content");
        if (with_extra_classes) {
            content_box.add_css_class(css_class + "-content");
        }

        var content_revealer = new Gtk.Revealer();
        content_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN);
        content_revealer.set_transition_duration(220);
        content_revealer.set_child(content_box);
        content_revealer.add_css_class("nm-edit-section-revealer");
        if (with_extra_classes) {
            content_revealer.add_css_class(css_class + "-revealer");
        }
        container.append(content_revealer);

        set_collapsible_state(container, toggle_button, content_revealer, true);

        toggle_button.clicked.connect(() => {
            bool expanded = !content_revealer.get_reveal_child();
            set_collapsible_state(container, toggle_button, content_revealer, expanded);
        });

        return container;
    }

    public static void append_ipv4_section(
        Gtk.Box form,
        out Gtk.DropDown ipv4_method_dropdown,
        out Gtk.Entry ipv4_address_entry,
        out Gtk.Entry ipv4_prefix_entry,
        out Gtk.Switch gateway_auto_switch,
        out Gtk.Entry ipv4_gateway_entry,
        out Gtk.Switch dns_auto_switch,
        out Gtk.Entry ipv4_dns_entry,
        MainWindowActionCallback on_sync_sensitivity,
        bool with_extra_classes
    ) {
        Gtk.Box section;
        var collapsible = build_collapsible_section(
            "IPv4 Settings",
            with_extra_classes,
            "nm-edit-ipv4-section",
            out section
        );
        form.append(collapsible);

        if (with_extra_classes) {
            section.add_css_class("nm-edit-ip-section");
            section.add_css_class("nm-edit-ipv4-section");
        }

        section.append(build_label(
            "IPv4 Method",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-method-label" : null
        ));

        var ipv4_method_list = new Gtk.StringList(null);
        ipv4_method_list.append("Automatic (DHCP)");
        ipv4_method_list.append("Manual");
        ipv4_method_list.append("Disabled");
        ipv4_method_dropdown = new Gtk.DropDown(ipv4_method_list, null);
        apply_control_classes(ipv4_method_dropdown, with_extra_classes, null);
        if (with_extra_classes) {
            ipv4_method_dropdown.add_css_class("nm-edit-dropdown");
            ipv4_method_dropdown.add_css_class("nm-edit-ipv4-method-dropdown");
        }
        section.append(ipv4_method_dropdown);

        var manual_fields = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        if (with_extra_classes) {
            manual_fields.add_css_class("nm-edit-ip-advanced");
            manual_fields.add_css_class("nm-edit-ipv4-manual");
        }

        var manual_revealer = new Gtk.Revealer();
        manual_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN);
        manual_revealer.set_transition_duration(180);
        manual_revealer.add_css_class("nm-edit-ip-subsection-revealer");
        manual_revealer.add_css_class("nm-edit-ipv4-manual-revealer");
        manual_revealer.set_child(manual_fields);
        section.append(manual_revealer);

        manual_fields.append(build_label(
            "IPv4 Address",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-address-label" : null
        ));

        ipv4_address_entry = new Gtk.Entry();
        ipv4_address_entry.set_placeholder_text("192.168.1.100");
        apply_control_classes(
            ipv4_address_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-address-entry" : null
        );
        if (with_extra_classes) {
            ipv4_address_entry.add_css_class("nm-edit-field-entry");
        }
        manual_fields.append(ipv4_address_entry);

        manual_fields.append(build_label(
            "Prefix (CIDR)",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-prefix-label" : null
        ));

        ipv4_prefix_entry = new Gtk.Entry();
        ipv4_prefix_entry.set_placeholder_text("24");
        apply_control_classes(
            ipv4_prefix_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-prefix-entry" : null
        );
        if (with_extra_classes) {
            ipv4_prefix_entry.add_css_class("nm-edit-field-entry");
        }
        manual_fields.append(ipv4_prefix_entry);

        var override_fields = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        if (with_extra_classes) {
            override_fields.add_css_class("nm-edit-ip-advanced");
            override_fields.add_css_class("nm-edit-ipv4-overrides");
        }

        var override_revealer = new Gtk.Revealer();
        override_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN);
        override_revealer.set_transition_duration(180);
        override_revealer.add_css_class("nm-edit-ip-subsection-revealer");
        override_revealer.add_css_class("nm-edit-ipv4-overrides-revealer");
        override_revealer.set_child(override_fields);
        section.append(override_revealer);

        override_fields.append(build_label(
            "Gateway",
            with_extra_classes,
            with_extra_classes ? "nm-edit-gateway-label" : null
        ));

        var gateway_mode_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        gateway_mode_row.set_halign(Gtk.Align.FILL);
        gateway_mode_row.set_hexpand(true);
        if (with_extra_classes) {
            gateway_mode_row.add_css_class("nm-edit-mode-row");
            gateway_mode_row.add_css_class("nm-edit-gateway-mode-row");
        }

        var gateway_mode_label = new Gtk.Label("Automatic gateway");
        gateway_mode_label.set_xalign(0.0f);
        gateway_mode_label.set_hexpand(true);
        gateway_mode_label.set_valign(Gtk.Align.CENTER);
        if (with_extra_classes) {
            gateway_mode_label.add_css_class("nm-edit-mode-label");
            gateway_mode_label.add_css_class("nm-edit-gateway-mode-label");
        }
        gateway_mode_row.append(gateway_mode_label);

        gateway_auto_switch = new Gtk.Switch();
        gateway_auto_switch.set_valign(Gtk.Align.CENTER);
        gateway_auto_switch.set_active(true);
        if (with_extra_classes) {
            gateway_auto_switch.add_css_class("nm-switch");
            gateway_auto_switch.add_css_class("nm-edit-field-control");
            gateway_auto_switch.add_css_class("nm-edit-mode-switch");
            gateway_auto_switch.add_css_class("nm-edit-gateway-mode-switch");
        }
        gateway_auto_switch.notify["active"].connect(() => {
            on_sync_sensitivity();
        });
        gateway_mode_row.append(gateway_auto_switch);
        override_fields.append(gateway_mode_row);

        ipv4_gateway_entry = new Gtk.Entry();
        ipv4_gateway_entry.set_placeholder_text("192.168.1.1");
        apply_control_classes(
            ipv4_gateway_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-gateway-entry" : null
        );
        if (with_extra_classes) {
            ipv4_gateway_entry.add_css_class("nm-edit-field-entry");
        }
        override_fields.append(ipv4_gateway_entry);

        override_fields.append(build_label(
            "DNS Servers (comma-separated)",
            with_extra_classes,
            with_extra_classes ? "nm-edit-dns-label" : null
        ));

        var dns_mode_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        dns_mode_row.set_halign(Gtk.Align.FILL);
        dns_mode_row.set_hexpand(true);
        if (with_extra_classes) {
            dns_mode_row.add_css_class("nm-edit-mode-row");
            dns_mode_row.add_css_class("nm-edit-dns-mode-row");
        }

        var dns_mode_label = new Gtk.Label("Automatic DNS");
        dns_mode_label.set_xalign(0.0f);
        dns_mode_label.set_hexpand(true);
        dns_mode_label.set_valign(Gtk.Align.CENTER);
        if (with_extra_classes) {
            dns_mode_label.add_css_class("nm-edit-mode-label");
            dns_mode_label.add_css_class("nm-edit-dns-mode-label");
        }
        dns_mode_row.append(dns_mode_label);

        dns_auto_switch = new Gtk.Switch();
        dns_auto_switch.set_valign(Gtk.Align.CENTER);
        dns_auto_switch.set_active(true);
        if (with_extra_classes) {
            dns_auto_switch.add_css_class("nm-switch");
            dns_auto_switch.add_css_class("nm-edit-field-control");
            dns_auto_switch.add_css_class("nm-edit-mode-switch");
            dns_auto_switch.add_css_class("nm-edit-dns-mode-switch");
        }
        dns_auto_switch.notify["active"].connect(() => {
            on_sync_sensitivity();
        });
        dns_mode_row.append(dns_auto_switch);
        override_fields.append(dns_mode_row);

        ipv4_dns_entry = new Gtk.Entry();
        ipv4_dns_entry.set_placeholder_text("1.1.1.1, 8.8.8.8");
        apply_control_classes(
            ipv4_dns_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-dns-entry" : null
        );
        if (with_extra_classes) {
            ipv4_dns_entry.add_css_class("nm-edit-field-entry");
        }
        override_fields.append(ipv4_dns_entry);

        Gtk.DropDown local_ipv4_method_dropdown = ipv4_method_dropdown;
        Gtk.Switch local_gateway_auto_switch = gateway_auto_switch;
        Gtk.Switch local_dns_auto_switch = dns_auto_switch;

        MainWindowActionCallback sync_compact_visibility = () => {
            uint selected = local_ipv4_method_dropdown.get_selected();
            bool is_auto = selected == 0;
            bool is_manual = selected == 1;
            bool is_disabled = selected == 2;

            manual_revealer.set_reveal_child(is_manual);
            override_revealer.set_reveal_child(is_auto || is_manual);

            if (is_disabled) {
                if (!local_gateway_auto_switch.get_active()) {
                    local_gateway_auto_switch.set_active(true);
                }
                if (!local_dns_auto_switch.get_active()) {
                    local_dns_auto_switch.set_active(true);
                }
            }
            on_sync_sensitivity();
        };

        local_ipv4_method_dropdown.notify["selected"].connect(() => {
            sync_compact_visibility();
        });

        sync_compact_visibility();
    }

    public static void append_ipv6_section(
        Gtk.Box form,
        out Gtk.DropDown ipv6_method_dropdown,
        out Gtk.Entry ipv6_address_entry,
        out Gtk.Entry ipv6_prefix_entry,
        out Gtk.Switch ipv6_gateway_auto_switch,
        out Gtk.Entry ipv6_gateway_entry,
        MainWindowActionCallback on_sync_sensitivity,
        bool with_extra_classes
    ) {
        Gtk.Box section;
        var collapsible = build_collapsible_section(
            "IPv6 Settings",
            with_extra_classes,
            "nm-edit-ipv6-section",
            out section
        );
        form.append(collapsible);

        if (with_extra_classes) {
            section.add_css_class("nm-edit-ip-section");
            section.add_css_class("nm-edit-ipv6-section");
        }

        section.append(build_label(
            "IPv6 Method",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-method-label" : null
        ));

        var ipv6_method_list = new Gtk.StringList(null);
        ipv6_method_list.append("Automatic");
        ipv6_method_list.append("Manual");
        ipv6_method_list.append("Disabled");
        ipv6_method_list.append("Ignore");
        ipv6_method_dropdown = new Gtk.DropDown(ipv6_method_list, null);
        apply_control_classes(ipv6_method_dropdown, with_extra_classes, null);
        if (with_extra_classes) {
            ipv6_method_dropdown.add_css_class("nm-edit-dropdown");
            ipv6_method_dropdown.add_css_class("nm-edit-ipv6-method-dropdown");
        }
        section.append(ipv6_method_dropdown);

        var manual_fields = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        if (with_extra_classes) {
            manual_fields.add_css_class("nm-edit-ip-advanced");
            manual_fields.add_css_class("nm-edit-ipv6-manual");
        }

        var manual_revealer = new Gtk.Revealer();
        manual_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN);
        manual_revealer.set_transition_duration(180);
        manual_revealer.add_css_class("nm-edit-ip-subsection-revealer");
        manual_revealer.add_css_class("nm-edit-ipv6-manual-revealer");
        manual_revealer.set_child(manual_fields);
        section.append(manual_revealer);

        manual_fields.append(build_label(
            "IPv6 Address",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-address-label" : null
        ));

        ipv6_address_entry = new Gtk.Entry();
        ipv6_address_entry.set_placeholder_text("2001:db8::100");
        apply_control_classes(
            ipv6_address_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-address-entry" : null
        );
        if (with_extra_classes) {
            ipv6_address_entry.add_css_class("nm-edit-field-entry");
        }
        manual_fields.append(ipv6_address_entry);

        manual_fields.append(build_label(
            "IPv6 Prefix (CIDR)",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-prefix-label" : null
        ));

        ipv6_prefix_entry = new Gtk.Entry();
        ipv6_prefix_entry.set_placeholder_text("64");
        apply_control_classes(
            ipv6_prefix_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-prefix-entry" : null
        );
        if (with_extra_classes) {
            ipv6_prefix_entry.add_css_class("nm-edit-field-entry");
        }
        manual_fields.append(ipv6_prefix_entry);

        var override_fields = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        if (with_extra_classes) {
            override_fields.add_css_class("nm-edit-ip-advanced");
            override_fields.add_css_class("nm-edit-ipv6-overrides");
        }

        var override_revealer = new Gtk.Revealer();
        override_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN);
        override_revealer.set_transition_duration(180);
        override_revealer.add_css_class("nm-edit-ip-subsection-revealer");
        override_revealer.add_css_class("nm-edit-ipv6-overrides-revealer");
        override_revealer.set_child(override_fields);
        section.append(override_revealer);

        override_fields.append(build_label(
            "IPv6 Gateway",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-gateway-label" : null
        ));

        var gateway_mode_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        gateway_mode_row.set_halign(Gtk.Align.FILL);
        gateway_mode_row.set_hexpand(true);
        if (with_extra_classes) {
            gateway_mode_row.add_css_class("nm-edit-mode-row");
            gateway_mode_row.add_css_class("nm-edit-ipv6-gateway-mode-row");
        }

        var gateway_mode_label = new Gtk.Label("Automatic IPv6 gateway");
        gateway_mode_label.set_xalign(0.0f);
        gateway_mode_label.set_hexpand(true);
        gateway_mode_label.set_valign(Gtk.Align.CENTER);
        if (with_extra_classes) {
            gateway_mode_label.add_css_class("nm-edit-mode-label");
            gateway_mode_label.add_css_class("nm-edit-ipv6-gateway-mode-label");
        }
        gateway_mode_row.append(gateway_mode_label);

        ipv6_gateway_auto_switch = new Gtk.Switch();
        ipv6_gateway_auto_switch.set_valign(Gtk.Align.CENTER);
        ipv6_gateway_auto_switch.set_active(true);
        if (with_extra_classes) {
            ipv6_gateway_auto_switch.add_css_class("nm-switch");
            ipv6_gateway_auto_switch.add_css_class("nm-edit-field-control");
            ipv6_gateway_auto_switch.add_css_class("nm-edit-mode-switch");
            ipv6_gateway_auto_switch.add_css_class("nm-edit-ipv6-gateway-mode-switch");
        }
        ipv6_gateway_auto_switch.notify["active"].connect(() => {
            on_sync_sensitivity();
        });
        gateway_mode_row.append(ipv6_gateway_auto_switch);
        override_fields.append(gateway_mode_row);

        ipv6_gateway_entry = new Gtk.Entry();
        ipv6_gateway_entry.set_placeholder_text("fe80::1");
        apply_control_classes(
            ipv6_gateway_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-gateway-entry" : null
        );
        if (with_extra_classes) {
            ipv6_gateway_entry.add_css_class("nm-edit-field-entry");
        }
        override_fields.append(ipv6_gateway_entry);

        Gtk.DropDown local_ipv6_method_dropdown = ipv6_method_dropdown;
        Gtk.Switch local_ipv6_gateway_auto_switch = ipv6_gateway_auto_switch;

        MainWindowActionCallback sync_compact_visibility = () => {
            uint selected = local_ipv6_method_dropdown.get_selected();
            bool is_auto = selected == 0;
            bool is_manual = selected == 1;
            bool is_disabled_or_ignore = selected == 2 || selected == 3;

            manual_revealer.set_reveal_child(is_manual);
            override_revealer.set_reveal_child(is_auto || is_manual);

            if (is_disabled_or_ignore) {
                if (!local_ipv6_gateway_auto_switch.get_active()) {
                    local_ipv6_gateway_auto_switch.set_active(true);
                }
            }
            on_sync_sensitivity();
        };

        local_ipv6_method_dropdown.notify["selected"].connect(() => {
            sync_compact_visibility();
        });

        sync_compact_visibility();
    }
}
