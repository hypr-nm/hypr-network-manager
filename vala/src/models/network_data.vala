/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

public class WifiRefreshData : GLib.Object {
    public WifiNetwork[] networks;
    public NetworkDevice[] devices;
    public bool is_hotspot_active;
    public int num_wifi_devices;

    public WifiRefreshData (
        WifiNetwork[] networks,
        NetworkDevice[] devices,
        bool is_hotspot_active = false,
        int num_wifi_devices = 0
    ) {
        this.networks = networks;
        this.devices = devices;
        this.is_hotspot_active = is_hotspot_active;
        this.num_wifi_devices = num_wifi_devices;
    }
}

public class WifiScanData : GLib.Object {
    public WifiNetwork[] networks;
    public NetworkDevice[] devices;
    public int num_wifi_devices;

    public WifiScanData (
        WifiNetwork[] networks,
        NetworkDevice[] devices,
        int num_wifi_devices = 0
    ) {
        this.networks = networks;
        this.devices = devices;
        this.num_wifi_devices = num_wifi_devices;
    }
}

public class WifiBandSupport : GLib.Object {
    public bool supports_2ghz;
    public bool supports_5ghz;

    public WifiBandSupport (bool supports_2ghz, bool supports_5ghz) {
        this.supports_2ghz = supports_2ghz;
        this.supports_5ghz = supports_5ghz;
    }
}
