using GLib;
using Json;

public class HotspotConfigStorage : GLib.Object {
        private static string get_config_path () {
            string config_dir = GLib.Path.build_filename (Environment.get_user_state_dir (), "hypr-network-manager");
            if (!FileUtils.test (config_dir, FileTest.EXISTS)) {
                DirUtils.create_with_parents (config_dir, 0700);
            }
            FileUtils.chmod (config_dir, 0700);
            return GLib.Path.build_filename (config_dir, "hotspot.json");
        }

        public static void load (HyprNetworkManager.Models.HotspotConfig config) {
            string path = get_config_path ();
            if (!FileUtils.test (path, FileTest.EXISTS)) return;
            FileUtils.chmod (path, 0600);
            
            try {
                string content;
                FileUtils.get_contents (path, out content);
                var parser = new Json.Parser ();
                parser.load_from_data (content, -1);
                
                var root = parser.get_root ();
                if (root != null && root.get_node_type () == Json.NodeType.OBJECT) {
                    var obj = root.get_object ();
                    
                    if (obj.has_member ("ssid")) config.ssid = obj.get_string_member ("ssid");
                    if (obj.has_member ("password")) config.password = obj.get_string_member ("password");
                    if (obj.has_member ("security")) config.security = obj.get_string_member ("security");
                    if (obj.has_member ("band")) config.band = obj.get_string_member ("band");
                    if (obj.has_member ("is_hidden")) config.is_hidden = obj.get_boolean_member ("is_hidden");
                    if (obj.has_member ("timeout")) config.timeout = (int) obj.get_int_member ("timeout");
                    if (obj.has_member ("ap_interface")) config.ap_interface = obj.get_string_member ("ap_interface");
                    if (obj.has_member ("uplink_interface")) config.uplink_interface = obj.get_string_member ("uplink_interface");
                }
            } catch (Error e) {
                warning ("Failed to load hotspot config: %s", e.message);
            }
        }

        public static void save (HyprNetworkManager.Models.HotspotConfig config) {
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();
                
                builder.set_member_name ("ssid");
                builder.add_string_value (config.ssid);
                
                builder.set_member_name ("password");
                builder.add_string_value (config.password);
                
                builder.set_member_name ("security");
                builder.add_string_value (config.security);
                
                builder.set_member_name ("band");
                builder.add_string_value (config.band);
                
                builder.set_member_name ("is_hidden");
                builder.add_boolean_value (config.is_hidden);
                
                builder.set_member_name ("timeout");
                builder.add_int_value (config.timeout);
                
                builder.set_member_name ("ap_interface");
                builder.add_string_value (config.ap_interface);
                
                builder.set_member_name ("uplink_interface");
                builder.add_string_value (config.uplink_interface);
                
                builder.end_object ();
                
                var generator = new Json.Generator ();
                var root = builder.get_root ();
                generator.set_root (root);
                generator.pretty = true;
                
                string content = generator.to_data (null);
                string path = get_config_path ();
                FileUtils.set_contents_full (
                    path,
                    content,
                    -1,
                    FileSetContentsFlags.CONSISTENT,
                    0600);
                FileUtils.chmod (path, 0600);
            } catch (Error e) {
                warning ("Failed to save hotspot config: %s", e.message);
            }
        }
    }
