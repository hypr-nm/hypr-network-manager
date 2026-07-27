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

using GLib;
using Gtk;

namespace MainWindowCssClassResolver {
    // Class application is deterministic: every class in a hierarchy is applied
    // and GTK's own cascade (specificity then source order) decides which rule
    // wins. There is no runtime CSS parsing or specificity re-implementation.

    public static void initialize (string css_content, string base_css_path, bool force_reload = false) {
    }

    public static void add_hook_and_best_class (
        Gtk.Widget widget,
        string hook_class,
        string[] class_hierarchy
    ) {
        add_class_if_absent (widget, hook_class);
        add_best_class (widget, class_hierarchy);
    }

    public static void add_best_class (Gtk.Widget widget, string[] class_hierarchy) {
        foreach (string css_class in class_hierarchy) {
            add_class_if_absent (widget, css_class);
        }
    }

    public static string resolve_best_class (string[] class_hierarchy) {
        for (int i = class_hierarchy.length - 1; i >= 0; i--) {
            string normalized = class_hierarchy[i].strip ();
            if (normalized != "") {
                return normalized;
            }
        }
        return "";
    }

    private static void add_class_if_absent (Gtk.Widget widget, string css_class) {
        string normalized = css_class.strip ();
        if (normalized != "" && !widget.has_css_class (normalized)) {
            widget.add_css_class (normalized);
        }
    }
}
