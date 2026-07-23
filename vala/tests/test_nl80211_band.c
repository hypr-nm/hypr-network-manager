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

#include "../src/backend/utils/nl80211_band.h"

#include <assert.h>
#include <linux/nl80211.h>
#include <netlink/attr.h>
#include <netlink/genl/genl.h>
#include <netlink/msg.h>
#include <stddef.h>

static struct nl_msg *
new_wiphy_message (void)
{
    struct nl_msg *message = nlmsg_alloc ();

    assert (message != NULL);
    assert (genlmsg_put (message,
                         NL_AUTO_PORT,
                         NL_AUTO_SEQ,
                         NLMSG_MIN_TYPE,
                         0,
                         0,
                         NL80211_CMD_NEW_WIPHY,
                         0) != NULL);
    return message;
}

static void
append_frequency (struct nl_msg *message,
                  unsigned int entry_index,
                  unsigned int frequency_mhz,
                  int disabled,
                  int no_ir)
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
    nla_nest_end (message, entry);
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
}

int
main (void)
{
    test_frequency_classification ();
    test_nested_band_parsing ();
    test_no_band_attribute ();
    test_restricted_and_6ghz_frequencies_are_ignored ();
    test_query_argument_contract ();
    return 0;
}
