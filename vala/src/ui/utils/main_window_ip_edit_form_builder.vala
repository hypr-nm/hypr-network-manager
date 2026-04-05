using Gtk;

namespace MainWindowIpEditFormBuilder {
    private Gtk.Label build_label (string text, bool with_extra_classes, string? extra_class = null) {
        var label = new Gtk.Label (text);
        label.set_xalign (0.0f);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (label, {"nm-edit-field-label", "nm-form-label"});
        } else {
            label.add_css_class ("nm-form-label");
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
            MainWindowCssClassResolver.add_hook_and_best_class (widget, extra_class, {"nm-edit-field-control"});
            return;
        }

        widget.add_css_class ("nm-edit-field-control");
    }

    private void set_collapsible_state (
        Gtk.Box container,
        Gtk.Button toggle_button,
        Gtk.Revealer content_revealer,
        bool expanded
    ) {
        content_revealer.set_reveal_child (expanded);
        if (expanded) {
            container.add_css_class ("is-expanded");
            container.remove_css_class ("is-collapsed");
            toggle_button.set_tooltip_text ("Collapse section");
        } else {
            container.add_css_class ("is-collapsed");
            container.remove_css_class ("is-expanded");
            toggle_button.set_tooltip_text ("Expand section");
        }
    }

    private Gtk.Box build_collapsible_section (
        string title,
        bool with_extra_classes,
        string css_class,
        out Gtk.Box content_box
    ) {
        var container = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (container, css_class, {"nm-edit-collapsible"});
        } else {
            container.add_css_class ("nm-edit-collapsible");
        }

        var toggle_button = new Gtk.Button ();
        toggle_button.set_has_frame (false);
        toggle_button.set_halign (Gtk.Align.FILL);
        toggle_button.set_hexpand (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                toggle_button,
                css_class + "-toggle",
                {"nm-edit-section-toggle"}
            );
        } else {
            toggle_button.add_css_class ("nm-edit-section-toggle");
        }

        var toggle_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        toggle_row.set_halign (Gtk.Align.FILL);
        toggle_row.set_hexpand (true);
        toggle_row.add_css_class ("nm-edit-section-toggle-row");

        var toggle_icon = new Gtk.Image.from_icon_name ("pan-down-symbolic");
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                toggle_icon,
                css_class + "-toggle-icon",
                {"nm-edit-section-toggle-icon"}
            );
        } else {
            toggle_icon.add_css_class ("nm-edit-section-toggle-icon");
        }
        toggle_row.append (toggle_icon);

        var toggle_label = new Gtk.Label (title);
        toggle_label.set_xalign (0.0f);
        toggle_label.set_hexpand (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                toggle_label,
                css_class + "-toggle-label",
                {"nm-edit-section-toggle-label"}
            );
        } else {
            toggle_label.add_css_class ("nm-edit-section-toggle-label");
        }
        toggle_row.append (toggle_label);

        toggle_button.set_child (toggle_row);
        container.append (toggle_button);

        content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                content_box,
                css_class + "-content",
                {"nm-edit-section-content"}
            );
        } else {
            content_box.add_css_class ("nm-edit-section-content");
        }

        var content_revealer = new Gtk.Revealer ();
        content_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        content_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_MS);
        content_revealer.set_child (content_box);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                content_revealer,
                css_class + "-revealer",
                {"nm-edit-section-revealer"}
            );
        } else {
            content_revealer.add_css_class ("nm-edit-section-revealer");
        }
        container.append (content_revealer);

        set_collapsible_state (container, toggle_button, content_revealer, true);

        toggle_button.clicked.connect (() => {
            bool expanded = !content_revealer.get_reveal_child ();
            set_collapsible_state (container, toggle_button, content_revealer, expanded);
        });

        return container;
    }

    public void append_ipv4_section (
        Gtk.Box form,
        out Gtk.DropDown ipv4_method_dropdown,
        out Gtk.Entry ipv4_address_entry,
        out Gtk.Entry ipv4_prefix_entry,
        out Gtk.Entry ipv4_gateway_entry,
        out Gtk.Switch dns_auto_switch,
        out Gtk.Entry ipv4_dns_entry,
        MainWindowActionCallback on_sync_sensitivity,
        bool with_extra_classes
    ) {
        Gtk.Box section;
        var collapsible = build_collapsible_section (
            "IPv4 Settings",
            with_extra_classes,
            "nm-edit-ipv4-section",
            out section
        );
        form.append (collapsible);

        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                section,
                "nm-edit-ipv4-section",
                {"nm-edit-ip-section"}
            );
        }

        section.append (build_label (
            "IPv4 Method",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-method-label" : null
        ));

        var ipv4_method_list = new Gtk.StringList (null);
        ipv4_method_list.append ("Automatic (DHCP)");
        ipv4_method_list.append ("Manual");
        ipv4_method_list.append ("Disabled");
        ipv4_method_dropdown = new Gtk.DropDown (ipv4_method_list, null);
        apply_control_classes (ipv4_method_dropdown, with_extra_classes, null);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_method_dropdown,
                {"nm-edit-dropdown", "nm-edit-field-control"}
            );
            MainWindowCssClassResolver.add_best_class (
                ipv4_method_dropdown,
                {"nm-edit-ipv4-method-dropdown", "nm-edit-dropdown"}
            );
        }
        section.append (ipv4_method_dropdown);

        var manual_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                manual_fields,
                "nm-edit-ipv4-manual",
                {"nm-edit-ip-advanced"}
            );
        }

        var manual_revealer = new Gtk.Revealer ();
        manual_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        manual_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        MainWindowCssClassResolver.add_hook_and_best_class (
            manual_revealer,
            "nm-edit-ipv4-manual-revealer",
            {"nm-edit-ip-subsection-revealer"}
        );
        manual_revealer.set_child (manual_fields);
        section.append (manual_revealer);

        manual_fields.append (build_label (
            "IPv4 Address",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-address-label" : null
        ));

        ipv4_address_entry = new Gtk.Entry ();
        ipv4_address_entry.set_placeholder_text ("192.168.1.100");
        apply_control_classes (
            ipv4_address_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-address-entry" : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_address_entry,
                {"nm-edit-field-entry", "nm-edit-field-control"}
            );
        }
        manual_fields.append (ipv4_address_entry);

        manual_fields.append (build_label (
            "Prefix (CIDR)",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-prefix-label" : null
        ));

        ipv4_prefix_entry = new Gtk.Entry ();
        ipv4_prefix_entry.set_placeholder_text ("24");
        apply_control_classes (
            ipv4_prefix_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv4-prefix-entry" : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_prefix_entry,
                {"nm-edit-field-entry", "nm-edit-field-control"}
            );
        }
        manual_fields.append (ipv4_prefix_entry);

        manual_fields.append (build_label (
            "Gateway",
            with_extra_classes,
            with_extra_classes ? "nm-edit-gateway-label" : null
        ));

        ipv4_gateway_entry = new Gtk.Entry ();
        ipv4_gateway_entry.set_placeholder_text ("192.168.1.1");
        apply_control_classes (
            ipv4_gateway_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-gateway-entry" : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_gateway_entry,
                {"nm-edit-field-entry", "nm-edit-field-control"}
            );
        }
        manual_fields.append (ipv4_gateway_entry);

        var override_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                override_fields,
                "nm-edit-ipv4-overrides",
                {"nm-edit-ip-advanced"}
            );
        }

        var override_revealer = new Gtk.Revealer ();
        override_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        override_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        MainWindowCssClassResolver.add_hook_and_best_class (
            override_revealer,
            "nm-edit-ipv4-overrides-revealer",
            {"nm-edit-ip-subsection-revealer"}
        );
        override_revealer.set_child (override_fields);
        section.append (override_revealer);

        override_fields.append (build_label (
            "DNS Servers (comma-separated)",
            with_extra_classes,
            with_extra_classes ? "nm-edit-dns-label" : null
        ));

        var dns_mode_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        dns_mode_row.set_halign (Gtk.Align.FILL);
        dns_mode_row.set_hexpand (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                dns_mode_row,
                {"nm-edit-dns-mode-row", "nm-edit-mode-row"}
            );
        }

        var dns_mode_label = new Gtk.Label ("Automatic DNS");
        dns_mode_label.set_xalign (0.0f);
        dns_mode_label.set_hexpand (true);
        dns_mode_label.set_valign (Gtk.Align.CENTER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                dns_mode_label,
                "nm-edit-dns-mode-label",
                {"nm-edit-mode-label"}
            );
        }
        dns_mode_row.append (dns_mode_label);

        dns_auto_switch = new Gtk.Switch ();
        dns_auto_switch.set_valign (Gtk.Align.CENTER);
        dns_auto_switch.set_active (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                dns_auto_switch,
                {"nm-switch", "nm-edit-field-control"}
            );
            MainWindowCssClassResolver.add_best_class (
                dns_auto_switch,
                {"nm-edit-mode-switch", "nm-switch"}
            );
            MainWindowCssClassResolver.add_best_class (
                dns_auto_switch,
                {"nm-edit-dns-mode-switch", "nm-edit-mode-switch"}
            );
        }
        dns_auto_switch.notify["active"].connect (() => {
            on_sync_sensitivity ();
        });
        dns_mode_row.append (dns_auto_switch);
        override_fields.append (dns_mode_row);

        ipv4_dns_entry = new Gtk.Entry ();
        ipv4_dns_entry.set_placeholder_text ("1.1.1.1, 8.8.8.8");
        apply_control_classes (
            ipv4_dns_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-dns-entry" : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_dns_entry,
                {"nm-edit-field-entry", "nm-edit-field-control"}
            );
        }
        override_fields.append (ipv4_dns_entry);

        Gtk.DropDown local_ipv4_method_dropdown = ipv4_method_dropdown;
        Gtk.Switch local_dns_auto_switch = dns_auto_switch;

        MainWindowActionCallback sync_compact_visibility = () => {
            uint selected = local_ipv4_method_dropdown.get_selected ();
            bool is_auto = selected == 0;
            bool is_manual = selected == 1;
            bool is_disabled = selected == 2;

            manual_revealer.set_reveal_child (is_manual);
            override_revealer.set_reveal_child (is_auto || is_manual);

            if (is_disabled) {
                if (!local_dns_auto_switch.get_active ()) {
                    local_dns_auto_switch.set_active (true);
                }
            }
            on_sync_sensitivity ();
        };

        local_ipv4_method_dropdown.notify["selected"].connect (() => {
            sync_compact_visibility ();
        });

        sync_compact_visibility ();
    }

    public void append_ipv6_section (
        Gtk.Box form,
        out Gtk.DropDown ipv6_method_dropdown,
        out Gtk.Entry ipv6_address_entry,
        out Gtk.Entry ipv6_prefix_entry,
        out Gtk.Entry ipv6_gateway_entry,
        out Gtk.Switch ipv6_dns_auto_switch,
        out Gtk.Entry ipv6_dns_entry,
        MainWindowActionCallback on_sync_sensitivity,
        bool with_extra_classes
    ) {
        Gtk.Box section;
        var collapsible = build_collapsible_section (
            "IPv6 Settings",
            with_extra_classes,
            "nm-edit-ipv6-section",
            out section
        );
        form.append (collapsible);

        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                section,
                "nm-edit-ipv6-section",
                {"nm-edit-ip-section"}
            );
        }

        section.append (build_label (
            "IPv6 Method",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-method-label" : null
        ));

        var ipv6_method_list = new Gtk.StringList (null);
        ipv6_method_list.append ("Automatic");
        ipv6_method_list.append ("Manual");
        ipv6_method_list.append ("Disabled");
        ipv6_method_list.append ("Ignore");
        ipv6_method_dropdown = new Gtk.DropDown (ipv6_method_list, null);
        apply_control_classes (ipv6_method_dropdown, with_extra_classes, null);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_method_dropdown,
                {"nm-edit-dropdown", "nm-edit-field-control"}
            );
            MainWindowCssClassResolver.add_hook_and_best_class (
                ipv6_method_dropdown,
                "nm-edit-ipv6-method-dropdown",
                {"nm-edit-dropdown"}
            );
        }
        section.append (ipv6_method_dropdown);

        var manual_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                manual_fields,
                "nm-edit-ipv6-manual",
                {"nm-edit-ip-advanced"}
            );
        }

        var manual_revealer = new Gtk.Revealer ();
        manual_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        manual_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        MainWindowCssClassResolver.add_hook_and_best_class (
            manual_revealer,
            "nm-edit-ipv6-manual-revealer",
            {"nm-edit-ip-subsection-revealer"}
        );
        manual_revealer.set_child (manual_fields);
        section.append (manual_revealer);

        manual_fields.append (build_label (
            "IPv6 Address",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-address-label" : null
        ));

        ipv6_address_entry = new Gtk.Entry ();
        ipv6_address_entry.set_placeholder_text ("2001:db8::100");
        apply_control_classes (
            ipv6_address_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-address-entry" : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_address_entry,
                {"nm-edit-field-entry", "nm-edit-field-control"}
            );
        }
        manual_fields.append (ipv6_address_entry);

        manual_fields.append (build_label (
            "IPv6 Prefix (CIDR)",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-prefix-label" : null
        ));

        ipv6_prefix_entry = new Gtk.Entry ();
        ipv6_prefix_entry.set_placeholder_text ("64");
        apply_control_classes (
            ipv6_prefix_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-prefix-entry" : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_prefix_entry,
                {"nm-edit-field-entry", "nm-edit-field-control"}
            );
        }
        manual_fields.append (ipv6_prefix_entry);

        manual_fields.append (build_label (
            "IPv6 Gateway",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-gateway-label" : null
        ));

        ipv6_gateway_entry = new Gtk.Entry ();
        ipv6_gateway_entry.set_placeholder_text ("fe80::1");
        apply_control_classes (
            ipv6_gateway_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-gateway-entry" : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_gateway_entry,
                {"nm-edit-field-entry", "nm-edit-field-control"}
            );
        }
        manual_fields.append (ipv6_gateway_entry);

        var override_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                override_fields,
                "nm-edit-ipv6-overrides",
                {"nm-edit-ip-advanced"}
            );
        }

        var override_revealer = new Gtk.Revealer ();
        override_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        override_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        MainWindowCssClassResolver.add_hook_and_best_class (
            override_revealer,
            "nm-edit-ipv6-overrides-revealer",
            {"nm-edit-ip-subsection-revealer"}
        );
        override_revealer.set_child (override_fields);
        section.append (override_revealer);

        override_fields.append (build_label (
            "IPv6 DNS",
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-dns-label" : null
        ));

        var dns_mode_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        dns_mode_row.set_halign (Gtk.Align.FILL);
        dns_mode_row.set_hexpand (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                dns_mode_row,
                {"nm-edit-ipv6-dns-mode-row", "nm-edit-mode-row"}
            );
        }

        var dns_mode_label = new Gtk.Label ("Automatic IPv6 DNS");
        dns_mode_label.set_xalign (0.0f);
        dns_mode_label.set_hexpand (true);
        dns_mode_label.set_valign (Gtk.Align.CENTER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                dns_mode_label,
                "nm-edit-ipv6-dns-mode-label",
                {"nm-edit-mode-label"}
            );
        }
        dns_mode_row.append (dns_mode_label);

        ipv6_dns_auto_switch = new Gtk.Switch ();
        ipv6_dns_auto_switch.set_valign (Gtk.Align.CENTER);
        ipv6_dns_auto_switch.set_active (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_dns_auto_switch,
                {"nm-switch", "nm-edit-field-control"}
            );
            MainWindowCssClassResolver.add_best_class (
                ipv6_dns_auto_switch,
                {"nm-edit-mode-switch", "nm-switch"}
            );
            MainWindowCssClassResolver.add_best_class (
                ipv6_dns_auto_switch,
                {
                    "nm-edit-ipv6-dns-mode-switch",
                    "nm-edit-mode-switch"
                }
            );
        }
        ipv6_dns_auto_switch.notify["active"].connect (() => {
            on_sync_sensitivity ();
        });
        dns_mode_row.append (ipv6_dns_auto_switch);
        override_fields.append (dns_mode_row);

        ipv6_dns_entry = new Gtk.Entry ();
        ipv6_dns_entry.set_placeholder_text ("2606:4700:4700::1111, 2001:4860:4860::8888");
        apply_control_classes (
            ipv6_dns_entry,
            with_extra_classes,
            with_extra_classes ? "nm-edit-ipv6-dns-entry" : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_dns_entry,
                {"nm-edit-field-entry", "nm-edit-field-control"}
            );
        }
        override_fields.append (ipv6_dns_entry);

        Gtk.DropDown local_ipv6_method_dropdown = ipv6_method_dropdown;
        Gtk.Switch local_ipv6_dns_auto_switch = ipv6_dns_auto_switch;

        MainWindowActionCallback sync_compact_visibility = () => {
            uint selected = local_ipv6_method_dropdown.get_selected ();
            bool is_auto = selected == 0;
            bool is_manual = selected == 1;
            bool is_disabled_or_ignore = selected == 2 || selected == 3;

            manual_revealer.set_reveal_child (is_manual);
            override_revealer.set_reveal_child (is_auto || is_manual);

            if (is_disabled_or_ignore) {
                if (!local_ipv6_dns_auto_switch.get_active ()) {
                    local_ipv6_dns_auto_switch.set_active (true);
                }
            }
            on_sync_sensitivity ();
        };

        local_ipv6_method_dropdown.notify["selected"].connect (() => {
            sync_compact_visibility ();
        });

        sync_compact_visibility ();
    }
}
