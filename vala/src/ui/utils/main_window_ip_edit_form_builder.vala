using Gtk;
using HyprNetworkManager.UI.Interfaces;

namespace MainWindowIpEditFormBuilder {
    private Gtk.Label build_label (string text, bool with_extra_classes, string? extra_class = null) {
        var label = new Gtk.Label (text);
        label.set_xalign (0.0f);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (label, {MainWindowCssClasses.EDIT_FIELD_LABEL,
                MainWindowCssClasses.FORM_LABEL});
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
            MainWindowCssClassResolver.add_hook_and_best_class (widget, extra_class,
                {MainWindowCssClasses.EDIT_FIELD_CONTROL});
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
            MainWindowCssClassResolver.add_hook_and_best_class (container, css_class,
                {MainWindowCssClasses.EDIT_COLLAPSIBLE});
        } else {
            container.add_css_class (MainWindowCssClasses.EDIT_COLLAPSIBLE);
        }

        var toggle_button = new Gtk.Button ();
        toggle_button.set_has_frame (false);
        toggle_button.set_halign (Gtk.Align.FILL);
        toggle_button.set_hexpand (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                toggle_button,
                css_class + "-toggle",
                {MainWindowCssClasses.EDIT_SECTION_TOGGLE}
            );
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
            MainWindowCssClassResolver.add_hook_and_best_class (
                toggle_icon,
                css_class + "-toggle-icon",
                {MainWindowCssClasses.EDIT_SECTION_TOGGLE_ICON}
            );
        } else {
            toggle_icon.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_ICON);
        }
        toggle_row.append (toggle_icon);

        var toggle_label = new Gtk.Label (title);
        toggle_label.set_xalign (0.0f);
        toggle_label.set_hexpand (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                toggle_label,
                css_class + "-toggle-label",
                {MainWindowCssClasses.EDIT_SECTION_TOGGLE_LABEL}
            );
        } else {
            toggle_label.add_css_class (MainWindowCssClasses.EDIT_SECTION_TOGGLE_LABEL);
        }
        toggle_row.append (toggle_label);

        toggle_button.set_child (toggle_row);
        container.append (toggle_button);

        content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                content_box,
                css_class + "-content",
                {MainWindowCssClasses.EDIT_SECTION_CONTENT}
            );
        } else {
            content_box.add_css_class (MainWindowCssClasses.EDIT_SECTION_CONTENT);
        }

        var content_revealer = new Gtk.Revealer ();
        content_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        content_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_MS);
        content_revealer.set_child (content_box);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                content_revealer,
                css_class + "-revealer",
                {MainWindowCssClasses.EDIT_SECTION_REVEALER}
            );
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

    private void sync_ipv4_section_sensitivity (
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

        if (MainWindowIpSensitivityRules.should_force_ipv4_dns_auto_from_dropdown (selected)
            && !dns_auto_switch.get_active ()) {
            dns_auto_switch.set_active (true);
        }

        dns_entry.set_sensitive (
            MainWindowIpSensitivityRules.is_dns_entry_sensitive (dns_auto_switch.get_active ())
        );
    }

    private void sync_ipv6_section_sensitivity (
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

        if (MainWindowIpSensitivityRules.should_force_ipv6_dns_auto_from_dropdown (selected)
            && !dns_auto_switch.get_active ()) {
            dns_auto_switch.set_active (true);
        }

        dns_entry.set_sensitive (
            MainWindowIpSensitivityRules.is_dns_entry_sensitive (dns_auto_switch.get_active ())
        );
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
        Gtk.Box section;
        var collapsible = build_collapsible_section (
            "IPv4 Settings",
            with_extra_classes,
            MainWindowCssClasses.EDIT_IPV4_SECTION,
            out section
        );
        form.append (collapsible);

        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                section,
                MainWindowCssClasses.EDIT_IPV4_SECTION,
                {MainWindowCssClasses.EDIT_IP_SECTION}
            );
        }

        section.append (build_label (
            "IPv4 Method",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV4_METHOD_LABEL : null
        ));

        var ipv4_method_list = new Gtk.StringList (null);
        ipv4_method_list.append ("Automatic (DHCP)");
        ipv4_method_list.append ("Manual");
        ipv4_method_list.append ("Disabled");
        ipv4_method_dropdown = create_dropdown (ipv4_method_list);
        apply_control_classes (ipv4_method_dropdown, with_extra_classes, null);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_method_dropdown,
                {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
            MainWindowCssClassResolver.add_best_class (
                ipv4_method_dropdown,
                {MainWindowCssClasses.EDIT_IPV4_METHOD_DROPDOWN, MainWindowCssClasses.EDIT_DROPDOWN}
            );
        }
        section.append (ipv4_method_dropdown);

        var manual_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                manual_fields,
                MainWindowCssClasses.EDIT_IPV4_MANUAL,
                {MainWindowCssClasses.EDIT_IP_ADVANCED}
            );
        }

        var manual_revealer = new Gtk.Revealer ();
        manual_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        manual_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        MainWindowCssClassResolver.add_hook_and_best_class (
            manual_revealer,
            MainWindowCssClasses.EDIT_IPV4_MANUAL_REVEALER,
            {MainWindowCssClasses.EDIT_IP_SUBSECTION_REVEALER}
        );
        manual_revealer.set_child (manual_fields);
        section.append (manual_revealer);

        manual_fields.append (build_label (
            "IPv4 Address",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV4_ADDRESS_LABEL : null
        ));

        ipv4_address_entry = new Gtk.Entry ();
        ipv4_address_entry.set_placeholder_text ("192.168.1.100");
        apply_control_classes (
            ipv4_address_entry,
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV4_ADDRESS_ENTRY : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_address_entry,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
        }
        manual_fields.append (ipv4_address_entry);

        manual_fields.append (build_label (
            "Prefix (CIDR)",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV4_PREFIX_LABEL : null
        ));

        ipv4_prefix_entry = new Gtk.Entry ();
        ipv4_prefix_entry.set_placeholder_text ("24");
        apply_control_classes (
            ipv4_prefix_entry,
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV4_PREFIX_ENTRY : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_prefix_entry,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
        }
        manual_fields.append (ipv4_prefix_entry);

        manual_fields.append (build_label (
            "Gateway",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_GATEWAY_LABEL : null
        ));

        ipv4_gateway_entry = new Gtk.Entry ();
        ipv4_gateway_entry.set_placeholder_text ("192.168.1.1");
        apply_control_classes (
            ipv4_gateway_entry,
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_GATEWAY_ENTRY : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_gateway_entry,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
        }
        manual_fields.append (ipv4_gateway_entry);

        var override_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                override_fields,
                MainWindowCssClasses.EDIT_IPV4_OVERRIDES,
                {MainWindowCssClasses.EDIT_IP_ADVANCED}
            );
        }

        var override_revealer = new Gtk.Revealer ();
        override_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        override_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        MainWindowCssClassResolver.add_hook_and_best_class (
            override_revealer,
            MainWindowCssClasses.EDIT_IPV4_OVERRIDES_REVEALER,
            {MainWindowCssClasses.EDIT_IP_SUBSECTION_REVEALER}
        );
        override_revealer.set_child (override_fields);
        section.append (override_revealer);

        override_fields.append (build_label (
            "DNS Servers (comma-separated)",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_DNS_LABEL : null
        ));

        var dns_mode_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        dns_mode_row.set_halign (Gtk.Align.FILL);
        dns_mode_row.set_hexpand (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                dns_mode_row,
                {MainWindowCssClasses.EDIT_DNS_MODE_ROW, MainWindowCssClasses.EDIT_MODE_ROW}
            );
        }

        var dns_mode_label = new Gtk.Label ("Automatic DNS");
        dns_mode_label.set_xalign (0.0f);
        dns_mode_label.set_hexpand (true);
        dns_mode_label.set_valign (Gtk.Align.CENTER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                dns_mode_label,
                MainWindowCssClasses.EDIT_DNS_MODE_LABEL,
                {MainWindowCssClasses.EDIT_MODE_LABEL}
            );
        }
        dns_mode_row.append (dns_mode_label);

        dns_auto_switch = new Gtk.Switch ();
        dns_auto_switch.set_valign (Gtk.Align.CENTER);
        dns_auto_switch.set_active (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                dns_auto_switch,
                {MainWindowCssClasses.SWITCH, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
            MainWindowCssClassResolver.add_best_class (
                dns_auto_switch,
                {MainWindowCssClasses.EDIT_MODE_SWITCH, MainWindowCssClasses.SWITCH}
            );
            MainWindowCssClassResolver.add_best_class (
                dns_auto_switch,
                {MainWindowCssClasses.EDIT_DNS_MODE_SWITCH, MainWindowCssClasses.EDIT_MODE_SWITCH}
            );
        }
        dns_mode_row.append (dns_auto_switch);
        override_fields.append (dns_mode_row);

        ipv4_dns_entry = new Gtk.Entry ();
        ipv4_dns_entry.set_placeholder_text ("1.1.1.1, 8.8.8.8");
        apply_control_classes (
            ipv4_dns_entry,
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_DNS_ENTRY : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv4_dns_entry,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
        }
        override_fields.append (ipv4_dns_entry);

        HyprNetworkManager.UI.Widgets.TrackedDropDown local_ipv4_method_dropdown = ipv4_method_dropdown;
        Gtk.Switch local_dns_auto_switch = dns_auto_switch;
        Gtk.Entry local_ipv4_dns_entry = ipv4_dns_entry;

        local_ipv4_method_dropdown.notify_selected.connect (() => {
            sync_ipv4_section_sensitivity (
                local_ipv4_method_dropdown,
                manual_revealer,
                override_revealer,
                local_dns_auto_switch,
                local_ipv4_dns_entry
            );
        });

        local_dns_auto_switch.notify["active"].connect (() => {
            sync_ipv4_section_sensitivity (
                local_ipv4_method_dropdown,
                manual_revealer,
                override_revealer,
                local_dns_auto_switch,
                local_ipv4_dns_entry
            );
        });

        sync_ipv4_section_sensitivity (
            local_ipv4_method_dropdown,
            manual_revealer,
            override_revealer,
            local_dns_auto_switch,
            local_ipv4_dns_entry
        );
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
        Gtk.Box section;
        var collapsible = build_collapsible_section (
            "IPv6 Settings",
            with_extra_classes,
            MainWindowCssClasses.EDIT_IPV6_SECTION,
            out section
        );
        form.append (collapsible);

        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                section,
                MainWindowCssClasses.EDIT_IPV6_SECTION,
                {MainWindowCssClasses.EDIT_IP_SECTION}
            );
        }

        section.append (build_label (
            "IPv6 Method",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV6_METHOD_LABEL : null
        ));

        var ipv6_method_list = new Gtk.StringList (null);
        ipv6_method_list.append ("Automatic");
        ipv6_method_list.append ("Manual");
        ipv6_method_list.append ("Disabled");
        ipv6_method_list.append ("Ignore");
        ipv6_method_dropdown = create_dropdown (ipv6_method_list);
        apply_control_classes (ipv6_method_dropdown, with_extra_classes, null);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_method_dropdown,
                {MainWindowCssClasses.EDIT_DROPDOWN, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
            MainWindowCssClassResolver.add_hook_and_best_class (
                ipv6_method_dropdown,
                MainWindowCssClasses.EDIT_IPV6_METHOD_DROPDOWN,
                {MainWindowCssClasses.EDIT_DROPDOWN}
            );
        }
        section.append (ipv6_method_dropdown);

        var manual_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                manual_fields,
                MainWindowCssClasses.EDIT_IPV6_MANUAL,
                {MainWindowCssClasses.EDIT_IP_ADVANCED}
            );
        }

        var manual_revealer = new Gtk.Revealer ();
        manual_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        manual_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        MainWindowCssClassResolver.add_hook_and_best_class (
            manual_revealer,
            MainWindowCssClasses.EDIT_IPV6_MANUAL_REVEALER,
            {MainWindowCssClasses.EDIT_IP_SUBSECTION_REVEALER}
        );
        manual_revealer.set_child (manual_fields);
        section.append (manual_revealer);

        manual_fields.append (build_label (
            "IPv6 Address",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV6_ADDRESS_LABEL : null
        ));

        ipv6_address_entry = new Gtk.Entry ();
        ipv6_address_entry.set_placeholder_text ("2001:db8::100");
        apply_control_classes (
            ipv6_address_entry,
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV6_ADDRESS_ENTRY : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_address_entry,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
        }
        manual_fields.append (ipv6_address_entry);

        manual_fields.append (build_label (
            "IPv6 Prefix (CIDR)",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV6_PREFIX_LABEL : null
        ));

        ipv6_prefix_entry = new Gtk.Entry ();
        ipv6_prefix_entry.set_placeholder_text ("64");
        apply_control_classes (
            ipv6_prefix_entry,
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV6_PREFIX_ENTRY : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_prefix_entry,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
        }
        manual_fields.append (ipv6_prefix_entry);

        manual_fields.append (build_label (
            "IPv6 Gateway",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV6_GATEWAY_LABEL : null
        ));

        ipv6_gateway_entry = new Gtk.Entry ();
        ipv6_gateway_entry.set_placeholder_text ("fe80::1");
        apply_control_classes (
            ipv6_gateway_entry,
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV6_GATEWAY_ENTRY : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_gateway_entry,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
        }
        manual_fields.append (ipv6_gateway_entry);

        var override_fields = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                override_fields,
                MainWindowCssClasses.EDIT_IPV6_OVERRIDES,
                {MainWindowCssClasses.EDIT_IP_ADVANCED}
            );
        }

        var override_revealer = new Gtk.Revealer ();
        override_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        override_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_COMPACT_MS);
        MainWindowCssClassResolver.add_hook_and_best_class (
            override_revealer,
            MainWindowCssClasses.EDIT_IPV6_OVERRIDES_REVEALER,
            {MainWindowCssClasses.EDIT_IP_SUBSECTION_REVEALER}
        );
        override_revealer.set_child (override_fields);
        section.append (override_revealer);

        override_fields.append (build_label (
            "IPv6 DNS",
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV6_DNS_LABEL : null
        ));

        var dns_mode_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        dns_mode_row.set_halign (Gtk.Align.FILL);
        dns_mode_row.set_hexpand (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                dns_mode_row,
                {MainWindowCssClasses.EDIT_IPV6_DNS_MODE_ROW, MainWindowCssClasses.EDIT_MODE_ROW}
            );
        }

        var dns_mode_label = new Gtk.Label ("Automatic IPv6 DNS");
        dns_mode_label.set_xalign (0.0f);
        dns_mode_label.set_hexpand (true);
        dns_mode_label.set_valign (Gtk.Align.CENTER);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_hook_and_best_class (
                dns_mode_label,
                MainWindowCssClasses.EDIT_IPV6_DNS_MODE_LABEL,
                {MainWindowCssClasses.EDIT_MODE_LABEL}
            );
        }
        dns_mode_row.append (dns_mode_label);

        ipv6_dns_auto_switch = new Gtk.Switch ();
        ipv6_dns_auto_switch.set_valign (Gtk.Align.CENTER);
        ipv6_dns_auto_switch.set_active (true);
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_dns_auto_switch,
                {MainWindowCssClasses.SWITCH, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
            MainWindowCssClassResolver.add_best_class (
                ipv6_dns_auto_switch,
                {MainWindowCssClasses.EDIT_MODE_SWITCH, MainWindowCssClasses.SWITCH}
            );
            MainWindowCssClassResolver.add_best_class (
                ipv6_dns_auto_switch,
                {
                    MainWindowCssClasses.EDIT_IPV6_DNS_MODE_SWITCH,
                    MainWindowCssClasses.EDIT_MODE_SWITCH
                }
            );
        }
        dns_mode_row.append (ipv6_dns_auto_switch);
        override_fields.append (dns_mode_row);

        ipv6_dns_entry = new Gtk.Entry ();
        ipv6_dns_entry.set_placeholder_text ("2606:4700:4700::1111, 2001:4860:4860::8888");
        apply_control_classes (
            ipv6_dns_entry,
            with_extra_classes,
            with_extra_classes ? MainWindowCssClasses.EDIT_IPV6_DNS_ENTRY : null
        );
        if (with_extra_classes) {
            MainWindowCssClassResolver.add_best_class (
                ipv6_dns_entry,
                {MainWindowCssClasses.EDIT_FIELD_ENTRY, MainWindowCssClasses.EDIT_FIELD_CONTROL}
            );
        }
        override_fields.append (ipv6_dns_entry);

        HyprNetworkManager.UI.Widgets.TrackedDropDown local_ipv6_method_dropdown = ipv6_method_dropdown;
        Gtk.Switch local_ipv6_dns_auto_switch = ipv6_dns_auto_switch;
        Gtk.Entry local_ipv6_dns_entry = ipv6_dns_entry;

        local_ipv6_method_dropdown.notify_selected.connect (() => {
            sync_ipv6_section_sensitivity (
                local_ipv6_method_dropdown,
                manual_revealer,
                override_revealer,
                local_ipv6_dns_auto_switch,
                local_ipv6_dns_entry
            );
        });

        local_ipv6_dns_auto_switch.notify["active"].connect (() => {
            sync_ipv6_section_sensitivity (
                local_ipv6_method_dropdown,
                manual_revealer,
                override_revealer,
                local_ipv6_dns_auto_switch,
                local_ipv6_dns_entry
            );
        });

        sync_ipv6_section_sensitivity (
            local_ipv6_method_dropdown,
            manual_revealer,
            override_revealer,
            local_ipv6_dns_auto_switch,
            local_ipv6_dns_entry
        );
    }
}
