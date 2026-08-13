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

private static string? config_fixture_path;

private static void test_load_default_config () {
    AppConfig config = AppConfig.load (config_fixture_path);

    assert (config.window_width == 480);
    assert (config.window_height == 680);
    assert (config.layer_shell_layer == LayerShellLayer.OVERLAY);
    assert (config.log_level == AppLogLevel.INFO);
    assert (config.anchor_top);
    assert (config.anchor_right);
    assert (!config.anchor_bottom);
    assert (!config.anchor_left);
    assert (config.margin_top == 8);
    assert (config.margin_right == 8);
    assert (config.margin_bottom == 8);
    assert (config.margin_left == 8);
    assert (config.scan_interval == 20);
    assert (config.pending_wifi_connect_timeout_ms == 15000);
    assert (!config.close_on_connect);
    assert (!config.show_bssid);
    assert (!config.show_frequency);
    assert (config.show_band);
}

private static int main (string[] args) {
    if (args.length != 2) {
        error ("Expected the configuration fixture path as the only argument");
    }
    config_fixture_path = args[1];

    Test.init (ref args);
    Test.add_func ("/config/load-default", test_load_default_config);
    return Test.run ();
}
