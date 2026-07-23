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
        cheader_filename = "src/backend/utils/nl80211_band.h")]
namespace Nl80211Band {
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
}
