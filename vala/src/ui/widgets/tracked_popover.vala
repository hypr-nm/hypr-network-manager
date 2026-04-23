using Gtk;
using HyprNetworkManager.UI.Utils;

namespace HyprNetworkManager.UI.Widgets {
    public class TrackedPopover : Gtk.Popover {
        public TrackedPopover (TransientSurfaceTracker tracker) {
            Object ();
            tracker.track_popover (this);
        }
    }
}
