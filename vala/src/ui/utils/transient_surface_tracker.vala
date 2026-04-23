using GLib;
using Gtk;
using GtkLayerShell;

namespace HyprNetworkManager.UI.Utils {
    public class TransientSurfaceTracker : Object {
        private const uint RECHECK_DELAY_MS = 16;
        private const string SURFACE_ACTIVE_DATA_KEY = "nm-transient-surface-active";
        private const string POPOVER_TRACKED_DATA_KEY = "nm-transient-popover-tracked";
        private const string SURFACE_RECHECK_SOURCE_DATA_KEY = "nm-transient-surface-recheck-source";
        private const string SURFACE_TRACKED_DATA_KEY = "nm-transient-surface-tracked";

        private Gtk.Window window;
        private bool layer_shell_active;
        private int transient_surface_count = 0;

        public TransientSurfaceTracker (Gtk.Window window, bool layer_shell_active) {
            Object ();
            this.window = window;
            this.layer_shell_active = layer_shell_active;
        }

        public void apply_keyboard_mode () {
            if (!layer_shell_active) {
                return;
            }

            // Hyprland stops popup surfaces from receiving pointer events while the
            // layer-shell window holds exclusive input, so transient popovers temporarily
            // downgrade to ON_DEMAND until they close.
            GtkLayerShell.set_keyboard_mode (
                window,
                transient_surface_count > 0
                    ? GtkLayerShell.KeyboardMode.ON_DEMAND
                    : GtkLayerShell.KeyboardMode.EXCLUSIVE
            );
        }

        private void set_tracked_surface_state (Gtk.Widget widget, bool active) {
            bool was_active = widget.get_data<bool> (SURFACE_ACTIVE_DATA_KEY);
            if (was_active == active) {
                return;
            }

            widget.set_data<bool> (SURFACE_ACTIVE_DATA_KEY, active);
            transient_surface_count += active ? 1 : -1;
            if (transient_surface_count < 0) {
                transient_surface_count = 0;
            }

            apply_keyboard_mode ();
        }

        private void track_dropdown_transient_surfaces (Gtk.Widget widget) {
            if (widget is Gtk.Popover) {
                var popover = (Gtk.Popover) widget;
                track_popover (popover);

                if (widget.get_mapped ()) {
                    set_tracked_surface_state (widget, true);
                }
            }

            for (Gtk.Widget? child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
                track_dropdown_transient_surfaces (child);
            }
        }

        private void queue_dropdown_recheck (Gtk.DropDown dropdown) {
            var widget = (Gtk.Widget) dropdown;
            uint existing_source = widget.get_data<uint> (SURFACE_RECHECK_SOURCE_DATA_KEY);
            if (existing_source != 0) {
                Source.remove (existing_source);
            }

            uint source_id = Timeout.add (RECHECK_DELAY_MS, () => {
                widget.set_data<uint> (SURFACE_RECHECK_SOURCE_DATA_KEY, 0);
                track_dropdown_transient_surfaces (widget);
                return false;
            });
            widget.set_data<uint> (SURFACE_RECHECK_SOURCE_DATA_KEY, source_id);
        }

        private void reset_widget_state (Gtk.Widget widget) {
            uint source_id = widget.get_data<uint> (SURFACE_RECHECK_SOURCE_DATA_KEY);
            if (source_id != 0) {
                Source.remove (source_id);
                widget.set_data<uint> (SURFACE_RECHECK_SOURCE_DATA_KEY, 0);
            }

            widget.set_data<bool> (SURFACE_ACTIVE_DATA_KEY, false);

            for (Gtk.Widget? child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
                reset_widget_state (child);
            }
        }

        public void reset (Gtk.Widget? root_widget) {
            transient_surface_count = 0;

            if (root_widget != null) {
                reset_widget_state (root_widget);
            }

            apply_keyboard_mode ();
        }

        public void track_popover (Gtk.Popover popover) {
            if (popover.get_data<bool> (POPOVER_TRACKED_DATA_KEY)) {
                return;
            }

            popover.set_data<bool> (POPOVER_TRACKED_DATA_KEY, true);

            popover.map.connect (() => {
                set_tracked_surface_state ((Gtk.Widget) popover, true);
            });

            popover.unmap.connect (() => {
                set_tracked_surface_state ((Gtk.Widget) popover, false);
            });

            popover.closed.connect (() => {
                set_tracked_surface_state ((Gtk.Widget) popover, false);
            });
        }

        public void track_dropdown (Gtk.DropDown dropdown) {
            if (dropdown.get_data<bool> (SURFACE_TRACKED_DATA_KEY)) {
                return;
            }

            dropdown.set_data<bool> (SURFACE_TRACKED_DATA_KEY, true);
            track_dropdown_transient_surfaces ((Gtk.Widget) dropdown);

            dropdown.activate.connect (() => {
                queue_dropdown_recheck (dropdown);
            });

            dropdown.notify["selected"].connect (() => {
                queue_dropdown_recheck (dropdown);
            });

            var focus_controller = new Gtk.EventControllerFocus ();
            focus_controller.leave.connect (() => {
                queue_dropdown_recheck (dropdown);
            });
            dropdown.add_controller (focus_controller);
        }
    }
}
