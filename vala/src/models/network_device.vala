public class NetworkDevice : Object {
    public string name { get; construct set; }
    public uint32 device_type { get; construct set; }
    public uint32 state { get; construct set; }
    public string connection { get; construct set; }

    public bool is_ethernet {
        get {
            return device_type == NM_DEVICE_TYPE_ETHERNET;
        }
    }

    public bool is_wifi {
        get {
            return device_type == NM_DEVICE_TYPE_WIFI;
        }
    }

    public bool is_connected {
        get {
            return state == NM_DEVICE_STATE_ACTIVATED;
        }
    }

    public string state_label {
        owned get {
            if (state == NM_DEVICE_STATE_ACTIVATED) {
                return "Connected";
            }
            return "Disconnected";
        }
    }
}
