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
using Gtk;
using GtkLayerShell;
using HyprNetworkManager.Models;

namespace HyprNetworkManager.UI.Utils {
    public class MainWindowLayerShellConfigurator : Object {
        public static bool configure (Gtk.Window window, WindowConfigContext config) {
            GtkLayerShell.Layer layer_mode = parse_layer_mode (config.shell_layer);

            if (!GtkLayerShell.is_supported ()) {
                log_warn (
                    "gui",
                    "layer_shell_init: unsupported in current session; outcome=using regular window"
                );
                return false;
            }

            GtkLayerShell.init_for_window (window);
            if (!GtkLayerShell.is_layer_window (window)) {
                log_error (
                    "gui",
                    "layer_shell_init: failed to create layer surface; outcome=using regular window"
                );
                return false;
            }

            GtkLayerShell.set_namespace (window, "hypr-network-manager");
            GtkLayerShell.set_layer (window, layer_mode);

            GtkLayerShell.set_anchor (window, GtkLayerShell.Edge.TOP, config.anchor_top);
            GtkLayerShell.set_anchor (window, GtkLayerShell.Edge.RIGHT, config.anchor_right);
            GtkLayerShell.set_anchor (window, GtkLayerShell.Edge.BOTTOM, config.anchor_bottom);
            GtkLayerShell.set_anchor (window, GtkLayerShell.Edge.LEFT, config.anchor_left);
            GtkLayerShell.set_margin (window, GtkLayerShell.Edge.TOP, config.shell_margin_top);
            GtkLayerShell.set_margin (window, GtkLayerShell.Edge.RIGHT, config.shell_margin_right);
            GtkLayerShell.set_margin (window, GtkLayerShell.Edge.BOTTOM, config.shell_margin_bottom);
            GtkLayerShell.set_margin (window, GtkLayerShell.Edge.LEFT, config.shell_margin_left);

            GtkLayerShell.set_keyboard_mode (window, GtkLayerShell.KeyboardMode.EXCLUSIVE);
            GtkLayerShell.auto_exclusive_zone_enable (window);
            return true;
        }

        public static GtkLayerShell.Layer parse_layer_mode (string value) {
            switch (value.strip ().down ()) {
            case "top":
                return GtkLayerShell.Layer.TOP;
            case "bottom":
                return GtkLayerShell.Layer.BOTTOM;
            case "background":
                return GtkLayerShell.Layer.BACKGROUND;
            case "overlay":
            default:
                return GtkLayerShell.Layer.OVERLAY;
            }
        }

        public static void configure_fallback (Gtk.Window window) {
            log_warn (
                "gui",
                "layer_shell_fallback: enabled; outcome=placement/exclusive-zone constraints disabled"
            );

            // Keep the fallback window above most windows to mimic popup behavior.
            window.set_modal (true);
        }
    }
}
