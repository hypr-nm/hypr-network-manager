/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

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
            this.progress_bar.set_visible (false);
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
            this.progress_bar.set_visible (true);
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
            this.progress_bar.set_visible (false);
            
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
