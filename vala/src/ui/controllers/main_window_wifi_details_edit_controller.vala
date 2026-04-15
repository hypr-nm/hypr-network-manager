using GLib;
using Gtk;

public class MainWindowWifiDetailsEditController : MainWindowAbstractDetailsEditController {
    private NetworkManagerRebuild.Models.NetworkStateContext state_context;
    private const uint WIFI_RECONNECT_CHECK_INTERVAL_MS = 300;
    private const uint WIFI_RECONNECT_MAX_WAIT_MS = 10000;

    private uint[] timeout_source_ids = {};
    private Cancellable? action_request_cancellable = null;

    public MainWindowWifiDetailsEditController (NetworkManagerRebuild.UI.Interfaces.IWindowHost host, NetworkManagerRebuild.Models.NetworkStateContext state_context) {
        base (host);
        this.state_context = state_context;
    }

    protected override void invalidate_ui_state () {
        base.invalidate_ui_state ();
        cancel_action_request ();
        cancel_all_timeout_sources ();
    }

    private void cancel_action_request () {
        if (action_request_cancellable != null) {
            action_request_cancellable.cancel ();
            action_request_cancellable = null;
        }
    }

    private void cancel_all_timeout_sources () {
        if (timeout_source_ids.length == 0) {
            return;
        }

        foreach (uint source_id in timeout_source_ids) {
            Source.remove (source_id);
        }
        timeout_source_ids = {};
    }

    private void track_timeout_source (uint source_id) {
        if (source_id == 0) {
            return;
        }
        timeout_source_ids += source_id;
    }

    private void untrack_timeout_source (uint source_id) {
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

    private bool is_wifi_device_fully_disconnected (NetworkDevice dev) {
        if (dev.is_connected) {
            return false;
        }

        bool is_connecting = dev.state >= 40 && dev.state < NM_DEVICE_STATE_ACTIVATED;
        return !is_connecting;
    }

    private void reconnect_after_disconnect_with_retry (
        NetworkManagerClient nm,
        WifiNetwork net,
        bool close_after_apply,
        Gtk.Stack wifi_stack,
        MainWindowWifiDetailsPage details_page,
        uint epoch,
        uint waited_ms,
        Cancellable request_cancellable
    ) {
        string net_key = net.network_key;

        if (!is_ui_epoch_valid (epoch)) {
            return;
        }

        nm.get_devices.begin (request_cancellable, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            bool ready_to_reconnect = true;
            try {
                var devices = nm.get_devices.end (res);
                foreach (var dev in devices) {
                    if (!dev.is_wifi || dev.device_path != net.device_path) {
                        continue;
                    }

                    ready_to_reconnect = is_wifi_device_fully_disconnected (dev);
                    break;
                }
            } catch (Error e) {
                if (is_cancelled_error (e)) {
                    return;
                }
                // Treat transient D-Bus/read errors as not-ready and retry until timeout.
                ready_to_reconnect = false;
            }

            if (ready_to_reconnect) {
                nm.connect_wifi.begin (net, null, request_cancellable, (obj2, res2) => {
                    try {
                        nm.connect_wifi.end (res2);
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        if (close_after_apply) {
                            populate_wifi_details (nm, net, details_page);
                            wifi_stack.set_visible_child_name ("details");
                            host.set_popup_text_input_mode (false);
                        }
                        host.refresh_after_action (true);
                    } catch (Error e) {
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        if (is_cancelled_error (e)) {
                            return;
                        }
                        state_context.pending_wifi_connect.remove (net_key);
                        state_context.pending_wifi_seen_connecting.remove (net_key);
                        host.show_error ("Reconnect after edit failed: " + e.message);
                        host.refresh_after_action (false);
                    }
                });
                return;
            }

            if (waited_ms >= WIFI_RECONNECT_MAX_WAIT_MS) {
                state_context.pending_wifi_connect.remove (net_key);
                state_context.pending_wifi_seen_connecting.remove (net_key);
                host.show_error (
                    "Reconnect after edit timed out while waiting for disconnect to complete."
                );
                host.refresh_after_action (false);
                return;
            }

            uint next_waited_ms = waited_ms + WIFI_RECONNECT_CHECK_INTERVAL_MS;
            uint timeout_id = 0;
            timeout_id = Timeout.add (WIFI_RECONNECT_CHECK_INTERVAL_MS, () => {
                untrack_timeout_source (timeout_id);
                reconnect_after_disconnect_with_retry (
                    nm,
                    net,
                    close_after_apply,
                    wifi_stack,
                    details_page,
                    epoch,
                    next_waited_ms,
                    request_cancellable
                );
                return false;
            });
            track_timeout_source (timeout_id);
        });
    }

    public void populate_wifi_details (
        NetworkManagerClient nm,
        WifiNetwork net,
        MainWindowWifiDetailsPage page
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_details_request ();
        details_request_cancellable = new Cancellable ();
        var details_request = details_request_cancellable;

        bool is_connected_now = state_context.active_wifi_connections.contains (net.network_key);
        bool pending = state_context.pending_wifi_connect.contains (net.network_key);

        page.render_details (net, is_connected_now, pending);
        page.show_loading_ip ();

        nm.get_wifi_network_ip_settings.begin (net, details_request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            if (page.details_title.get_text () != net.ssid) {
                return;
            }

            NetworkIpSettings ip_settings = nm.get_wifi_network_ip_settings.end (res);
            page.render_ip_settings (ip_settings, is_connected_now);
        });
    }



    public void open_wifi_edit (
        NetworkManagerClient nm,
        WifiNetwork net,
        MainWindowWifiEditPage page,
        Gtk.Stack wifi_stack
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_edit_request ();
        edit_request_cancellable = new Cancellable ();
        var edit_request = edit_request_cancellable;

        page.edit_title.set_text ("Edit: %s".printf (net.ssid));
        page.password_entry.set_text ("");
        page.password_entry.set_visibility (false);

        if (net.is_secured) {
            page.note_label.set_text (
                "Current password is prefilled when available.\n"
                + "IPv4 and IPv6 settings can be changed below (auto/manual/disabled)."
            );
        } else {
            page.note_label.set_text ("Open network. Password is not required.");
        }

        wifi_stack.set_visible_child_name ("edit");
        host.set_popup_text_input_mode (true);
        page.password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        page.password_entry.grab_focus ();

        page.ipv4_method_dropdown.set_selected (0);
        page.ipv4_address_entry.set_text ("");
        page.ipv4_prefix_entry.set_text ("");
        page.ipv4_gateway_entry.set_text ("");
        page.dns_auto_switch.set_active (true);
        page.ipv4_dns_entry.set_text ("");
        page.ipv6_method_dropdown.set_selected (0);
        page.ipv6_address_entry.set_text ("");
        page.ipv6_prefix_entry.set_text ("");
        page.ipv6_gateway_entry.set_text ("");
        page.ipv6_dns_auto_switch.set_active (true);
        page.ipv6_dns_entry.set_text ("");
        page.sync_edit_gateway_dns_sensitivity ();

        nm.get_wifi_network_ip_settings.begin (net, edit_request, (obj, res) => {
            if (!is_ui_epoch_valid (epoch)) {
                return;
            }

            if (page.edit_title.get_text () != "Edit: %s".printf (net.ssid)) {
                return;
            }

            NetworkIpSettings ip_settings = nm.get_wifi_network_ip_settings.end (res);

            if (net.is_secured) {
                page.password_entry.set_text (MainWindowHelpers.safe_text (ip_settings.configured_password));
            } else {
                page.password_entry.set_text ("");
            }
            page.populate_ip_settings (ip_settings);
        });
    }

    public bool apply_wifi_edit (
        NetworkManagerClient nm,
        WifiNetwork net,
        MainWindowWifiEditPage page,
        Gtk.Stack wifi_stack,
        MainWindowWifiDetailsPage details_page,
        bool close_after_apply,
        MainWindowWifiNetworkCallback? on_open_details = null
    ) {
        uint epoch = capture_ui_epoch ();
        cancel_action_request ();
        action_request_cancellable = new Cancellable ();
        var action_request = action_request_cancellable;
        string net_key = net.network_key;
        string password = page.password_entry.get_text ().strip ();

        string? error_message = null;
        var base_request = page.build_ip_update_request (out error_message);
        if (base_request == null) {
            if (error_message != null) {
                host.show_error (error_message);
            }
            return false;
        }

        var request = new WifiNetworkUpdateRequest () {
            password = password,
            ipv4_method = base_request.ipv4_method,
            ipv4_address = base_request.ipv4_address,
            ipv4_prefix = base_request.ipv4_prefix,
            ipv4_gateway_auto = base_request.ipv4_gateway_auto,
            ipv4_gateway = base_request.ipv4_gateway,
            ipv4_dns_auto = base_request.ipv4_dns_auto,
            ipv4_dns_servers = base_request.ipv4_dns_servers,
            ipv6_method = base_request.ipv6_method,
            ipv6_address = base_request.ipv6_address,
            ipv6_prefix = base_request.ipv6_prefix,
            ipv6_gateway_auto = base_request.ipv6_gateway_auto,
            ipv6_gateway = base_request.ipv6_gateway,
            ipv6_dns_auto = base_request.ipv6_dns_auto,
            ipv6_dns_servers = base_request.ipv6_dns_servers
        };

        nm.update_wifi_network_settings.begin (net, request, action_request, (obj, res) => {
                try {
                    nm.update_wifi_network_settings.end (res);
                } catch (Error e) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    if (is_cancelled_error (e)) {
                        return;
                    }
                    host.show_error ("Apply failed: " + e.message);
                    return;
                }

                if (!net.connected) {
                    if (!is_ui_epoch_valid (epoch)) {
                        return;
                    }
                    if (close_after_apply) {
                        populate_wifi_details (nm, net, details_page);
                        wifi_stack.set_visible_child_name ("details");
                        host.set_popup_text_input_mode (false);
                    }
                    host.refresh_after_action (base_request.ipv4_method != "disabled");
                    return;
                }

                nm.disconnect_wifi.begin (net, action_request, (obj2, res2) => {
                    try {
                        nm.disconnect_wifi.end (res2);
                    } catch (Error e) {
                        if (!is_ui_epoch_valid (epoch)) {
                            return;
                        }
                        if (is_cancelled_error (e)) {
                            return;
                        }
                        host.show_error ("Disconnect before reconnect failed: " + e.message);
                        return;
                    }

                    state_context.pending_wifi_connect.insert (net_key, true);
                    state_context.pending_wifi_seen_connecting.remove (net_key);

                    reconnect_after_disconnect_with_retry (
                        nm,
                        net,
                        close_after_apply,
                        wifi_stack,
                        details_page,
                        epoch,
                        0,
                        action_request
                    );
                });
        });

        if (!is_ui_epoch_valid (epoch)) {
            return false;
        }
        return true;
    }
}
