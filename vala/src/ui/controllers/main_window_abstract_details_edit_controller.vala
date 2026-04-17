using GLib;
using Gtk;

public abstract class MainWindowAbstractDetailsEditController : Object {
    protected bool is_disposed = false;
    protected uint ui_epoch = 1;
    protected Cancellable? details_request_cancellable = null;
    protected Cancellable? edit_request_cancellable = null;

    protected HyprNetworkManager.UI.Interfaces.IWindowHost host;

    protected MainWindowAbstractDetailsEditController (HyprNetworkManager.UI.Interfaces.IWindowHost host) {
        this.host = host;
    }

    public virtual void on_page_leave () {
        invalidate_ui_state ();
    }

    public virtual void dispose_controller () {
        if (is_disposed) {
            return;
        }
        is_disposed = true;
        invalidate_ui_state ();
    }

    protected uint capture_ui_epoch () {
        return ui_epoch;
    }

    protected bool is_ui_epoch_valid (uint epoch) {
        return !is_disposed && epoch == ui_epoch;
    }

    protected virtual void invalidate_ui_state () {
        ui_epoch++;
        if (ui_epoch == 0) {
            ui_epoch = 1;
        }
        cancel_details_request ();
        cancel_edit_request ();
    }

    protected bool is_cancelled_error (Error e) {
        return e is IOError.CANCELLED;
    }

    protected void cancel_details_request () {
        if (details_request_cancellable != null) {
            details_request_cancellable.cancel ();
            details_request_cancellable = null;
        }
    }

    protected void cancel_edit_request () {
        if (edit_request_cancellable != null) {
            edit_request_cancellable.cancel ();
            edit_request_cancellable = null;
        }
    }
}
