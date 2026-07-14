## create_ap (vendored)

This directory contains a verbatim copy of the `create_ap` script used by this
project to provision Wi-Fi access points (hostapd + dnsmasq + iptables) when the
"share internet" hotspot path is selected.

The files here are **unmodified** copies taken verbatim from the upstream
project so that bug fixes and features can be cherry-picked from upstream in
the future. The only change is the directory layout.

### Provenance

- **Upstream project:** linux-wifi-hotspot
- **Upstream repository:** https://github.com/lakinduakash/linux-wifi-hotspot
- **Original author of `create_ap`:** @oblique (https://github.com/oblique)
- **Maintainer of the linux-wifi-hotspot fork:** lakinduakash
- **Commit at time of vendoring:** `8182f4a`
- **License:** BSD-2-Clause (see `LICENSE` in this directory)

### License summary

Copyright (c) 2013, oblique
Copyright (c) 2023, lakinduaksh

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the conditions in `LICENSE` are met.

### Updating

To pick up upstream fixes:

    git clone https://github.com/lakinduakash/linux-wifi-hotspot /tmp/lwh
    cp /tmp/lwh/src/scripts/create_ap scripts/create_ap/create_ap
    cp /tmp/lwh/src/scripts/LICENSE scripts/create_ap/LICENSE

Then verify the diff and rebuild.