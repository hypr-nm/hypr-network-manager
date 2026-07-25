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

#ifndef NM_NL80211_CLIENT_H
#define NM_NL80211_CLIENT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct nl_msg;

enum nm_nl80211_band {
    NM_NL80211_BAND_NONE = 0,
    NM_NL80211_BAND_2GHZ = 2,
    NM_NL80211_BAND_5GHZ = 5,
};

/* Classify a center frequency without conflating 6 GHz with 5 GHz. */
int nm_nl80211_frequency_band (uint32_t frequency_mhz);

/*
 * Parse band support from one nl80211 generic-netlink wiphy message.
 * Returns 0 when bands were parsed, 1 when the message had no band
 * attribute, and -1 for malformed input.
 */
int nm_nl80211_parse_band_support_message (struct nl_msg *message,
                                           int *supports_2ghz,
                                           int *supports_5ghz);

/*
 * Parse one nl80211 interface response. Returns 0 for a complete record,
 * 1 when required interface attributes are absent, and -1 when malformed.
 */
int nm_nl80211_parse_interface_message (struct nl_msg *message,
                                        uint32_t *ifindex,
                                        uint32_t *wiphy,
                                        uint32_t *iftype);

/*
 * Returns 1 for a complete station response, 0 when station attributes are
 * absent, and -1 when malformed.
 */
int nm_nl80211_parse_station_message (struct nl_msg *message);

/*
 * Query 2.4 GHz / 5 GHz AP-capable band support for `ifname` via the kernel
 * nl80211 netlink ABI. Returns 0 on success (flags set to 0/1), -1 on error.
 */
int nm_nl80211_band_support_by_iface (const char *ifname,
                                      int *supports_2ghz,
                                      int *supports_5ghz);

/*
 * Report whether the radio owning `ifname` currently has an AP interface.
 * This also detects virtual AP interfaces such as create_ap's ap0.
 */
int nm_nl80211_ap_active_by_iface (const char *ifname, int *is_active);

/*
 * Count stations on every AP interface belonging to the radio that owns
 * `ifname`.
 */
int nm_nl80211_ap_station_count_by_iface (const char *ifname,
                                          int *station_count);

#ifdef __cplusplus
}
#endif

#endif /* NM_NL80211_CLIENT_H */
