public class MainWindowIpConfigHelper : Object {
    public static uint method_to_index (string method, bool is_ipv4 = true) {
        string m = method.down ();
        if (is_ipv4) {
            if (m == "auto") return 0;
            if (m == "manual") return 1;
            if (m == "disabled") return 2;
            return 0;
        } else {
            if (m == "auto") return 0;
            if (m == "manual") return 1;
            if (m == "disabled") return 2;
            if (m == "ignore") return 3;
            return 0;
        }
    }

    public static string index_to_method (uint index, bool is_ipv4 = true) {
        if (is_ipv4) {
            switch (index) {
                case 0: return "auto";
                case 1: return "manual";
                case 2: return "disabled";
                default: return "auto";
            }
        } else {
            switch (index) {
                case 0: return "auto";
                case 1: return "manual";
                case 2: return "disabled";
                case 3: return "ignore";
                default: return "auto";
            }
        }
    }
}
