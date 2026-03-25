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
        form.append(build_label(
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
        form.append(ipv4_method_dropdown);

        form.append(build_label(
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
        form.append(ipv4_address_entry);

        form.append(build_label(
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
        form.append(ipv4_prefix_entry);

        form.append(build_label(
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
        form.append(gateway_mode_row);

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
        form.append(ipv4_gateway_entry);

        form.append(build_label(
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
        form.append(dns_mode_row);

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
        form.append(ipv4_dns_entry);

        on_sync_sensitivity();
    }
}
