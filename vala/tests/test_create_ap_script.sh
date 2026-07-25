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
