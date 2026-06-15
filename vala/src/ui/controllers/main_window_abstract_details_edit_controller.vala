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
