namespace NetworkManagerRebuild.Models {

    /**
     * Context for application window configuration, dimensions, 
     */
    public class WindowConfigContext : Object {
        public const int MIN_WINDOW_WIDTH = 480;
        public const int MIN_WINDOW_HEIGHT = 680;

        public int window_width { get; set; default = MIN_WINDOW_WIDTH; }
        public int window_height { get; set; default = MIN_WINDOW_HEIGHT; }
        public bool anchor_top { get; set; default = false; }
        public bool anchor_right { get; set; default = false; }
        public bool anchor_bottom { get; set; default = false; }
        public bool anchor_left { get; set; default = false; }
        
        public int shell_margin_top { get; set; default = 0; }
        public int shell_margin_right { get; set; default = 0; }
        public int shell_margin_bottom { get; set; default = 0; }
        public int shell_margin_left { get; set; default = 0; }
        public string shell_layer { get; set; default = "top"; }
        
        public uint refresh_interval_seconds { get; set; default = 30; }
        public uint pending_wifi_connect_timeout_ms { get; set; default = 45000; }
        public bool close_on_connect { get; set; default = false; }
        
        public bool show_bssid { get; set; default = false; }
        public bool show_frequency { get; set; default = false; }
        public bool show_band { get; set; default = false; }

        public WindowConfigContext (Json.Node? config_node) {
            if (config_node == null || config_node.get_node_type() != Json.NodeType.OBJECT) {
                return;
            }

            var config = config_node.get_object();

            if (config.has_member("window")) {
                var window_config = config.get_object_member("window");
                
                if (window_config.has_member("width")) {
                    this.window_width = (int)int64.max(MIN_WINDOW_WIDTH, window_config.get_int_member("width"));
                }
                
                if (window_config.has_member("height")) {
                    this.window_height = (int)int64.max(MIN_WINDOW_HEIGHT, window_config.get_int_member("height"));
                }
                
                if (window_config.has_member("anchor")) {
                    var anchor = window_config.get_object_member("anchor");
                    this.anchor_top = anchor.has_member("top") ? anchor.get_boolean_member("top") : false;
                    this.anchor_right = anchor.has_member("right") ? anchor.get_boolean_member("right") : false;
                    this.anchor_bottom = anchor.has_member("bottom") ? anchor.get_boolean_member("bottom") : false;
                    this.anchor_left = anchor.has_member("left") ? anchor.get_boolean_member("left") : false;
                }
                
                if (window_config.has_member("margin")) {
                    var margin = window_config.get_object_member("margin");
                    this.shell_margin_top = margin.has_member("top") ? (int)margin.get_int_member("top") : 0;
                    this.shell_margin_right = margin.has_member("right") ? (int)margin.get_int_member("right") : 0;
                    this.shell_margin_bottom = margin.has_member("bottom") ? (int)margin.get_int_member("bottom") : 0;
                    this.shell_margin_left = margin.has_member("left") ? (int)margin.get_int_member("left") : 0;
                }
                
                if (window_config.has_member("layer")) {
                    this.shell_layer = window_config.get_string_member("layer");
                }
            }

            if (config.has_member("behavior")) {
                var behavior = config.get_object_member("behavior");
                if (behavior.has_member("scan_interval")) {
                    this.refresh_interval_seconds = (uint)behavior.get_int_member("scan_interval");
                }
                if (behavior.has_member("close_on_connect")) {
                    this.close_on_connect = behavior.get_boolean_member("close_on_connect");
                }
            }
            
            if (config.has_member("display")) {
                var display = config.get_object_member("display");
                if (display.has_member("show_bssid")) {
                    this.show_bssid = display.get_boolean_member("show_bssid");
                }
                if (display.has_member("show_frequency")) {
                    this.show_frequency = display.get_boolean_member("show_frequency");
                }
                if (display.has_member("show_band")) {
                    this.show_band = display.get_boolean_member("show_band");
                }
            }

            // Provide sane defaults if parsing missed anything critical
            if (this.refresh_interval_seconds < 1) {
                this.refresh_interval_seconds = 30; // 30 sec fallback
            }
            if (this.pending_wifi_connect_timeout_ms <= 0) {
                this.pending_wifi_connect_timeout_ms = 45000;
            }
        }
    }
}