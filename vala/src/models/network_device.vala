public class NetworkDevice : Object {
    public string name { get; construct set; }
    public string device_path { get; construct set; }
    public uint32 device_type { get; construct set; }
    public uint32 state { get; construct set; }
    public string connection { get; construct set; }
    public string connection_uuid { get; construct set; }

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

    public bool is_connecting {
        get {
            return state >= 40 && state < NM_DEVICE_STATE_ACTIVATED;
        }
    }

    public string state_label {
        owned get {
            switch (state) {
            case 10:
                return "Unknown";
            case 20:
                return "Unavailable";
            case 30:
                return "Disconnected";
            case 40:
                return "Preparing";
            case 50:
                return "Configuring";
            case 60:
                return "Auth required";
            case 70:
                return "IP configuring";
            case 80:
                return "IP checking";
            case 90:
                return "Secondaries";
            case 100:
                return "Connected";
            case 110:
                return "Disconnecting";
            case 120:
                return "Failed";
            default:
                return _("State %u").printf (state);
            }
        }
    }
}
