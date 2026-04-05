using Gtk;

namespace MainWindowHelpers {
    public Gtk.Button build_back_button (MainWindowActionCallback on_back) {
        var back_btn = new Gtk.Button ();
        MainWindowCssClassResolver.add_best_class (back_btn, {"nm-nav-back", "nm-button"});

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        var icon = new Gtk.Image.from_icon_name ("go-previous-symbolic");
        MainWindowCssClassResolver.add_best_class (icon, {"nm-icon-size-14", "nm-icon-size"});
        MainWindowCssClassResolver.add_best_class (icon, {"nm-back-icon", "nm-icon-size"});

        var label = new Gtk.Label ("Back");
        label.add_css_class ("nm-back-label");

        content.append (icon);
        content.append (label);
        back_btn.set_child (content);

        back_btn.clicked.connect (() => {
            on_back ();
        });

        return back_btn;
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

    public Gtk.Widget build_details_row (string? key, string? value) {
        var row = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_INFO_GROUP);
        MainWindowCssClassResolver.add_best_class (row, {"nm-details-item", "nm-details-row"});

        string key_text = display_text_or_na (key);
        string value_text = display_text_or_na (value);

        var key_label = new Gtk.Label (key_text);
        key_label.set_xalign (0.0f);
        key_label.set_halign (Gtk.Align.START);
        key_label.set_hexpand (false);
        MainWindowCssClassResolver.add_best_class (key_label, {"nm-details-item-key", "nm-details-key"});

        var value_label = new Gtk.Label (value_text);
        value_label.set_xalign (0.0f);
        value_label.set_halign (Gtk.Align.START);
        value_label.set_wrap (true);
        MainWindowCssClassResolver.add_best_class (
            value_label,
            {"nm-details-item-value", "nm-details-value"}
        );

        row.append (key_label);
        row.append (value_label);
        return row;
    }

    public Gtk.Widget build_details_section (string title, out Gtk.Box rows_container) {
        var section = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_TOOLBAR);
        section.add_css_class ("nm-details-section");

        var heading = new Gtk.Label (title);
        heading.set_xalign (0.5f);
        heading.add_css_class ("nm-details-group-title");
        section.append (heading);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.add_css_class ("nm-separator");
        section.append (separator);

        rows_container = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_COMPACT);
        rows_container.add_css_class ("nm-details-rows");
        section.append (rows_container);

        return section;
    }
}
