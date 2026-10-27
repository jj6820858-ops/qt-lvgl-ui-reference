#!/usr/bin/env bash
# Install the cross-built binary as the RK3328 board's direct-EGLFS service.
#
#   ./scripts/deploy-to-board.sh
set -euo pipefail
cd "$(dirname "$0")/.."

BOARD="${BOARD:-10.42.0.130}"
USER="${BOARD_USER:-root}"
BIN="build/rk3328/bin/smarton"
UNIT="packaging/smarton.service"
ENV_EXAMPLE="packaging/smarton.env.example"

[[ -f "$BIN" ]] || {
    echo "Build first: cmake --preset rk3328 && cmake --build --preset rk3328"
    exit 1
}

[[ -f "$UNIT" ]] || { echo "Missing service unit: $UNIT"; exit 1; }

scp "$BIN" "$UNIT" "$ENV_EXAMPLE" "$USER@$BOARD:/tmp/"
ssh "$USER@$BOARD" '
    set -eu
    install -m 0755 /tmp/smarton /usr/bin/smarton
    install -m 0644 /tmp/smarton.service /etc/systemd/system/smarton.service
    install -d -m 0700 /etc/smarton
    # Never overwrite a provisioned file: it may contain live MQTT credentials.
    if [ ! -e /etc/smarton/smarton.env ]; then
        install -m 0600 /tmp/smarton.env.example /etc/smarton/smarton.env
    fi
    rm -f /tmp/smarton /tmp/smarton.service /tmp/smarton.env.example
    systemctl daemon-reload
    # The hardened service stores state under /var/lib instead of /root. On
    # the first upgrade, copy the old state only once and leave its source as
    # a recoverable backup. Stop first so SQLite WAL and SHM files form one
    # consistent set.
    if [ ! -e /var/lib/smarton/.legacy-state-migrated ] && \
       [ -f /root/.local/share/SmarTon/SmarTon/accounts.db ]; then
        systemctl stop smarton.service || true
        install -d -m 0700 /var/lib/smarton/SmarTon/SmarTon /var/lib/smarton/config
        cp -a /root/.local/share/SmarTon/SmarTon/. /var/lib/smarton/SmarTon/SmarTon/
        if [ -f /root/.config/SmarTon/SmarTon.conf ]; then
            install -d -m 0700 /var/lib/smarton/config/SmarTon
            cp -a /root/.config/SmarTon/SmarTon.conf /var/lib/smarton/config/SmarTon/
        fi
        touch /var/lib/smarton/.legacy-state-migrated
        chmod 0700 /var/lib/smarton /var/lib/smarton/SmarTon /var/lib/smarton/SmarTon/SmarTon
        chmod 0600 /var/lib/smarton/SmarTon/SmarTon/accounts.db* \
                   /var/lib/smarton/SmarTon/SmarTon/activity.json 2>/dev/null || true
    fi
    # Some images have already removed ThinClient; that is not a deployment
    # failure and must not prevent SmarTon from being restarted.
    systemctl disable --now thinclient.service || true
    # EGLFS owns the DRM framebuffer; Weston must not immediately respawn and
    # reclaim it. Re-enable weston.service and weston.socket before restoring
    # ThinClient.
    systemctl disable --now weston.service
    systemctl disable --now weston.socket
    systemctl enable smarton.service
    systemctl restart smarton.service
    sleep 5
    systemctl is-active --quiet smarton.service
    systemctl --no-pager --full status smarton.service
'
