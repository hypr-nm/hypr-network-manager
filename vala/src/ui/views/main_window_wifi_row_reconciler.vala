/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using Constants;
using Gtk;

public class MainWindowWifiRowReconciler : Object {
    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private string[] wifi_row_order = {};

    public MainWindowWifiRowReconciler (
        HyprNetworkManager.UI.Interfaces.IWindowHost host
    ) {
        this.host = host;
    }

    public void reset () {
        wifi_row_order = {};
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
        Gtk.ListBox listbox,
        WifiNetwork[] networks,
        string? active_password_row_id,
        bool has_active_password_prompt,
        IMainWindowWifiRowProvider row_provider
    ) {
        bool should_invalidate_sort = false;
        var visible_rows = new HashTable<string, Gtk.ListBoxRow> (str_hash, str_equal);
        for (Gtk.Widget? child = listbox.get_first_child ();
             child != null;
             child = child.get_next_sibling ()) {
            var row = child as Gtk.ListBoxRow;
            if (row == null) {
                continue;
            }
            string? row_id = (string?) row.get_data<string> (MainWindowDataKeys.ROW_ID);
            if (row_id != null && row_id != "" && !visible_rows.contains (row_id)) {
                visible_rows.insert (row_id, row);
            }
        }

        var networks_by_row_id = new HashTable<string, WifiNetwork> (str_hash, str_equal);
        string[] scan_order = {};
        foreach (var network in networks) {
            if (network.ap_path.has_prefix ("saved:")) {
                continue;
            }
            string row_id = network.network_key;
            networks_by_row_id.insert (row_id, network);
            scan_order += row_id;
        }

        bool has_prompt_id = has_active_password_prompt
            && active_password_row_id != null
            && active_password_row_id != "";
        bool prompt_row_present = has_prompt_id
            && networks_by_row_id.contains (active_password_row_id);
        if (has_prompt_id && !prompt_row_present) {
            host.hide_active_wifi_password_prompt ();
        }

        string[] ordered_row_ids = {};
        if (has_prompt_id && prompt_row_present) {
            foreach (var existing_id in wifi_row_order) {
                if (networks_by_row_id.contains (existing_id)) {
                    ordered_row_ids += existing_id;
                }
            }
            foreach (var scanned_id in scan_order) {
                if (!contains_value (ordered_row_ids, scanned_id)) {
                    ordered_row_ids += scanned_id;
                }
            }
        } else {
            ordered_row_ids = scan_order;
        }

        foreach (var existing_id in visible_rows.get_keys ()) {
            if (networks_by_row_id.contains (existing_id)) {
                continue;
            }
            var stale_row = visible_rows.lookup (existing_id);
            if (stale_row != null && stale_row.get_parent () == listbox) {
                listbox.remove (stale_row);
            }
        }

        int index = 0;
        foreach (var row_id in ordered_row_ids) {
            var network = networks_by_row_id.lookup (row_id);
            var row = visible_rows.lookup (row_id);
            if (row == null) {
                row = row_provider.build_wifi_row (network);
                row.set_data<string> (MainWindowDataKeys.ROW_ID, row_id.dup ());
                visible_rows.insert (row_id, row);
            } else {
                row_provider.update_wifi_row (row, network);
            }

            if (row.get_parent () != listbox) {
                row.set_data<int> ("sort-index", index);
                listbox.append (row);
                should_invalidate_sort = true;
            } else if (row.get_data<int> ("sort-index") != index) {
                row.set_data<int> ("sort-index", index);
                should_invalidate_sort = true;
            }
            index++;
        }

        wifi_row_order = ordered_row_ids;
        if (should_invalidate_sort) {
            listbox.invalidate_sort ();
        }
        listbox.invalidate_headers ();
    }
}
