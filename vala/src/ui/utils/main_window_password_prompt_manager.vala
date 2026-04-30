using Gtk;

public class MainWindowPasswordPromptManager : Object {
    private Gtk.Revealer? active_revealer = null;
    private Gtk.Entry? active_entry = null;

    public void show_prompt (
        Gtk.Revealer revealer,
        Gtk.Entry entry
    ) {
        if (active_revealer != null && active_revealer != revealer) {
            active_revealer.set_reveal_child (false);
        }

        if (active_entry != null && active_entry != entry) {
            active_entry.set_text ("");
        }

        active_revealer = revealer;
        active_entry = entry;
        entry.set_text ("");
        entry.set_visibility (false);
        entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        MainWindowIconResources.set_password_visibility_icon (entry, false);
        entry.set_icon_tooltip_text (Gtk.EntryIconPosition.SECONDARY, _("Show password"));
        revealer.set_reveal_child (true);
        entry.grab_focus ();
    }

    public bool hide_prompt (
        Gtk.Revealer revealer,
        Gtk.Entry entry,
        string? value
    ) {
        revealer.set_reveal_child (false);
        if (value == null) {
            entry.set_text ("");
        }

        if (active_revealer == revealer) {
            active_revealer = null;
            active_entry = null;
            return true;
        }
        return false;
    }

    public bool hide_active_prompt () {
        if (active_revealer != null) {
            active_revealer.set_reveal_child (false);
        }
        if (active_entry != null) {
            active_entry.set_text ("");
        }

        bool had_active = active_revealer != null;
        active_revealer = null;
        active_entry = null;
        return had_active;
    }
}
