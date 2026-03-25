public class MainWindowWifiRowBuilder : Object {
    public static Gtk.ListBoxRow build_row(
        WifiNetwork net,
        bool is_connected_now,
        bool is_connecting,
        bool show_frequency,
        bool show_band,
        bool show_bssid,
        string signal_icon_name,
        MainWindowWifiNetworkCallback on_open_details,
        MainWindowWifiNetworkCallback on_forget_saved_network,
        MainWindowWifiNetworkCallback on_disconnect,
        MainWindowWifiNetworkPasswordCallback on_connect,
        MainWindowPasswordPromptShowCallback on_show_password_prompt,
        MainWindowPasswordPromptHideCallback on_hide_password_prompt
    ) {
        var row = new Gtk.ListBoxRow();
        row.add_css_class("nm-wifi-row");
        if (is_connected_now) {
            row.add_css_class("connected");
        }

        var row_root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        row_root.add_css_class("nm-row-root");

        var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
        content.add_css_class("nm-row-content");

        var signal_icon = new Gtk.Image.from_icon_name(signal_icon_name);
        signal_icon.set_pixel_size(16);
        signal_icon.add_css_class("nm-signal-icon");
        signal_icon.add_css_class("nm-wifi-icon");
        if (net.is_secured) {
            signal_icon.add_css_class("nm-signal-icon-secured");
        }
        content.append(signal_icon);

        var info = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
        info.set_hexpand(true);
        info.add_css_class("nm-row-info");
        var ssid_lbl = new Gtk.Label(net.ssid);
        ssid_lbl.set_xalign(0.0f);
        ssid_lbl.add_css_class("nm-ssid-label");
        info.append(ssid_lbl);

        string subtitle = "%s (%u%%)".printf(net.signal_label, net.signal);
        if (show_frequency && net.frequency_mhz > 0) {
            subtitle += " - %u MHz".printf(net.frequency_mhz);
        }
        if (show_band && net.frequency_mhz > 0) {
            string band = MainWindowHelpers.get_band_label(net.frequency_mhz);
            if (band != "") {
                subtitle += " - %s".printf(band);
            }
        }
        if (show_bssid && net.bssid != "") {
            subtitle += " - %s".printf(net.bssid);
        }

        var sub = new Gtk.Label(subtitle);
        sub.set_xalign(0.0f);
        sub.add_css_class("nm-sub-label");
        info.append(sub);
        content.append(info);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        actions.add_css_class("nm-row-actions");
        actions.set_valign(Gtk.Align.CENTER);

        var details_btn = new Gtk.Button();
        details_btn.add_css_class("nm-button");
        details_btn.add_css_class("nm-menu-button");
        details_btn.add_css_class("nm-details-open-button");
        details_btn.add_css_class("nm-row-icon-button");
        details_btn.set_valign(Gtk.Align.CENTER);
        details_btn.set_tooltip_text("Details");
        var details_icon = new Gtk.Image.from_icon_name("document-properties-symbolic");
        details_icon.add_css_class("nm-details-open-icon");
        details_icon.add_css_class("nm-details-button-icon");
        details_btn.set_child(details_icon);
        details_btn.clicked.connect(() => {
            on_open_details(net);
        });

        if (net.saved) {
            var forget = new Gtk.Button.with_label("Forget");
            forget.add_css_class("nm-button");
            forget.add_css_class("nm-action-button");
            forget.add_css_class("nm-row-action-button");
            forget.set_valign(Gtk.Align.CENTER);
            forget.clicked.connect(() => {
                on_forget_saved_network(net);
            });
            actions.append(forget);
        }

        string action_label = is_connecting ? "Connecting..." : (is_connected_now ? "Disconnect" : "Connect");
        var action = new Gtk.Button.with_label(action_label);
        action.add_css_class("nm-button");
        action.add_css_class(is_connected_now && !is_connecting ? "nm-disconnect-button" : "nm-connect-button");
        action.add_css_class("nm-row-action-button");
        action.set_valign(Gtk.Align.CENTER);
        action.set_sensitive(!is_connecting);

        var prompt_label = new Gtk.Label("Password for %s".printf(net.ssid));
        prompt_label.set_xalign(0.0f);
        prompt_label.set_hexpand(true);
        prompt_label.add_css_class("nm-form-label");
        prompt_label.add_css_class("nm-inline-password-label");

        var prompt_entry = new Gtk.Entry();
        prompt_entry.set_hexpand(true);
        prompt_entry.set_visibility(false);
        prompt_entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
        prompt_entry.set_placeholder_text("Wi-Fi password");
        prompt_entry.add_css_class("nm-password-entry");
        prompt_entry.add_css_class("nm-inline-password-entry");

        var prompt_cancel = new Gtk.Button.with_label("Cancel");
        prompt_cancel.add_css_class("nm-button");
        prompt_cancel.add_css_class("nm-inline-password-cancel");

        var prompt_connect = new Gtk.Button.with_label("Connect");
        prompt_connect.add_css_class("nm-button");
        prompt_connect.add_css_class("suggested-action");
        prompt_connect.add_css_class("nm-inline-password-connect");

        var prompt_actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        prompt_actions.add_css_class("nm-inline-password-actions");
        prompt_actions.set_halign(Gtk.Align.END);
        prompt_actions.append(prompt_cancel);
        prompt_actions.append(prompt_connect);

        var prompt_inner = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        prompt_inner.add_css_class("nm-inline-password");
        prompt_inner.append(prompt_label);
        prompt_inner.append(prompt_entry);
        prompt_inner.append(prompt_actions);

        var prompt_revealer = new Gtk.Revealer();
        prompt_revealer.add_css_class("nm-inline-password-revealer");
        prompt_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN);
        prompt_revealer.set_transition_duration(220);
        prompt_revealer.set_reveal_child(false);
        prompt_revealer.set_child(prompt_inner);

        prompt_cancel.clicked.connect(() => {
            on_hide_password_prompt(prompt_revealer, prompt_entry, null);
        });

        prompt_connect.clicked.connect(() => {
            on_hide_password_prompt(prompt_revealer, prompt_entry, prompt_entry.get_text());
            on_connect(net, prompt_entry.get_text());
        });

        prompt_entry.activate.connect(() => {
            on_hide_password_prompt(prompt_revealer, prompt_entry, prompt_entry.get_text());
            on_connect(net, prompt_entry.get_text());
        });

        action.clicked.connect(() => {
            if (is_connected_now) {
                on_disconnect(net);
                return;
            }

            if (net.is_secured && !net.saved) {
                on_show_password_prompt(prompt_revealer, prompt_entry);
            } else {
                on_connect(net, null);
            }
        });
        actions.append(action);
        actions.append(details_btn);
        content.append(actions);

        row_root.append(content);
        row_root.append(prompt_revealer);
        row.set_child(row_root);
        return row;
    }
}
