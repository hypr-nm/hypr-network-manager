using Gtk;
using Gdk;

namespace HyprNetworkManager.UI.Utils {
    public class MainWindowDismissHandler : Object {
        private Gtk.Window window;
        private TransientSurfaceTracker tracker;
        private Gtk.Box? root_container;
        
        private Gtk.EventControllerKey key_controller;
        private Gtk.GestureClick blank_window_gesture;
        private bool blank_window_down = false;
        private bool blank_window_in = false;

        public MainWindowDismissHandler (Gtk.Window window, TransientSurfaceTracker tracker) {
            this.window = window;
            this.tracker = tracker;
            configure ();
        }

        public void set_root_container (Gtk.Box root_container) {
            this.root_container = root_container;
        }

        public void reset_state () {
            blank_window_down = false;
            blank_window_in = false;
        }

        private void configure () {
            key_controller = new Gtk.EventControllerKey ();
            key_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            ((Gtk.Widget) window).add_controller (key_controller);
            key_controller.key_pressed.connect (key_press_event_cb);

            blank_window_gesture = new Gtk.GestureClick ();
            ((Gtk.Widget) window).add_controller (blank_window_gesture);
            blank_window_gesture.touch_only = false;
            blank_window_gesture.exclusive = true;
            blank_window_gesture.button = Gdk.BUTTON_PRIMARY;
            blank_window_gesture.propagation_phase = Gtk.PropagationPhase.BUBBLE;

            blank_window_gesture.pressed.connect (on_pressed);
            blank_window_gesture.released.connect (on_released);
            blank_window_gesture.update.connect (on_update);
            blank_window_gesture.cancel.connect (() => {
                blank_window_down = false;
            });
        }

        private void on_pressed (int n_press, double x, double y) {
            Graphene.Point click_point = Graphene.Point ().init ((float) x, (float) y);
            Graphene.Rect? bounds = null;
            bool bounds_success = false;
            if (root_container != null) {
                bounds_success = root_container.compute_bounds (window, out bounds);
            }
            
            if (bounds_success && bounds != null) {
                log_debug ("gui", "Gesture pressed: x=" + x.to_string () + ", y=" + y.to_string () +
                    " | bounds: x=" + bounds.origin.x.to_string () + ", y=" + bounds.origin.y.to_string () + 
                    ", w=" + bounds.size.width.to_string () + ", h=" + bounds.size.height.to_string ());
            } else {
                log_debug ("gui", "Gesture pressed: x=" + x.to_string () + ", y=" + y.to_string () +
                    " | bounds_success=" + bounds_success.to_string () + " (root_container=" + (root_container != null).to_string() + ")");
            }

            if (bounds_success && bounds != null && bounds.size.width > 0 && bounds.size.height > 0) {
                blank_window_in = !bounds.contains_point (click_point);
                
                if (blank_window_in
                    && tracker != null
                    && tracker.should_ignore_window_dismiss_click (x, y)) {
                     log_debug ("gui", "Gesture pressed eval: ignoring outside click because it intersects a transient surface.");
                     blank_window_in = false;
                } else {
                     log_debug ("gui", "Gesture pressed eval: point inside bounds? " + (!blank_window_in).to_string ());
                }
            } else {
                blank_window_in = false;
                log_debug ("gui", "Gesture pressed eval: assuming inside because bounds are invalid or 0x0.");
            }
            blank_window_down = true;
        }

        private void on_released (int n_press, double x, double y) {
            if (!blank_window_down) return;
            
            log_debug ("gui", "Gesture released: down=" + blank_window_down.to_string () + 
                ", in(outside bounds)=" + blank_window_in.to_string ());
            
            blank_window_down = false;

            if (blank_window_in) {
                if (tracker != null
                    && tracker.should_ignore_window_dismiss_click (x, y)) {
                    log_debug ("gui", "MainWindow NOT closing: release matched recent transient dismiss");
                    blank_window_in = false;
                    return;
                }

                Graphene.Point release_point = Graphene.Point ().init ((float) x, (float) y);
                Graphene.Rect? release_bounds = null;
                bool release_bounds_success = false;
                if (root_container != null) {
                    release_bounds_success = root_container.compute_bounds (window, out release_bounds);
                }
                
                if (release_bounds_success && release_bounds != null && release_bounds.size.width > 0 && release_bounds.size.height > 0) {
                     if (release_bounds.contains_point (release_point)) {
                         log_debug ("gui", "MainWindow NOT closing: click released inside valid bounds");
                         blank_window_in = false;
                         return;
                     }
                }

                log_debug ("gui", "MainWindow closing: blank_window_gesture triggered close (clicked outside bounds)");
                window.close ();
            }

            if (blank_window_gesture.get_current_sequence () == null) {
                blank_window_in = false;
            }
        }

        private void on_update (Gtk.Gesture gesture, Gdk.EventSequence? sequence) {
            Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
            if (sequence != gesture_single.get_current_sequence ()) return;

            double x, y;
            gesture.get_point (sequence, out x, out y);

            Graphene.Point click_point = Graphene.Point ().init ((float) x, (float) y);
            Graphene.Rect? bounds = null;
            bool bounds_success = false;
            if (root_container != null) {
                bounds_success = root_container.compute_bounds (window, out bounds);
            }
            if (bounds_success && bounds != null && bounds.size.width > 0 && bounds.size.height > 0 && bounds.contains_point (click_point)) {
                blank_window_in = false;
            }
        }

        private bool key_press_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (window.get_focus () is Gtk.Editable) {
                if (Gdk.keyval_name (keyval) == "Escape") {
                    window.close ();
                    return true;
                }
                return false;
            }

            switch (Gdk.keyval_name (keyval)) {
            case "Escape":
                window.close ();
                return true;
            default:
                break;
            }

            return false;
        }
    }
}
