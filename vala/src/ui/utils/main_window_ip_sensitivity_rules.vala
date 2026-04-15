namespace MainWindowIpSensitivityRules {
    public bool should_show_manual_fields (uint selected_method) {
        return selected_method == 1;
    }

    public bool should_show_override_fields (uint selected_method) {
        return selected_method == 0 || selected_method == 1;
    }

    public bool should_force_ipv4_dns_auto_from_dropdown (uint selected_method) {
        return selected_method == 2;
    }

    public bool should_force_ipv6_dns_auto_from_dropdown (uint selected_method) {
        return selected_method == 2 || selected_method == 3;
    }

    public bool is_dns_entry_sensitive (bool dns_auto_enabled) {
        return !dns_auto_enabled;
    }

    public bool should_force_ipv4_dns_auto_from_method (string method) {
        return method == "disabled";
    }

    public bool should_force_ipv6_dns_auto_from_method (string method) {
        return method == "disabled" || method == "ignore";
    }
}
