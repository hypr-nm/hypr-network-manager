using GLib;
using Gtk;

public class MainWindowEthernetController : Object {
    private bool is_disposed = false;
    private uint ui_epoch = 1;
    private uint[] timeout_source_ids = {};

    private NetworkManagerClientVala nm;
    private owned MainWindowErrorCallback on_error;
    private owned MainWindowRefreshActionCallback on_refresh_after_action;
    private owned MainWindowBoolCallback on_set_popup_text_input_mode;

    private Gtk.ListBox ethernet_listbox;
    private Gtk.Stack ethernet_stack;
    private NetworkDevice? selected_ethernet_device = null;

    private Gtk.Label ethernet_details_title;
    private Gtk.Box ethernet_details_basic_rows;
    private Gtk.Box ethernet_details_advanced_rows;
    private Gtk.Box ethernet_details_ip_rows;
    private Gtk.Button ethernet_details_primary_button;
    private Gtk.Button ethernet_details_edit_button;

    private Gtk.Label ethernet_edit_title;
    private Gtk.Label ethernet_edit_note;
    private Gtk.DropDown ethernet_edit_ipv4_method_dropdown;
    private Gtk.Entry ethernet_edit_ipv4_address_entry;
    private Gtk.Entry ethernet_edit_ipv4_prefix_entry;
    private Gtk.Switch ethernet_edit_gateway_auto_switch;
    private Gtk.Entry ethernet_edit_ipv4_gateway_entry;
    private Gtk.Switch ethernet_edit_dns_auto_switch;
    private Gtk.Entry ethernet_edit_ipv4_dns_entry;
    private Gtk.DropDown ethernet_edit_ipv6_method_dropdown;
    private Gtk.Entry ethernet_edit_ipv6_address_entry;
    private Gtk.Entry ethernet_edit_ipv6_prefix_entry;
    private Gtk.Switch ethernet_edit_ipv6_gateway_auto_switch;
    private Gtk.Entry ethernet_edit_ipv6_gateway_entry;

    private HashTable<string, bool> pending_ethernet_action;
    private HashTable<string, bool> pending_ethernet_target_connected;

    public MainWindowEthernetController(
        NetworkManagerClientVala nm,
        owned MainWindowErrorCallback on_error,
        owned MainWindowRefreshActionCallback on_refresh_after_action,
        owned MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        this.nm = nm;
        this.on_error = (owned) on_error;
        this.on_refresh_after_action = (owned) on_refresh_after_action;
        this.on_set_popup_text_input_mode = (owned) on_set_popup_text_input_mode;
        pending_ethernet_action = new HashTable<string, bool>(str_hash, str_equal);
        pending_ethernet_target_connected = new HashTable<string, bool>(str_hash, str_equal);
    }

    public void on_page_leave() {
        invalidate_ui_state();
    }

    public void dispose_controller() {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        invalidate_ui_state();
    }

    private uint capture_ui_epoch() {
        return ui_epoch;
    }

    private bool is_ui_epoch_valid(uint epoch) {
        return !is_disposed && epoch == ui_epoch;
    }

    private void invalidate_ui_state() {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_all_timeout_sources();
    }

    private void track_timeout_source(uint source_id) {
        if (source_id == 0) {
            return;
        }
        timeout_source_ids += source_id;
    }

    private void untrack_timeout_source(uint source_id) {
        if (source_id == 0 || timeout_source_ids.length == 0) {
            return;
        }

        uint[] remaining = {};
        foreach (uint id in timeout_source_ids) {
            if (id != source_id) {
                remaining += id;
            }
        }
        timeout_source_ids = remaining;
    }

    private void cancel_all_timeout_sources() {
        if (timeout_source_ids.length == 0) {
            return;
        }

        foreach (uint source_id in timeout_source_ids) {
            Source.remove(source_id);
        }
        timeout_source_ids = {};
    }

    public Gtk.Widget build_page() {
        var details_page = new MainWindowEthernetDetailsPage();
        var edit_page = new MainWindowEthernetEditPage();

        ethernet_details_title = details_page.details_title;
        ethernet_details_basic_rows = details_page.basic_rows;
        ethernet_details_advanced_rows = details_page.advanced_rows;
        ethernet_details_ip_rows = details_page.ip_rows;
        ethernet_details_primary_button = details_page.primary_button;
        ethernet_details_edit_button = details_page.edit_button;

        ethernet_edit_title = edit_page.edit_title;
        ethernet_edit_note = edit_page.note_label;
        ethernet_edit_ipv4_method_dropdown = edit_page.ipv4_method_dropdown;
        ethernet_edit_ipv4_address_entry = edit_page.ipv4_address_entry;
        ethernet_edit_ipv4_prefix_entry = edit_page.ipv4_prefix_entry;
        ethernet_edit_gateway_auto_switch = edit_page.gateway_auto_switch;
        ethernet_edit_ipv4_gateway_entry = edit_page.ipv4_gateway_entry;
        ethernet_edit_dns_auto_switch = edit_page.dns_auto_switch;
        ethernet_edit_ipv4_dns_entry = edit_page.ipv4_dns_entry;
        ethernet_edit_ipv6_method_dropdown = edit_page.ipv6_method_dropdown;
        ethernet_edit_ipv6_address_entry = edit_page.ipv6_address_entry;
        ethernet_edit_ipv6_prefix_entry = edit_page.ipv6_prefix_entry;
        ethernet_edit_ipv6_gateway_auto_switch = edit_page.ipv6_gateway_auto_switch;
        ethernet_edit_ipv6_gateway_entry = edit_page.ipv6_gateway_entry;

        details_page.back.connect(() => {
            invalidate_ui_state();
            selected_ethernet_device = null;
            on_set_popup_text_input_mode(false);
            ethernet_stack.set_visible_child_name("list");
        });

        details_page.primary_action.connect(() => {
            if (selected_ethernet_device != null) {
                trigger_toggle(selected_ethernet_device);
            }
        });

        details_page.edit.connect(() => {
            if (selected_ethernet_device != null) {
                open_edit(selected_ethernet_device);
            }
        });

        edit_page.back.connect(() => {
            on_set_popup_text_input_mode(false);
            if (selected_ethernet_device != null) {
                open_details(selected_ethernet_device);
            } else {
                ethernet_stack.set_visible_child_name("list");
            }
        });

        edit_page.apply.connect(() => {
            apply_edit();
        });

        edit_page.sync_sensitivity.connect(() => {
            sync_edit_gateway_dns_sensitivity();
        });

        return MainWindowEthernetPageBuilder.build_page(
            out ethernet_listbox,
            out ethernet_stack,
            details_page,
            edit_page,
            () => {
                refresh();
            }
        );
    }

    private void sync_edit_gateway_dns_sensitivity() {
        if (ethernet_edit_ipv4_method_dropdown != null) {
            bool ipv4_manual = ethernet_edit_ipv4_method_dropdown.get_selected() == 1;
            bool ipv4_disabled = ethernet_edit_ipv4_method_dropdown.get_selected() == 2;
            if (!ipv4_manual && ipv4_disabled) {
                if (ethernet_edit_gateway_auto_switch != null) {
                    ethernet_edit_gateway_auto_switch.set_active(true);
                }
                if (ethernet_edit_dns_auto_switch != null) {
                    ethernet_edit_dns_auto_switch.set_active(true);
                }
            }
        }

        if (ethernet_edit_ipv6_method_dropdown != null) {
            bool ipv6_manual = ethernet_edit_ipv6_method_dropdown.get_selected() == 1;
            uint selected = ethernet_edit_ipv6_method_dropdown.get_selected();
            bool ipv6_disabled_or_ignore = selected == 2 || selected == 3;
            if (!ipv6_manual && ipv6_disabled_or_ignore) {
                if (ethernet_edit_ipv6_gateway_auto_switch != null) {
                    ethernet_edit_ipv6_gateway_auto_switch.set_active(true);
                }
            }
        }

        if (ethernet_edit_ipv4_gateway_entry != null && ethernet_edit_gateway_auto_switch != null) {
            ethernet_edit_ipv4_gateway_entry.set_sensitive(!ethernet_edit_gateway_auto_switch.get_active());
        }
        if (ethernet_edit_ipv4_dns_entry != null && ethernet_edit_dns_auto_switch != null) {
            ethernet_edit_ipv4_dns_entry.set_sensitive(!ethernet_edit_dns_auto_switch.get_active());
        }
        if (ethernet_edit_ipv6_gateway_entry != null && ethernet_edit_ipv6_gateway_auto_switch != null) {
            ethernet_edit_ipv6_gateway_entry.set_sensitive(!ethernet_edit_ipv6_gateway_auto_switch.get_active());
        }
    }

    private void track_pending_action(NetworkDevice dev, bool target_connected, uint epoch) {
        pending_ethernet_action.insert(dev.name, true);
        pending_ethernet_target_connected.insert(dev.name, target_connected);

        string iface_name = dev.name;
        uint timeout_id = 0;
        timeout_id = Timeout.add(20000, () => {
            untrack_timeout_source(timeout_id);
            if (!is_ui_epoch_valid(epoch)) {
                return false;
            }
            pending_ethernet_action.remove(iface_name);
            pending_ethernet_target_connected.remove(iface_name);
            refresh();
            return false;
        });
        track_timeout_source(timeout_id);
    }

    private void trigger_toggle(NetworkDevice dev) {
        if (pending_ethernet_action.contains(dev.name)) {
            return;
        }

        uint epoch = capture_ui_epoch();
        bool target_connected = !dev.is_connected;
        if (dev.is_connected) {
            nm.disconnect_device.begin(dev.name, null, (obj, res) => {
                try {
                    nm.disconnect_device.end(res);
                    if (!is_ui_epoch_valid(epoch)) {
                        return;
                    }
                    track_pending_action(dev, target_connected, epoch);
                    on_refresh_after_action(false);
                } catch (Error e) {
                    if (!is_ui_epoch_valid(epoch)) {
                        return;
                    }
                    on_error("Ethernet disconnect failed: " + e.message);
                }
            });
            return;
        }

        nm.connect_ethernet_device.begin(dev, null, (obj, res) => {
            try {
                nm.connect_ethernet_device.end(res);
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                track_pending_action(dev, target_connected, epoch);
                on_refresh_after_action(false);
            } catch (Error e) {
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                on_error("Ethernet connect failed: " + e.message);
            }
        });
    }

    private void populate_details(NetworkDevice dev) {
        uint epoch = capture_ui_epoch();
        ethernet_details_title.set_text(dev.name);

        MainWindowHelpers.clear_box(ethernet_details_basic_rows);
        MainWindowHelpers.clear_box(ethernet_details_advanced_rows);
        MainWindowHelpers.clear_box(ethernet_details_ip_rows);

        string profile_name = dev.connection.strip() != "" ? dev.connection : "n/a";
        bool has_profile = dev.connection.strip() != "";
        bool pending = pending_ethernet_action.contains(dev.name);

        ethernet_details_basic_rows.append(MainWindowHelpers.build_details_row("Interface", dev.name));
        ethernet_details_basic_rows.append(MainWindowHelpers.build_details_row("Profile", profile_name));
        ethernet_details_basic_rows.append(MainWindowHelpers.build_details_row("State", dev.state_label));
        ethernet_details_basic_rows.append(
            MainWindowHelpers.build_details_row("Connected", dev.is_connected ? "Yes" : "No")
        );

        ethernet_details_advanced_rows.append(
            MainWindowHelpers.build_details_row("Device Path", dev.device_path)
        );
        ethernet_details_advanced_rows.append(
            MainWindowHelpers.build_details_row("State Code", "%u".printf(dev.state))
        );

        ethernet_details_ip_rows.append(MainWindowHelpers.build_details_row("Loading", "Reading IP settings..."));

        nm.get_ethernet_device_ip_settings.begin(dev, null, (obj, res) => {
            var ip_settings = nm.get_ethernet_device_ip_settings.end(res);
            if (!is_ui_epoch_valid(epoch)) {
                return;
            }

            if (selected_ethernet_device == null
                || (selected_ethernet_device.device_path != dev.device_path
                    && selected_ethernet_device.name != dev.name)) {
                return;
            }

            MainWindowHelpers.clear_box(ethernet_details_ip_rows);
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Configured IPv4 Method",
                    MainWindowHelpers.get_ipv4_method_label(ip_settings.ipv4_method)
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Configured IPv4 Address",
                    MainWindowHelpers.format_ip_with_prefix(
                        ip_settings.configured_address,
                        ip_settings.configured_prefix
                    )
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Configured Gateway",
                    ip_settings.configured_gateway.strip() != "" ? ip_settings.configured_gateway : "n/a"
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Configured DNS",
                    ip_settings.configured_dns.strip() != "" ? ip_settings.configured_dns : "n/a"
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Current IPv4 Address",
                    MainWindowHelpers.format_ip_with_prefix(
                        ip_settings.current_address,
                        ip_settings.current_prefix
                    )
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Current Gateway",
                    ip_settings.current_gateway.strip() != "" ? ip_settings.current_gateway : "n/a"
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Current DNS",
                    ip_settings.current_dns.strip() != "" ? ip_settings.current_dns : "n/a"
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Configured IPv6 Method",
                    MainWindowHelpers.get_ipv6_method_label(ip_settings.ipv6_method)
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Configured IPv6 Address",
                    MainWindowHelpers.format_ip_with_prefix(
                        ip_settings.configured_ipv6_address,
                        ip_settings.configured_ipv6_prefix
                    )
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Configured IPv6 Gateway",
                    ip_settings.configured_ipv6_gateway.strip() != ""
                        ? ip_settings.configured_ipv6_gateway
                        : "n/a"
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Current IPv6 Address",
                    MainWindowHelpers.format_ip_with_prefix(
                        ip_settings.current_ipv6_address,
                        ip_settings.current_ipv6_prefix
                    )
                )
            );
            ethernet_details_ip_rows.append(
                MainWindowHelpers.build_details_row(
                    "Current IPv6 Gateway",
                    ip_settings.current_ipv6_gateway.strip() != "" ? ip_settings.current_ipv6_gateway : "n/a"
                )
            );
        });

        if (pending) {
            ethernet_details_primary_button.set_label("Updating...");
            ethernet_details_primary_button.set_sensitive(false);
        } else if (dev.is_connected) {
            ethernet_details_primary_button.set_label("Disconnect");
            ethernet_details_primary_button.set_sensitive(true);
        } else if (has_profile) {
            ethernet_details_primary_button.set_label("Connect");
            ethernet_details_primary_button.set_sensitive(true);
        } else {
            ethernet_details_primary_button.set_label("No Profile");
            ethernet_details_primary_button.set_sensitive(false);
        }

        ethernet_details_edit_button.set_sensitive(has_profile && !pending);
    }

    private void open_details(NetworkDevice dev) {
        selected_ethernet_device = dev;
        populate_details(dev);
        ethernet_stack.set_visible_child_name("details");
    }

    private void open_edit(NetworkDevice dev) {
        if (dev.connection.strip() == "") {
            on_error("This interface has no saved Ethernet profile to edit.");
            return;
        }

        selected_ethernet_device = dev;
        uint epoch = capture_ui_epoch();
        ethernet_edit_title.set_text("Edit: %s".printf(dev.name));
        ethernet_edit_note.set_text("Update IPv4 and IPv6 settings for profile: %s".printf(dev.connection));

        ethernet_stack.set_visible_child_name("edit");
        on_set_popup_text_input_mode(true);

        nm.get_ethernet_device_ip_settings.begin(dev, null, (obj, res) => {
            var ip_settings = nm.get_ethernet_device_ip_settings.end(res);
            if (!is_ui_epoch_valid(epoch)) {
                return;
            }

            if (selected_ethernet_device == null
                || (selected_ethernet_device.device_path != dev.device_path
                    && selected_ethernet_device.name != dev.name)) {
                return;
            }

            ethernet_edit_ipv4_method_dropdown.set_selected(
                MainWindowHelpers.get_ipv4_method_dropdown_index(ip_settings.ipv4_method)
            );
            ethernet_edit_ipv4_address_entry.set_text(ip_settings.configured_address);
            ethernet_edit_ipv4_prefix_entry.set_text(
                ip_settings.configured_prefix > 0 ? "%u".printf(ip_settings.configured_prefix) : ""
            );
            ethernet_edit_gateway_auto_switch.set_active(ip_settings.gateway_auto);
            ethernet_edit_ipv4_gateway_entry.set_text(ip_settings.configured_gateway);
            ethernet_edit_dns_auto_switch.set_active(ip_settings.dns_auto);
            ethernet_edit_ipv4_dns_entry.set_text(ip_settings.configured_dns);
            ethernet_edit_ipv6_method_dropdown.set_selected(
                MainWindowHelpers.get_ipv6_method_dropdown_index(ip_settings.ipv6_method)
            );
            ethernet_edit_ipv6_address_entry.set_text(ip_settings.configured_ipv6_address);
            ethernet_edit_ipv6_prefix_entry.set_text(
                ip_settings.configured_ipv6_prefix > 0 ? "%u".printf(ip_settings.configured_ipv6_prefix) : ""
            );
            ethernet_edit_ipv6_gateway_auto_switch.set_active(ip_settings.ipv6_gateway_auto);
            ethernet_edit_ipv6_gateway_entry.set_text(ip_settings.configured_ipv6_gateway);

            sync_edit_gateway_dns_sensitivity();
            ethernet_edit_ipv4_address_entry.grab_focus();
        });
    }

    private void apply_edit() {
        if (selected_ethernet_device == null) {
            return;
        }

        uint epoch = capture_ui_epoch();
        NetworkDevice dev = selected_ethernet_device;
        string method = MainWindowWifiEditUtils.get_selected_ipv4_method(
            ethernet_edit_ipv4_method_dropdown
        );
        string ipv4_address = ethernet_edit_ipv4_address_entry.get_text().strip();
        bool gateway_auto = ethernet_edit_gateway_auto_switch.get_active();
        string ipv4_gateway = ethernet_edit_ipv4_gateway_entry.get_text().strip();
        bool dns_auto = ethernet_edit_dns_auto_switch.get_active();
        string dns_csv = ethernet_edit_ipv4_dns_entry.get_text().strip();
        string method6 = MainWindowWifiEditUtils.get_selected_ipv6_method(
            ethernet_edit_ipv6_method_dropdown
        );
        string ipv6_address = ethernet_edit_ipv6_address_entry.get_text().strip();
        bool ipv6_gateway_auto = ethernet_edit_ipv6_gateway_auto_switch.get_active();
        string ipv6_gateway = ethernet_edit_ipv6_gateway_entry.get_text().strip();

        if (method == "disabled") {
            gateway_auto = true;
            dns_auto = true;
        }

        if (method6 == "disabled" || method6 == "ignore") {
            ipv6_gateway_auto = true;
        }

        uint32 ipv4_prefix;
        string prefix_error;
        if (!MainWindowWifiEditUtils.try_parse_prefix(
            ethernet_edit_ipv4_prefix_entry.get_text(),
            out ipv4_prefix,
            out prefix_error
        )) {
            on_error(prefix_error);
            return;
        }

        uint32 ipv6_prefix;
        string prefix6_error;
        if (!MainWindowWifiEditUtils.try_parse_ipv6_prefix(
            ethernet_edit_ipv6_prefix_entry.get_text(),
            out ipv6_prefix,
            out prefix6_error
        )) {
            on_error(prefix6_error);
            return;
        }

        if (method == "manual") {
            if (ipv4_address == "") {
                on_error("Manual IPv4 requires an address.");
                return;
            }
            if (ipv4_prefix == 0) {
                on_error("Manual IPv4 requires a prefix between 1 and 32.");
                return;
            }
        }

        if (!gateway_auto && ipv4_gateway == "") {
            on_error("Manual gateway is enabled; please provide a gateway address.");
            return;
        }

        if (!gateway_auto && method == "disabled") {
            on_error("Manual gateway is not supported when IPv4 method is Disabled.");
            return;
        }

        string[] dns_servers = MainWindowWifiEditUtils.parse_dns_csv(dns_csv);
        if (!dns_auto && dns_servers.length == 0) {
            on_error("Manual DNS is enabled; provide at least one DNS server.");
            return;
        }

        if (method6 == "manual") {
            if (ipv6_address == "") {
                on_error("Manual IPv6 requires an address.");
                return;
            }
            if (ipv6_prefix == 0) {
                on_error("Manual IPv6 requires a prefix between 1 and 128.");
                return;
            }
        }

        if (!ipv6_gateway_auto && ipv6_gateway == "") {
            on_error("Manual IPv6 gateway is enabled; please provide a gateway address.");
            return;
        }

        if (!ipv6_gateway_auto && (method6 == "disabled" || method6 == "ignore")) {
            on_error("Manual IPv6 gateway is not supported when IPv6 method is Disabled or Ignore.");
            return;
        }

        nm.update_ethernet_device_settings.begin(
            dev,
            method,
            ipv4_address,
            ipv4_prefix,
            gateway_auto,
            ipv4_gateway,
            dns_auto,
            dns_servers,
            method6,
            ipv6_address,
            ipv6_prefix,
            ipv6_gateway_auto,
            ipv6_gateway,
            true,
            {},
            null,
            (obj, res) => {
                try {
                    nm.update_ethernet_device_settings.end(res);
                } catch (Error e) {
                    if (!is_ui_epoch_valid(epoch)) {
                        return;
                    }
                    on_error("Apply failed: " + e.message);
                    return;
                }

                if (!dev.is_connected) {
                    if (!is_ui_epoch_valid(epoch)) {
                        return;
                    }
                    on_refresh_after_action(false);
                    open_details(dev);
                    on_set_popup_text_input_mode(false);
                    return;
                }

                nm.disconnect_device.begin(dev.name, null, (obj2, res2) => {
                    try {
                        nm.disconnect_device.end(res2);
                    } catch (Error e) {
                        if (!is_ui_epoch_valid(epoch)) {
                            return;
                        }
                        on_error("Disconnect before reconnect failed: " + e.message);
                        return;
                    }

                    nm.connect_ethernet_device.begin(dev, null, (obj3, res3) => {
                        bool reconnect_ok = true;
                        string reconnect_error = "";
                        try {
                            nm.connect_ethernet_device.end(res3);
                        } catch (Error e) {
                            reconnect_ok = false;
                            reconnect_error = e.message;
                        }

                        if (!is_ui_epoch_valid(epoch)) {
                            return;
                        }
                        track_pending_action(dev, true, epoch);
                        if (!reconnect_ok) {
                            on_error("Reconnect after edit failed: " + reconnect_error);
                        }
                        on_refresh_after_action(false);
                        open_details(dev);
                        on_set_popup_text_input_mode(false);
                    });
                });
            }
        );
    }

    private Gtk.ListBoxRow build_row(NetworkDevice dev) {
        var row = new Gtk.ListBoxRow();
        row.add_css_class("nm-device-row");
        if (dev.is_connected) {
            row.add_css_class("connected");
        }

        var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
        content.set_margin_start(12);
        content.set_margin_end(8);
        content.set_margin_top(8);
        content.set_margin_bottom(8);

        var icon = new Gtk.Image.from_icon_name("network-wired-symbolic");
        icon.set_pixel_size(16);
        icon.add_css_class("nm-signal-icon");
        icon.add_css_class("nm-ethernet-icon");
        content.append(icon);

        var info = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
        info.set_hexpand(true);
        var name_lbl = new Gtk.Label(dev.name);
        name_lbl.set_xalign(0.0f);
        name_lbl.add_css_class("nm-ssid-label");
        info.append(name_lbl);

        string subtitle = dev.state_label;
        if (dev.connection != "") {
            subtitle = "%s (%s)".printf(dev.state_label, dev.connection);
        }
        var sub = new Gtk.Label(subtitle);
        sub.set_xalign(0.0f);
        sub.add_css_class("nm-sub-label");
        info.append(sub);
        content.append(info);

        var details_btn = new Gtk.Button();
        details_btn.add_css_class("nm-button");
        details_btn.add_css_class("nm-menu-button");
        details_btn.add_css_class("nm-details-open-button");
        details_btn.add_css_class("nm-row-icon-button");
        details_btn.set_tooltip_text("Details");
        var details_icon = new Gtk.Image.from_icon_name("document-properties-symbolic");
        details_btn.set_child(details_icon);
        details_btn.clicked.connect(() => {
            open_details(dev);
        });
        content.append(details_btn);

        bool pending = pending_ethernet_action.contains(dev.name);
        string action_label;
        bool can_toggle = true;

        if (pending) {
            action_label = "Updating...";
            can_toggle = false;
        } else if (dev.is_connected) {
            action_label = "Disconnect";
        } else if (dev.connection.strip() != "") {
            action_label = "Connect";
        } else {
            action_label = "No Profile";
            can_toggle = false;
        }

        var action = new Gtk.Button.with_label(action_label);
        action.add_css_class("nm-button");
        action.add_css_class(dev.is_connected ? "nm-disconnect-button" : "nm-connect-button");
        action.add_css_class("nm-row-action-button");
        action.set_sensitive(can_toggle);
        action.clicked.connect(() => {
            trigger_toggle(dev);
        });
        content.append(action);

        row.set_child(content);
        return row;
    }

    public void refresh() {
        uint epoch = capture_ui_epoch();
        string current_view = ethernet_stack.get_visible_child_name();
        nm.get_devices.begin(null, (obj, res) => {
            try {
                var devices = nm.get_devices.end(res);
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }

                var ethernet_devices = new List<NetworkDevice>();
                MainWindowHelpers.clear_listbox(ethernet_listbox);

                foreach (var dev in devices) {
                    if (!dev.is_ethernet) {
                        continue;
                    }

                    if (pending_ethernet_action.contains(dev.name)
                        && pending_ethernet_target_connected.contains(dev.name)) {
                        bool target_connected = pending_ethernet_target_connected.get(dev.name);
                        if (dev.is_connected == target_connected) {
                            pending_ethernet_action.remove(dev.name);
                            pending_ethernet_target_connected.remove(dev.name);
                        }
                    }

                    ethernet_devices.append(dev);
                    ethernet_listbox.append(build_row(dev));
                }

                if (current_view == "details" || current_view == "edit") {
                    if (selected_ethernet_device != null) {
                        NetworkDevice? updated = null;
                        foreach (var dev in ethernet_devices) {
                            if (dev.device_path == selected_ethernet_device.device_path
                                || dev.name == selected_ethernet_device.name) {
                                updated = dev;
                                break;
                            }
                        }

                        if (updated != null) {
                            selected_ethernet_device = updated;
                            if (current_view == "details") {
                                populate_details(updated);
                            }
                            ethernet_stack.set_visible_child_name(current_view);
                        } else {
                            selected_ethernet_device = null;
                            on_set_popup_text_input_mode(false);
                            ethernet_stack.set_visible_child_name(
                                ethernet_devices.length() > 0 ? "list" : "empty"
                            );
                        }
                    } else {
                        ethernet_stack.set_visible_child_name(
                            ethernet_devices.length() > 0 ? "list" : "empty"
                        );
                    }
                    return;
                }

                ethernet_stack.set_visible_child_name(ethernet_devices.length() > 0 ? "list" : "empty");
            } catch (Error e) {
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                on_error("Ethernet refresh failed: " + e.message);
            }
        });
    }
}
