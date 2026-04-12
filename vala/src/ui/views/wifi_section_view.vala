// SPDX-License-Identifier: GPL-3.0-or-later
using GLib;
using Gtk;
using NetworkManagerRebuild.UI.Interfaces;
using NetworkManagerRebuild.Models;

namespace NetworkManagerRebuild.UI.Views {
    public class WifiSectionView : Object {
        public Gtk.Widget widget { get; private set; }
        public Gtk.Stack stack { get; private set; }
        public Gtk.ListBox listbox { get; private set; }
        public Gtk.Switch wifi_switch { get; private set; }

        private NetworkManagerClient nm;
        private MainWindowWifiController controller;
        private IWindowHost window_host;
        private WindowConfigContext config_context;

        private WifiNetwork? selected_wifi_network = null;
        private MainWindowWifiDetailsPage details_page;
        private MainWindowWifiEditPage edit_page;

        private Gtk.Entry add_ssid_entry;
        private Gtk.DropDown add_security_dropdown;
        private Gtk.Entry add_password_entry;

        public Gtk.Revealer? active_wifi_password_revealer { get; private set; }
        public Gtk.Entry? active_wifi_password_entry { get; private set; }
        public string? active_wifi_password_row_id { get; private set; }

        public signal void refresh_requested ();
        public signal void refresh_switch_states_requested ();
        
        private Gtk.Label status_label;
        private Gtk.Image status_icon;

        public WifiSectionView (
            NetworkManagerClient nm,
            MainWindowWifiController controller,
            IWindowHost window_host,
            WindowConfigContext config_context,
            Gtk.Label status_label,
            Gtk.Image status_icon
        ) {
            this.nm = nm;
            this.controller = controller;
            this.window_host = window_host;
            this.config_context = config_context;
            this.status_label = status_label;
            this.status_icon = status_icon;

            this.details_page = new MainWindowWifiDetailsPage ();
            this.edit_page = new MainWindowWifiEditPage ();

            wire_details_page_signals ();
            wire_edit_page_signals ();

            var add_page = build_add_page ();

            Gtk.Switch local_wifi_switch;
            Gtk.ListBox local_wifi_listbox;
            Gtk.Stack local_wifi_stack;

            var page = MainWindowWifiPageBuilder.build_page (
                out local_wifi_switch,
                out local_wifi_listbox,
                out local_wifi_stack,
                details_page,
                edit_page,
                add_page,
                () => {
                    refresh_requested ();
                },
                () => {
                    controller.open_add_network (
                        stack,
                        add_ssid_entry,
                        add_security_dropdown,
                        add_password_entry
                    );
                },
                () => {
                    on_wifi_switch_changed ();
                }
            );

            this.wifi_switch = local_wifi_switch;
            this.listbox = local_wifi_listbox;
            this.stack = local_wifi_stack;
            this.widget = page;
        }

        private void wire_details_page_signals () {
            details_page.back.connect (() => {
                selected_wifi_network = null;
                window_host.set_popup_text_input_mode (false);
                stack.set_visible_child_name ("list");
            });

            details_page.forget.connect (() => {
                if (selected_wifi_network == null) return;
                forget_wifi_network (selected_wifi_network, () => {
                    stack.set_visible_child_name ("list");
                });
            });

            details_page.edit.connect (() => {
                if (selected_wifi_network != null) {
                    open_wifi_edit (selected_wifi_network);
                }
            });
        }

        private void wire_edit_page_signals () {
            edit_page.back.connect (() => {
                window_host.set_popup_text_input_mode (false);
                if (selected_wifi_network != null) {
                    open_wifi_details (selected_wifi_network);
                } else {
                    stack.set_visible_child_name ("list");
                }
            });

            edit_page.apply.connect (() => {
                apply_wifi_edit (false);
            });

            edit_page.ok.connect (() => {
                apply_wifi_edit (true);
            });

            edit_page.sync_sensitivity.connect (sync_wifi_edit_gateway_dns_sensitivity);
        }

        private Gtk.Widget build_add_page () {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_ROW);
            page.add_css_class ("nm-page");
            page.add_css_class ("nm-page-shell-inset");
            MainWindowCssClassResolver.add_best_class (page, {"nm-page-shell-inset", "nm-page"});
            MainWindowCssClassResolver.add_hook_and_best_class (
                page,
                "nm-page-wifi-add",
                {"nm-page-network-edit", "nm-page"}
            );

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            var back_btn = MainWindowHelpers.build_back_button (() => {
                window_host.set_popup_text_input_mode (false);
                stack.set_visible_child_name ("list");
            });
            header.append (back_btn);

            var title = new Gtk.Label ("Add Hidden Network");
            title.set_xalign (0.0f);
            title.set_hexpand (true);
            title.add_css_class ("nm-section-title");
            header.append (title);
            page.append (header);

            var form = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_HEADER);
            MainWindowCssClassResolver.add_best_class (form, {"nm-edit-network-form", "nm-edit-form"});
            form.add_css_class ("nm-details-scroll-body-inset");

            var note = new Gtk.Label ("Manually add a hidden Wi-Fi network.");
            note.set_xalign (0.0f);
            note.set_wrap (true);
            MainWindowCssClassResolver.add_best_class (note, {"nm-edit-note", "nm-sub-label"});
            form.append (note);

            var ssid_label = new Gtk.Label ("SSID");
            ssid_label.set_xalign (0.0f);
            MainWindowCssClassResolver.add_best_class (ssid_label, {"nm-edit-field-label", "nm-form-label"});
            form.append (ssid_label);

            add_ssid_entry = new Gtk.Entry ();
            add_ssid_entry.set_placeholder_text ("Network name");
            MainWindowCssClassResolver.add_best_class (
                add_ssid_entry,
                {"nm-edit-field-entry", "nm-edit-field-control"}
            );
            form.append (add_ssid_entry);

            var security_label = new Gtk.Label ("Security");
            security_label.set_xalign (0.0f);
            MainWindowCssClassResolver.add_best_class (security_label, {"nm-edit-field-label", "nm-form-label"});
            form.append (security_label);

            var security_list = new Gtk.StringList (null);
            foreach (string label in HiddenWifiSecurityModeUtils.get_dropdown_labels ()) {
                security_list.append (label);
            }
            add_security_dropdown = new Gtk.DropDown (security_list, null);
            MainWindowCssClassResolver.add_best_class (
                add_security_dropdown,
                {"nm-edit-dropdown", "nm-edit-field-control"}
            );
            add_security_dropdown.set_selected (
                HiddenWifiSecurityModeUtils.to_dropdown_index (HiddenWifiSecurityMode.WPA_PSK)
            );

            var save_btn = new Gtk.Button.with_label ("Connect");
            save_btn.add_css_class ("nm-button");
            MainWindowCssClassResolver.add_best_class (save_btn, {"suggested-action", "nm-button"});

            add_security_dropdown.notify["selected"].connect (() => {
                controller.sync_add_network_sensitivity (
                    add_security_dropdown,
                    add_password_entry,
                    save_btn
                );
            });
            form.append (add_security_dropdown);

            var password_label = new Gtk.Label ("Password");
            password_label.set_xalign (0.0f);
            MainWindowCssClassResolver.add_best_class (
                password_label,
                {"nm-edit-field-label", "nm-form-label"}
            );
            form.append (password_label);

            add_password_entry = new Gtk.Entry ();
            add_password_entry.set_visibility (false);
            add_password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
            add_password_entry.set_placeholder_text (
                "Network password (min %d chars)".printf (HiddenWifiSecurityModeUtils.MIN_PASSWORD_LENGTH)
            );
            MainWindowCssClassResolver.add_best_class (
                add_password_entry,
                {"nm-edit-field-entry", "nm-edit-field-control", "nm-password-entry"}
            );
            add_password_entry.changed.connect (() => {
                controller.sync_add_network_sensitivity (
                    add_security_dropdown,
                    add_password_entry,
                    save_btn
                );
            });
            add_password_entry.activate.connect (() => {
                if (!save_btn.get_sensitive ()) {
                    return;
                }
                submit_add_hidden_network ();
            });
            form.append (add_password_entry);

            controller.sync_add_network_sensitivity (
                add_security_dropdown,
                add_password_entry,
                save_btn
            );

            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_HEADER);
            actions.add_css_class ("nm-edit-actions");

            save_btn.clicked.connect (submit_add_hidden_network);
            actions.append (save_btn);

            form.append (actions);

            page.append (form);
            return page;
        }

        private void submit_add_hidden_network () {
            controller.apply_add_network (
                nm,
                stack,
                add_ssid_entry,
                add_security_dropdown,
                add_password_entry
            );
        }

        private void sync_wifi_edit_gateway_dns_sensitivity () {
            if (edit_page == null) return;
            controller.sync_edit_gateway_dns_sensitivity (
                edit_page.ipv4_method_dropdown,
                edit_page.ipv4_gateway_entry,
                edit_page.ipv4_dns_entry,
                edit_page.dns_auto_switch,
                edit_page.ipv6_method_dropdown,
                edit_page.ipv6_gateway_entry,
                edit_page.ipv6_dns_entry,
                edit_page.ipv6_dns_auto_switch
            );
        }

        private void populate_wifi_details (WifiNetwork net) {
            controller.populate_details (
                nm,
                net,
                details_page
            );
        }

        private void open_wifi_details (WifiNetwork net) {
            controller.open_details (
                ref selected_wifi_network,
                net,
                stack,
                (wifi_net) => {
                    populate_wifi_details (wifi_net);
                }
            );
        }

        private void open_wifi_edit (WifiNetwork net) {
            controller.open_edit (
                ref selected_wifi_network,
                nm,
                net,
                edit_page,
                stack,
                sync_wifi_edit_gateway_dns_sensitivity
            );
        }

        private bool apply_wifi_edit (bool close_after_apply) {
            return controller.apply_edit (
                ref selected_wifi_network,
                nm,
                edit_page,
                close_after_apply,
                () => {
                    if (selected_wifi_network != null) {
                        open_wifi_details (selected_wifi_network);
                    }
                }
            );
        }

        private void forget_wifi_network (WifiNetwork net, MainWindowActionCallback? on_done = null) {
            controller.forget_wifi_network (
                nm,
                net
            );
            if (on_done != null) {
                on_done ();
            }
        }

        private void disconnect_wifi_network (WifiNetwork net) {
            controller.disconnect_wifi_network (
                nm,
                net
            );
        }

        private string resolve_wifi_row_icon_name (WifiNetwork net) {
            return MainWindowHelpers.resolve_wifi_row_icon_name (net);
        }

        private Gtk.ListBoxRow build_wifi_row (WifiNetwork net, NetworkStateContext state_context) {
            var nm_client = nm;
            var wifi_controller_ref = controller;
            uint pending_timeout_ms = config_context.pending_wifi_connect_timeout_ms;
            bool should_close_on_connect = config_context.close_on_connect;
            string net_key = net.network_key;
            bool is_connected_now = state_context.active_wifi_connections.contains (net_key);
            bool is_connecting = state_context.pending_wifi_connect.contains (net_key);

            return controller.build_row (
                net,
                is_connected_now,
                is_connecting,
                config_context.show_frequency,
                config_context.show_band,
                config_context.show_bssid,
                resolve_wifi_row_icon_name (net),
                (wifi_net) => {
                    open_wifi_details (wifi_net);
                },
                (wifi_net) => {
                    forget_wifi_network (wifi_net);
                },
                (wifi_net) => {
                    disconnect_wifi_network (wifi_net);
                },
                (wifi_net, password, hidden_ssid) => {
                    wifi_controller_ref.connect_with_optional_password (
                        nm_client,
                        wifi_net,
                        password,
                        hidden_ssid,
                        pending_timeout_ms,
                        should_close_on_connect,
                        () => {
                            refresh_requested ();
                        }
                    );
                },
                (wifi_net, enabled) => {
                    wifi_controller_ref.set_wifi_network_autoconnect (
                        nm_client,
                        wifi_net,
                        enabled,
                        () => {
                            refresh_requested ();
                        }
                    );
                },
                (revealer, entry) => {
                    active_wifi_password_row_id = get_wifi_row_id (net);
                    show_wifi_password_prompt (revealer, entry);
                },
                (revealer, entry, value) => {
                    hide_wifi_password_prompt (revealer, entry, value);
                }
            );
        }

        private string get_wifi_row_id (WifiNetwork net) {
            return "%s|%s".printf (net.device_path, net.ap_path);
        }

        public void perform_refresh (NetworkStateContext state_context) {
            bool has_active_prompt_open = active_wifi_password_revealer != null
                && active_wifi_password_revealer.get_reveal_child ();

            controller.refresh (
                nm,
                stack,
                listbox,
                status_label,
                status_icon,
                active_wifi_password_row_id,
                has_active_prompt_open,
                () => {
                    hide_active_wifi_password_prompt ();
                },
                () => {
                    refresh_switch_states_requested ();
                },
                (net) => {
                    return build_wifi_row (net, state_context);
                }
            );
        }

        private void on_wifi_switch_changed () {
            controller.on_wifi_switch_changed (
                nm,
                wifi_switch,
                () => {
                    refresh_switch_states_requested ();
                }
            );
        }

        private void show_wifi_password_prompt (Gtk.Revealer revealer, Gtk.Entry entry) {
            var rev = active_wifi_password_revealer;
            var ent = active_wifi_password_entry;
            controller.show_wifi_password_prompt (
                ref rev,
                ref ent,
                revealer,
                entry
            );
            active_wifi_password_revealer = rev;
            active_wifi_password_entry = ent;
        }

        private void hide_wifi_password_prompt (Gtk.Revealer revealer, Gtk.Entry entry, string? value) {
            var rev = active_wifi_password_revealer;
            var ent = active_wifi_password_entry;
            controller.hide_wifi_password_prompt (
                ref rev,
                ref ent,
                revealer,
                entry,
                value
            );
            active_wifi_password_revealer = rev;
            active_wifi_password_entry = ent;

            if (active_wifi_password_revealer == null) {
                active_wifi_password_row_id = null;
            }
        }

        public void hide_active_wifi_password_prompt () {
            var rev = active_wifi_password_revealer;
            var ent = active_wifi_password_entry;
            controller.hide_active_wifi_password_prompt (
                ref rev,
                ref ent
            );
            active_wifi_password_revealer = rev;
            active_wifi_password_entry = ent;
            active_wifi_password_row_id = null;
        }
    }
}
