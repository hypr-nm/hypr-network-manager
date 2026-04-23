using GLib;
using Gtk;

namespace MainWindowWifiRowBuilder {
    private void collapse_row (Gtk.ListBoxRow row) {
        var revealer = row.get_data<Gtk.Revealer> ("actions-revealer");
        if (revealer != null) {
            revealer.set_reveal_child (false);
            row.set_data<bool> (MainWindowDataKeys.ACTIONS_EXPANDED, false);
        }
        var expand_hint = row.get_data<Gtk.Image> ("expand-hint");
        if (expand_hint != null) {
            MainWindowIconResources.set_expand_indicator_icon (expand_hint, false);
        }
    }

    private void collapse_other_expanded_rows (Gtk.ListBoxRow row) {
        var parent = row.get_parent () as Gtk.ListBox;
        if (parent == null) {
            return;
        }

        for (Gtk.Widget? child = parent.get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child == row) {
                continue;
            }

            var other_row = child as Gtk.ListBoxRow;
            if (other_row == null) {
                continue;
            }

            if (!other_row.get_data<bool> (MainWindowDataKeys.ACTIONS_EXPANDED)) {
                continue;
            }

            collapse_row (other_row);
        }
    }

    private void sync_prompt_connect_button_sensitivity (
        Gtk.Button prompt_connect,
        Gtk.Entry hidden_ssid_entry,
        Gtk.Entry prompt_entry,
        bool requires_hidden_ssid,
        bool is_secured
    ) {
        bool has_hidden_ssid = !requires_hidden_ssid || hidden_ssid_entry.get_text ().strip () != "";
        bool has_valid_password = !is_secured
            || HiddenWifiSecurityModeUtils.is_password_valid (prompt_entry.get_text ());
        prompt_connect.set_sensitive (has_hidden_ssid && has_valid_password);
    }

    private Gtk.Box build_info_box (
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting,
        string? error_message,
        bool show_frequency,
        bool show_band,
        bool show_bssid,
        Gtk.ListBoxRow row
    ) {
        var info = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_INLINE);
        info.set_hexpand (true);
        info.add_css_class (MainWindowCssClasses.ROW_INFO);

        string ssid_text = MainWindowHelpers.safe_text (net.ssid);

        var ssid_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        ssid_row.set_hexpand (true);

        var ssid_lbl = new Gtk.Label (ssid_text);
        ssid_lbl.set_xalign (0.0f);
        ssid_lbl.add_css_class (MainWindowCssClasses.SSID_LABEL);
        ssid_row.append (ssid_lbl);
        row.set_data<Gtk.Label> ("ssid-label", ssid_lbl);

        var connected_indicator = new Gtk.Label ("• Connected");
        connected_indicator.add_css_class (MainWindowCssClasses.CONNECTED_INDICATOR);
        ssid_row.append (connected_indicator);
        connected_indicator.set_visible (is_connected_now);
        row.set_data<Gtk.Label> ("connected-indicator", connected_indicator);

        info.append (ssid_row);

        string subtitle = resolve_subtitle (net, show_frequency, show_band, show_bssid);

        string secondary_text = error_message != null ? error_message : subtitle;
        var sub = new Gtk.Label (secondary_text);
        sub.set_xalign (0.0f);
        sub.set_ellipsize (Pango.EllipsizeMode.END);
        update_sub_label_style (sub, error_message);
        info.append (sub);
        row.set_data<Gtk.Label> ("sub-label", sub);

        return info;
    }

    private string resolve_subtitle (
        WifiNetwork net,
        bool show_frequency,
        bool show_band,
        bool show_bssid
    ) {
        bool is_saved_only = net.saved && net.ap_path.has_prefix ("saved:");
        if (is_saved_only) {
            return "Saved network";
        }

        string bssid_text = MainWindowHelpers.safe_text (net.bssid);
        string subtitle = "%s (%u%%)".printf (net.signal_label, net.signal);
        if (show_frequency && net.frequency_mhz > 0) {
            subtitle += " - %u MHz".printf (net.frequency_mhz);
        }
        if (show_band && net.frequency_mhz > 0) {
            string band = MainWindowHelpers.get_band_label (net.frequency_mhz);
            if (band != "") {
                subtitle += " - %s".printf (band);
            }
        }
        if (show_bssid && bssid_text != "") {
            subtitle += " - %s".printf (bssid_text);
        }
        return subtitle;
    }

    private void update_sub_label_style (Gtk.Label sub, string? error_message) {
        if (error_message != null) {
            sub.set_tooltip_text (error_message);
            sub.add_css_class (MainWindowCssClasses.ERROR_LABEL);
            sub.add_css_class (MainWindowCssClasses.ROW_ERROR_LABEL);
            sub.remove_css_class (MainWindowCssClasses.SUB_LABEL);
        } else {
            sub.set_tooltip_text (null);
            sub.remove_css_class (MainWindowCssClasses.ERROR_LABEL);
            sub.remove_css_class (MainWindowCssClasses.ROW_ERROR_LABEL);
            sub.add_css_class (MainWindowCssClasses.SUB_LABEL);
        }
    }

    private Gtk.Box build_action_buttons (
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting,
        bool has_resolvable_saved_profile,
        bool requires_hidden_ssid,
        IMainWindowWifiRowActionHandler action_handler,
        Gtk.Revealer prompt_revealer,
        Gtk.Entry prompt_entry,
        Gtk.Entry hidden_ssid_entry,
        Gtk.CheckButton auto_connect,
        Gtk.ListBoxRow row
    ) {
        var action_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        action_buttons.add_css_class (MainWindowCssClasses.ROW_ACTION_BUTTONS);
        action_buttons.set_valign (Gtk.Align.CENTER);

        var details_btn = new Gtk.Button ();
        details_btn.add_css_class (MainWindowCssClasses.ROW_ICON_ACTION);
        MainWindowCssClassResolver.add_best_class (
            details_btn,
            {MainWindowCssClasses.ROW_ICON_ACTION, MainWindowCssClasses.BUTTON}
        );
        MainWindowCssClassResolver.add_best_class (details_btn, {MainWindowCssClasses.DETAILS_OPEN_BUTTON,
            MainWindowCssClasses.ROW_ICON_ACTION});
        details_btn.set_valign (Gtk.Align.CENTER);
        details_btn.set_tooltip_text ("Details");
        var details_icon = new Gtk.Image.from_icon_name ("document-properties-symbolic");
        MainWindowCssClassResolver.add_best_class (
            details_icon,
            {MainWindowCssClasses.DETAILS_BUTTON_ICON, MainWindowCssClasses.DETAILS_OPEN_ICON}
        );
        details_btn.set_child (details_icon);
        details_btn.clicked.connect (() => {
            action_handler.open_details (net);
        });

        var forget = new Gtk.Button.with_label ("Forget");
        MainWindowCssClassResolver.add_best_class (
            forget,
            {MainWindowCssClasses.ROW_LINK_ACTION, MainWindowCssClasses.BUTTON}
        );
        forget.add_css_class (MainWindowCssClasses.ACTION_BUTTON);
        forget.add_css_class (MainWindowCssClasses.FORGET_BUTTON);
        forget.set_valign (Gtk.Align.CENTER);
        forget.clicked.connect (() => {
            action_handler.forget_saved_network (net);
        });
        forget.set_visible (has_resolvable_saved_profile);
        action_buttons.append (forget);
        row.set_data<Gtk.Button> ("forget-button", forget);

        var action = new Gtk.Button ();
        MainWindowCssClassResolver.add_best_class (
            action,
            {MainWindowCssClasses.ROW_LINK_ACTION, MainWindowCssClasses.BUTTON}
        );
        action.set_valign (Gtk.Align.CENTER);
        update_action_button (action, is_connected_now, is_connecting);

        action.clicked.connect (() => {
            bool current_connected = action.has_css_class (MainWindowCssClasses.DISCONNECT_BUTTON);
            bool current_connecting = action.get_label ().has_prefix ("Connecting");

            if (current_connecting) return;

            if (current_connected) {
                action_handler.disconnect_network (net);
                return;
            }

            var latest_net = row.get_data<WifiNetwork> ("wifi-network");

            if ((latest_net.is_secured && !latest_net.saved) || latest_net.is_hidden) {
                action_handler.show_password_prompt (latest_net, prompt_revealer, prompt_entry);
                if (latest_net.is_hidden) {
                    hidden_ssid_entry.grab_focus ();
                } else {
                    prompt_entry.grab_focus ();
                }
            } else {
                action_handler.connect_network (latest_net, null, null, auto_connect.get_active ());
            }
        });

        action_buttons.append (action);
        row.set_data<Gtk.Button> ("action-button", action);
        action_buttons.append (details_btn);

        return action_buttons;
    }

    private void update_action_button (Gtk.Button action, bool is_connected_now, bool is_connecting) {
        string action_label = is_connecting ? "Connecting…" : (is_connected_now ? "Disconnect" : "Connect");
        action.set_label (action_label);
        action.set_sensitive (!is_connecting);

        if (is_connected_now && !is_connecting) {
            action.add_css_class (MainWindowCssClasses.DISCONNECT_BUTTON);
            action.remove_css_class (MainWindowCssClasses.CONNECT_BUTTON);
        } else {
            action.add_css_class (MainWindowCssClasses.CONNECT_BUTTON);
            action.remove_css_class (MainWindowCssClasses.DISCONNECT_BUTTON);
        }
    }

    private Gtk.Revealer build_password_prompt (
        WifiNetwork net,
        bool requires_hidden_ssid,
        IMainWindowWifiRowActionHandler action_handler,
        Gtk.CheckButton auto_connect,
        out Gtk.Entry prompt_entry,
        out Gtk.Entry hidden_ssid_entry
    ) {
        var prompt_label = new Gtk.Label ("Password for %s".printf (net.ssid));
        prompt_label.set_xalign (0.0f);
        prompt_label.set_hexpand (true);
        MainWindowCssClassResolver.add_hook_and_best_class (
            prompt_label,
            MainWindowCssClasses.INLINE_PASSWORD_LABEL,
            {MainWindowCssClasses.FORM_LABEL}
        );
        prompt_label.set_visible (net.is_secured);

        var hidden_ssid_label = new Gtk.Label ("SSID");
        hidden_ssid_label.set_xalign (0.0f);
        hidden_ssid_label.set_hexpand (true);
        MainWindowCssClassResolver.add_hook_and_best_class (
            hidden_ssid_label,
            MainWindowCssClasses.INLINE_PASSWORD_LABEL,
            {MainWindowCssClasses.FORM_LABEL}
        );

        hidden_ssid_entry = new Gtk.Entry ();
        hidden_ssid_entry.set_hexpand (true);
        hidden_ssid_entry.set_placeholder_text ("Hidden network name");
        MainWindowCssClassResolver.add_hook_and_best_class (
            hidden_ssid_entry,
            MainWindowCssClasses.INLINE_SSID_ENTRY,
            {MainWindowCssClasses.INLINE_PASSWORD_ENTRY, MainWindowCssClasses.PASSWORD_ENTRY}
        );
        hidden_ssid_label.set_visible (requires_hidden_ssid);
        hidden_ssid_entry.set_visible (requires_hidden_ssid);

        prompt_entry = new Gtk.Entry ();
        prompt_entry.set_hexpand (true);
        prompt_entry.set_visibility (false);
        prompt_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        prompt_entry.set_placeholder_text (
            "Wi-Fi password (min %d chars)".printf (HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH)
        );
        MainWindowCssClassResolver.add_hook_and_best_class (
            prompt_entry,
            MainWindowCssClasses.INLINE_PASSWORD_ENTRY,
            {MainWindowCssClasses.PASSWORD_ENTRY}
        );
        prompt_entry.set_visible (net.is_secured);

        if (net.is_secured) {
            prompt_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
            prompt_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
            MainWindowHelpers.sync_password_visibility_icon (prompt_entry);

            var local_prompt_entry = prompt_entry;
            prompt_entry.icon_press.connect ((icon_pos) => {
                if (icon_pos != Gtk.EntryIconPosition.SECONDARY) {
                    return;
                }
                local_prompt_entry.set_visibility (!local_prompt_entry.get_visibility ());
                MainWindowHelpers.sync_password_visibility_icon (local_prompt_entry);
            });
        }

        var prompt_cancel = new Gtk.Button.with_label ("Cancel");
        prompt_cancel.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_hook_and_best_class (
            prompt_cancel,
            MainWindowCssClasses.INLINE_PASSWORD_CANCEL,
            {MainWindowCssClasses.BUTTON}
        );

        var prompt_connect = new Gtk.Button.with_label ("Connect");
        prompt_connect.add_css_class (MainWindowCssClasses.BUTTON);
        MainWindowCssClassResolver.add_hook_and_best_class (
            prompt_connect,
            MainWindowCssClasses.INLINE_PASSWORD_CONNECT,
            {MainWindowCssClasses.SUGGESTED_ACTION, MainWindowCssClasses.BUTTON}
        );
        prompt_connect.set_sensitive (false);

        var local_prompt_connect = prompt_connect;
        var local_hidden_ssid_entry = hidden_ssid_entry;
        var local_prompt_entry = prompt_entry;

        prompt_entry.changed.connect (() => {
            sync_prompt_connect_button_sensitivity (
                local_prompt_connect,
                local_hidden_ssid_entry,
                local_prompt_entry,
                requires_hidden_ssid,
                net.is_secured
            );
        });
        hidden_ssid_entry.changed.connect (() => {
            sync_prompt_connect_button_sensitivity (
                local_prompt_connect,
                local_hidden_ssid_entry,
                local_prompt_entry,
                requires_hidden_ssid,
                net.is_secured
            );
        });
        sync_prompt_connect_button_sensitivity (
            prompt_connect,
            hidden_ssid_entry,
            prompt_entry,
            requires_hidden_ssid,
            net.is_secured
        );

        var prompt_actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        prompt_actions.add_css_class (MainWindowCssClasses.INLINE_PASSWORD_ACTIONS);
        prompt_actions.set_halign (Gtk.Align.END);
        prompt_actions.append (prompt_cancel);
        prompt_actions.append (prompt_connect);

        var prompt_inner = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        prompt_inner.add_css_class (MainWindowCssClasses.INLINE_PASSWORD);
        prompt_inner.append (hidden_ssid_label);
        prompt_inner.append (hidden_ssid_entry);
        prompt_inner.append (prompt_label);
        prompt_inner.append (prompt_entry);
        prompt_inner.append (prompt_actions);

        var prompt_revealer = new Gtk.Revealer ();
        prompt_revealer.add_css_class (MainWindowCssClasses.INLINE_PASSWORD_REVEALER);
        prompt_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        prompt_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_MS);
        prompt_revealer.set_reveal_child (false);
        prompt_revealer.set_child (prompt_inner);

        var local_prompt_revealer = prompt_revealer;
        prompt_cancel.clicked.connect (() => {
            local_hidden_ssid_entry.set_text ("");
            action_handler.hide_password_prompt (local_prompt_revealer, local_prompt_entry, null);
        });

        prompt_connect.clicked.connect (() => {
            if (!local_prompt_connect.get_sensitive ()) {
                return;
            }
            action_handler.hide_password_prompt (local_prompt_revealer, local_prompt_entry,
                local_prompt_entry.get_text ());
            action_handler.connect_network (
                net,
                net.is_secured ? local_prompt_entry.get_text () : null,
                requires_hidden_ssid ? local_hidden_ssid_entry.get_text ().strip () : null,
                auto_connect.get_active ()
            );
            local_hidden_ssid_entry.set_text ("");
        });

        prompt_entry.activate.connect (() => {
            if (!local_prompt_connect.get_sensitive ()) {
                return;
            }
            action_handler.hide_password_prompt (local_prompt_revealer, local_prompt_entry,
                local_prompt_entry.get_text ());
            action_handler.connect_network (
                net,
                net.is_secured ? local_prompt_entry.get_text () : null,
                requires_hidden_ssid ? local_hidden_ssid_entry.get_text ().strip () : null,
                auto_connect.get_active ()
            );
            local_hidden_ssid_entry.set_text ("");
        });

        hidden_ssid_entry.activate.connect (() => {
            if (net.is_secured) {
                local_prompt_entry.grab_focus ();
                return;
            }

            if (!local_prompt_connect.get_sensitive ()) {
                return;
            }

            action_handler.hide_password_prompt (local_prompt_revealer, local_prompt_entry,
                local_prompt_entry.get_text ());
            action_handler.connect_network (
                net,
                null,
                local_hidden_ssid_entry.get_text ().strip (),
                auto_connect.get_active ()
            );
            local_hidden_ssid_entry.set_text ("");
        });

        return prompt_revealer;
    }

    public void update_row (
        Gtk.ListBoxRow row,
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting,
        string? error_message,
        bool show_frequency,
        bool show_band,
        bool show_bssid,
        string signal_icon_name
    ) {
        row.set_data<WifiNetwork> ("wifi-network", net);

        if (is_connected_now) {
            row.add_css_class (MainWindowCssClasses.CONNECTED);
        } else {
            row.remove_css_class (MainWindowCssClasses.CONNECTED);
        }

        var signal_icon = row.get_data<Gtk.Image> ("signal-icon");
        if (signal_icon != null) {
            signal_icon.set_from_icon_name (signal_icon_name);
            if (net.is_secured) {
                signal_icon.add_css_class (MainWindowCssClasses.SIGNAL_ICON_SECURED);
            } else {
                signal_icon.remove_css_class (MainWindowCssClasses.SIGNAL_ICON_SECURED);
            }
        }

        var ssid_lbl = row.get_data<Gtk.Label> ("ssid-label");
        if (ssid_lbl != null) {
            ssid_lbl.set_text (MainWindowHelpers.safe_text (net.ssid));
        }

        var connected_indicator = row.get_data<Gtk.Label> ("connected-indicator");
        if (connected_indicator != null) {
            connected_indicator.set_visible (is_connected_now);
        }

        var sub = row.get_data<Gtk.Label> ("sub-label");
        if (sub != null) {
            string subtitle = resolve_subtitle (net, show_frequency, show_band, show_bssid);
            sub.set_text (error_message != null ? error_message : subtitle);
            update_sub_label_style (sub, error_message);
        }

        var auto_connect = row.get_data<Gtk.CheckButton> ("auto-connect-check");
        if (auto_connect != null) {
            auto_connect.set_active (net.autoconnect);
            auto_connect.set_sensitive (!is_connecting);
        }

        var forget = row.get_data<Gtk.Button> ("forget-button");
        if (forget != null) {
            bool has_resolvable_saved_profile = net.saved && net.saved_connection_uuid.strip () != "";
            forget.set_visible (has_resolvable_saved_profile);
        }

        var action = row.get_data<Gtk.Button> ("action-button");
        if (action != null) {
            update_action_button (action, is_connected_now, is_connecting);
        }
    }

    public Gtk.ListBoxRow build_row (
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting,
        string? error_message,
        bool show_frequency,
        bool show_band,
        bool show_bssid,
        string signal_icon_name,
        IMainWindowWifiRowActionHandler action_handler
    ) {
        var row = new Gtk.ListBoxRow ();
        row.set_data<WifiNetwork> ("wifi-network", net);
        row.add_css_class (MainWindowCssClasses.WIFI_ROW);
        if (is_connected_now) {
            row.add_css_class (MainWindowCssClasses.CONNECTED);
        }

        bool has_resolvable_saved_profile = net.saved && net.saved_connection_uuid.strip () != "";
        bool requires_hidden_ssid = net.is_hidden;

        var row_root = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        row_root.add_css_class (MainWindowCssClasses.ROW_ROOT);

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
        content.add_css_class (MainWindowCssClasses.ROW_CONTENT);

        var signal_icon = new Gtk.Image.from_icon_name (signal_icon_name);
        MainWindowCssClassResolver.add_best_class (signal_icon, {MainWindowCssClasses.ICON_SIZE_16,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_best_class (signal_icon, {MainWindowCssClasses.WIFI_ICON,
            MainWindowCssClasses.SIGNAL_ICON});
        if (net.is_secured) {
            signal_icon.add_css_class (MainWindowCssClasses.SIGNAL_ICON_SECURED);
        }
        content.append (signal_icon);
        row.set_data<Gtk.Image> ("signal-icon", signal_icon);

        var info = build_info_box (
            net,
            is_connected_now,
            is_connecting,
            error_message,
            show_frequency,
            show_band,
            show_bssid,
            row
        );
        content.append (info);

        var expand_hint = new Gtk.Image ();
        MainWindowIconResources.set_expand_indicator_icon (expand_hint, false);
        expand_hint.add_css_class (MainWindowCssClasses.ROW_EXPAND_ICON);
        expand_hint.set_valign (Gtk.Align.CENTER);
        content.append (expand_hint);
        row.set_data<Gtk.Image> ("expand-hint", expand_hint);

        var actions_panel = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
        actions_panel.add_css_class (MainWindowCssClasses.ROW_ACTIONS);

        var auto_connect = new Gtk.CheckButton.with_label ("Connect automatically");
        auto_connect.add_css_class (MainWindowCssClasses.ROW_AUTOCONNECT_CHECK);
        auto_connect.set_active (net.autoconnect);
        auto_connect.set_sensitive (!is_connecting);
        auto_connect.set_hexpand (true);
        auto_connect.set_halign (Gtk.Align.START);
        auto_connect.toggled.connect (() => {
            var latest_net = row.get_data<WifiNetwork> ("wifi-network");
            bool latest_has_resolvable_saved_profile = latest_net.saved &
                latest_net.saved_connection_uuid.strip () != "";
            if (latest_has_resolvable_saved_profile) {
                action_handler.set_auto_connect (latest_net, auto_connect.get_active ());
            }
        });
        actions_panel.append (auto_connect);
        row.set_data<Gtk.CheckButton> ("auto-connect-check", auto_connect);

        Gtk.Entry prompt_entry;
        Gtk.Entry hidden_ssid_entry;
        var prompt_revealer = build_password_prompt (
            net,
            requires_hidden_ssid,
            action_handler,
            auto_connect,
            out prompt_entry,
            out hidden_ssid_entry
        );

        var action_buttons = build_action_buttons (
            net,
            is_connected_now,
            is_connecting,
            has_resolvable_saved_profile,
            requires_hidden_ssid,
            action_handler,
            prompt_revealer,
            prompt_entry,
            hidden_ssid_entry,
            auto_connect,
            row
        );

        actions_panel.append (action_buttons);

        var actions_revealer = new Gtk.Revealer ();
        actions_revealer.add_css_class (MainWindowCssClasses.ROW_ACTIONS_REVEALER);
        actions_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        actions_revealer.set_transition_duration (MainWindowUiMetrics.TRANSITION_REVEALER_MS);
        actions_revealer.set_reveal_child (false);
        actions_revealer.set_child (actions_panel);
        row.set_data<Gtk.Revealer> ("actions-revealer", actions_revealer);

        var click = new Gtk.GestureClick ();
        var local_row = row;
        click.released.connect ((n_press, x, y) => {
            bool expanded = !actions_revealer.get_reveal_child ();

            if (expanded) {
                collapse_other_expanded_rows (local_row);
            }

            actions_revealer.set_reveal_child (expanded);
            local_row.set_data<bool> (MainWindowDataKeys.ACTIONS_EXPANDED, expanded);
            MainWindowIconResources.set_expand_indicator_icon (expand_hint, expanded);
            if (!expanded) {
                action_handler.hide_password_prompt (prompt_revealer, prompt_entry, null);
            }
        });
        content.add_controller (click);

        row_root.append (content);
        row_root.append (actions_revealer);
        row_root.append (prompt_revealer);
        row.set_child (row_root);
        return row;
    }
}
