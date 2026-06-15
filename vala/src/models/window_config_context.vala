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

namespace HyprNetworkManager.Models {

    /**
     * Context for application window configuration and display options.
     */
    public class WindowConfigContext : Object {
        public const int MIN_WINDOW_WIDTH = 480;
        public const int MIN_WINDOW_HEIGHT = 680;

        public int window_width { get; set; default = MIN_WINDOW_WIDTH; }
        public int window_height { get; set; default = MIN_WINDOW_HEIGHT; }
        public bool anchor_top { get; set; default = false; }
        public bool anchor_right { get; set; default = false; }
        public bool anchor_bottom { get; set; default = false; }
        public bool anchor_left { get; set; default = false; }

        public int shell_margin_top { get; set; default = 8; }
        public int shell_margin_right { get; set; default = 8; }
        public int shell_margin_bottom { get; set; default = 8; }
        public int shell_margin_left { get; set; default = 8; }
        public string shell_layer { get; set; default = "overlay"; }

        public uint refresh_interval_seconds { get; set; default = 30; }
        public uint pending_wifi_connect_timeout_ms { get; set; default = 45000; }
        public bool close_on_connect { get; set; default = false; }

        public bool show_bssid { get; set; default = false; }
        public bool show_frequency { get; set; default = false; }
        public bool show_band { get; set; default = false; }

        public WindowConfigContext.from_app_config (AppConfig config) {
            window_width = config.window_width >= MIN_WINDOW_WIDTH
                ? config.window_width
                : MIN_WINDOW_WIDTH;
            window_height = config.window_height >= MIN_WINDOW_HEIGHT
                ? config.window_height
                : MIN_WINDOW_HEIGHT;
            anchor_top = config.anchor_top;
            anchor_right = config.anchor_right;
            anchor_bottom = config.anchor_bottom;
            anchor_left = config.anchor_left;

            shell_margin_top = config.margin_top >= 0 ? config.margin_top : 0;
            shell_margin_right = config.margin_right >= 0 ? config.margin_right : 0;
            shell_margin_bottom = config.margin_bottom >= 0 ? config.margin_bottom : 0;
            shell_margin_left = config.margin_left >= 0 ? config.margin_left : 0;

            string parsed_layer = config.layer.strip ();
            shell_layer = parsed_layer != "" ? parsed_layer : "overlay";

            refresh_interval_seconds = (uint) (config.scan_interval > 0 ? config.scan_interval : 30);
            pending_wifi_connect_timeout_ms = (uint) (
                config.pending_wifi_connect_timeout_ms > 0 ? config.pending_wifi_connect_timeout_ms : 45000
            );
            close_on_connect = config.close_on_connect;

            show_bssid = config.show_bssid;
            show_frequency = config.show_frequency;
            show_band = config.show_band;
        }
    }
}
