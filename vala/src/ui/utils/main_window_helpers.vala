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

namespace MainWindowHelpers {
    public Gtk.Button build_back_button () {
        var back_btn = new Gtk.Button ();
        back_btn.add_css_class (MainWindowCssClasses.NAV_BACK);
        MainWindowCssClassResolver.add_best_class (back_btn, {MainWindowCssClasses.NAV_BACK,
            MainWindowCssClasses.BUTTON});

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        var icon = new Gtk.Image.from_icon_name ("go-previous-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {MainWindowCssClasses.ICON_SIZE_14,
            MainWindowCssClasses.ICON_SIZE});
        MainWindowCssClassResolver.add_hook_and_best_class (icon, MainWindowCssClasses.BACK_ICON,
            {MainWindowCssClasses.ICON_SIZE});

        var label = new Gtk.Label (_("Back"));
        label.add_css_class (MainWindowCssClasses.BACK_LABEL);

        content.append (icon);
        content.append (label);
        back_btn.set_child (content);

        return back_btn;
    }

    public void sync_password_visibility_icon (Gtk.Entry entry) {
        bool reveal = entry.get_visibility ();
        MainWindowIconResources.set_password_visibility_icon (entry, reveal);
        entry.set_icon_tooltip_text (
            Gtk.EntryIconPosition.SECONDARY,
            reveal ? _("Hide password") : _("Show password")
        );
    }

    public void clear_listbox (Gtk.ListBox? listbox) {
        if (listbox == null) {
            return;
        }

        Gtk.Widget? child = listbox.get_first_child ();
        while (child != null) {
            Gtk.Widget? next = child.get_next_sibling ();
            listbox.remove (child);
            child = next;
        }
    }

    public void clear_box (Gtk.Box? box) {
        if (box == null) {
            return;
        }

        Gtk.Widget? child = box.get_first_child ();
        while (child != null) {
            Gtk.Widget? next = child.get_next_sibling ();
            box.remove (child);
            child = next;
        }
    }

    public static Gtk.Widget build_details_row (string? key, string? value) {
        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_INFO_GROUP);
        MainWindowCssClassResolver.add_best_class (row, {MainWindowCssClasses.DETAILS_ITEM,
            MainWindowCssClasses.DETAILS_ROW});

        string key_text = display_text_or_na (key);
        string value_text = display_text_or_na (value);

        var key_label = new Gtk.Label (key_text);
        key_label.set_xalign (0.0f);
        key_label.set_halign (Gtk.Align.START);
        key_label.set_valign (Gtk.Align.CENTER);
        key_label.set_hexpand (true);
        MainWindowCssClassResolver.add_best_class (key_label, {MainWindowCssClasses.DETAILS_ITEM_KEY,
            MainWindowCssClasses.DETAILS_KEY});

        var value_label = new Gtk.Label (value_text);
        value_label.set_xalign (1.0f);
        value_label.set_halign (Gtk.Align.END);
        value_label.set_valign (Gtk.Align.CENTER);
        value_label.set_wrap (true);
        value_label.set_max_width_chars (30);
        MainWindowCssClassResolver.add_best_class (
            value_label,
            {MainWindowCssClasses.DETAILS_ITEM_VALUE, MainWindowCssClasses.DETAILS_VALUE}
        );

        row.append (key_label);
        row.append (value_label);
        return row;
    }
public Gtk.Widget build_details_section (string title, out Gtk.ListBox rows_container) {
    var section = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_TOOLBAR);
    section.add_css_class (MainWindowCssClasses.DETAILS_SECTION);

    var heading = new Gtk.Label (title);
    heading.set_xalign (0.0f);
    heading.set_hexpand (true);
    heading.add_css_class (MainWindowCssClasses.DETAILS_GROUP_TITLE);
    section.append (heading);

    rows_container = new Gtk.ListBox ();
    rows_container.set_selection_mode (Gtk.SelectionMode.NONE);
    rows_container.add_css_class ("boxed-list");
    rows_container.add_css_class (MainWindowCssClasses.DETAILS_ROWS);
    section.append (rows_container);

    return section;
}
}
