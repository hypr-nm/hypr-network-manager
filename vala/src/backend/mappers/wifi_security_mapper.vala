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

using GLib;

namespace HyprNetworkManager.Backend.Mappers {
    public class WifiSecurityMapper : GLib.Object {
        public static WifiSecurityCapabilities map_capabilities (
            uint32 flags,
            uint32 wpa_flags,
            uint32 rsn_flags
        ) {
            var caps = new WifiSecurityCapabilities ();
            caps.is_secured = (flags != 0 || wpa_flags != 0 || rsn_flags != 0);

            bool is_8021x = (rsn_flags & NM.80211ApSecurityFlags.KEY_MGMT_802_1X) != 0 ||
                            (wpa_flags & NM.80211ApSecurityFlags.KEY_MGMT_802_1X) != 0;
            caps.is_enterprise = is_8021x;

            caps.supports_sae = (rsn_flags & NM.80211ApSecurityFlags.KEY_MGMT_SAE) != 0;
            caps.supports_psk = (rsn_flags & NM.80211ApSecurityFlags.KEY_MGMT_PSK) != 0 ||
                                (wpa_flags & NM.80211ApSecurityFlags.KEY_MGMT_PSK) != 0;

            return caps;
        }

        public static WifiNetworkMode map_mode (NM.80211Mode nm_mode) {
            switch (nm_mode) {
                case NM.80211Mode.ADHOC: return WifiNetworkMode.ADHOC;
                case NM.80211Mode.INFRA: return WifiNetworkMode.INFRA;
                case NM.80211Mode.AP: return WifiNetworkMode.AP;
                case NM.80211Mode.MESH: return WifiNetworkMode.MESH;
                default: return WifiNetworkMode.UNKNOWN;
            }
        }
    }
}
