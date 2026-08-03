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

internal interface HotspotSecretBackend : GLib.Object {
    public abstract async string? lookup (Cancellable? cancellable) throws GLib.Error;
    public abstract async void store (string password, Cancellable? cancellable) throws GLib.Error;
    public abstract async void clear (Cancellable? cancellable) throws GLib.Error;
}

private class LibsecretHotspotSecretBackend : GLib.Object, HotspotSecretBackend {
    private const string SCHEMA_NAME = "org.hypr_network_manager.Hotspot";
    private const string ATTRIBUTE_NAME = "uuid";
    private const string ATTRIBUTE_VALUE = "hotspot";
    private const string SECRET_LABEL = "Hypr Network Manager Hotspot";

    private Secret.Schema schema;

    public LibsecretHotspotSecretBackend () {
        schema = new Secret.Schema (
            SCHEMA_NAME,
            Secret.SchemaFlags.NONE,
            ATTRIBUTE_NAME,
            Secret.SchemaAttributeType.STRING
        );
    }

    public async string? lookup (Cancellable? cancellable) throws GLib.Error {
        return yield Secret.password_lookup (
            schema,
            cancellable,
            ATTRIBUTE_NAME,
            ATTRIBUTE_VALUE
        );
    }

    public async void store (string password, Cancellable? cancellable) throws GLib.Error {
        yield Secret.password_store (
            schema,
            Secret.COLLECTION_DEFAULT,
            SECRET_LABEL,
            password,
            cancellable,
            ATTRIBUTE_NAME,
            ATTRIBUTE_VALUE
        );
    }

    public async void clear (Cancellable? cancellable) throws GLib.Error {
        yield Secret.password_clear (
            schema,
            cancellable,
            ATTRIBUTE_NAME,
            ATTRIBUTE_VALUE
        );
    }
}

public class HotspotConfigStorage : GLib.Object {
    private const string APPLICATION_DIRECTORY = "hypr-network-manager";
    private const string CONFIG_FILE_NAME = "hotspot.json";
    private const int CONFIG_DIRECTORY_MODE = 0700;
    private const int CONFIG_FILE_MODE = 0600;

    private const string KEY_SSID = "ssid";
    private const string KEY_PASSWORD = "password";
    private const string KEY_PASSWORD_STORAGE = "password_storage";
    private const string KEY_SECURITY = "security";
    private const string KEY_BAND = "band";
    private const string KEY_IS_HIDDEN = "is_hidden";
    private const string KEY_TIMEOUT = "timeout";
    private const string KEY_AP_INTERFACE = "ap_interface";
    private const string KEY_UPLINK_INTERFACE = "uplink_interface";

    private const string PASSWORD_STORAGE_SECRET_SERVICE = "secret-service";
    private const string PASSWORD_STORAGE_LOCAL = "local";
    private const string PASSWORD_STORAGE_NONE = "none";
    private const string FALLBACK_MACHINE_ID = "hypr-nm-fallback-id-12345";

    private static string? config_path_override = null;
    private static HotspotSecretBackend? secret_backend = null;

#if HOTSPOT_STORAGE_TESTS
    internal static void set_test_dependencies (
        string? config_path,
        HotspotSecretBackend? backend
    ) {
        config_path_override = config_path;
        secret_backend = backend;
    }
#endif

    private static HotspotSecretBackend get_secret_backend () {
        if (secret_backend == null) {
            secret_backend = new LibsecretHotspotSecretBackend ();
        }
        return secret_backend;
    }

    private static void throw_if_cancelled (Cancellable? cancellable) throws IOError {
        if (cancellable != null && cancellable.is_cancelled ()) {
            throw new IOError.CANCELLED ("Hotspot configuration operation was cancelled");
        }
    }

    private static string get_machine_id () {
        try {
            string content;
            FileUtils.get_contents ("/etc/machine-id", out content);
            string machine_id = content.strip ();
            return machine_id != "" ? machine_id : FALLBACK_MACHINE_ID;
        } catch (GLib.Error e) {
            return FALLBACK_MACHINE_ID;
        }
    }

    private static string obfuscate_password (string password) {
        if (password == "") return "";

        string key = get_machine_id ();
        uint8[] data = new uint8[password.length];
        for (int i = 0; i < password.length; i++) {
            data[i] = ((uint8) password[i]) ^ ((uint8) key[i % key.length]);
        }
        return GLib.Base64.encode (data);
    }

    private static string deobfuscate_password (string encoded_password) {
        if (encoded_password == "") return "";

        uint8[] decoded = GLib.Base64.decode (encoded_password);
        string key = get_machine_id ();
        var result = new StringBuilder ();
        for (int i = 0; i < decoded.length; i++) {
            result.append_c ((char) (decoded[i] ^ ((uint8) key[i % key.length])));
        }
        return result.str;
    }

    private static string get_config_path () throws GLib.Error {
        if (config_path_override != null) {
            return config_path_override;
        }

        string config_dir = GLib.Path.build_filename (
            Environment.get_user_state_dir (),
            APPLICATION_DIRECTORY
        );
        if (!FileUtils.test (config_dir, FileTest.EXISTS)
            && DirUtils.create_with_parents (config_dir, CONFIG_DIRECTORY_MODE) != 0) {
            throw new IOError.FAILED ("Could not create config directory");
        }
        if (FileUtils.chmod (config_dir, CONFIG_DIRECTORY_MODE) != 0) {
            throw new IOError.FAILED ("Could not set config directory permissions");
        }
        return GLib.Path.build_filename (config_dir, CONFIG_FILE_NAME);
    }

    private static async string? lookup_secret_password (
        Cancellable? cancellable
    ) throws GLib.Error {
        try {
            return yield get_secret_backend ().lookup (cancellable);
        } catch (IOError.CANCELLED e) {
            throw e;
        } catch (GLib.Error e) {
            global::log_debug (
                "hotspot-storage",
                "Could not read hotspot password from Secret Service: " + e.message
            );
            return null;
        }
    }

    public static async void load (
        HyprNetworkManager.Models.HotspotConfig config,
        Cancellable? cancellable = null
    ) throws GLib.Error {
        throw_if_cancelled (cancellable);
        string path = get_config_path ();
        if (!FileUtils.test (path, FileTest.EXISTS)) return;

        string content;
        FileUtils.get_contents (path, out content);
        var parser = new Json.Parser ();
        parser.load_from_data (content, -1);

        var root = parser.get_root ();
        if (root == null || root.get_node_type () != Json.NodeType.OBJECT) return;

        var obj = root.get_object ();
        if (obj.has_member (KEY_SSID)) {
            config.ssid = obj.get_string_member (KEY_SSID).strip ();
        }
        if (obj.has_member (KEY_SECURITY)) {
            string security = obj.get_string_member (KEY_SECURITY).strip ();
            if (security == Constants.WifiKeyMgmt.NONE
                || security == Constants.WifiKeyMgmt.WPA_PSK
                || security == Constants.WifiKeyMgmt.SAE) {
                config.security = security;
            }
        }
        if (obj.has_member (KEY_BAND)) {
            string band = obj.get_string_member (KEY_BAND).strip ();
            if (band == Constants.WifiBand.BAND_2GHZ
                || band == Constants.WifiBand.BAND_5GHZ) {
                config.band = band;
            }
        }
        if (obj.has_member (KEY_IS_HIDDEN)) {
            config.is_hidden = obj.get_boolean_member (KEY_IS_HIDDEN);
        }
        if (obj.has_member (KEY_TIMEOUT)) {
            int timeout = (int) obj.get_int_member (KEY_TIMEOUT);
            if (Constants.HotspotTimeout.is_valid (timeout)) {
                config.timeout = timeout;
            }
        }
        if (obj.has_member (KEY_AP_INTERFACE)) {
            config.ap_interface = obj.get_string_member (KEY_AP_INTERFACE).strip ();
        }
        if (obj.has_member (KEY_UPLINK_INTERFACE)) {
            config.uplink_interface = obj.get_string_member (KEY_UPLINK_INTERFACE).strip ();
        }

        string password_storage = obj.has_member (KEY_PASSWORD_STORAGE)
            ? obj.get_string_member (KEY_PASSWORD_STORAGE)
            : "";

        if (password_storage == PASSWORD_STORAGE_NONE) {
            config.password = "";
        } else if (password_storage == PASSWORD_STORAGE_LOCAL) {
            if (obj.has_member (KEY_PASSWORD)) {
                config.password = deobfuscate_password (
                    obj.get_string_member (KEY_PASSWORD)
                );
            }
        } else if (password_storage == PASSWORD_STORAGE_SECRET_SERVICE) {
            string? secret_password = yield lookup_secret_password (cancellable);
            if (secret_password != null) {
                config.password = secret_password;
            }
        } else {
            string? secret_password = yield lookup_secret_password (cancellable);
            if (secret_password != null) {
                config.password = secret_password;
            } else if (obj.has_member (KEY_PASSWORD)) {
                config.password = deobfuscate_password (
                    obj.get_string_member (KEY_PASSWORD)
                );
            }
        }
    }

    public static async void save (
        HyprNetworkManager.Models.HotspotConfig config,
        Cancellable? cancellable = null
    ) throws GLib.Error {
        throw_if_cancelled (cancellable);

        string password_storage = PASSWORD_STORAGE_NONE;
        string? local_password = null;

        if (config.password != "") {
            try {
                yield get_secret_backend ().store (config.password, cancellable);
                password_storage = PASSWORD_STORAGE_SECRET_SERVICE;
            } catch (IOError.CANCELLED e) {
                throw e;
            } catch (GLib.Error e) {
                password_storage = PASSWORD_STORAGE_LOCAL;
                local_password = obfuscate_password (config.password);
                global::log_warn (
                    "hotspot-storage",
                    "Could not store hotspot password in Secret Service; using the private local fallback: "
                        + e.message
                );
            }
        } else {
            try {
                yield get_secret_backend ().clear (cancellable);
            } catch (IOError.CANCELLED e) {
                throw e;
            } catch (GLib.Error e) {
                global::log_warn (
                    "hotspot-storage",
                    "Could not clear the old Secret Service hotspot password; the local configuration will ignore it: "
                        + e.message
                );
            }
        }

        throw_if_cancelled (cancellable);

        var builder = new Json.Builder ();
        builder.begin_object ();

        builder.set_member_name (KEY_SSID);
        builder.add_string_value (config.ssid);

        builder.set_member_name (KEY_PASSWORD_STORAGE);
        builder.add_string_value (password_storage);

        if (local_password != null) {
            builder.set_member_name (KEY_PASSWORD);
            builder.add_string_value (local_password);
        }

        builder.set_member_name (KEY_SECURITY);
        builder.add_string_value (config.security);

        builder.set_member_name (KEY_BAND);
        builder.add_string_value (config.band);

        builder.set_member_name (KEY_IS_HIDDEN);
        builder.add_boolean_value (config.is_hidden);

        builder.set_member_name (KEY_TIMEOUT);
        builder.add_int_value (config.timeout);

        builder.set_member_name (KEY_AP_INTERFACE);
        builder.add_string_value (config.ap_interface);

        builder.set_member_name (KEY_UPLINK_INTERFACE);
        builder.add_string_value (config.uplink_interface);

        builder.end_object ();

        var generator = new Json.Generator ();
        generator.set_root (builder.get_root ());
        generator.pretty = true;

        string path = get_config_path ();
        FileUtils.set_contents_full (
            path,
            generator.to_data (null),
            -1,
            FileSetContentsFlags.CONSISTENT,
            CONFIG_FILE_MODE
        );

        if (FileUtils.chmod (path, CONFIG_FILE_MODE) != 0) {
            throw new IOError.FAILED ("Could not set config file permissions");
        }
    }
}
