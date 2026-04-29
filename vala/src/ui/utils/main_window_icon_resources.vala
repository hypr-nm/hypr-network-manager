using Gtk;
using Gdk;
using GLib;

namespace MainWindowIconResources {
    private const string ICON_PASSWORD_HIDDEN = "view-visible-symbolic";
    private const string ICON_PASSWORD_VISIBLE = "view-visible-off-symbolic";
    private const string ICON_COLLAPSED = "expand-element-symbolic";
    private const string ICON_EXPANDED = "collapse-element-symbolic";
    private const string ICON_AIRPLANE = "network-flightmode-on-symbolic";
    private const string ICON_WIFI_EMPTY = "network-wireless-offline-symbolic";
    private const string ICON_WIFI_DISABLED = "network-wireless-disabled-symbolic";
    private const string ICON_ETHERNET_EMPTY = "network-ethernet-offline-symbolic";
    private const string ICON_SECURE_LOCK = "network-wireless-encrypted-symbolic";
    
    private const string ICON_MENU_MORE = "view-more-symbolic";
    private const string ICON_DROPDOWN_TRIGGER = "pan-down-symbolic";
    private const string ICON_DROPDOWN_CHECK = "object-select-symbolic";

    private const string RESOURCE_PASSWORD_HIDDEN = (
        "/yeab212/hypr-network-manager/icons/hicolor/symbolic/actions/view-visible-symbolic.svg");
    private const string RESOURCE_PASSWORD_VISIBLE = (
        "/yeab212/hypr-network-manager/icons/hicolor/symbolic/actions/view-visible-off-symbolic.svg");

    private const string FALLBACK_PASSWORD_HIDDEN = "view-reveal-symbolic";
    private const string FALLBACK_PASSWORD_VISIBLE = "view-conceal-symbolic";
    private const string FALLBACK_COLLAPSED = "pan-up-symbolic";
    private const string FALLBACK_EXPANDED = "pan-down-symbolic";
    private const string FALLBACK_AIRPLANE = "airplane-mode";
    private const string FALLBACK_WIFI_EMPTY = "network-wireless-offline";
    private const string FALLBACK_WIFI_DISABLED = "network-wireless-disabled";
    private const string FALLBACK_ETHERNET_EMPTY = "network-ethernet-offline";
    private const string FALLBACK_SECURE_LOCK = "changes-prevent-symbolic";
    private const string FALLBACK_MENU_MORE = "view-more-symbolic";
    private const string FALLBACK_DROPDOWN_TRIGGER = "pan-down-symbolic";
    private const string FALLBACK_DROPDOWN_CHECK = "object-select-symbolic";

    public enum NetworkPlaceholderIcon {
        WIFI_EMPTY,
        WIFI_DISABLED,
        ETHERNET_EMPTY,
        FLIGHT_MODE
    }

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

    public Gtk.Image create_network_placeholder_icon (NetworkPlaceholderIcon icon_type) {
        // Explicitly define arrays to ensure Vala passes them correctly to GIO
        string[] wifi_empty = {ICON_WIFI_EMPTY, FALLBACK_WIFI_EMPTY};
        string[] wifi_disabled = {ICON_WIFI_DISABLED, FALLBACK_WIFI_DISABLED};
        string[] ethernet_empty = {ICON_ETHERNET_EMPTY, FALLBACK_ETHERNET_EMPTY};
        string[] flight_mode = { ICON_AIRPLANE, FALLBACK_AIRPLANE };

        switch (icon_type) {
        case NetworkPlaceholderIcon.WIFI_EMPTY:
            return new Gtk.Image.from_gicon (new ThemedIcon.from_names (wifi_empty));

        case NetworkPlaceholderIcon.WIFI_DISABLED:
            return new Gtk.Image.from_gicon (new ThemedIcon.from_names (wifi_disabled));

        case NetworkPlaceholderIcon.ETHERNET_EMPTY:
            return new Gtk.Image.from_gicon (new ThemedIcon.from_names (ethernet_empty));

        case NetworkPlaceholderIcon.FLIGHT_MODE:
        default:
            // This ensures the ThemedIcon logic prioritizes your list
            var icon = new ThemedIcon.from_names (flight_mode);
            return new Gtk.Image.from_gicon (icon);
        }
    }

    public Gtk.Image create_menu_more_icon () {
        string[] names = {ICON_MENU_MORE, FALLBACK_MENU_MORE};
        return new Gtk.Image.from_gicon (new ThemedIcon.from_names (names));
    }

    public Gtk.Image create_dropdown_trigger_icon () {
        string[] names = {ICON_DROPDOWN_TRIGGER, FALLBACK_DROPDOWN_TRIGGER};
        return new Gtk.Image.from_gicon (new ThemedIcon.from_names (names));
    }

    public Gtk.Image create_dropdown_check_icon () {
        string[] names = {ICON_DROPDOWN_CHECK, FALLBACK_DROPDOWN_CHECK};
        return new Gtk.Image.from_gicon (new ThemedIcon.from_names (names));
    }

    public Gtk.Image create_secure_lock_icon () {
        string[] names = {ICON_SECURE_LOCK, FALLBACK_SECURE_LOCK};
        return new Gtk.Image.from_gicon (new ThemedIcon.from_names (names));
    }
}
