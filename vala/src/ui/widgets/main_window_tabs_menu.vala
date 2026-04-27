using Gtk;
using HyprNetworkManager.UI.Utils;

namespace HyprNetworkManager.UI.Widgets {
    public class MainWindowTabsMenu : Gtk.Box {
        private TransientSurfaceTracker tracker;
        private Gtk.Button flight_mode_button;
        private TrackedPopover tracked_popover;
        private Gtk.MenuButton menu_button;
        
        public signal void saved_profiles_clicked ();
        public signal void flight_mode_clicked ();
        public signal void popover_mapped ();

        public MainWindowTabsMenu (TransientSurfaceTracker tracker) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
            this.tracker = tracker;
            
            menu_button = new Gtk.MenuButton ();
            menu_button.add_css_class (MainWindowCssClasses.TABS_MENU_BUTTON);
            menu_button.set_focus_on_click (false);
            menu_button.set_tooltip_text ("Profiles");

            tracked_popover = new TrackedPopover (tracker);
            tracked_popover.add_css_class (MainWindowCssClasses.TABS_MENU_POPOVER);
            tracked_popover.set_has_arrow (false);
            tracked_popover.set_position (Gtk.PositionType.BOTTOM);
            tracked_popover.set_offset (
                MainWindowUiMetrics.TABS_POPOVER_OFFSET_X,
                MainWindowUiMetrics.TABS_POPOVER_OFFSET_Y
            );

            var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, MainWindowUiMetrics.SPACING_NONE);
            MainWindowCssClassResolver.add_best_class (
                menu_box,
                {MainWindowCssClasses.POPOVER_LIST_INSET}
            );
            MainWindowCssClassResolver.add_best_class (
                menu_box,
                {MainWindowCssClasses.TABS_MENU_LIST, MainWindowCssClasses.LIST}
            );

            var saved_profiles_item = new Gtk.Button.with_label ("Saved Profiles");
            saved_profiles_item.add_css_class (MainWindowCssClasses.TABS_MENU_ITEM);
            var sp_label = saved_profiles_item.get_child () as Gtk.Label;
            if (sp_label != null) sp_label.set_halign (Gtk.Align.START);

            saved_profiles_item.clicked.connect (() => {
                tracked_popover.popdown ();
                saved_profiles_clicked ();
            });
            menu_box.append (saved_profiles_item);

            flight_mode_button = new Gtk.Button.with_label ("Turn on flight mode");
            flight_mode_button.add_css_class (MainWindowCssClasses.TABS_MENU_ITEM);
            var fm_label = flight_mode_button.get_child () as Gtk.Label;
            if (fm_label != null) fm_label.set_halign (Gtk.Align.START);

            flight_mode_button.clicked.connect (() => {
                tracked_popover.popdown ();
                flight_mode_clicked ();
            });
            menu_box.append (flight_mode_button);

            tracked_popover.map.connect (() => {
                menu_button.add_css_class (MainWindowCssClasses.TABS_MENU_BUTTON_OPEN);
                popover_mapped ();
            });

            tracked_popover.closed.connect (() => {
                menu_button.remove_css_class (MainWindowCssClasses.TABS_MENU_BUTTON_OPEN);
                clear_transient_menu_button_state (menu_button);
            });

            tracked_popover.set_child (menu_box);
            menu_button.set_popover (tracked_popover);

            var icon = new Gtk.Image.from_icon_name ("view-more-symbolic");
            MainWindowCssClassResolver.add_best_class (
                icon,
                {MainWindowCssClasses.TABS_MENU_ICON, MainWindowCssClasses.TOOLBAR_ICON}
            );
            menu_button.set_child (icon);

            this.append (menu_button);
        }

        public void popdown () {
            menu_button.popdown ();
        }

        public void set_flight_mode_label (string label) {
            flight_mode_button.set_label (label);
        }

        private void clear_transient_menu_button_state (Gtk.Widget widget) {
            widget.unset_state_flags (
                Gtk.StateFlags.ACTIVE | Gtk.StateFlags.PRELIGHT | Gtk.StateFlags.CHECKED
            );

            for (Gtk.Widget? child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
                clear_transient_menu_button_state (child);
            }
        }
    }
}
