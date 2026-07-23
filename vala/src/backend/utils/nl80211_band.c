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

#include "nl80211_band.h"

#include <errno.h>
#include <linux/netlink.h>
#include <linux/nl80211.h>
#include <net/if.h>
#include <stdint.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>

#include <netlink/attr.h>
#include <netlink/genl/ctrl.h>
#include <netlink/genl/genl.h>
#include <netlink/handlers.h>
#include <netlink/msg.h>
#include <netlink/netlink.h>
#include <netlink/socket.h>

#define NM_NL80211_RECEIVE_TIMEOUT_SECONDS 2
#define NM_NL80211_SOCKET_BUFFER_SIZE (32 * 1024)

struct nm_nl80211_query_state {
    int pending;
    int error;
    int saw_bands;
    int supports_2ghz;
    int supports_5ghz;
};

int
nm_nl80211_frequency_band (uint32_t frequency_mhz)
{
    if (frequency_mhz >= 2412U && frequency_mhz <= 2484U) {
        return NM_NL80211_BAND_2GHZ;
    }

    /*
     * 5925 MHz is the upper edge of the 5 GHz allocation. In particular,
     * 5935, 5955, 5975, ... are 6 GHz channels and must not make the UI offer
     * a 5 GHz hotspot.
     */
    if (frequency_mhz >= 4900U && frequency_mhz < 5925U) {
        return NM_NL80211_BAND_5GHZ;
    }

    return NM_NL80211_BAND_NONE;
}

static void
record_usable_frequency (uint32_t frequency_mhz,
                         int *supports_2ghz,
                         int *supports_5ghz)
{
    switch (nm_nl80211_frequency_band (frequency_mhz)) {
    case NM_NL80211_BAND_2GHZ:
        *supports_2ghz = 1;
        break;
    case NM_NL80211_BAND_5GHZ:
        *supports_5ghz = 1;
        break;
    default:
        break;
    }
}

/*
 * Parse NL80211_ATTR_WIPHY_BANDS from a generic-netlink message.
 *
 * Returns 0 when the message contained and successfully parsed WIPHY_BANDS,
 * 1 when the message did not contain WIPHY_BANDS, and -1 when it was malformed.
 * Multiple split-wiphy messages can therefore be accumulated by the caller.
 */
int
nm_nl80211_parse_band_support_message (struct nl_msg *message,
                                       int *supports_2ghz,
                                       int *supports_5ghz)
{
    static const struct nla_policy frequency_policy[NL80211_FREQUENCY_ATTR_MAX + 1] = {
        [NL80211_FREQUENCY_ATTR_FREQ] = { .type = NLA_U32 },
        [NL80211_FREQUENCY_ATTR_DISABLED] = { .type = NLA_FLAG },
        [NL80211_FREQUENCY_ATTR_NO_IR] = { .type = NLA_FLAG },
    };
    struct nlmsghdr *nl_header;
    struct nlattr *top_level[NL80211_ATTR_MAX + 1] = { 0 };
    struct nlattr *band;
    int band_remaining;

    if (message == NULL || supports_2ghz == NULL || supports_5ghz == NULL) {
        errno = EINVAL;
        return -1;
    }

    nl_header = nlmsg_hdr (message);
    if (nl_header == NULL || !genlmsg_valid_hdr (nl_header, 0)) {
        errno = EBADMSG;
        return -1;
    }

    if (genlmsg_parse (nl_header, 0, top_level, NL80211_ATTR_MAX, NULL) < 0) {
        errno = EBADMSG;
        return -1;
    }

    if (top_level[NL80211_ATTR_WIPHY_BANDS] == NULL) {
        return 1;
    }

    nla_for_each_nested (band,
                         top_level[NL80211_ATTR_WIPHY_BANDS],
                         band_remaining) {
        struct nlattr *band_attributes[NL80211_BAND_ATTR_MAX + 1] = { 0 };
        struct nlattr *frequency;
        int frequency_remaining;

        if (nla_parse_nested (band_attributes,
                              NL80211_BAND_ATTR_MAX,
                              band,
                              NULL) < 0) {
            errno = EBADMSG;
            return -1;
        }

        if (band_attributes[NL80211_BAND_ATTR_FREQS] == NULL) {
            continue;
        }

        nla_for_each_nested (frequency,
                             band_attributes[NL80211_BAND_ATTR_FREQS],
                             frequency_remaining) {
            struct nlattr *frequency_attributes[NL80211_FREQUENCY_ATTR_MAX + 1] = { 0 };

            if (nla_parse_nested (frequency_attributes,
                                  NL80211_FREQUENCY_ATTR_MAX,
                                  frequency,
                                  frequency_policy) < 0) {
                errno = EBADMSG;
                return -1;
            }

            if (frequency_attributes[NL80211_FREQUENCY_ATTR_FREQ] == NULL ||
                frequency_attributes[NL80211_FREQUENCY_ATTR_DISABLED] != NULL ||
                frequency_attributes[NL80211_FREQUENCY_ATTR_NO_IR] != NULL) {
                continue;
            }

            record_usable_frequency (
                nla_get_u32 (frequency_attributes[NL80211_FREQUENCY_ATTR_FREQ]),
                supports_2ghz,
                supports_5ghz);
        }
    }

    return 0;
}

static int
valid_message_callback (struct nl_msg *message, void *user_data)
{
    struct nm_nl80211_query_state *state = user_data;
    int supports_2ghz = 0;
    int supports_5ghz = 0;
    int result;

    result = nm_nl80211_parse_band_support_message (
        message,
        &supports_2ghz,
        &supports_5ghz);
    if (result < 0) {
        state->error = -EBADMSG;
        state->pending = 0;
        return NL_STOP;
    }

    if (result == 0) {
        state->saw_bands = 1;
        state->supports_2ghz |= supports_2ghz;
        state->supports_5ghz |= supports_5ghz;
    }

    return NL_OK;
}

static int
acknowledgement_callback (struct nl_msg *message, void *user_data)
{
    struct nm_nl80211_query_state *state = user_data;

    (void) message;
    state->pending = 0;
    return NL_STOP;
}

static int
finish_callback (struct nl_msg *message, void *user_data)
{
    struct nm_nl80211_query_state *state = user_data;

    (void) message;
    state->pending = 0;
    return NL_SKIP;
}

static int
error_callback (struct sockaddr_nl *address,
                struct nlmsgerr *netlink_error,
                void *user_data)
{
    struct nm_nl80211_query_state *state = user_data;

    (void) address;
    state->error = netlink_error != NULL ? netlink_error->error : -EIO;
    state->pending = 0;
    return NL_STOP;
}

static int
configure_receive_timeout (struct nl_sock *socket)
{
    const struct timeval timeout = {
        .tv_sec = NM_NL80211_RECEIVE_TIMEOUT_SECONDS,
        .tv_usec = 0,
    };
    int socket_fd;

    socket_fd = nl_socket_get_fd (socket);
    if (socket_fd < 0) {
        return -1;
    }

    return setsockopt (socket_fd,
                       SOL_SOCKET,
                       SO_RCVTIMEO,
                       &timeout,
                       sizeof (timeout));
}

int
nm_nl80211_band_support_by_iface (const char *ifname,
                                  int *supports_2ghz,
                                  int *supports_5ghz)
{
    struct nm_nl80211_query_state state = {
        .pending = 1,
        .error = 0,
        .saw_bands = 0,
        .supports_2ghz = 0,
        .supports_5ghz = 0,
    };
    struct nl_sock *socket = NULL;
    struct nl_cb *callbacks = NULL;
    struct nl_msg *request = NULL;
    unsigned int interface_index;
    int family_id;
    int result = -1;

    if (supports_2ghz == NULL || supports_5ghz == NULL) {
        errno = EINVAL;
        return -1;
    }

    *supports_2ghz = 0;
    *supports_5ghz = 0;

    if (ifname == NULL || ifname[0] == '\0') {
        errno = EINVAL;
        return -1;
    }

    interface_index = if_nametoindex (ifname);
    if (interface_index == 0U) {
        return -1;
    }

    socket = nl_socket_alloc ();
    callbacks = nl_cb_alloc (NL_CB_DEFAULT);
    request = nlmsg_alloc ();
    if (socket == NULL || callbacks == NULL || request == NULL) {
        errno = ENOMEM;
        goto cleanup;
    }

    if (genl_connect (socket) < 0 ||
        nl_socket_set_buffer_size (socket,
                                   NM_NL80211_SOCKET_BUFFER_SIZE,
                                   NM_NL80211_SOCKET_BUFFER_SIZE) < 0 ||
        configure_receive_timeout (socket) < 0) {
        goto cleanup;
    }

    family_id = genl_ctrl_resolve (socket, "nl80211");
    if (family_id < 0) {
        goto cleanup;
    }

    if (genlmsg_put (request,
                     NL_AUTO_PORT,
                     NL_AUTO_SEQ,
                     family_id,
                     0,
                     NLM_F_REQUEST | NLM_F_ACK,
                     NL80211_CMD_GET_WIPHY,
                     0) == NULL ||
        nla_put_u32 (request,
                     NL80211_ATTR_IFINDEX,
                     (uint32_t) interface_index) < 0) {
        goto cleanup;
    }

    if (nl_cb_set (callbacks,
                   NL_CB_VALID,
                   NL_CB_CUSTOM,
                   valid_message_callback,
                   &state) < 0 ||
        nl_cb_set (callbacks,
                   NL_CB_ACK,
                   NL_CB_CUSTOM,
                   acknowledgement_callback,
                   &state) < 0 ||
        nl_cb_set (callbacks,
                   NL_CB_FINISH,
                   NL_CB_CUSTOM,
                   finish_callback,
                   &state) < 0 ||
        nl_cb_err (callbacks,
                   NL_CB_CUSTOM,
                   error_callback,
                   &state) < 0) {
        goto cleanup;
    }

    if (nl_send_auto_complete (socket, request) < 0) {
        goto cleanup;
    }

    while (state.pending != 0) {
        int receive_result = nl_recvmsgs (socket, callbacks);

        if (receive_result < 0) {
            state.error = receive_result;
            break;
        }
    }

    if (state.error == 0 && state.saw_bands != 0) {
        *supports_2ghz = state.supports_2ghz != 0;
        *supports_5ghz = state.supports_5ghz != 0;
        result = 0;
    }

cleanup:
    if (request != NULL) {
        nlmsg_free (request);
    }
    if (callbacks != NULL) {
        nl_cb_put (callbacks);
    }
    if (socket != NULL) {
        nl_socket_free (socket);
    }
    return result;
}
