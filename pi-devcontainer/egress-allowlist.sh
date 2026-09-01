#!/usr/bin/env bash
# Turn the accumulated egress log into a candidate allowlist.
# Phase 1 is allow-all + record; run this after a few weeks/months to see every
# host the agent actually reached, ranked by frequency. That ranked list is the
# seed for a Phase-2 "default allowlist + ask on miss" posture.
#
# Usage:
#   ./egress-allowlist.sh [egress.log]     # default: ./.pi-egress/egress.log
set -euo pipefail

LOG="${1:-.pi-egress/egress.log}"
[ -f "$LOG" ] || { echo "no egress log at: $LOG (run the devcontainer first)" >&2; exit 1; }

echo "# Candidate egress allowlist — hosts reached, by frequency"
echo "# source: $LOG   generated: $(date -u +%FT%TZ)"
echo
# dnsmasq --log-queries lines look like: "... query[A] github.com from 127.0.0.1"
# Pull the queried name, drop in-addr/reverse + cluster-internal noise, rank.
grep -hoE 'query\[[A-Z]+\] [^ ]+' "$LOG" \
  | awk '{print $2}' \
  | grep -vE '(\.in-addr\.arpa|\.local$|\.cluster\.local$|^localhost$)' \
  | sort | uniq -c | sort -rn \
  | awk '{printf "%6d  %s\n", $1, $2}'
