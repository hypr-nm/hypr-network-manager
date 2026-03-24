// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions of this file are adapted from SwayNotificationCenter:
// https://github.com/ErikReider/SwayNotificationCenter
// Original license: GPL-3.0

using Gtk;
using Gdk;
using GtkLayerShell;

[CCode (cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
private extern void blank_window_style_provider_add_for_display(
    Gdk.Display display,
    Gtk.StyleProvider provider,
    uint priority
);

public class BlankWindow : Gtk.ApplicationWindow {
    private Gtk.Box click_surface;
    private Gtk.GestureClick blank_window_gesture;
    private Gtk.GestureClick window_gesture;

    public BlankWindow(NetworkManagerValaApp app, Gdk.Monitor monitor) {
        Object(application: app, css_name: "blankwindow");

        Gdk.Rectangle monitor_geometry = monitor.get_geometry();

        set_decorated(false);
        set_resizable(false);
        set_focusable(false);
        set_default_size(monitor_geometry.width, monitor_geometry.height);
        set_size_request(monitor_geometry.width, monitor_geometry.height);

        click_surface = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        click_surface.set_hexpand(true);
        click_surface.set_vexpand(true);
        click_surface.set_can_target(true);
        click_surface.set_sensitive(true);
        click_surface.add_css_class("blank-window-surface");
        set_child(click_surface);

        blank_window_gesture = new Gtk.GestureClick();
        click_surface.add_controller(blank_window_gesture);
        window_gesture = new Gtk.GestureClick();
        ((Gtk.Widget) this).add_controller(window_gesture);

        blank_window_gesture.touch_only = false;
        blank_window_gesture.exclusive = false;
        blank_window_gesture.button = 0;
        blank_window_gesture.propagation_phase = Gtk.PropagationPhase.TARGET;

        window_gesture.touch_only = false;
        window_gesture.exclusive = false;
        window_gesture.button = 0;
        window_gesture.propagation_phase = Gtk.PropagationPhase.CAPTURE;

        blank_window_gesture.pressed.connect((n_press, x, y) => {
            app.request_close();
        });

        window_gesture.pressed.connect((n_press, x, y) => {
            app.request_close();
        });

        GtkLayerShell.init_for_window(this);
        GtkLayerShell.set_namespace(this, "hypr-network-manager-dismiss");
        GtkLayerShell.set_layer(this, GtkLayerShell.Layer.TOP);
        GtkLayerShell.set_monitor(this, monitor);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.TOP, true);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.RIGHT, true);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.BOTTOM, true);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.LEFT, true);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.TOP, 0);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.RIGHT, 0);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.BOTTOM, 0);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.LEFT, 0);
        GtkLayerShell.set_keyboard_mode(this, GtkLayerShell.KeyboardMode.NONE);
        GtkLayerShell.set_exclusive_zone(this, -1);

        add_css_class("blank-window");
        var provider = new Gtk.CssProvider();
        provider.load_from_string(
            "window.blankwindow, .blank-window, .blank-window-surface {"
            + "background-color: transparent;"
            + "background: transparent;"
            + "box-shadow: none;"
            + "}"
        );
        var display = Gdk.Display.get_default();
        if (display != null) {
            blank_window_style_provider_add_for_display(
                display,
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 50
            );
        }
    }

    protected override void snapshot(Gtk.Snapshot snapshot) {
        int w = this.get_width();
        int h = this.get_height();
        if (w <= 0 || h <= 0) {
            w = 1;
            h = 1;
        }

        Gdk.RGBA color = Gdk.RGBA() { red = 0, green = 0, blue = 0, alpha = 0.0004f };
        snapshot.append_color(color, Graphene.Rect().init(0, 0, (float) w, (float) h));
    }
}
