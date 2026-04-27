using GLib;
using Gtk;
using GtkLayerShell;

namespace HyprNetworkManager.UI.Utils {
    public class TransientSurfaceTracker : Object {
        private const int64 ACTIVE_SURFACE_GRACE_US = 300000;
        private const int64 DISMISS_INTERCEPT_GRACE_US = 4000000;
        private const int64 RECENT_SURFACE_BOUNDS_GRACE_US = 1000000;
        private const int RECENT_SURFACE_BOUNDS_MARGIN_PX = 12;
        private const int SYNTHETIC_DISMISS_REPEAT_MARGIN_PX = 32;
        private const uint SURFACE_BOUNDS_CAPTURE_DELAY_MS = 16;
        private const uint WINDOW_RECLAIM_DELAY_MS = 16;
        private const string SURFACE_ACTIVE_DATA_KEY = "nm-transient-surface-active";
        private const string SURFACE_BOUNDS_CAPTURE_SOURCE_DATA_KEY = "nm-transient-surface-bounds-capture-source";
        private const string POPOVER_TRACKED_DATA_KEY = "nm-transient-popover-tracked";

        private Gtk.Window window;
        private bool layer_shell_active;
        private int transient_surface_count = 0;
        private int64 last_surface_closed_time = 0;
        private uint window_reclaim_source_id = 0;
        private weak Gtk.Widget? focus_restore_widget = null;
        private uint pending_dismiss_intercepts = 0;
        private bool recent_synthetic_dismiss_valid = false;
        private double recent_synthetic_dismiss_x = 0.0;
        private double recent_synthetic_dismiss_y = 0.0;
        private bool recent_surface_bounds_valid = false;
        private Gdk.Rectangle recent_surface_bounds = Gdk.Rectangle ();

        public TransientSurfaceTracker (Gtk.Window window, bool layer_shell_active) {
            Object ();
            this.window = window;
            this.layer_shell_active = layer_shell_active;
        }

        public bool has_active_surfaces () {
            // Provide a 300ms grace period after a surface closes where we still
            // consider surfaces "active" to absorb the click that dismissed them.
            return transient_surface_count > 0 || (GLib.get_monotonic_time () - last_surface_closed_time) < ACTIVE_SURFACE_GRACE_US;
        }

        private void cancel_window_reclaim () {
            if (window_reclaim_source_id == 0) {
                return;
            }

            Source.remove (window_reclaim_source_id);
            window_reclaim_source_id = 0;
        }

        private void cancel_surface_bounds_capture (Gtk.Widget widget) {
            uint source_id = widget.get_data<uint> (SURFACE_BOUNDS_CAPTURE_SOURCE_DATA_KEY);
            if (source_id == 0) {
                return;
            }

            Source.remove (source_id);
            widget.set_data<uint> (SURFACE_BOUNDS_CAPTURE_SOURCE_DATA_KEY, 0);
        }

        private void capture_recent_surface_bounds (Gtk.Widget widget) {
            Gtk.Native? widget_native = widget.get_native ();
            Gtk.Native? window_native = ((Gtk.Widget) window).get_native ();
            if (widget_native == null || window_native == null) {
                return;
            }

            Gdk.Surface? widget_surface = widget_native.get_surface ();
            Gdk.Surface? window_surface = window_native.get_surface ();
            if (widget_surface == null || window_surface == null) {
                return;
            }

            double x = 0.0;
            double y = 0.0;
            if (!widget_surface.translate_coordinates (window_surface, ref x, ref y)) {
                return;
            }

            int width = widget_surface.get_width ();
            int height = widget_surface.get_height ();
            if (width <= 0 || height <= 0) {
                return;
            }

            recent_surface_bounds = Gdk.Rectangle () {
                x = (int) x,
                y = (int) y,
                width = width,
                height = height
            };
            recent_surface_bounds_valid = true;
        }

        private void queue_surface_bounds_capture (Gtk.Widget widget) {
            cancel_surface_bounds_capture (widget);

            uint source_id = Timeout.add (SURFACE_BOUNDS_CAPTURE_DELAY_MS, () => {
                widget.set_data<uint> (SURFACE_BOUNDS_CAPTURE_SOURCE_DATA_KEY, 0);
                capture_recent_surface_bounds (widget);
                return false;
            });
            widget.set_data<uint> (SURFACE_BOUNDS_CAPTURE_SOURCE_DATA_KEY, source_id);
        }

        private void clear_recent_synthetic_dismiss () {
            recent_synthetic_dismiss_valid = false;
            recent_synthetic_dismiss_x = 0.0;
            recent_synthetic_dismiss_y = 0.0;
        }

        private void remember_recent_synthetic_dismiss (double window_x, double window_y) {
            recent_synthetic_dismiss_valid = true;
            recent_synthetic_dismiss_x = window_x;
            recent_synthetic_dismiss_y = window_y;
        }

        private bool matches_recent_synthetic_dismiss (double window_x, double window_y) {
            if (!recent_synthetic_dismiss_valid) {
                return false;
            }

            return window_x >= (recent_synthetic_dismiss_x - SYNTHETIC_DISMISS_REPEAT_MARGIN_PX)
                && window_x <= (recent_synthetic_dismiss_x + SYNTHETIC_DISMISS_REPEAT_MARGIN_PX)
                && window_y >= (recent_synthetic_dismiss_y - SYNTHETIC_DISMISS_REPEAT_MARGIN_PX)
                && window_y <= (recent_synthetic_dismiss_y + SYNTHETIC_DISMISS_REPEAT_MARGIN_PX);
        }

        public bool should_ignore_window_dismiss_click (double window_x, double window_y) {
            if (has_active_surfaces ()) {
                return true;
            }

            Gtk.Widget window_widget = (Gtk.Widget) window;
            bool within_vertical_window_span = window_x >= 0
                && window_x <= window_widget.get_width ()
                && (window_y < 0 || window_y > window_widget.get_height ());

            bool within_dismiss_intercept_grace = last_surface_closed_time != 0
                && (GLib.get_monotonic_time () - last_surface_closed_time) < DISMISS_INTERCEPT_GRACE_US;

            if (within_dismiss_intercept_grace && within_vertical_window_span) {
                if (pending_dismiss_intercepts > 0) {
                    pending_dismiss_intercepts--;
                    remember_recent_synthetic_dismiss (window_x, window_y);
                    log_info (
                        "gui",
                        "Transient surface dismiss intercept: ignoring synthetic outside click x="
                        + window_x.to_string () + ", y=" + window_y.to_string ()
                    );
                    return true;
                }

                if (matches_recent_synthetic_dismiss (window_x, window_y)) {
                    log_info (
                        "gui",
                        "Transient surface dismiss intercept: ignoring repeated synthetic outside click x="
                        + window_x.to_string () + ", y=" + window_y.to_string ()
                    );
                    return true;
                }
            }

            if (!recent_surface_bounds_valid
                || last_surface_closed_time == 0
                || (GLib.get_monotonic_time () - last_surface_closed_time) >= RECENT_SURFACE_BOUNDS_GRACE_US) {
                return false;
            }

            Gtk.Native? window_native = ((Gtk.Widget) window).get_native ();
            if (window_native == null) {
                return false;
            }

            double surface_transform_x = 0.0;
            double surface_transform_y = 0.0;
            window_native.get_surface_transform (out surface_transform_x, out surface_transform_y);

            double surface_x = window_x + surface_transform_x;
            double surface_y = window_y + surface_transform_y;

            return surface_x >= (recent_surface_bounds.x - RECENT_SURFACE_BOUNDS_MARGIN_PX)
                && surface_x <= (recent_surface_bounds.x + recent_surface_bounds.width + RECENT_SURFACE_BOUNDS_MARGIN_PX)
                && surface_y >= (recent_surface_bounds.y - RECENT_SURFACE_BOUNDS_MARGIN_PX)
                && surface_y <= (recent_surface_bounds.y + recent_surface_bounds.height + RECENT_SURFACE_BOUNDS_MARGIN_PX);
        }

        private void queue_window_reclaim () {
            cancel_window_reclaim ();

            // Let the popover fully unmap before we reassert the main surface.
            window_reclaim_source_id = Timeout.add (WINDOW_RECLAIM_DELAY_MS, () => {
                window_reclaim_source_id = 0;

                if (transient_surface_count > 0) {
                    return false;
                }

                apply_keyboard_mode ();

                Gtk.Widget window_widget = (Gtk.Widget) window;
                if (!window_widget.get_mapped () || !window_widget.get_visible ()) {
                    focus_restore_widget = null;
                    return false;
                }

                window.present ();

                if (focus_restore_widget != null
                    && focus_restore_widget.get_root () == window
                    && focus_restore_widget.get_focusable ()
                    && focus_restore_widget.get_sensitive ()) {
                    focus_restore_widget.grab_focus ();
                }

                focus_restore_widget = null;
                return false;
            });
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

            if (active && transient_surface_count == 0) {
                focus_restore_widget = window.get_focus ();
                cancel_window_reclaim ();
                pending_dismiss_intercepts = 0;
                clear_recent_synthetic_dismiss ();
            }

            widget.set_data<bool> (SURFACE_ACTIVE_DATA_KEY, active);
            transient_surface_count += active ? 1 : -1;
            if (transient_surface_count < 0) {
                transient_surface_count = 0;
            }

            if (!active && transient_surface_count == 0) {
                last_surface_closed_time = GLib.get_monotonic_time ();
                pending_dismiss_intercepts = 1;
                queue_window_reclaim ();
            }

            apply_keyboard_mode ();
        }

        private void reset_widget_state (Gtk.Widget widget) {
            cancel_surface_bounds_capture (widget);
            widget.set_data<bool> (SURFACE_ACTIVE_DATA_KEY, false);

            for (Gtk.Widget? child = widget.get_first_child (); child != null; child = child.get_next_sibling ()) {
                reset_widget_state (child);
            }
        }

        public void reset (Gtk.Widget? root_widget) {
            cancel_window_reclaim ();
            transient_surface_count = 0;
            last_surface_closed_time = 0;
            focus_restore_widget = null;
            pending_dismiss_intercepts = 0;
            clear_recent_synthetic_dismiss ();
            recent_surface_bounds_valid = false;
            recent_surface_bounds = Gdk.Rectangle ();

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
                queue_surface_bounds_capture ((Gtk.Widget) popover);
            });

            popover.unmap.connect (() => {
                capture_recent_surface_bounds ((Gtk.Widget) popover);
                cancel_surface_bounds_capture ((Gtk.Widget) popover);
                set_tracked_surface_state ((Gtk.Widget) popover, false);
            });

            popover.closed.connect (() => {
                capture_recent_surface_bounds ((Gtk.Widget) popover);
                set_tracked_surface_state ((Gtk.Widget) popover, false);
            });
        }
    }
}
