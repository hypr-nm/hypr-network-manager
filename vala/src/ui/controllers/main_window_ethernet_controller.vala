using GLib;
using Gtk;

public class MainWindowEthernetController : Object {
    private NetworkManagerClientVala nm;
    private MainWindowErrorCallback on_error;
    private MainWindowRefreshActionCallback on_refresh_after_action;
    private MainWindowBoolCallback on_set_popup_text_input_mode;

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
        MainWindowErrorCallback on_error,
        MainWindowRefreshActionCallback on_refresh_after_action,
        MainWindowBoolCallback on_set_popup_text_input_mode
    ) {
        this.nm = nm;
        this.on_error = on_error;
        this.on_refresh_after_action = on_refresh_after_action;
        this.on_set_popup_text_input_mode = on_set_popup_text_input_mode;
        pending_ethernet_action = new HashTable<string, bool>(str_hash, str_equal);
        pending_ethernet_target_connected = new HashTable<string, bool>(str_hash, str_equal);
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
        ethernet_edit_ipv4_gateway_entry.set_sensitive(!ethernet_edit_gateway_auto_switch.get_active());
        ethernet_edit_ipv4_dns_entry.set_sensitive(!ethernet_edit_dns_auto_switch.get_active());
    }

    private void track_pending_action(NetworkDevice dev, bool target_connected) {
        pending_ethernet_action.insert(dev.name, true);
        pending_ethernet_target_connected.insert(dev.name, target_connected);

        string iface_name = dev.name;
        Timeout.add(20000, () => {
            pending_ethernet_action.remove(iface_name);
            pending_ethernet_target_connected.remove(iface_name);
            refresh();
            return false;
        });
    }

    private void trigger_toggle(NetworkDevice dev) {
        if (pending_ethernet_action.contains(dev.name)) {
            return;
        }

        bool target_connected = !dev.is_connected;
        try {
            Thread.create<void>(() => {
                string error_message;
                bool ok;

                if (dev.is_connected) {
                    ok = nm.disconnect_device(dev.name, out error_message);
                } else {
                    ok = nm.connect_ethernet_device(dev, out error_message);
                }

                Idle.add(() => {
                    if (!ok) {
                        on_error(
                            (dev.is_connected ? "Ethernet disconnect failed: " : "Ethernet connect failed: ")
                            + error_message
                        );
                        return false;
                    }

                    track_pending_action(dev, target_connected);
                    on_refresh_after_action(false);
                    return false;
                });
                return;
            }, false);
        } catch (ThreadError e) {
            on_error("Ethernet action failed: " + e.message);
        }
    }

    private void populate_details(NetworkDevice dev) {
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

        try {
            Thread.create<void>(() => {
                NetworkIpSettings ip_settings;
                string ip_error;
                nm.get_ethernet_device_ip_settings(dev, out ip_settings, out ip_error);

                Idle.add(() => {
                    if (selected_ethernet_device == null
                        || (selected_ethernet_device.device_path != dev.device_path
                            && selected_ethernet_device.name != dev.name)) {
                        return false;
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

                    return false;
                });
                return;
            }, false);
        } catch (ThreadError e) {
            MainWindowHelpers.clear_box(ethernet_details_ip_rows);
            ethernet_details_ip_rows.append(MainWindowHelpers.build_details_row("IP", "Failed to load: " + e.message));
        }

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
        ethernet_edit_title.set_text("Edit: %s".printf(dev.name));
        ethernet_edit_note.set_text("Update IPv4 settings for profile: %s".printf(dev.connection));

        ethernet_stack.set_visible_child_name("edit");
        on_set_popup_text_input_mode(true);

        try {
            Thread.create<void>(() => {
                NetworkIpSettings ip_settings;
                string ip_error;
                nm.get_ethernet_device_ip_settings(dev, out ip_settings, out ip_error);

                Idle.add(() => {
                    if (selected_ethernet_device == null
                        || (selected_ethernet_device.device_path != dev.device_path
                            && selected_ethernet_device.name != dev.name)) {
                        return false;
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
                    return false;
                });
                return;
            }, false);
        } catch (ThreadError e) {
            on_error("Could not load Ethernet IP settings: " + e.message);
        }
    }

    private void apply_edit() {
        if (selected_ethernet_device == null) {
            return;
        }

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

        try {
            Thread.create<void>(() => {
                string error_message;
                bool ok = nm.update_ethernet_device_settings(
                    dev,
                    method,
                    ipv4_address,
                    ipv4_prefix,
                    gateway_auto,
                    ipv4_gateway,
                    dns_auto,
                    dns_servers,
                    out error_message
                );

                if (!ok) {
                    Idle.add(() => {
                        on_error("Apply failed: " + error_message);
                        return false;
                    });
                    return;
                }

                if (dev.is_connected) {
                    string disconnect_error;
                    if (!nm.disconnect_device(dev.name, out disconnect_error)) {
                        Idle.add(() => {
                            on_error("Disconnect before reconnect failed: " + disconnect_error);
                            return false;
                        });
                        return;
                    }

                    string reconnect_error;
                    bool reconnect_ok = nm.connect_ethernet_device(dev, out reconnect_error);

                    Idle.add(() => {
                        track_pending_action(dev, true);
                        if (!reconnect_ok) {
                            on_error("Reconnect after edit failed: " + reconnect_error);
                        }
                        on_refresh_after_action(false);
                        open_details(dev);
                        on_set_popup_text_input_mode(false);
                        return false;
                    });
                    return;
                }

                Idle.add(() => {
                    on_refresh_after_action(false);
                    open_details(dev);
                    on_set_popup_text_input_mode(false);
                    return false;
                });
            }, false);
        } catch (ThreadError e) {
            on_error("Apply failed: " + e.message);
        }
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
        string current_view = ethernet_stack.get_visible_child_name();
        try {
            Thread.create<void>(() => {
                var devices = nm.get_devices();

                Idle.add(() => {
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
                        return false;
                    }

                    ethernet_stack.set_visible_child_name(ethernet_devices.length() > 0 ? "list" : "empty");
                    return false;
                });
                return;
            }, false);
        } catch (ThreadError e) {
            on_error("Ethernet refresh failed: " + e.message);
        }
    }
}
