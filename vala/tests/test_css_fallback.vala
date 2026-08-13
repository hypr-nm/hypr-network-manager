/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using GLib;
using Gtk;

private const string RESOURCE_PREFIX =
    "/yeab212/hypr-network-manager/styles/";

private string read_style_resource (string filename) {
    try {
        Bytes bytes = resources_lookup_data (
            RESOURCE_PREFIX + filename,
            ResourceLookupFlags.NONE
        );
        return (string) bytes.get_data ();
    } catch (Error e) {
        Test.message ("Missing style resource %s: %s", filename, e.message);
        assert_not_reached ();
    }
}

private void test_embedded_default_theme () {
    string[] layers = {
        "structure.css",
        "core-components.css",
        "default-theme-tokens.css",
        "default-theme-overrides.css"
    };
    var css = new StringBuilder ();

    foreach (unowned string layer in layers) {
        string contents = read_style_resource (layer);
        assert (contents.strip () != "");
        css.append (contents);
        css.append_c ('\n');
    }

    bool parse_failed = false;
    var provider = new Gtk.CssProvider ();
    provider.parsing_error.connect ((section, error) => {
        parse_failed = true;
        Test.message ("Embedded fallback CSS failed to parse: %s", error.message);
    });
    provider.load_from_string (css.str);

    assert (!parse_failed);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/css/embedded-default-theme", test_embedded_default_theme);
    return Test.run ();
}
