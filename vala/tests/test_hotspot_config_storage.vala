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
using HyprNetworkManager.Models;

private class FakeHotspotSecretBackend : GLib.Object, HotspotSecretBackend {
    public string? stored_password = null;
    public bool fail_store = false;
    public bool fail_clear = false;
    public int lookup_calls = 0;

    public async string? lookup (Cancellable? cancellable) throws GLib.Error {
        lookup_calls++;
        return stored_password;
    }

    public async void store (string password, Cancellable? cancellable) throws GLib.Error {
        if (fail_store) {
            throw new IOError.FAILED ("simulated Secret Service store failure");
        }
        stored_password = password;
    }

    public async void clear (Cancellable? cancellable) throws GLib.Error {
        if (fail_clear) {
            throw new IOError.FAILED ("simulated Secret Service clear failure");
        }
        stored_password = null;
    }
}

private static string create_temp_config_path () {
    try {
        string state_home = DirUtils.make_tmp ("hynm-hotspot-storage.XXXXXX");
        return Path.build_filename (state_home, "hotspot.json");
    } catch (FileError e) {
        error ("Unable to create temporary state directory: %s", e.message);
    }
}

private static void remove_temp_config_path (string path) {
    FileUtils.remove (path);
    DirUtils.remove (Path.get_dirname (path));
}

private static GLib.Error? save_sync (HotspotConfig config) {
    GLib.Error? failure = null;
    var loop = new MainLoop ();
    HotspotConfigStorage.save.begin (config, null, (obj, res) => {
        try {
            HotspotConfigStorage.save.end (res);
        } catch (GLib.Error e) {
            failure = e;
        }
        loop.quit ();
    });
    loop.run ();
    return failure;
}

private static GLib.Error? load_sync (HotspotConfig config) {
    GLib.Error? failure = null;
    var loop = new MainLoop ();
    HotspotConfigStorage.load.begin (config, null, (obj, res) => {
        try {
            HotspotConfigStorage.load.end (res);
        } catch (GLib.Error e) {
            failure = e;
        }
        loop.quit ();
    });
    loop.run ();
    return failure;
}

private static void assert_success (GLib.Error? failure) {
    if (failure != null) {
        error ("Unexpected hotspot storage failure: %s", failure.message);
    }
}

private static void test_private_storage_mode () {
    string path = create_temp_config_path ();
    var secrets = new FakeHotspotSecretBackend ();
    HotspotConfigStorage.set_test_dependencies (path, secrets);

    var config = new HotspotConfig ();
    config.ssid = "Private AP";
    config.password = "private passphrase";
    assert_success (save_sync (config));

    FileInfo info;
    try {
        info = File.new_for_path (path).query_info (
            "unix::mode",
            FileQueryInfoFlags.NONE
        );
    } catch (GLib.Error e) {
        error ("Unable to inspect saved hotspot configuration: %s", e.message);
    }
    uint32 mode = info.get_attribute_uint32 ("unix::mode") & 0777;
    assert (mode == 0600);

    string raw_config;
    try {
        FileUtils.get_contents (path, out raw_config);
    } catch (GLib.Error e) {
        error ("Unable to read saved hotspot configuration: %s", e.message);
    }
    assert (!raw_config.contains (config.password));
    assert (raw_config.contains ("secret-service"));

    var loaded = new HotspotConfig ();
    assert_success (load_sync (loaded));
    assert (loaded.ssid == config.ssid);
    assert (loaded.password == config.password);

    remove_temp_config_path (path);
}

private static void test_local_fallback_overrides_stale_secret () {
    string path = create_temp_config_path ();
    var secrets = new FakeHotspotSecretBackend ();
    secrets.stored_password = "stale password";
    secrets.fail_store = true;
    HotspotConfigStorage.set_test_dependencies (path, secrets);

    var config = new HotspotConfig ();
    config.password = "current password";
    Test.expect_message (
        "hypr-nm.hotspot-storage",
        LogLevelFlags.LEVEL_WARNING,
        "*using the private local fallback*"
    );
    assert_success (save_sync (config));
    Test.assert_expected_messages ();

    var loaded = new HotspotConfig ();
    assert_success (load_sync (loaded));
    assert (loaded.password == config.password);
    assert (secrets.lookup_calls == 0);

    remove_temp_config_path (path);
}

private static void test_clear_failure_ignores_stale_secret () {
    string path = create_temp_config_path ();
    var secrets = new FakeHotspotSecretBackend ();
    secrets.stored_password = "stale password";
    secrets.fail_clear = true;
    HotspotConfigStorage.set_test_dependencies (path, secrets);

    var config = new HotspotConfig ();
    config.password = "";
    Test.expect_message (
        "hypr-nm.hotspot-storage",
        LogLevelFlags.LEVEL_WARNING,
        "*the local configuration will ignore it*"
    );
    assert_success (save_sync (config));
    Test.assert_expected_messages ();

    var loaded = new HotspotConfig ();
    assert_success (load_sync (loaded));
    assert (loaded.password == "");
    assert (secrets.lookup_calls == 0);

    remove_temp_config_path (path);
}

private static void test_permissions_failure () {
    string path = create_temp_config_path ();
    var secrets = new FakeHotspotSecretBackend ();
    HotspotConfigStorage.set_test_dependencies (path, secrets);

    DirUtils.create_with_parents (path, 0700);

    var config = new HotspotConfig ();
    config.ssid = "Test";
    assert (save_sync (config) != null);

    DirUtils.remove (path);
    DirUtils.remove (Path.get_dirname (path));
}

private static void test_malformed_json () {
    string path = create_temp_config_path ();
    var secrets = new FakeHotspotSecretBackend ();
    HotspotConfigStorage.set_test_dependencies (path, secrets);

    try {
        FileUtils.set_contents_full (
            path,
            "{ malformed json",
            -1,
            FileSetContentsFlags.CONSISTENT,
            0600
        );
    } catch (GLib.Error e) {
        error ("Failed to write malformed JSON: %s", e.message);
    }

    var loaded = new HotspotConfig ();
    loaded.ssid = "Fallback";
    assert (load_sync (loaded) != null);
    assert (loaded.ssid == "Fallback");

    remove_temp_config_path (path);
}

private static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/hotspot-config-storage/private-mode", test_private_storage_mode);
    Test.add_func (
        "/hotspot-config-storage/local-fallback-overrides-stale-secret",
        test_local_fallback_overrides_stale_secret
    );
    Test.add_func (
        "/hotspot-config-storage/clear-failure-ignores-stale-secret",
        test_clear_failure_ignores_stale_secret
    );
    Test.add_func ("/hotspot-config-storage/permissions-failure", test_permissions_failure);
    Test.add_func ("/hotspot-config-storage/malformed-json", test_malformed_json);
    return Test.run ();
}
