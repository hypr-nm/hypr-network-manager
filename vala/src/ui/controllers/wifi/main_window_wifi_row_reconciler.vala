using Gtk;

public class MainWindowWifiRowReconciler : Object {
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;
    private NetworkManagerRebuild.Models.NetworkStateContext state_context;
    private HashTable<string, string> wifi_row_signatures;
    private string[] wifi_row_order = {};

    public MainWindowWifiRowReconciler (NetworkManagerRebuild.UI.Interfaces.IWindowHost host, NetworkManagerRebuild.Models.NetworkStateContext state_context) {
        this.host = host;
        this.state_context = state_context;
        wifi_row_signatures = new HashTable<string, string> (str_hash, str_equal);
    }

    public void reset () {
        wifi_row_order = {};
        wifi_row_signatures.remove_all ();
    }

    private string get_wifi_row_id (WifiNetwork net) {
        return "%s|%s".printf (net.device_path, net.ap_path);
    }

    private string build_wifi_row_signature (
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting
    ) {
        int connected_flag = is_connected_now ? 1 : 0;
        int connecting_flag = is_connecting ? 1 : 0;
        int secured_flag = net.is_secured ? 1 : 0;
        int saved_flag = net.saved ? 1 : 0;
        return "%s|%s|%s|%u|%d|%d|%d|%d|%s|%u|%u|%u|%u|%u|%u|%u|%s|%s".printf (
            net.ssid,
            net.device_path,
            net.ap_path,
            net.signal,
            connected_flag,
            connecting_flag,
            secured_flag,
            saved_flag,
            net.saved_connection_uuid,
            net.frequency_mhz,
            net.max_bitrate_kbps,
            net.mode,
            net.flags,
            net.wpa_flags,
            net.rsn_flags,
            net.connected ? 1u : 0u,
            net.signal_label,
            net.signal_icon_name
        );
    }

    private bool contains_value (string[] values, string candidate) {
        foreach (var value in values) {
            if (value == candidate) {
                return true;
            }
        }
        return false;
    }

    public void reconcile (
        Gtk.ListBox wifi_listbox,
        WifiNetwork[] networks,
        string? active_wifi_password_row_id,
        bool has_active_wifi_password_prompt,
        MainWindowWifiRowBuildCallback on_build_wifi_row
    ) {
        var visible_rows_by_id = new HashTable<string, Gtk.ListBoxRow> (str_hash, str_equal);
        for (Gtk.Widget? child = wifi_listbox.get_first_child (); child != null; child = child.get_next_sibling ()) {
            var existing_row = child as Gtk.ListBoxRow;
            if (existing_row == null) {
                continue;
            }

            string? existing_row_id = (string?) existing_row.get_data<string> (MainWindowDataKeys.ROW_ID);
            if (existing_row_id == null || existing_row_id == "") {
                continue;
            }

            if (!visible_rows_by_id.contains (existing_row_id)) {
                visible_rows_by_id.insert (existing_row_id, existing_row);
            }
        }

        var networks_by_row_id = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        string[] scan_order = {};

        foreach (var net in networks) {
            if (net.ap_path.has_prefix ("saved:")) {
                continue;
            }
            string row_id = get_wifi_row_id (net);
            networks_by_row_id.insert (row_id, net);
            scan_order += row_id;
        }

        bool has_active_prompt_id = has_active_wifi_password_prompt
            && active_wifi_password_row_id != null
            && active_wifi_password_row_id != "";
        bool active_prompt_row_still_present = has_active_prompt_id
            && networks_by_row_id.contains (active_wifi_password_row_id);

        if (has_active_prompt_id && !active_prompt_row_still_present) {
            host.hide_active_wifi_password_prompt ();
        }

        bool keep_stable_order = has_active_prompt_id && active_prompt_row_still_present;
        string[] ordered_row_ids = {};
        if (keep_stable_order) {
            foreach (var existing_id in wifi_row_order) {
                if (networks_by_row_id.contains (existing_id)) {
                    ordered_row_ids += existing_id;
                }
            }
            foreach (var scan_row_id in scan_order) {
                if (!contains_value (ordered_row_ids, scan_row_id)) {
                    ordered_row_ids += scan_row_id;
                }
            }
        } else {
            ordered_row_ids = scan_order;
        }

        foreach (var existing_id in visible_rows_by_id.get_keys ()) {
            if (networks_by_row_id.contains (existing_id)) {
                continue;
            }

            var stale_row = visible_rows_by_id.lookup (existing_id);
            if (stale_row != null && stale_row.get_parent () == wifi_listbox) {
                wifi_listbox.remove (stale_row);
            }
            wifi_row_signatures.remove (existing_id);
        }

        int index = 0;
        foreach (var row_id in ordered_row_ids) {
            var net = networks_by_row_id.lookup (row_id);
            string net_key = net.network_key;
            bool is_connected_now = state_context.active_wifi_connections.contains (net_key);
            bool is_connecting = state_context.pending_wifi_connect.contains (net_key);
            string new_signature = build_wifi_row_signature (net, is_connected_now, is_connecting);

            var row = visible_rows_by_id.lookup (row_id);
            string? existing_signature = wifi_row_signatures.lookup (row_id);
            bool preserve_prompt_row = active_prompt_row_still_present
                && active_wifi_password_row_id == row_id;
            bool needs_rebuild = row == null || (!preserve_prompt_row && existing_signature != new_signature);

            if (needs_rebuild) {
                bool was_expanded = false;
                if (row != null) {
                    was_expanded = row.get_data<bool> (MainWindowDataKeys.ACTIONS_EXPANDED);
                }

                var rebuilt_row = on_build_wifi_row (net);
                rebuilt_row.set_data<string> (MainWindowDataKeys.ROW_ID, row_id);

                if (was_expanded) {
                    for (Gtk.Widget? child = rebuilt_row.get_first_child ();
                     child != null; child = child.get_next_sibling ()) {
                        var box = child as Gtk.Box;
                        if (box != null) {
                            for (Gtk.Widget? bchild = box.get_first_child ();
                             bchild != null; bchild = bchild.get_next_sibling ()) {
                                var rev = bchild as Gtk.Revealer;
                                if (rev != null && rev.has_css_class (MainWindowCssClasses.ROW_ACTIONS_REVEALER)) {
                                    rev.set_reveal_child (true);
                                    rebuilt_row.set_data<bool> (MainWindowDataKeys.ACTIONS_EXPANDED, true);
                                    break;
                                }
                            }
                            break;
                        }
                    }
                }

                if (row != null && row.get_parent () == wifi_listbox) {
                    wifi_listbox.remove (row);
                }
                row = rebuilt_row;
                visible_rows_by_id.insert (row_id, row);
                wifi_row_signatures.insert (row_id, new_signature);
            }

            var current_row = wifi_listbox.get_row_at_index (index);
            if (current_row != row) {
                if (row.get_parent () == wifi_listbox) {
                    wifi_listbox.remove (row);
                }
                wifi_listbox.insert (row, index);
            }

            if (!preserve_prompt_row) {
                wifi_row_signatures.insert (row_id, new_signature);
            }

            index++;
        }

        wifi_row_order = ordered_row_ids;
    }
}
