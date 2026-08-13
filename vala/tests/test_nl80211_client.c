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

#include "../src/backend/utils/nl80211_client.h"

#include <assert.h>
#include <linux/nl80211.h>
#include <netlink/attr.h>
#include <netlink/genl/genl.h>
#include <netlink/msg.h>
#include <stddef.h>
#include <stdint.h>

static struct nl_msg *
new_nl80211_message (uint8_t command)
{
    struct nl_msg *message = nlmsg_alloc ();

    assert (message != NULL);
    assert (genlmsg_put (message,
                         NL_AUTO_PORT,
                         NL_AUTO_SEQ,
                         NLMSG_MIN_TYPE,
                         0,
                         0,
                         command,
                         0) != NULL);
    return message;
}

static struct nl_msg *
new_wiphy_message (void)
{
    return new_nl80211_message (NL80211_CMD_NEW_WIPHY);
}

static void
append_frequency_with_flags (struct nl_msg *message,
                             unsigned int entry_index,
                             unsigned int frequency_mhz,
                             int disabled,
                             int no_ir,
                             int radar,
                             int no_20mhz)
{
    struct nlattr *entry = nla_nest_start (message, (int) entry_index);

    assert (entry != NULL);
    assert (nla_put_u32 (message,
                         NL80211_FREQUENCY_ATTR_FREQ,
                         frequency_mhz) == 0);
    if (disabled != 0) {
        assert (nla_put_flag (message,
                              NL80211_FREQUENCY_ATTR_DISABLED) == 0);
    }
    if (no_ir != 0) {
        assert (nla_put_flag (message,
                              NL80211_FREQUENCY_ATTR_NO_IR) == 0);
    }
    if (radar != 0) {
        assert (nla_put_flag (message,
                              NL80211_FREQUENCY_ATTR_RADAR) == 0);
    }
    if (no_20mhz != 0) {
        assert (nla_put_flag (message,
                              NL80211_FREQUENCY_ATTR_NO_20MHZ) == 0);
    }
    nla_nest_end (message, entry);
}

static void
append_frequency (struct nl_msg *message,
                  unsigned int entry_index,
                  unsigned int frequency_mhz,
                  int disabled,
                  int no_ir)
{
    append_frequency_with_flags (
        message,
        entry_index,
        frequency_mhz,
        disabled,
        no_ir,
        0,
        0);
}

static void
test_frequency_classification (void)
{
    assert (nm_nl80211_frequency_band (2412U) == NM_NL80211_BAND_2GHZ);
    assert (nm_nl80211_frequency_band (2484U) == NM_NL80211_BAND_2GHZ);
    assert (nm_nl80211_frequency_band (2500U) == NM_NL80211_BAND_NONE);

    assert (nm_nl80211_frequency_band (4910U) == NM_NL80211_BAND_5GHZ);
    assert (nm_nl80211_frequency_band (5180U) == NM_NL80211_BAND_5GHZ);
    assert (nm_nl80211_frequency_band (5920U) == NM_NL80211_BAND_5GHZ);

    assert (nm_nl80211_frequency_band (5935U) == NM_NL80211_BAND_NONE);
    assert (nm_nl80211_frequency_band (5955U) == NM_NL80211_BAND_NONE);
    assert (nm_nl80211_frequency_band (7115U) == NM_NL80211_BAND_NONE);

    assert (nm_nl80211_frequency_channel (2412U) == 1U);
    assert (nm_nl80211_frequency_channel (2437U) == 6U);
    assert (nm_nl80211_frequency_channel (2484U) == 14U);
    assert (nm_nl80211_frequency_channel (4910U) == 182U);
    assert (nm_nl80211_frequency_channel (5180U) == 36U);
    assert (nm_nl80211_frequency_channel (5955U) == 0U);
    assert (nm_nl80211_frequency_channel (5181U) == 0U);
}

static void
test_regulatory_channel_selection (void)
{
    struct nl_msg *message = new_wiphy_message ();
    struct nlattr *bands;
    struct nlattr *band;
    struct nlattr *frequencies;
    uint32_t selected_frequency = 0U;
    uint32_t selected_channel = 0U;
    uint32_t selection_rank = UINT32_MAX;

    bands = nla_nest_start (message, NL80211_ATTR_WIPHY_BANDS);
    assert (bands != NULL);
    band = nla_nest_start (message, 1);
    assert (band != NULL);
    frequencies = nla_nest_start (message, NL80211_BAND_ATTR_FREQS);
    assert (frequencies != NULL);

    append_frequency (message, 1, 2412U, 0, 0);
    append_frequency (message, 2, 2437U, 0, 0);
    append_frequency (message, 3, 2462U, 0, 1);
    append_frequency_with_flags (message, 4, 5180U, 0, 0, 1, 0);
    append_frequency_with_flags (message, 5, 5200U, 0, 0, 0, 1);
    append_frequency (message, 6, 5220U, 0, 1);
    append_frequency (message, 7, 5745U, 0, 0);

    nla_nest_end (message, frequencies);
    nla_nest_end (message, band);
    nla_nest_end (message, bands);

    assert (nm_nl80211_parse_ap_channel_message (
                message,
                NM_NL80211_BAND_2GHZ,
                0U,
                &selected_frequency,
                &selected_channel,
                &selection_rank) == 0);
    assert (selected_frequency == 2437U);
    assert (selected_channel == 6U);

    selected_frequency = 0U;
    selected_channel = 0U;
    selection_rank = UINT32_MAX;
    assert (nm_nl80211_parse_ap_channel_message (
                message,
                NM_NL80211_BAND_2GHZ,
                2412U,
                &selected_frequency,
                &selected_channel,
                &selection_rank) == 0);
    assert (selected_frequency == 2412U);
    assert (selected_channel == 1U);

    selected_frequency = 0U;
    selected_channel = 0U;
    selection_rank = UINT32_MAX;
    assert (nm_nl80211_parse_ap_channel_message (
                message,
                NM_NL80211_BAND_5GHZ,
                0U,
                &selected_frequency,
                &selected_channel,
                &selection_rank) == 0);
    assert (selected_frequency == 5745U);
    assert (selected_channel == 149U);

    nlmsg_free (message);
}

static void
test_nested_band_parsing (void)
{
    struct nl_msg *message = new_wiphy_message ();
    struct nlattr *bands;
    struct nlattr *band;
    struct nlattr *frequencies;
    int supports_2ghz = 0;
    int supports_5ghz = 0;

    bands = nla_nest_start (message, NL80211_ATTR_WIPHY_BANDS);
    assert (bands != NULL);
    band = nla_nest_start (message, 1);
    assert (band != NULL);
    frequencies = nla_nest_start (message, NL80211_BAND_ATTR_FREQS);
    assert (frequencies != NULL);

    append_frequency (message, 1, 2412U, 0, 0);
    append_frequency (message, 2, 5180U, 0, 1);
    append_frequency (message, 3, 5200U, 1, 0);
    append_frequency (message, 4, 5955U, 0, 0);
    append_frequency (message, 5, 5745U, 0, 0);

    nla_nest_end (message, frequencies);
    nla_nest_end (message, band);
    nla_nest_end (message, bands);

    assert (nm_nl80211_parse_band_support_message (
                message,
                &supports_2ghz,
                &supports_5ghz) == 0);
    assert (supports_2ghz == 1);
    assert (supports_5ghz == 1);

    nlmsg_free (message);
}

static void
test_no_band_attribute (void)
{
    struct nl_msg *message = new_wiphy_message ();
    int supports_2ghz = 0;
    int supports_5ghz = 0;

    assert (nm_nl80211_parse_band_support_message (
                message,
                &supports_2ghz,
                &supports_5ghz) == 1);
    assert (supports_2ghz == 0);
    assert (supports_5ghz == 0);

    nlmsg_free (message);
}

static void
test_restricted_and_6ghz_frequencies_are_ignored (void)
{
    struct nl_msg *message = new_wiphy_message ();
    struct nlattr *bands;
    struct nlattr *band;
    struct nlattr *frequencies;
    int supports_2ghz = 0;
    int supports_5ghz = 0;

    bands = nla_nest_start (message, NL80211_ATTR_WIPHY_BANDS);
    assert (bands != NULL);
    band = nla_nest_start (message, 1);
    assert (band != NULL);
    frequencies = nla_nest_start (message, NL80211_BAND_ATTR_FREQS);
    assert (frequencies != NULL);

    append_frequency (message, 1, 5180U, 0, 1);
    append_frequency (message, 2, 5200U, 1, 0);
    append_frequency (message, 3, 5955U, 0, 0);
    append_frequency_with_flags (message, 4, 5220U, 0, 0, 1, 0);
    append_frequency_with_flags (message, 5, 5240U, 0, 0, 0, 1);

    nla_nest_end (message, frequencies);
    nla_nest_end (message, band);
    nla_nest_end (message, bands);

    assert (nm_nl80211_parse_band_support_message (
                message,
                &supports_2ghz,
                &supports_5ghz) == 0);
    assert (supports_2ghz == 0);
    assert (supports_5ghz == 0);

    nlmsg_free (message);
}

static void
test_query_argument_contract (void)
{
    int supports_2ghz = 1;
    int supports_5ghz = 1;
    uint32_t selected_frequency = 1U;
    uint32_t selected_channel = 1U;
    int is_ap_active = 1;
    int station_count = 12;

    assert (nm_nl80211_band_support_by_iface (
                NULL,
                &supports_2ghz,
                &supports_5ghz) == -1);
    assert (supports_2ghz == 0);
    assert (supports_5ghz == 0);

    assert (nm_nl80211_band_support_by_iface (
                "interface-that-does-not-exist",
                &supports_2ghz,
                &supports_5ghz) == -1);

    assert (nm_nl80211_ap_channel_by_iface (
                NULL,
                NM_NL80211_BAND_2GHZ,
                0U,
                &selected_frequency,
                &selected_channel) == -1);
    assert (selected_frequency == 0U);
    assert (selected_channel == 0U);
    assert (nm_nl80211_ap_channel_by_iface (
                "interface-that-does-not-exist",
                NM_NL80211_BAND_5GHZ,
                0U,
                &selected_frequency,
                &selected_channel) == -1);

    assert (nm_nl80211_ap_active_by_iface (NULL, &is_ap_active) == -1);
    assert (is_ap_active == 0);
    assert (nm_nl80211_ap_active_by_iface (
                "interface-that-does-not-exist",
                &is_ap_active) == -1);

    assert (nm_nl80211_ap_station_count_by_iface (
                NULL,
                &station_count) == -1);
    assert (station_count == 0);
    assert (nm_nl80211_ap_station_count_by_iface (
                "interface-that-does-not-exist",
                &station_count) == -1);
}

static void
test_interface_message_parsing (void)
{
    struct nl_msg *message = new_nl80211_message (NL80211_CMD_NEW_INTERFACE);
    uint32_t ifindex = 0U;
    uint32_t wiphy = 0U;
    uint32_t iftype = 0U;

    assert (nla_put_u32 (message, NL80211_ATTR_IFINDEX, 42U) == 0);
    assert (nla_put_u32 (message, NL80211_ATTR_WIPHY, 7U) == 0);
    assert (nla_put_u32 (
                message,
                NL80211_ATTR_IFTYPE,
                (uint32_t) NL80211_IFTYPE_AP) == 0);

    assert (nm_nl80211_parse_interface_message (
                message,
                &ifindex,
                &wiphy,
                &iftype) == 0);
    assert (ifindex == 42U);
    assert (wiphy == 7U);
    assert (iftype == (uint32_t) NL80211_IFTYPE_AP);
    nlmsg_free (message);

    message = new_nl80211_message (NL80211_CMD_NEW_INTERFACE);
    assert (nm_nl80211_parse_interface_message (
                message,
                &ifindex,
                &wiphy,
                &iftype) == 1);
    assert (ifindex == 0U);
    assert (wiphy == 0U);
    assert (iftype == 0U);
    nlmsg_free (message);
}

static void
test_station_message_parsing (void)
{
    static const unsigned char station_mac[6] = {
        0x02U, 0x00U, 0x00U, 0x00U, 0x00U, 0x01U,
    };
    struct nl_msg *message = new_nl80211_message (NL80211_CMD_NEW_STATION);
    struct nlattr *station_info;

    assert (nla_put_u32 (message, NL80211_ATTR_IFINDEX, 42U) == 0);
    assert (nla_put (
                message,
                NL80211_ATTR_MAC,
                sizeof (station_mac),
                station_mac) == 0);
    station_info = nla_nest_start (message, NL80211_ATTR_STA_INFO);
    assert (station_info != NULL);
    assert (nla_put_u32 (
                message,
                NL80211_STA_INFO_INACTIVE_TIME,
                0U) == 0);
    nla_nest_end (message, station_info);

    assert (nm_nl80211_parse_station_message (message) == 1);
    nlmsg_free (message);

    message = new_nl80211_message (NL80211_CMD_NEW_STATION);
    assert (nm_nl80211_parse_station_message (message) == 0);
    nlmsg_free (message);
}

int
main (void)
{
    test_frequency_classification ();
    test_regulatory_channel_selection ();
    test_nested_band_parsing ();
    test_no_band_attribute ();
    test_restricted_and_6ghz_frequencies_are_ignored ();
    test_interface_message_parsing ();
    test_station_message_parsing ();
    test_query_argument_contract ();
    return 0;
}
