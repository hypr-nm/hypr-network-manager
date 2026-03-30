using Gtk;

namespace MainWindowHelpers {
    public Gtk.Button build_back_button (MainWindowActionCallback on_back) {
        var back_btn = new Gtk.Button ();
        back_btn.add_css_class ("nm-button");
        back_btn.add_css_class ("nm-nav-back");

        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var icon = new Gtk.Image.from_icon_name ("go-previous-symbolic");
        icon.set_pixel_size (14);
        icon.add_css_class ("nm-back-icon");

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
        var row = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        row.add_css_class ("nm-details-row");
        row.add_css_class ("nm-details-item");

        string key_text = display_text_or_na (key);
        string value_text = display_text_or_na (value);

        var key_label = new Gtk.Label (key_text);
        key_label.set_xalign (0.0f);
        key_label.set_halign (Gtk.Align.START);
        key_label.set_hexpand (false);
        key_label.add_css_class ("nm-details-key");
        key_label.add_css_class ("nm-details-item-key");

        var value_label = new Gtk.Label (value_text);
        value_label.set_xalign (0.0f);
        value_label.set_halign (Gtk.Align.START);
        value_label.set_wrap (true);
        value_label.add_css_class ("nm-details-value");
        value_label.add_css_class ("nm-details-item-value");

        row.append (key_label);
        row.append (value_label);
        return row;
    }

    public Gtk.Widget build_details_section (string title, out Gtk.Box rows_container) {
        var section = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        section.add_css_class ("nm-details-section");

        var heading = new Gtk.Label (title);
        heading.set_xalign (0.5f);
        heading.add_css_class ("nm-details-group-title");
        section.append (heading);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.add_css_class ("nm-separator");
        section.append (separator);

        rows_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        rows_container.add_css_class ("nm-details-rows");
        section.append (rows_container);

        return section;
    }
}
