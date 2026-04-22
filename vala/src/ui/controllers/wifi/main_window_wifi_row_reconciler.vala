using Gtk;
using Gdk;

[CCode (cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
private extern void wifi_row_style_provider_add_for_display (
    Gdk.Display display,
    Gtk.StyleProvider provider,
    uint priority
);

[CCode (cname = "gtk_style_context_remove_provider_for_display", cheader_filename = "gtk/gtk.h")]
private extern void wifi_row_style_provider_remove_for_display (
    Gdk.Display display,
    Gtk.StyleProvider provider
);

public class MainWindowWifiRowReconciler : Object {
    private const uint ROW_MOVE_ANIMATION_MS = 220;
    private const uint ROW_ENTER_ANIMATION_MS = 180;
    private const uint ROW_ANIMATION_CLEANUP_PADDING_MS = 40;
    private const int ROW_MOVE_MIN_DELTA_PX = 3;
    private const string ROW_MOVE_CLASS_PREFIX = "nm-wifi-row-move-";
    private const string ROW_ENTER_CLASS = "nm-wifi-row-enter";

    private HyprNetworkManager.UI.Interfaces.IWindowHost host;
    private HyprNetworkManager.Models.NetworkStateContext state_context;
    private HashTable<string, string> wifi_row_signatures;
    private string[] wifi_row_order = {};
    private uint row_animation_serial = 0;
    private Gtk.CssProvider? row_animation_css_provider = null;

    public MainWindowWifiRowReconciler (HyprNetworkManager.UI.Interfaces.IWindowHost host,
        HyprNetworkManager.Models.NetworkStateContext state_context) {
        this.host = host;
        this.state_context = state_context;
        wifi_row_signatures = new HashTable<string, string> (str_hash, str_equal);
    }

    public void reset () {
        row_animation_serial++;
        wifi_row_order = {};
        wifi_row_signatures.remove_all ();
        clear_row_animation_provider ();
    }

    private string get_wifi_row_id (WifiNetwork net) {
        return "%s|%s".printf (net.device_path, net.ap_path);
    }

    private string build_wifi_row_signature (
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting,
        string? error_message
    ) {
        int connected_flag = is_connected_now ? 1 : 0;
        int connecting_flag = is_connecting ? 1 : 0;
        int secured_flag = net.is_secured ? 1 : 0;
        int saved_flag = net.saved ? 1 : 0;
        string safe_error = error_message != null ? error_message : "";
        return "%s|%s|%s|%u|%d|%d|%d|%d|%s|%u|%u|%u|%u|%u|%u|%u|%s|%s|%s".printf (
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
            net.signal_icon_name,
            safe_error
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

    private bool row_order_equals (string[] left, string[] right) {
        if (left.length != right.length) {
            return false;
        }

        for (int i = 0; i < left.length; i++) {
            if (left[i] != right[i]) {
                return false;
            }
        }

        return true;
    }

    private void clear_row_animation_provider () {
        if (row_animation_css_provider == null) {
            return;
        }

        var display = Gdk.Display.get_default ();
        if (display != null) {
            wifi_row_style_provider_remove_for_display (display, row_animation_css_provider);
        }
        row_animation_css_provider = null;
    }

    private bool get_row_top (Gtk.ListBoxRow row, Gtk.Widget relative_to, out int top) {
        top = 0;
        Graphene.Rect bounds = Graphene.Rect ();

        if (!row.compute_bounds (relative_to, out bounds)) {
            return false;
        }

        top = (int) bounds.get_y ();
        return true;
    }

    private HashTable<string, int> capture_row_tops (Gtk.ListBox wifi_listbox) {
        var row_tops = new HashTable<string, int> (str_hash, str_equal);

        for (Gtk.Widget? child = wifi_listbox.get_first_child (); child != null; child = child.get_next_sibling ()) {
            var row = child as Gtk.ListBoxRow;
            if (row == null) {
                continue;
            }

            string? row_id = (string?) row.get_data<string> (MainWindowDataKeys.ROW_ID);
            if (row_id == null || row_id == "") {
                continue;
            }

            int top = 0;
            if (get_row_top (row, wifi_listbox, out top)) {
                row_tops.insert (row_id, top);
            }
        }

        return row_tops;
    }

    private void clear_row_move_classes (Gtk.ListBoxRow row) {
        foreach (var css_class in row.get_css_classes ()) {
            if (css_class.has_prefix (ROW_MOVE_CLASS_PREFIX)) {
                row.remove_css_class (css_class);
            }
        }
    }

    private void animate_row_enter (Gtk.ListBoxRow row) {
        row.remove_css_class (ROW_ENTER_CLASS);
        row.add_css_class (ROW_ENTER_CLASS);

        var row_ref = row;
        GLib.Timeout.add (ROW_ENTER_ANIMATION_MS + ROW_ANIMATION_CLEANUP_PADDING_MS, () => {
            row_ref.remove_css_class (ROW_ENTER_CLASS);
            return false;
        });
    }

    private void schedule_row_move_animation (
        Gtk.ListBox wifi_listbox,
        HashTable<string, int> previous_row_tops
    ) {
        row_animation_serial++;
        uint animation_serial = row_animation_serial;

        var listbox_ref = wifi_listbox;
        listbox_ref.add_tick_callback ((widget, frame_clock) => {
            if (animation_serial != row_animation_serial || !widget.get_mapped ()) {
                return false;
            }

            apply_row_move_animation ((Gtk.ListBox) widget, previous_row_tops, animation_serial);
            return false;
        });
    }

    private void apply_row_move_animation (
        Gtk.ListBox wifi_listbox,
        HashTable<string, int> previous_row_tops,
        uint animation_serial
    ) {
        clear_row_animation_provider ();

        var css = new GLib.StringBuilder ();
        Gtk.ListBoxRow[] animated_rows = {};
        string[] animation_classes = {};
        int animation_index = 0;

        for (Gtk.Widget? child = wifi_listbox.get_first_child (); child != null; child = child.get_next_sibling ()) {
            var row = child as Gtk.ListBoxRow;
            if (row == null) {
                continue;
            }

            clear_row_move_classes (row);

            string? row_id = (string?) row.get_data<string> (MainWindowDataKeys.ROW_ID);
            if (row_id == null || row_id == "" || !previous_row_tops.contains (row_id)) {
                continue;
            }

            int new_top = 0;
            if (!get_row_top (row, wifi_listbox, out new_top)) {
                continue;
            }

            int previous_top = previous_row_tops.lookup (row_id);
            int delta_px = previous_top - new_top;
            if (delta_px > -ROW_MOVE_MIN_DELTA_PX && delta_px < ROW_MOVE_MIN_DELTA_PX) {
                continue;
            }

            string class_name = "%s%u-%d".printf (ROW_MOVE_CLASS_PREFIX, animation_serial, animation_index);
            string keyframes_name = "nm-wifi-row-move-keyframes-%u-%d".printf (
                animation_serial,
                animation_index
            );

            css.append (
                "@keyframes %s { 0%% { transform: translateY(%dpx); } 100%% { transform: translateY(0); } }\n"
                    .printf (keyframes_name, delta_px)
            );
            css.append (
                ".%s { animation: %s %ums cubic-bezier(0.2, 0.0, 0, 1) both; }\n"
                    .printf (class_name, keyframes_name, ROW_MOVE_ANIMATION_MS)
            );

            animated_rows += row;
            animation_classes += class_name;
            animation_index++;
        }

        if (animation_index == 0) {
            return;
        }

        var display = Gdk.Display.get_default ();
        if (display == null) {
            return;
        }

        var provider = new Gtk.CssProvider ();
        provider.load_from_string (css.str);
        row_animation_css_provider = provider;
        wifi_row_style_provider_add_for_display (
            display,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 80
        );

        for (int i = 0; i < animated_rows.length; i++) {
            animated_rows[i].add_css_class (animation_classes[i]);
        }

        GLib.Timeout.add (ROW_MOVE_ANIMATION_MS + ROW_ANIMATION_CLEANUP_PADDING_MS, () => {
            for (int i = 0; i < animated_rows.length; i++) {
                animated_rows[i].remove_css_class (animation_classes[i]);
            }

            if (row_animation_css_provider == provider) {
                clear_row_animation_provider ();
            }
            return false;
        });
    }

    public void reconcile (
        Gtk.ListBox wifi_listbox,
        WifiNetwork[] networks,
        string? active_wifi_password_row_id,
        bool has_active_wifi_password_prompt,
        IMainWindowWifiRowProvider row_provider
    ) {
        var previous_row_tops = capture_row_tops (wifi_listbox);
        bool can_animate_row_changes = wifi_listbox.get_mapped () && previous_row_tops.size () > 0;
        bool should_animate_row_changes = false;
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
        should_animate_row_changes = can_animate_row_changes
            && !row_order_equals (wifi_row_order, ordered_row_ids);

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
            bool is_connected_now = false;
            bool is_connecting = false;
            string? error_message = null;

            if (state_context != null) {
                is_connected_now = state_context.active_wifi_connections.contains (net_key);
                is_connecting = state_context.pending_wifi_connect.contains (net_key);
                error_message = state_context.wifi_errors.lookup (net_key);
            }
            string new_signature = build_wifi_row_signature (net, is_connected_now, is_connecting, error_message);

            var row = visible_rows_by_id.lookup (row_id);
            string? existing_signature = wifi_row_signatures.lookup (row_id);
            bool preserve_prompt_row = active_prompt_row_still_present
                && active_wifi_password_row_id == row_id;
            bool is_new_row = row == null;
            bool needs_rebuild = row == null || (!preserve_prompt_row && existing_signature != new_signature);

            if (needs_rebuild) {
                bool was_expanded = false;
                if (row != null) {
                    was_expanded = row.get_data<bool> (MainWindowDataKeys.ACTIONS_EXPANDED);
                }

                var rebuilt_row = row_provider.build_wifi_row (net);
                rebuilt_row.set_data<string> (MainWindowDataKeys.ROW_ID, row_id.dup ());

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

            if (row.get_parent () != wifi_listbox) {
                row.set_data<int> ("sort-index", index);
                wifi_listbox.append (row);
                should_invalidate_sort = true;
                if (should_animate_row_changes && is_new_row && !previous_row_tops.contains (row_id)) {
                    animate_row_enter (row);
                }
            } else {
                int current_index = row.get_data<int> ("sort-index");
                if (current_index != index) {
                    row.set_data<int> ("sort-index", index);
                    should_invalidate_sort = true;
                }
            }

            if (!preserve_prompt_row) {
                wifi_row_signatures.insert (row_id, new_signature);
            }

            index++;
        }

        wifi_row_order = ordered_row_ids;

        if (should_invalidate_sort) {
            wifi_listbox.invalidate_sort ();
        }

        if (should_animate_row_changes) {
            schedule_row_move_animation (wifi_listbox, previous_row_tops);
        }
    }
}
