/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Constants;
using GLib;
using Gtk;

namespace MainWindowWifiRowBuilder {
    private const string SELECTED_WIFI_DEVICE_PATH = "selected-wifi-device-path";
    private const string RADIO_DROPDOWN = "radio-dropdown";
    private const string RADIO_DROPDOWN_MODEL = "radio-dropdown-model";
    private const string PASSWORD_PROMPT_REVEALER = "password-prompt-revealer";
    private const string PASSWORD_PROMPT_ENTRY = "password-prompt-entry";
    private const string UPDATING_RADIO_DROPDOWN = "updating-radio-dropdown";
    private const string UPDATING_AUTOCONNECT = "updating-auto-connect";
    private const string WIFI_IS_CONNECTING = "wifi-is-connecting";
    private const string WIFI_ACTION_STATE = "wifi-action-state";

    private enum WifiActionState {
        CONNECT,
        CONNECTING,
        DISCONNECT
    }

    private bool is_selectable_candidate (WifiNetwork candidate) {
        return candidate.device_is_available;
    }

    private WifiNetwork? selectable_candidate_at (WifiNetwork network, uint requested_index) {
        uint index = 0;
        if (network.radio_candidates.length == 0) {
            return requested_index == 0 && is_selectable_candidate (network) ? network : null;
        }

        foreach (var candidate in network.radio_candidates) {
            if (!is_selectable_candidate (candidate)) {
                continue;
            }
            if (index == requested_index) {
                return candidate;
            }
            index++;
        }
        return null;
    }

    private WifiNetwork selected_candidate (Gtk.ListBoxRow row, WifiNetwork network) {
        string? selected_device_path = (string?) row.get_data<string> (SELECTED_WIFI_DEVICE_PATH);
        if (selected_device_path != null && selected_device_path != "") {
            var selected = network.candidate_for_device (selected_device_path);
            if (selected != null && is_selectable_candidate (selected)) {
                return selected;
            }
        }

        var preferred = selectable_candidate_at (network, 0);
        return preferred != null ? preferred : network;
    }

    private bool candidate_has_saved_profile (WifiNetwork candidate) {
        return candidate.saved && candidate.saved_connection_uuid.strip () != "";
    }

    private void close_password_prompt_for_saved_candidate (
        WifiNetwork candidate,
        Gtk.Revealer prompt_revealer,
        Gtk.Entry prompt_entry,
        IMainWindowWifiRowActionHandler action_handler
    ) {
        if (candidate_has_saved_profile (candidate)
            && prompt_revealer.get_reveal_child ()) {
            action_handler.hide_password_prompt (prompt_revealer, prompt_entry, null);
        }
    }

    private string candidate_label (WifiNetwork candidate) {
        string device_label = candidate.device_name.strip () != ""
            ? candidate.device_name.strip ()
            : _("Wi-Fi device");
        string state_label;
        if (candidate.connected) {
            state_label = _("Connected here");
        } else if (candidate.device_is_connecting) {
            state_label = _("Connecting");
        } else if (candidate.device_is_connected) {
            string connection = candidate.device_connection.strip ();
            state_label = connection != "" ? connection : _("Connected");
        } else {
            state_label = _("Available");
        }
        return _("%s · %s · %u%%").printf (device_label, state_label, candidate.signal);
    }

    private void sync_radio_dropdown (
        Gtk.ListBoxRow row,
        WifiNetwork network,
        HyprNetworkManager.UI.Widgets.TrackedDropDown dropdown,
        Gtk.StringList model
    ) {
        string? previous_device_path = (string?) row.get_data<string> (SELECTED_WIFI_DEVICE_PATH);
        string[] labels = {};
        uint selected_index = 0;
        uint index = 0;
        bool found_previous = false;

        if (network.radio_candidates.length == 0) {
            if (is_selectable_candidate (network)) {
                labels += candidate_label (network);
            }
        } else {
            foreach (var candidate in network.radio_candidates) {
                if (!is_selectable_candidate (candidate)) {
                    continue;
                }
                labels += candidate_label (candidate);
                if (previous_device_path != null
                    && candidate.device_path == previous_device_path) {
                    selected_index = index;
                    found_previous = true;
                }
                index++;
            }
        }

        row.set_data<bool> (UPDATING_RADIO_DROPDOWN, true);
        model.splice (0, model.get_n_items (), labels);
        if (labels.length > 0) {
            dropdown.set_selected (found_previous ? selected_index : 0);
            var selected = selectable_candidate_at (
                network,
                found_previous ? selected_index : 0
            );
            if (selected != null) {
                row.set_data<string> (SELECTED_WIFI_DEVICE_PATH, selected.device_path.dup ());
            }
        }
        dropdown.set_visible (labels.length > 1);
        row.set_data<bool> (UPDATING_RADIO_DROPDOWN, false);
    }

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
        bool is_secured,
        Gtk.Entry? identity_entry = null
    ) {
        bool has_hidden_ssid = !requires_hidden_ssid || hidden_ssid_entry.get_text ().strip () != "";
        bool has_valid_password = !is_secured
            || HiddenWifiSecurityModeUtils.is_password_valid (prompt_entry.get_text ())
            || (identity_entry != null && prompt_entry.get_text ().strip () != "");
        bool has_valid_identity = identity_entry == null || identity_entry.get_text ().strip () != "";
        prompt_connect.set_sensitive (has_hidden_ssid && has_valid_password && has_valid_identity);
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

        var lock_icon = MainWindowIconResources.create_secure_lock_icon ();
        lock_icon.add_css_class (MainWindowCssClasses.ICON_SIZE_14);
        lock_icon.add_css_class (MainWindowCssClasses.ICON_SIZE);
        lock_icon.add_css_class (MainWindowCssClasses.LOCK_ICON);
        lock_icon.set_visible (net.is_secured);
        ssid_row.append (lock_icon);
        row.set_data<Gtk.Image> ("lock-icon", lock_icon);

        var connected_indicator = new Gtk.Label (_("• Connected"));
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
            return _("Saved network");
        }

        string bssid_text = MainWindowHelpers.safe_text (net.bssid);
        string subtitle = "%s (%u%%)".printf (WifiSignalLevels.get_label (net.signal), net.signal);
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
        details_btn.add_css_class (MainWindowCssClasses.BUTTON);
        details_btn.add_css_class (MainWindowCssClasses.ACTION);
        details_btn.add_css_class (MainWindowCssClasses.ROW_ICON_ACTION);
        details_btn.add_css_class (MainWindowCssClasses.DETAILS_OPEN_BUTTON);
        details_btn.set_valign (Gtk.Align.CENTER);
        details_btn.set_tooltip_text (_("Details"));
        var details_icon = new Gtk.Image.from_icon_name ("document-properties-symbolic");
        details_icon.add_css_class (MainWindowCssClasses.DETAILS_BUTTON_ICON);
        details_icon.add_css_class (MainWindowCssClasses.DETAILS_OPEN_ICON);
        details_btn.set_child (details_icon);
        details_btn.clicked.connect (() => {
            var latest_net = row.get_data<WifiNetwork> ("wifi-network");
            if (latest_net == null) {
                latest_net = net;
            }
            action_handler.open_details (selected_candidate (row, latest_net));
        });

        var forget = new Gtk.Button.with_label (_("Forget"));
        forget.add_css_class (MainWindowCssClasses.BUTTON);
        forget.add_css_class (MainWindowCssClasses.ACTION);
        forget.add_css_class (MainWindowCssClasses.ROW_ACTION);
        forget.add_css_class (MainWindowCssClasses.ACTION_DESTRUCTIVE);
        forget.set_valign (Gtk.Align.CENTER);
        forget.clicked.connect (() => {
            // Read the latest network from the row so a Forget issued after a
            // refresh targets the currently-bound connection UUID instead of the
            // (possibly already deleted) network captured when the row was built.
            var latest_net = row.get_data<WifiNetwork> ("wifi-network");
            if (latest_net == null) {
                latest_net = net;
            }
            action_handler.forget_saved_network (selected_candidate (row, latest_net));
        });
        forget.set_visible (has_resolvable_saved_profile);
        action_buttons.append (forget);
        row.set_data<Gtk.Button> ("forget-button", forget);

        var radio_model = new Gtk.StringList (null);
        var retained_radio_model = radio_model;
        var radio_dropdown = action_handler.create_radio_dropdown ((owned) radio_model);
        radio_dropdown.add_css_class (MainWindowCssClasses.EDIT_DROPDOWN);
        sync_radio_dropdown (row, net, radio_dropdown, retained_radio_model);
        action_buttons.prepend (radio_dropdown);
        row.set_data<HyprNetworkManager.UI.Widgets.TrackedDropDown> (
            RADIO_DROPDOWN,
            radio_dropdown
        );
        row.set_data<Gtk.StringList> (RADIO_DROPDOWN_MODEL, retained_radio_model);

        var action = new Gtk.Button ();
        action.add_css_class (MainWindowCssClasses.BUTTON);
        action.add_css_class (MainWindowCssClasses.ACTION);
        action.add_css_class (MainWindowCssClasses.ROW_ACTION);
        action.set_valign (Gtk.Align.CENTER);
        var initial_target = selected_candidate (row, net);
        update_action_button (action, initial_target, is_connecting);

        radio_dropdown.notify_selected.connect (() => {
            if (row.get_data<bool> (UPDATING_RADIO_DROPDOWN)) {
                return;
            }

            var latest_network = row.get_data<WifiNetwork> ("wifi-network");
            if (latest_network == null) {
                latest_network = net;
            }
            var selected = selectable_candidate_at (latest_network, radio_dropdown.get_selected ());
            if (selected == null) {
                return;
            }
            row.set_data<string> (SELECTED_WIFI_DEVICE_PATH, selected.device_path.dup ());
            close_password_prompt_for_saved_candidate (
                selected,
                prompt_revealer,
                prompt_entry,
                action_handler
            );
            sync_selected_candidate_controls (
                row,
                latest_network,
                action,
                auto_connect,
                forget,
                row.get_data<bool> (WIFI_IS_CONNECTING)
            );
        });

        action.clicked.connect (() => {
            var current_state = (WifiActionState) action.get_data<int> (WIFI_ACTION_STATE);
            if (current_state == WifiActionState.CONNECTING) return;

            var latest_network = row.get_data<WifiNetwork> ("wifi-network");
            if (latest_network == null) {
                latest_network = net;
            }
            var latest_net = selected_candidate (row, latest_network);

            if (current_state == WifiActionState.DISCONNECT) {
                action_handler.disconnect_network (latest_net);
                return;
            }

            if (!candidate_has_saved_profile (latest_net)
                && (latest_net.is_secured || latest_net.is_hidden)) {
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

    private void update_action_button (
        Gtk.Button action,
        WifiNetwork target,
        bool is_connecting
    ) {
        bool is_connected_now = target.connected;
        bool replaces_connection = !is_connected_now && target.device_is_connected;
        WifiActionState state = is_connecting
            ? WifiActionState.CONNECTING
            : (is_connected_now ? WifiActionState.DISCONNECT : WifiActionState.CONNECT);
        action.set_data<int> (WIFI_ACTION_STATE, (int) state);

        string action_label;
        switch (state) {
        case WifiActionState.CONNECTING:
            action_label = _("Connecting…");
            break;
        case WifiActionState.DISCONNECT:
            action_label = _("Disconnect");
            break;
        case WifiActionState.CONNECT:
        default:
            action_label = _("Connect");
            break;
        }
        action.set_label (action_label);
        action.set_sensitive (
            state != WifiActionState.CONNECTING
            && is_selectable_candidate (target)
            && !target.device_is_connecting
        );

        if (replaces_connection) {
            string connection = target.device_connection.strip ();
            action.set_tooltip_text (connection != ""
                ? _("This will disconnect %s on %s.").printf (connection, target.device_name)
                : _("This will replace the current connection on %s.").printf (target.device_name));
        } else {
            action.set_tooltip_text (null);
        }

        action.remove_css_class (MainWindowCssClasses.ACTION_CONNECT);
        action.remove_css_class (MainWindowCssClasses.ACTION_DISCONNECT);
        if (state == WifiActionState.CONNECT) {
            action.add_css_class (MainWindowCssClasses.ACTION_CONNECT);
        } else if (state == WifiActionState.DISCONNECT) {
            action.add_css_class (MainWindowCssClasses.ACTION_DISCONNECT);
        }
    }

    private void sync_selected_candidate_controls (
        Gtk.ListBoxRow row,
        WifiNetwork network,
        Gtk.Button action,
        Gtk.CheckButton auto_connect,
        Gtk.Button forget,
        bool is_connecting
    ) {
        var target = selected_candidate (row, network);
        row.set_data<bool> (UPDATING_AUTOCONNECT, true);
        auto_connect.set_active (target.autoconnect);
        row.set_data<bool> (UPDATING_AUTOCONNECT, false);
        auto_connect.set_sensitive (!is_connecting);

        forget.set_visible (candidate_has_saved_profile (target));
        update_action_button (action, target, is_connecting);
    }

    private Gtk.Revealer build_password_prompt (
        WifiNetwork net,
        bool requires_hidden_ssid,
        IMainWindowWifiRowActionHandler action_handler,
        Gtk.CheckButton auto_connect,
        Gtk.ListBoxRow row,
        out Gtk.Entry prompt_entry,
        out Gtk.Entry hidden_ssid_entry
    ) {
        bool is_enterprise = net.security != null && net.security.is_enterprise;

        var prompt_label = new Gtk.Label (_("Password for %s").printf (net.ssid));
        prompt_label.set_xalign (0.0f);
        prompt_label.set_hexpand (true);
        prompt_label.add_css_class (MainWindowCssClasses.INLINE_PASSWORD_LABEL);
        prompt_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        prompt_label.set_visible (net.is_secured);

        var hidden_ssid_label = new Gtk.Label (_("SSID"));
        hidden_ssid_label.set_xalign (0.0f);
        hidden_ssid_label.set_hexpand (true);
        hidden_ssid_label.add_css_class (MainWindowCssClasses.INLINE_PASSWORD_LABEL);
        hidden_ssid_label.add_css_class (MainWindowCssClasses.FORM_LABEL);

        hidden_ssid_entry = new Gtk.Entry ();
        hidden_ssid_entry.set_hexpand (true);
        hidden_ssid_entry.set_placeholder_text (_("Hidden network name"));
        hidden_ssid_entry.add_css_class (MainWindowCssClasses.INLINE_SSID_ENTRY);
        hidden_ssid_entry.add_css_class (MainWindowCssClasses.INPUT);
        hidden_ssid_entry.add_css_class (MainWindowCssClasses.INLINE_PASSWORD_ENTRY);
        hidden_ssid_entry.add_css_class (MainWindowCssClasses.PASSWORD_ENTRY);
        hidden_ssid_label.set_visible (requires_hidden_ssid);
        hidden_ssid_entry.set_visible (requires_hidden_ssid);

        var identity_label = new Gtk.Label (_("Identity"));
        identity_label.set_xalign (0.0f);
        identity_label.set_hexpand (true);
        identity_label.add_css_class (MainWindowCssClasses.INLINE_PASSWORD_LABEL);
        identity_label.add_css_class (MainWindowCssClasses.FORM_LABEL);
        identity_label.set_visible (is_enterprise);

        var identity_entry = new Gtk.Entry ();
        identity_entry.set_hexpand (true);
        identity_entry.set_placeholder_text (_("Username / Email"));
        identity_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
        identity_entry.add_css_class (MainWindowCssClasses.INPUT);
        identity_entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_CONTROL);
        identity_entry.set_visible (is_enterprise);

        prompt_entry = new Gtk.Entry ();
        prompt_entry.set_hexpand (true);
        prompt_entry.set_visibility (false);
        prompt_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        prompt_entry.set_placeholder_text (
            _("Wi-Fi password (min %d chars)").printf (HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH)
        );
        prompt_entry.add_css_class (MainWindowCssClasses.INLINE_PASSWORD_ENTRY);
        prompt_entry.add_css_class (MainWindowCssClasses.INPUT);
        prompt_entry.add_css_class (MainWindowCssClasses.PASSWORD_ENTRY);
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

        var prompt_cancel = new Gtk.Button.with_label (_("Cancel"));
        prompt_cancel.add_css_class (MainWindowCssClasses.BUTTON);
        prompt_cancel.add_css_class (MainWindowCssClasses.INLINE_PASSWORD_CANCEL);

        var prompt_connect = new Gtk.Button.with_label (_("Connect"));
        prompt_connect.add_css_class (MainWindowCssClasses.BUTTON);
        prompt_connect.add_css_class (MainWindowCssClasses.INLINE_PASSWORD_CONNECT);
        prompt_connect.add_css_class (MainWindowCssClasses.SUGGESTED_ACTION);
        prompt_connect.set_sensitive (false);

        var local_prompt_connect = prompt_connect;
        var local_hidden_ssid_entry = hidden_ssid_entry;
        var local_prompt_entry = prompt_entry;
        var local_identity_entry = is_enterprise ? identity_entry : null;

        prompt_entry.changed.connect (() => {
            sync_prompt_connect_button_sensitivity (
                local_prompt_connect,
                local_hidden_ssid_entry,
                local_prompt_entry,
                requires_hidden_ssid,
                net.is_secured,
                local_identity_entry
            );
        });
        hidden_ssid_entry.changed.connect (() => {
            sync_prompt_connect_button_sensitivity (
                local_prompt_connect,
                local_hidden_ssid_entry,
                local_prompt_entry,
                requires_hidden_ssid,
                net.is_secured,
                local_identity_entry
            );
        });
        if (is_enterprise) {
            identity_entry.changed.connect (() => {
                sync_prompt_connect_button_sensitivity (
                    local_prompt_connect,
                    local_hidden_ssid_entry,
                    local_prompt_entry,
                    requires_hidden_ssid,
                    net.is_secured,
                    local_identity_entry
                );
            });
            identity_entry.activate.connect (() => {
                local_prompt_entry.grab_focus ();
            });
        }
        sync_prompt_connect_button_sensitivity (
            prompt_connect,
            hidden_ssid_entry,
            prompt_entry,
            requires_hidden_ssid,
            net.is_secured,
            is_enterprise ? identity_entry : null
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
        prompt_inner.append (identity_label);
        prompt_inner.append (identity_entry);
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
            if (local_identity_entry != null) {
                local_identity_entry.set_text ("");
            }
            action_handler.hide_password_prompt (local_prompt_revealer, local_prompt_entry, null);
        });

        prompt_connect.clicked.connect (() => {
            if (!local_prompt_connect.get_sensitive ()) {
                return;
            }
            string payload;
            if (is_enterprise) {
                payload = local_identity_entry.get_text ().strip () + "\x1f" + local_prompt_entry.get_text ();
            } else {
                payload = local_prompt_entry.get_text ();
            }

            var latest_network = row.get_data<WifiNetwork> ("wifi-network");
            if (latest_network == null) {
                latest_network = net;
            }
            var connect_target = selected_candidate (row, latest_network);
            action_handler.hide_password_prompt (local_prompt_revealer, local_prompt_entry, payload);
            action_handler.connect_network (
                connect_target,
                connect_target.is_secured ? payload : null,
                requires_hidden_ssid ? local_hidden_ssid_entry.get_text ().strip () : null,
                auto_connect.get_active ()
            );
            local_hidden_ssid_entry.set_text ("");
            if (local_identity_entry != null) {
                local_identity_entry.set_text ("");
            }
        });

        prompt_entry.activate.connect (() => {
            if (!local_prompt_connect.get_sensitive ()) {
                return;
            }
            string payload;
            if (is_enterprise) {
                payload = local_identity_entry.get_text ().strip () + "\x1f" + local_prompt_entry.get_text ();
            } else {
                payload = local_prompt_entry.get_text ();
            }

            var latest_network = row.get_data<WifiNetwork> ("wifi-network");
            if (latest_network == null) {
                latest_network = net;
            }
            var connect_target = selected_candidate (row, latest_network);
            action_handler.hide_password_prompt (local_prompt_revealer, local_prompt_entry, payload);
            action_handler.connect_network (
                connect_target,
                connect_target.is_secured ? payload : null,
                requires_hidden_ssid ? local_hidden_ssid_entry.get_text ().strip () : null,
                auto_connect.get_active ()
            );
            local_hidden_ssid_entry.set_text ("");
            if (local_identity_entry != null) {
                local_identity_entry.set_text ("");
            }
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
            var latest_network = row.get_data<WifiNetwork> ("wifi-network");
            if (latest_network == null) {
                latest_network = net;
            }
            var connect_target = selected_candidate (row, latest_network);
            action_handler.connect_network (
                connect_target,
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
        string signal_icon_name,
        IMainWindowWifiRowActionHandler action_handler
    ) {
        row.set_data<WifiNetwork> ("wifi-network", net);
        row.set_data<bool> (WIFI_IS_CONNECTING, is_connecting);

        if (is_connected_now) {
            row.add_css_class (MainWindowCssClasses.CONNECTED);
        } else {
            row.remove_css_class (MainWindowCssClasses.CONNECTED);
        }

        var signal_icon = row.get_data<Gtk.Image> ("signal-icon");
        if (signal_icon != null) {
            signal_icon.set_from_icon_name (signal_icon_name);
        }

        var lock_icon = row.get_data<Gtk.Image> ("lock-icon");
        if (lock_icon != null) {
            lock_icon.set_visible (net.is_secured);
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

        var radio_dropdown = row.get_data<HyprNetworkManager.UI.Widgets.TrackedDropDown> (RADIO_DROPDOWN);
        var radio_model = row.get_data<Gtk.StringList> (RADIO_DROPDOWN_MODEL);
        if (radio_dropdown != null && radio_model != null) {
            sync_radio_dropdown (row, net, radio_dropdown, radio_model);
        }

        var prompt_revealer = row.get_data<Gtk.Revealer> (PASSWORD_PROMPT_REVEALER);
        var prompt_entry = row.get_data<Gtk.Entry> (PASSWORD_PROMPT_ENTRY);
        if (prompt_revealer != null && prompt_entry != null) {
            close_password_prompt_for_saved_candidate (
                selected_candidate (row, net),
                prompt_revealer,
                prompt_entry,
                action_handler
            );
        }

        var auto_connect = row.get_data<Gtk.CheckButton> ("auto-connect-check");
        var forget = row.get_data<Gtk.Button> ("forget-button");
        var action = row.get_data<Gtk.Button> ("action-button");
        if (auto_connect != null && forget != null && action != null) {
            sync_selected_candidate_controls (
                row,
                net,
                action,
                auto_connect,
                forget,
                is_connecting
            );
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
        row.set_data<bool> (WIFI_IS_CONNECTING, is_connecting);
        row.add_css_class (MainWindowCssClasses.ROW);
        row.add_css_class (MainWindowCssClasses.WIFI_ROW);
        if (is_connected_now) {
            row.add_css_class (MainWindowCssClasses.CONNECTED);
        }

        bool has_resolvable_saved_profile = candidate_has_saved_profile (net);
        bool requires_hidden_ssid = net.is_hidden;

        var row_root = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
        row_root.add_css_class (MainWindowCssClasses.ROW_ROOT);

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
        content.add_css_class (MainWindowCssClasses.ROW_CONTENT);

        var signal_icon = new Gtk.Image.from_icon_name (signal_icon_name);
        signal_icon.add_css_class (MainWindowCssClasses.ICON_SIZE_16);
        signal_icon.add_css_class (MainWindowCssClasses.ICON_SIZE);
        signal_icon.add_css_class (MainWindowCssClasses.WIFI_ICON);
        signal_icon.add_css_class (MainWindowCssClasses.SIGNAL_ICON);
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

        var auto_connect = new Gtk.CheckButton.with_label (_("Connect automatically"));
        auto_connect.add_css_class (MainWindowCssClasses.CHECKBOX);
        auto_connect.set_active (net.autoconnect);
        auto_connect.set_sensitive (!is_connecting);
        auto_connect.set_hexpand (true);
        auto_connect.set_halign (Gtk.Align.START);
        auto_connect.toggled.connect (() => {
            if (row.get_data<bool> (UPDATING_AUTOCONNECT)) {
                return;
            }
            var latest_net = row.get_data<WifiNetwork> ("wifi-network");
            var target = selected_candidate (row, latest_net);
            bool latest_has_resolvable_saved_profile = candidate_has_saved_profile (target);
            if (latest_has_resolvable_saved_profile) {
                action_handler.set_auto_connect (target, auto_connect.get_active ());
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
            row,
            out prompt_entry,
            out hidden_ssid_entry
        );
        row.set_data<Gtk.Revealer> (PASSWORD_PROMPT_REVEALER, prompt_revealer);
        row.set_data<Gtk.Entry> (PASSWORD_PROMPT_ENTRY, prompt_entry);

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
