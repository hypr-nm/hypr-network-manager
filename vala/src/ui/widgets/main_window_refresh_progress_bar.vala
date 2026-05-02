using GLib;
using Gtk;

namespace HyprNetworkManager.UI.Widgets {
    public class MainWindowRefreshProgressController : Object {
        private Gtk.ProgressBar progress_bar;
        private uint pulse_timeout_id = 0;
        private uint min_duration_timeout_id = 0;
        private int64 start_time = 0;
        private bool is_refreshing = false;
        private uint min_duration_ms = 800;

        public MainWindowRefreshProgressController (Gtk.ProgressBar progress_bar) {
            this.progress_bar = progress_bar;
            this.progress_bar.set_opacity (0.0);
            this.progress_bar.set_visible (true);
            this.progress_bar.add_css_class ("nm-refresh-progress");
        }

        public void start () {
            if (is_refreshing) {
                return;
            }

            if (min_duration_timeout_id != 0) {
                Source.remove (min_duration_timeout_id);
                min_duration_timeout_id = 0;
            }

            is_refreshing = true;
            this.progress_bar.set_opacity (1.0);
            start_time = GLib.get_monotonic_time ();

            if (pulse_timeout_id == 0) {
                pulse_timeout_id = Timeout.add (30, () => {
                    this.progress_bar.pulse ();
                    return true;
                });
            }
        }

        public void finish () {
            if (!is_refreshing) {
                return;
            }

            int64 current_time = GLib.get_monotonic_time ();
            int64 elapsed_ms = (current_time - start_time) / 1000;

            if (elapsed_ms >= min_duration_ms) {
                stop_animating ();
            } else if (min_duration_timeout_id == 0) {
                min_duration_timeout_id = Timeout.add ((uint) (min_duration_ms - elapsed_ms), () => {
                    min_duration_timeout_id = 0;
                    stop_animating ();
                    return false;
                });
            }
        }

        private void stop_animating () {
            is_refreshing = false;
            this.progress_bar.set_opacity (0.0);
            
            if (pulse_timeout_id != 0) {
                Source.remove (pulse_timeout_id);
                pulse_timeout_id = 0;
            }
        }

        ~MainWindowRefreshProgressController () {
            if (pulse_timeout_id != 0) {
                Source.remove (pulse_timeout_id);
                pulse_timeout_id = 0;
            }
            if (min_duration_timeout_id != 0) {
                Source.remove (min_duration_timeout_id);
                min_duration_timeout_id = 0;
            }
        }
    }
}
