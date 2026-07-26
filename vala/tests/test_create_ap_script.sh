#!/usr/bin/env bash

set -eu

script=$1

bash -n "$script"
help_output=$(bash "$script" --help)
option_parse_output=$(
    bash "$script" \
        --ready-file /tmp/hynm-test.ready \
        --passphrase-file /tmp/hynm-test.passphrase \
        --help
)

grep -q -- '--passphrase-file <file>' <<<"$help_output"
grep -q -- '--ready-file <file>' <<<"$help_output"
grep -q -- '--passphrase-file <file>' <<<"$option_parse_output"
grep -q 'DNSMASQ_READY' "$script"
grep -q "grep -q 'type AP'" "$script"
grep -q "printf 'ready" "$script"

# hostapd config-injection guards (C2): the SSID must be written hex-encoded
# via ssid2= (so a newline/control char can never break out of the value) and
# the raw, injectable `ssid=${SSID}` line must be gone; the passphrase must be
# validated to printable ASCII before it is written as wpa_passphrase=.
grep -q '^ssid2=${SSID_HEX}$' "$script"
if grep -q '^ssid=${SSID}$' "$script"; then
    echo "FAIL: hostapd.conf still writes raw ssid=\${SSID} (injection)" >&2
    exit 1
fi
grep -q 'SSID_HEX=$(ssid_to_hex' "$script"
grep -q 'is_printable_ascii "\$PASSPHRASE"' "$script"
grep -q 'non-printable or control characters' "$script"

# Behavioural checks: ssid_to_hex is byte-accurate and never emits a newline,
# and is_printable_ascii rejects control chars but accepts normal input.
tmpf=$(mktemp)
trap 'rm -f "$tmpf"' EXIT
sed -n '/^ssid_to_hex() {/,/^}/p; /^is_printable_ascii() {/,/^}/p' "$script" > "$tmpf"
LC_ALL=C bash -c '
    source "$1"
    [ "$(ssid_to_hex Test)" = 54657374 ] || { echo "FAIL ssid_to_hex" >&2; exit 1; }
    hex=$(ssid_to_hex "a
b"); [ "$hex" = 610a62 ] || { echo "FAIL ssid_to_hex newline -> [$hex]" >&2; exit 1; }
    is_printable_ascii "Hello 123!" || { echo "FAIL printable accept" >&2; exit 1; }
    if is_printable_ascii "a
b"; then echo "FAIL newline accept" >&2; exit 1; fi
' _ "$tmpf"
