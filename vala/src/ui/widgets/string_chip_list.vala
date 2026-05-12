using Gtk;

namespace HyprNetworkManager.UI.Widgets {
    public class StringChipList : Gtk.Box {
        private Gtk.FlowBox flowbox;
        private string placeholder;

        public StringChipList (string placeholder) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
            this.placeholder = placeholder;

            flowbox = new Gtk.FlowBox ();
            flowbox.set_selection_mode (Gtk.SelectionMode.NONE);
            flowbox.set_max_children_per_line (10);
            flowbox.set_column_spacing (6);
            flowbox.set_row_spacing (6);
            this.append (flowbox);

            var add_btn = new Gtk.Button.with_label ("+ Add IP");
            add_btn.add_css_class ("flat");
            add_btn.clicked.connect (() => {
                show_add_entry ();
            });
            this.append (add_btn);
        }

        private void show_add_entry () {
            var dialog_entry = new Gtk.Entry ();
            dialog_entry.set_placeholder_text (this.placeholder);
            
            var popover = new Gtk.Popover ();
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            box.set_margin_start (6);
            box.set_margin_end (6);
            box.set_margin_top (6);
            box.set_margin_bottom (6);
            box.append (dialog_entry);
            
            var add_confirm_btn = new Gtk.Button.with_label (_("Add"));
            add_confirm_btn.add_css_class ("suggested-action");
            add_confirm_btn.clicked.connect (() => {
                if (dialog_entry.get_text ().strip () != "") {
                    add_chip (dialog_entry.get_text ().strip ());
                }
                popover.popdown ();
            });
            box.append (add_confirm_btn);
            
            popover.set_child (box);
            popover.set_parent (this);
            popover.popup ();
        }

        public void add_chip (string text) {
            var chip_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            chip_box.add_css_class ("card");
            chip_box.set_margin_start (0);
            chip_box.set_margin_end (0);
            chip_box.set_margin_top (0);
            chip_box.set_margin_bottom (0);
            
            var label = new Gtk.Label (text);
            label.set_margin_start (6);
            chip_box.append (label);

            var remove_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
            remove_btn.add_css_class ("flat");
            remove_btn.add_css_class ("circular");
            
            var child = new Gtk.FlowBoxChild ();
            child.set_child (chip_box);
            
            remove_btn.clicked.connect (() => {
                this.flowbox.remove (child);
            });
            chip_box.append (remove_btn);

            flowbox.append (child);
        }

        public string[] get_values () {
            string[] values = {};
            var child = flowbox.get_first_child ();
            while (child != null) {
                var flow_child = child as Gtk.FlowBoxChild;
                if (flow_child != null) {
                    var box = flow_child.get_child () as Gtk.Box;
                    if (box != null) {
                        var label = box.get_first_child () as Gtk.Label;
                        if (label != null) {
                            values += label.get_text ();
                        }
                    }
                }
                child = child.get_next_sibling ();
            }
            return values;
        }

        public void set_values (string[] values) {
            var child = flowbox.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                flowbox.remove (child);
                child = next;
            }

            foreach (var val in values) {
                if (val.strip () != "") {
                    add_chip (val.strip ());
                }
            }
        }
    }
}