using Gtk;
using Gdk;

namespace MainWindowIconResources {
    private const string ICON_PASSWORD_HIDDEN = "view-visible-symbolic";
    private const string ICON_PASSWORD_VISIBLE = "view-visible-off-symbolic";
    private const string ICON_COLLAPSED = "collapse-element-symbolic";
    private const string ICON_EXPANDED = "expand-element-symbolic";

    private const string RESOURCE_PASSWORD_HIDDEN = "/yeab212/hypr-network-manager/icons/hicolor/symbolic/actions/view-visible-symbolic.svg";
    private const string RESOURCE_PASSWORD_VISIBLE = "/yeab212/hypr-network-manager/icons/hicolor/symbolic/actions/view-visible-off-symbolic.svg";

    private const string FALLBACK_PASSWORD_HIDDEN = "view-reveal-symbolic";
    private const string FALLBACK_PASSWORD_VISIBLE = "view-conceal-symbolic";
    private const string FALLBACK_COLLAPSED = "pan-down-symbolic";
    private const string FALLBACK_EXPANDED = "pan-up-symbolic";

    private bool looked_up = false;
    private bool has_password_hidden = false;
    private bool has_password_visible = false;
    private bool has_collapsed = false;
    private bool has_expanded = false;

    private Gdk.Paintable? password_hidden_paintable = null;
    private Gdk.Paintable? password_visible_paintable = null;

    private bool resource_exists (string path) {
        size_t size = 0;
        uint32 flags = 0;
        try {
            return GLib.resources_get_info (
                path,
                GLib.ResourceLookupFlags.NONE,
                out size,
                out flags
            );
        } catch (Error e) {
            return false;
        }
    }

    private void ensure_icon_availability () {
        if (looked_up) {
            return;
        }

        looked_up = true;
        var display = Gdk.Display.get_default ();
        if (display == null) {
            return;
        }

        var icon_theme = Gtk.IconTheme.get_for_display (display);
        has_password_hidden = icon_theme.has_icon (ICON_PASSWORD_HIDDEN);
        has_password_visible = icon_theme.has_icon (ICON_PASSWORD_VISIBLE);
        has_collapsed = icon_theme.has_icon (ICON_COLLAPSED);
        has_expanded = icon_theme.has_icon (ICON_EXPANDED);

        if (!has_password_hidden && resource_exists (RESOURCE_PASSWORD_HIDDEN)) {
            password_hidden_paintable = Gdk.Texture.from_resource (RESOURCE_PASSWORD_HIDDEN);
        }
        if (!has_password_visible && resource_exists (RESOURCE_PASSWORD_VISIBLE)) {
            password_visible_paintable = Gdk.Texture.from_resource (RESOURCE_PASSWORD_VISIBLE);
        }
    }

    public void set_password_visibility_icon (Gtk.Entry entry, bool password_visible) {
        ensure_icon_availability ();

        if (password_visible) {
            if (has_password_visible) {
                entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, ICON_PASSWORD_VISIBLE);
                return;
            }
            if (password_visible_paintable != null) {
                entry.set_icon_from_paintable (Gtk.EntryIconPosition.SECONDARY, password_visible_paintable);
                return;
            }
            entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, FALLBACK_PASSWORD_VISIBLE);
            return;
        }

        if (has_password_hidden) {
            entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, ICON_PASSWORD_HIDDEN);
            return;
        }
        if (password_hidden_paintable != null) {
            entry.set_icon_from_paintable (Gtk.EntryIconPosition.SECONDARY, password_hidden_paintable);
            return;
        }
        entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, FALLBACK_PASSWORD_HIDDEN);
    }

    public void set_expand_indicator_icon (Gtk.Image image, bool expanded) {
        ensure_icon_availability ();

        image.set_from_icon_name (
            expanded
                ? (has_expanded ? ICON_EXPANDED : FALLBACK_EXPANDED)
                : (has_collapsed ? ICON_COLLAPSED : FALLBACK_COLLAPSED)
        );
    }
}
