using Gtk;
using HyprNetworkManager.UI.Utils;

namespace HyprNetworkManager.UI.Widgets {
    public class TrackedDropDown : Gtk.Box {
        private Gtk.StringList model;
        private Gtk.MenuButton menu_button;
        private TrackedPopover popover;
        private Gtk.ListBox listbox;
        private Gtk.Label selected_label;
        private uint _selected = 0;

        public signal void notify_selected ();

        public TrackedDropDown (TransientSurfaceTracker tracker, Gtk.StringList model) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
            this.model = model;

            selected_label = new Gtk.Label ("");
            selected_label.set_halign (Gtk.Align.START);
            selected_label.set_hexpand (true);
            selected_label.set_ellipsize (Pango.EllipsizeMode.END);

            var icon = new Gtk.Image.from_icon_name ("pan-down-symbolic");

            var button_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            button_content.append (selected_label);
            button_content.append (icon);

            popover = new TrackedPopover (tracker);
            popover.set_has_arrow (false);
            popover.add_css_class ("menu");
            popover.add_css_class ("background");
            popover.set_position (Gtk.PositionType.BOTTOM);
            popover.set_offset (0, 4);

            listbox = new Gtk.ListBox ();
            listbox.set_selection_mode (Gtk.SelectionMode.NONE);
            listbox.add_css_class ("menu");
            listbox.add_css_class ("nm-popover-list");

            for (uint i = 0; i < model.get_n_items (); i++) {
                var item = (Gtk.StringObject) model.get_item (i);
                var row = new Gtk.ListBoxRow ();
                row.add_css_class ("menuitem");

                var row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
                row_box.set_margin_start (2);
                row_box.set_margin_end (2);
                row_box.set_margin_top (2);
                row_box.set_margin_bottom (2);

                var label = new Gtk.Label (item.get_string ());
                label.set_halign (Gtk.Align.START);
                label.set_hexpand (true);

                var check_icon = new Gtk.Image.from_icon_name ("object-select-symbolic");
                check_icon.set_opacity (0.0);

                row_box.append (label);
                row_box.append (check_icon);

                row.set_child (row_box);
                listbox.append (row);
            }

            listbox.row_activated.connect ((row) => {
                uint index = (uint) row.get_index ();
                set_selected (index);
                popover.popdown ();
            });

            var scroll = new Gtk.ScrolledWindow ();
            scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scroll.set_max_content_height (250);
            scroll.set_propagate_natural_height (true);
            scroll.set_propagate_natural_width (true);
            scroll.set_child (listbox);
            popover.set_child (scroll);

            menu_button = new Gtk.MenuButton ();
            menu_button.set_child (button_content);
            menu_button.set_popover (popover);
            menu_button.set_hexpand (true);
            menu_button.set_valign (Gtk.Align.CENTER);
            menu_button.set_has_frame (false);
            menu_button.set_focus_on_click (false);
            menu_button.add_css_class ("flat");
            menu_button.add_css_class (MainWindowCssClasses.EDIT_DROPDOWN_TRIGGER);

            popover.map.connect (() => {
                int width = menu_button.get_width ();
                if (width > 0) {
                    scroll.set_size_request (width, -1);
                }
            });

            this.append (menu_button);

            set_selected (0);
        }

        public uint get_selected () {
            return _selected;
        }

        public void set_selected (uint index) {
            if (index >= model.get_n_items ()) return;
            _selected = index;
            var item = (Gtk.StringObject) model.get_item (index);
            selected_label.set_text (item.get_string ());

            for (int i = 0; ; i++) {
                var row = listbox.get_row_at_index (i);
                if (row == null) break;

                var box = row.get_child () as Gtk.Box;
                if (box != null) {
                    var check = box.get_last_child () as Gtk.Image;
                    if (check != null) {
                        check.set_opacity (i == index ? 1.0 : 0.0);
                    }
                }
            }
            notify_selected ();
        }
    }
}
