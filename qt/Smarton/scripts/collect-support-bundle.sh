#!/usr/bin/env bash
# Collect diagnostics from a SmarTon panel without copying credentials,
# accounts, home data, photos, or MQTT configuration.
#
#   ./scripts/collect-support-bundle.sh
#   BOARD=10.42.0.130 OUT=/tmp ./scripts/collect-support-bundle.sh
set -euo pipefail

BOARD="${BOARD:-10.42.0.130}"
USER="${BOARD_USER:-root}"
OUT="${OUT:-.}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
NAME="smarton-support-${BOARD//[^A-Za-z0-9._-]/_}-${STAMP}.tar.gz"

mkdir -p "$OUT"

# The remote archive contains generated text only. In particular, do not add
# /etc/smarton/smarton.env, /var/lib/smarton, or /root: all can contain secrets
# or personal household data.
ssh "$USER@$BOARD" '
    set -eu
    work=/tmp/smarton-support-$$
    mkdir -p "$work"
    systemctl --no-pager --full status smarton.service >"$work/service-status.txt" 2>&1 || true
    systemctl show smarton.service --no-pager \
        -p ActiveState -p SubState -p MainPID -p MemoryCurrent -p RestartUSec \
        -p User -p ProtectSystem -p NoNewPrivileges >"$work/service-properties.txt" 2>&1 || true
    journalctl -u smarton.service -n 500 --no-pager >"$work/smarton-journal.txt" 2>&1 || true
    uname -a >"$work/kernel.txt" 2>&1 || true
    cat /etc/os-release >"$work/os-release.txt" 2>&1 || true
    df -h >"$work/disk.txt" 2>&1 || true
    free -h >"$work/memory.txt" 2>&1 || true
    ip -brief address >"$work/network-addresses.txt" 2>&1 || true
    /usr/bin/smarton --version >"$work/smarton-version.txt" 2>&1 || true
    tar -C /tmp -czf - "${work##/tmp/}"
    rm -rf "$work"
' >"$OUT/$NAME"

echo "Created $OUT/$NAME"
