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

[CCode (cprefix = "nm_nl80211_", lower_case_cprefix = "nm_nl80211_",
        cheader_filename = "src/backend/utils/nl80211_client.h")]
namespace Nl80211 {
    [CCode (cname = "enum nm_nl80211_band",
            cprefix = "NM_NL80211_BAND_", has_type_id = false)]
    public enum Band {
        [CCode (cname = "NM_NL80211_BAND_NONE")]
        NONE,
        [CCode (cname = "NM_NL80211_BAND_2GHZ")]
        GHZ_2,
        [CCode (cname = "NM_NL80211_BAND_5GHZ")]
        GHZ_5
    }

    [CCode (cname = "nm_nl80211_frequency_band")]
    public Band frequency_band (uint32 frequency_mhz);

    /*
     * Queries the wireless band (2.4 GHz / 5 GHz) AP-capable support for the
     * given interface name via the stable kernel nl80211 netlink ABI.
     *
     * Returns 0 on success (out params set to 0/1), -1 on error.
     * A band is "supported" only if it has at least one frequency that is
     * neither disabled nor marked "no IR", so hotspot/AP mode can use it.
     */
    [CCode (cname = "nm_nl80211_band_support_by_iface")]
    public int band_support_by_iface (string ifname, out int supports_2ghz, out int supports_5ghz);

    /*
     * Selects a non-DFS, 20 MHz AP channel allowed by the kernel's current
     * per-radio regulatory result. A legal preferred frequency wins.
     */
    [CCode (cname = "nm_nl80211_ap_channel_by_iface")]
    public int ap_channel_by_iface (
        string ifname,
        Band requested_band,
        uint32 preferred_frequency_mhz,
        out uint32 selected_frequency_mhz,
        out uint32 selected_channel
    );

    /*
     * Reports whether the radio that owns the given interface currently has
     * an AP-mode interface. This includes virtual AP interfaces.
     */
    [CCode (cname = "nm_nl80211_ap_active_by_iface")]
    public int ap_active_by_iface (string ifname, out int is_active);

    /*
     * Counts associated stations across AP interfaces on the same radio.
     */
    [CCode (cname = "nm_nl80211_ap_station_count_by_iface")]
    public int ap_station_count_by_iface (string ifname, out int station_count);
}
