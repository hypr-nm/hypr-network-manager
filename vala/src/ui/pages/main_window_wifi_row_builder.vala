public class MainWindowWifiRowBuilder : Object {
    private static void collapse_row (Gtk.ListBoxRow row) {
        var revealer = row.get_data<Gtk.Revealer> ("actions-revealer");
        if (revealer != null) {
            revealer.set_reveal_child (false);
            row.set_data<bool> ("nm-actions-expanded", false);
        }
    }

    private static void collapse_other_expanded_rows (Gtk.ListBoxRow row) {
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

            if (!other_row.get_data<bool> ("nm-actions-expanded")) {
                continue;
            }

            collapse_row (other_row);
        }
    }

    public static Gtk.ListBoxRow build_row (
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting,
        bool show_frequency,
        bool show_band,
        bool show_bssid,
        string signal_icon_name,
        owned MainWindowWifiNetworkCallback on_open_details,
        owned MainWindowWifiNetworkCallback on_forget_saved_network,
        owned MainWindowWifiNetworkCallback on_disconnect,
        owned MainWindowWifiNetworkPasswordCallback on_connect,
        owned MainWindowWifiNetworkBoolCallback on_set_auto_connect,
        owned MainWindowPasswordPromptShowCallback on_show_password_prompt,
        owned MainWindowPasswordPromptHideCallback on_hide_password_prompt
    ) {
        var row = new Gtk.ListBoxRow ();
        row.add_css_class ("nm-wifi-row");
        if (is_connected_now) {
            row.add_css_class ("connected");
        }

        bool has_resolvable_saved_profile = net.saved && net.saved_connection_uuid.strip () != "";
        bool requires_hidden_ssid = net.is_hidden;

        var row_root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        row_root.add_css_class ("nm-row-root");

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        content.add_css_class ("nm-row-content");

        var signal_icon = new Gtk.Image.from_icon_name (signal_icon_name);
        signal_icon.set_pixel_size (16);
        signal_icon.add_css_class ("nm-signal-icon");
        signal_icon.add_css_class ("nm-wifi-icon");
        if (net.is_secured) {
            signal_icon.add_css_class ("nm-signal-icon-secured");
        }
        content.append (signal_icon);

        var info = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
        info.set_hexpand (true);
        info.add_css_class ("nm-row-info");
        var ssid_lbl = new Gtk.Label (net.ssid);
        ssid_lbl.set_xalign (0.0f);
        ssid_lbl.add_css_class ("nm-ssid-label");
        info.append (ssid_lbl);

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
        if (show_bssid && net.bssid != "") {
            subtitle += " - %s".printf (net.bssid);
        }

        var sub = new Gtk.Label (subtitle);
        sub.set_xalign (0.0f);
        sub.add_css_class ("nm-sub-label");
        info.append (sub);
        content.append (info);

        var expand_hint = new Gtk.Image.from_icon_name ("pan-down-symbolic");
        expand_hint.add_css_class ("nm-row-expand-icon");
        expand_hint.set_valign (Gtk.Align.CENTER);
        content.append (expand_hint);

        var actions_panel = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        actions_panel.add_css_class ("nm-row-actions");

        var action_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        action_buttons.add_css_class ("nm-row-action-buttons");
        action_buttons.set_valign (Gtk.Align.CENTER);

        var details_btn = new Gtk.Button ();
        details_btn.add_css_class ("nm-button");
        details_btn.add_css_class ("nm-menu-button");
        details_btn.add_css_class ("nm-details-open-button");
        details_btn.add_css_class ("nm-row-icon-button");
        details_btn.set_valign (Gtk.Align.CENTER);
        details_btn.set_tooltip_text ("Details");
        var details_icon = new Gtk.Image.from_icon_name ("document-properties-symbolic");
        details_icon.add_css_class ("nm-details-open-icon");
        details_icon.add_css_class ("nm-details-button-icon");
        details_btn.set_child (details_icon);
        details_btn.clicked.connect (() => {
            on_open_details (net);
        });

        if (has_resolvable_saved_profile) {
            var forget = new Gtk.Button.with_label ("Forget");
            forget.add_css_class ("nm-button");
            forget.add_css_class ("nm-action-button");
            forget.add_css_class ("nm-row-action-button");
            forget.set_valign (Gtk.Align.CENTER);
            forget.clicked.connect (() => {
                on_forget_saved_network (net);
            });
            action_buttons.append (forget);
        }

        string action_label = is_connecting ? "Connecting…" : (is_connected_now ? "Disconnect" : "Connect");
        var action = new Gtk.Button.with_label (action_label);
        action.add_css_class ("nm-button");
        action.add_css_class (is_connected_now && !is_connecting ? "nm-disconnect-button" : "nm-connect-button");
        action.add_css_class ("nm-row-action-button");
        action.set_valign (Gtk.Align.CENTER);
        action.set_sensitive (!is_connecting);

        var prompt_label = new Gtk.Label ("Password for %s".printf (net.ssid));
        prompt_label.set_xalign (0.0f);
        prompt_label.set_hexpand (true);
        prompt_label.add_css_class ("nm-form-label");
        prompt_label.add_css_class ("nm-inline-password-label");

        var hidden_ssid_label = new Gtk.Label ("SSID");
        hidden_ssid_label.set_xalign (0.0f);
        hidden_ssid_label.set_hexpand (true);
        hidden_ssid_label.add_css_class ("nm-form-label");
        hidden_ssid_label.add_css_class ("nm-inline-password-label");

        var hidden_ssid_entry = new Gtk.Entry ();
        hidden_ssid_entry.set_hexpand (true);
        hidden_ssid_entry.set_placeholder_text ("Hidden network name");
        hidden_ssid_entry.add_css_class ("nm-inline-password-entry");
        hidden_ssid_label.set_visible (requires_hidden_ssid);
        hidden_ssid_entry.set_visible (requires_hidden_ssid);

        var prompt_entry = new Gtk.Entry ();
        prompt_entry.set_hexpand (true);
        prompt_entry.set_visibility (false);
        prompt_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        prompt_entry.set_placeholder_text (
            "Wi-Fi password (min %d chars)".printf (HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH)
        );
        prompt_entry.add_css_class ("nm-password-entry");
        prompt_entry.add_css_class ("nm-inline-password-entry");

        MainWindowActionCallback update_prompt_password_visibility_icon = () => {
            bool reveal = prompt_entry.get_visibility ();
            prompt_entry.set_icon_from_icon_name (
                Gtk.EntryIconPosition.SECONDARY,
                reveal ? "view-conceal-symbolic" : "view-reveal-symbolic"
            );
            prompt_entry.set_icon_tooltip_text (
                Gtk.EntryIconPosition.SECONDARY,
                reveal ? "Hide password" : "Show password"
            );
        };

        if (net.is_secured) {
            prompt_entry.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
            prompt_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, true);
            update_prompt_password_visibility_icon ();
            prompt_entry.icon_press.connect ((icon_pos) => {
                if (icon_pos != Gtk.EntryIconPosition.SECONDARY) {
                    return;
                }
                prompt_entry.set_visibility (!prompt_entry.get_visibility ());
                update_prompt_password_visibility_icon ();
            });
        }

        var prompt_cancel = new Gtk.Button.with_label ("Cancel");
        prompt_cancel.add_css_class ("nm-button");
        prompt_cancel.add_css_class ("nm-inline-password-cancel");

        var prompt_connect = new Gtk.Button.with_label ("Connect");
        prompt_connect.add_css_class ("nm-button");
        prompt_connect.add_css_class ("suggested-action");
        prompt_connect.add_css_class ("nm-inline-password-connect");
        prompt_connect.set_sensitive (false);

        MainWindowActionCallback update_prompt_connect_sensitivity = () => {
            bool has_hidden_ssid = !requires_hidden_ssid || hidden_ssid_entry.get_text ().strip () != "";
            bool has_valid_password = !net.is_secured
                || HiddenWifiSecurityModeUtils.is_password_valid (prompt_entry.get_text ());
            prompt_connect.set_sensitive (has_hidden_ssid && has_valid_password);
        };

        prompt_entry.changed.connect (() => {
            update_prompt_connect_sensitivity ();
        });
        hidden_ssid_entry.changed.connect (() => {
            update_prompt_connect_sensitivity ();
        });

        var prompt_actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        prompt_actions.add_css_class ("nm-inline-password-actions");
        prompt_actions.set_halign (Gtk.Align.END);
        prompt_actions.append (prompt_cancel);
        prompt_actions.append (prompt_connect);

        var prompt_inner = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        prompt_inner.add_css_class ("nm-inline-password");
        prompt_inner.append (hidden_ssid_label);
        prompt_inner.append (hidden_ssid_entry);
        prompt_inner.append (prompt_label);
        prompt_inner.append (prompt_entry);
        prompt_inner.append (prompt_actions);

        var prompt_revealer = new Gtk.Revealer ();
        prompt_revealer.add_css_class ("nm-inline-password-revealer");
        prompt_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        prompt_revealer.set_transition_duration (220);
        prompt_revealer.set_reveal_child (false);
        prompt_revealer.set_child (prompt_inner);

        prompt_cancel.clicked.connect (() => {
            hidden_ssid_entry.set_text ("");
            on_hide_password_prompt (prompt_revealer, prompt_entry, null);
        });

        prompt_connect.clicked.connect (() => {
            if (!prompt_connect.get_sensitive ()) {
                return;
            }
            on_hide_password_prompt (prompt_revealer, prompt_entry, prompt_entry.get_text ());
            on_connect (
                net,
                prompt_entry.get_text (),
                requires_hidden_ssid ? hidden_ssid_entry.get_text ().strip () : null
            );
            hidden_ssid_entry.set_text ("");
        });

        prompt_entry.activate.connect (() => {
            if (!prompt_connect.get_sensitive ()) {
                return;
            }
            on_hide_password_prompt (prompt_revealer, prompt_entry, prompt_entry.get_text ());
            on_connect (
                net,
                prompt_entry.get_text (),
                requires_hidden_ssid ? hidden_ssid_entry.get_text ().strip () : null
            );
            hidden_ssid_entry.set_text ("");
        });

        hidden_ssid_entry.activate.connect (() => {
            if (net.is_secured) {
                prompt_entry.grab_focus ();
                return;
            }

            if (!prompt_connect.get_sensitive ()) {
                return;
            }

            on_hide_password_prompt (prompt_revealer, prompt_entry, prompt_entry.get_text ());
            on_connect (
                net,
                prompt_entry.get_text (),
                hidden_ssid_entry.get_text ().strip ()
            );
            hidden_ssid_entry.set_text ("");
        });

        action.clicked.connect (() => {
            if (is_connected_now) {
                on_disconnect (net);
                return;
            }

            if ((net.is_secured && !has_resolvable_saved_profile) || requires_hidden_ssid) {
                on_show_password_prompt (prompt_revealer, prompt_entry);
                if (requires_hidden_ssid) {
                    hidden_ssid_entry.grab_focus ();
                }
            } else {
                on_connect (net, null, null);
            }
        });

        update_prompt_connect_sensitivity ();

        action_buttons.append (action);
        action_buttons.append (details_btn);

        if (has_resolvable_saved_profile) {
            var auto_connect = new Gtk.CheckButton.with_label ("Connect automatically");
            auto_connect.add_css_class ("nm-row-autoconnect-check");
            auto_connect.set_active (net.autoconnect);
            auto_connect.set_sensitive (!is_connecting);
            auto_connect.set_hexpand (true);
            auto_connect.set_halign (Gtk.Align.START);
            auto_connect.toggled.connect (() => {
                on_set_auto_connect (net, auto_connect.get_active ());
            });
            actions_panel.append (auto_connect);
        } else {
            var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            spacer.set_hexpand (true);
            actions_panel.append (spacer);
        }

        actions_panel.append (action_buttons);

        var actions_revealer = new Gtk.Revealer ();
        actions_revealer.add_css_class ("nm-row-actions-revealer");
        actions_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
        actions_revealer.set_transition_duration (220);
        actions_revealer.set_reveal_child (false);
        actions_revealer.set_child (actions_panel);
        row.set_data<Gtk.Revealer> ("actions-revealer", actions_revealer);

        var click = new Gtk.GestureClick ();
        click.released.connect ((n_press, x, y) => {
            bool expanded = !actions_revealer.get_reveal_child ();

            if (expanded) {
                collapse_other_expanded_rows (row);
            }

            actions_revealer.set_reveal_child (expanded);
            row.set_data<bool> ("nm-actions-expanded", expanded);
            if (!expanded) {
                on_hide_password_prompt (prompt_revealer, prompt_entry, null);
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
