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
    private Gtk.Box ethernet_details_action_row;
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
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-ethernet");

        var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        toolbar.set_margin_start(12);
        toolbar.set_margin_end(8);
        toolbar.set_margin_top(8);
        toolbar.set_margin_bottom(8);
        toolbar.add_css_class("nm-toolbar");

        var title = new Gtk.Label("Ethernet");
        title.set_xalign(0.0f);
        title.set_hexpand(true);
        title.add_css_class("nm-section-title");
        toolbar.append(title);

        var refresh_btn = new Gtk.Button();
        refresh_btn.add_css_class("nm-button");
        refresh_btn.add_css_class("nm-icon-button");
        var refresh_icon = new Gtk.Image.from_icon_name("view-refresh-symbolic");
        refresh_icon.set_pixel_size(16);
        refresh_icon.add_css_class("nm-toolbar-icon");
        refresh_icon.add_css_class("nm-refresh-icon");
        refresh_icon.add_css_class("nm-ethernet-refresh-icon");
        refresh_btn.set_child(refresh_icon);
        refresh_btn.clicked.connect(() => {
            refresh();
        });
        toolbar.append(refresh_btn);

        page.append(toolbar);
        var toolbar_sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        toolbar_sep.add_css_class("nm-separator");
        page.append(toolbar_sep);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");

        ethernet_listbox = new Gtk.ListBox();
        ethernet_listbox.set_selection_mode(Gtk.SelectionMode.NONE);
        ethernet_listbox.add_css_class("nm-list");
        scroll.set_child(ethernet_listbox);

        var ethernet_placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        ethernet_placeholder.set_halign(Gtk.Align.CENTER);
        ethernet_placeholder.set_valign(Gtk.Align.CENTER);
        ethernet_placeholder.add_css_class("nm-empty-state");
        var eth_icon = new Gtk.Image.from_icon_name("network-wired-symbolic");
        eth_icon.set_pixel_size(24);
        eth_icon.add_css_class("nm-placeholder-icon");
        eth_icon.add_css_class("nm-ethernet-placeholder-icon");
        var eth_lbl = new Gtk.Label("No Ethernet devices found");
        eth_lbl.add_css_class("nm-placeholder-label");
        ethernet_placeholder.append(eth_icon);
        ethernet_placeholder.append(eth_lbl);

        ethernet_stack = new Gtk.Stack();
        ethernet_stack.set_vexpand(true);
        ethernet_stack.add_css_class("nm-content-stack");
        ethernet_stack.add_named(scroll, "list");
        ethernet_stack.add_named(ethernet_placeholder, "empty");
        ethernet_stack.add_named(build_details_page(), "details");
        ethernet_stack.add_named(build_edit_page(), "edit");
        ethernet_stack.set_visible_child_name("empty");

        page.append(ethernet_stack);
        return page;
    }

    private Gtk.Widget build_details_page() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        page.set_margin_start(12);
        page.set_margin_end(12);
        page.set_margin_top(12);
        page.set_margin_bottom(12);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-ethernet-details");
        page.add_css_class("nm-page-network-details");

        var nav_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        nav_row.add_css_class("nm-details-nav-row");

        var back_btn = MainWindowHelpers.build_back_button(() => {
            on_set_popup_text_input_mode(false);
            ethernet_stack.set_visible_child_name("list");
        });
        nav_row.append(back_btn);
        page.append(nav_row);

        var header = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        header.set_halign(Gtk.Align.CENTER);
        header.add_css_class("nm-details-header");

        var icon = new Gtk.Image.from_icon_name("network-transmit-receive-symbolic");
        icon.set_pixel_size(28);
        icon.add_css_class("nm-signal-icon");
        icon.add_css_class("nm-ethernet-icon");
        icon.add_css_class("nm-details-network-icon");
        header.append(icon);

        ethernet_details_title = new Gtk.Label("Ethernet");
        ethernet_details_title.set_xalign(0.5f);
        ethernet_details_title.set_halign(Gtk.Align.CENTER);
        ethernet_details_title.add_css_class("nm-details-network-title");
        header.append(ethernet_details_title);

        ethernet_details_action_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        ethernet_details_action_row.set_halign(Gtk.Align.CENTER);
        ethernet_details_action_row.add_css_class("nm-details-action-row");

        ethernet_details_primary_button = new Gtk.Button.with_label("Connect");
        ethernet_details_primary_button.add_css_class("nm-button");
        ethernet_details_primary_button.add_css_class("nm-action-button");
        ethernet_details_primary_button.add_css_class("nm-details-action-button");
        ethernet_details_primary_button.clicked.connect(() => {
            if (selected_ethernet_device != null) {
                trigger_toggle(selected_ethernet_device);
            }
        });
        ethernet_details_action_row.append(ethernet_details_primary_button);

        ethernet_details_edit_button = new Gtk.Button.with_label("Edit");
        ethernet_details_edit_button.add_css_class("nm-button");
        ethernet_details_edit_button.add_css_class("nm-action-button");
        ethernet_details_edit_button.add_css_class("nm-details-action-button");
        ethernet_details_edit_button.clicked.connect(() => {
            if (selected_ethernet_device != null) {
                open_edit(selected_ethernet_device);
            }
        });
        ethernet_details_action_row.append(ethernet_details_edit_button);

        header.append(ethernet_details_action_row);
        page.append(header);

        var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        sep.add_css_class("nm-separator");
        page.append(sep);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add_css_class("nm-scroll");
        scroll.set_vexpand(true);

        var body = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        body.set_margin_top(4);
        body.set_margin_bottom(4);
        body.append(MainWindowHelpers.build_details_section("Basic", out ethernet_details_basic_rows));
        body.append(MainWindowHelpers.build_details_section("Advanced", out ethernet_details_advanced_rows));
        body.append(MainWindowHelpers.build_details_section("IP", out ethernet_details_ip_rows));

        scroll.set_child(body);
        page.append(scroll);
        return page;
    }

    private Gtk.Widget build_edit_page() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        page.set_margin_start(12);
        page.set_margin_end(12);
        page.set_margin_top(12);
        page.set_margin_bottom(12);
        page.add_css_class("nm-page");
        page.add_css_class("nm-page-ethernet-edit");
        page.add_css_class("nm-page-network-edit");

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var back_btn = MainWindowHelpers.build_back_button(() => {
            on_set_popup_text_input_mode(false);
            if (selected_ethernet_device != null) {
                open_details(selected_ethernet_device);
            } else {
                ethernet_stack.set_visible_child_name("list");
            }
        });
        header.append(back_btn);

        ethernet_edit_title = new Gtk.Label("Edit Ethernet");
        ethernet_edit_title.set_xalign(0.0f);
        ethernet_edit_title.set_hexpand(true);
        ethernet_edit_title.add_css_class("nm-section-title");
        header.append(ethernet_edit_title);
        page.append(header);

        var form = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        form.add_css_class("nm-edit-form");
        form.add_css_class("nm-edit-ethernet-form");
        form.add_css_class("nm-edit-network-form");

        ethernet_edit_note = new Gtk.Label("");
        ethernet_edit_note.set_xalign(0.0f);
        ethernet_edit_note.set_wrap(true);
        ethernet_edit_note.add_css_class("nm-sub-label");
        ethernet_edit_note.add_css_class("nm-edit-note");
        form.append(ethernet_edit_note);

        MainWindowIpEditFormBuilder.append_ipv4_section(
            form,
            out ethernet_edit_ipv4_method_dropdown,
            out ethernet_edit_ipv4_address_entry,
            out ethernet_edit_ipv4_prefix_entry,
            out ethernet_edit_gateway_auto_switch,
            out ethernet_edit_ipv4_gateway_entry,
            out ethernet_edit_dns_auto_switch,
            out ethernet_edit_ipv4_dns_entry,
            () => {
                sync_edit_gateway_dns_sensitivity();
            },
            true
        );

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var save_btn = new Gtk.Button.with_label("Apply");
        save_btn.add_css_class("nm-button");
        save_btn.add_css_class("suggested-action");
        save_btn.clicked.connect(() => {
            apply_edit();
        });
        actions.append(save_btn);

        form.append(actions);
        page.append(form);
        return page;
    }

    private void sync_edit_gateway_dns_sensitivity() {
        if (ethernet_edit_ipv4_gateway_entry != null && ethernet_edit_gateway_auto_switch != null) {
            ethernet_edit_ipv4_gateway_entry.set_sensitive(!ethernet_edit_gateway_auto_switch.get_active());
        }
        if (ethernet_edit_ipv4_dns_entry != null && ethernet_edit_dns_auto_switch != null) {
            ethernet_edit_ipv4_dns_entry.set_sensitive(!ethernet_edit_dns_auto_switch.get_active());
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
            try {
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
            } catch (Error e) {
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                MainWindowHelpers.clear_box(ethernet_details_ip_rows);
                ethernet_details_ip_rows.append(
                    MainWindowHelpers.build_details_row("IP", "Failed to load: " + e.message)
                );
            }
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
        ethernet_edit_note.set_text("Update IPv4 settings for profile: %s".printf(dev.connection));

        ethernet_stack.set_visible_child_name("edit");
        on_set_popup_text_input_mode(true);

        nm.get_ethernet_device_ip_settings.begin(dev, null, (obj, res) => {
            try {
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

                sync_edit_gateway_dns_sensitivity();
                ethernet_edit_ipv4_address_entry.grab_focus();
            } catch (Error e) {
                if (!is_ui_epoch_valid(epoch)) {
                    return;
                }
                on_error("Could not load Ethernet IP settings: " + e.message);
            }
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

        nm.update_ethernet_device_settings.begin(
            dev,
            method,
            ipv4_address,
            ipv4_prefix,
            gateway_auto,
            ipv4_gateway,
            dns_auto,
            dns_servers,
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
