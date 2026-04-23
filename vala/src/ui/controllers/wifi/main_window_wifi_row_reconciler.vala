using Gtk;

public class MainWindowWifiRowReconciler : Object {
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;
    private string[] wifi_row_order = {};

    public MainWindowWifiRowReconciler (HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context) {
        this.host = host;
        this.state_context = state_context;
    }

    public void reset () {
        wifi_row_order = {};
    }

    private string get_wifi_row_id (WifiNetwork net) {
        return net.network_key;
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
        IMainWindowWifiRowProvider row_provider
    ) {
        bool should_invalidate_sort = false;
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
        }

        int index = 0;
        foreach (var row_id in ordered_row_ids) {
            var net = networks_by_row_id.lookup (row_id);
            var row = visible_rows_by_id.lookup (row_id);

            if (row == null) {
                row = row_provider.build_wifi_row (net);
                row.set_data<string> (MainWindowDataKeys.ROW_ID, row_id.dup ());
                visible_rows_by_id.insert (row_id, row);
            } else {
                row_provider.update_wifi_row (row, net);
            }

            if (row.get_parent () != wifi_listbox) {
                row.set_data<int> ("sort-index", index);
                wifi_listbox.append (row);
                should_invalidate_sort = true;
            } else {
                int current_index = row.get_data<int> ("sort-index");
                if (current_index != index) {
                    row.set_data<int> ("sort-index", index);
                    should_invalidate_sort = true;
                }
            }

            index++;
        }

        wifi_row_order = ordered_row_ids;

        if (should_invalidate_sort) {
            wifi_listbox.invalidate_sort ();
        }
    }
}
