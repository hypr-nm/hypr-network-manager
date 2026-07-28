/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using Constants;
using GLib;
using HyprNetworkManager.Models;

private static void test_private_storage_mode () {
    string state_home;
    try {
        state_home = DirUtils.make_tmp ("hynm-hotspot-storage.XXXXXX");
    } catch (FileError e) {
        error ("Unable to create temporary state directory: %s", e.message);
    }
    Environment.set_variable ("XDG_STATE_HOME", state_home, true);

    var config = new HotspotConfig ();
    config.ssid = "Private AP";
    config.password = "private passphrase";
    HotspotConfigStorage.save (config);

    string directory = Path.build_filename (
        state_home,
        "hypr-network-manager");
    string path = Path.build_filename (directory, "hotspot.json");
    FileInfo info;
    try {
        info = File.new_for_path (path).query_info (
            "unix::mode",
            FileQueryInfoFlags.NONE);
    } catch (Error e) {
        error ("Unable to inspect saved hotspot configuration: %s", e.message);
    }
    uint32 mode = info.get_attribute_uint32 ("unix::mode") & 0777;
    assert (mode == 0600);

    FileUtils.remove (path);
    DirUtils.remove (directory);
    DirUtils.remove (state_home);
}

private static int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/hotspot-config-storage/private-mode",
        test_private_storage_mode);
    return Test.run ();
}
