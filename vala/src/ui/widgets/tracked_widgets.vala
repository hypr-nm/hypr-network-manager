using Gtk;
using HyprNetworkManager.UI.Utils;

namespace HyprNetworkManager.UI.Widgets {
    namespace TrackedWidgets {
        public Gtk.DropDown dropdown (
            TransientSurfaceTracker tracker,
            owned GLib.ListModel? model,
            owned Gtk.Expression? expression
        ) {
            var dropdown = new Gtk.DropDown (model, expression);
            tracker.track_dropdown (dropdown);
            return dropdown;
        }
    }
}
