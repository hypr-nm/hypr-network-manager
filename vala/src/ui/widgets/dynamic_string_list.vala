using Gtk;
 
namespace HyprNetworkManager.UI.Widgets {
    public class DynamicStringList : Gtk.Box {
        private Gtk.Box listbox;
        private string placeholder;
 
        public DynamicStringList (string title_text, string placeholder) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: MainWindowUiMetrics.SPACING_HEADER);
            this.placeholder = placeholder;
 
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
            header_box.add_css_class (MainWindowCssClasses.EDIT_MODE_ROW);
            var title = new Gtk.Label (title_text);
            title.set_hexpand (true);
            title.set_xalign (0.0f);
            title.add_css_class (MainWindowCssClasses.EDIT_MODE_LABEL);
            header_box.append (title);
 
            var add_btn = new Gtk.Button.with_label (_("Add IP"));
            MainWindowCssClassResolver.add_best_class (add_btn, {MainWindowCssClasses.ROW_LINK_ACTION, MainWindowCssClasses.BUTTON});
            add_btn.add_css_class (MainWindowCssClasses.EDIT_MODE_SWITCH);
            add_btn.set_valign (Gtk.Align.CENTER);
            add_btn.clicked.connect (() => {
                this.add_row ("");
            });
            header_box.append (add_btn);
            this.append (header_box);
 
            listbox = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_ROW);
            listbox.set_visible (false);
            this.append (listbox);
        }
        
        private void update_listbox_visibility () {
            listbox.set_visible (listbox.get_first_child () != null);
        }
 
        public void add_row (string text) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, MainWindowUiMetrics.SPACING_ROW);
            box.set_margin_end (12);
            
            var entry = new Gtk.Entry ();
            entry.set_hexpand (true);
            entry.set_text (text);
            entry.set_placeholder_text (this.placeholder);
            entry.add_css_class (MainWindowCssClasses.EDIT_FIELD_ENTRY);
            box.append (entry);
 
            var remove_btn = new Gtk.Button.from_icon_name ("user-trash-symbolic");
            remove_btn.add_css_class (MainWindowCssClasses.ROW_ICON_ACTION);
            remove_btn.add_css_class (MainWindowCssClasses.DELETE_BUTTON);
            remove_btn.set_valign (Gtk.Align.CENTER);
            remove_btn.clicked.connect (() => {
                this.listbox.remove (box);
                update_listbox_visibility ();
            });
            box.append (remove_btn);
 
            listbox.append (box);
            update_listbox_visibility ();
        }
 
        public string[] get_values () {
            string[] values = {};
            var child = listbox.get_first_child ();
            while (child != null) {
                var box = child as Gtk.Box;
                if (box != null) {
                    var entry = box.get_first_child () as Gtk.Entry;
                    if (entry != null && entry.get_text ().strip () != "") {
                        values += entry.get_text ().strip ();
                    }
                }
                child = child.get_next_sibling ();
            }
            return values;
        }
 
        public void set_values (string[] values) {
            var child = listbox.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                listbox.remove (child);
                child = next;
            }
 
            foreach (var val in values) {
                if (val.strip () != "") {
                    add_row (val.strip ());
                }
            }
            update_listbox_visibility ();
        }
    }
}