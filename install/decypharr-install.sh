#!/usr/bin/env bash

# Copyright (c) 2021-2025 beerhunter1337
# Author: beerhunter1337
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/sirrobot01/debrid-blackhole

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl wget golang-go git
msg_ok "Installed Dependencies"

msg_info "Creating Directory Structure"
mkdir -p /app/logs
chmod 777 /app/logs
touch /app/logs/decypharr.log
chmod 666 /app/logs/decypharr.log
msg_ok "Created Directory Structure"

msg_info "Creating Non-Root User"
groupadd -g 65532 nonroot
useradd -u 65532 -g nonroot -s /bin/false nonroot
msg_ok "Created Non-Root User"

msg_info "Building Debrid-Blackhole"
cd /tmp || exit
git clone https://github.com/sirrobot01/debrid-blackhole.git
cd debrid-blackhole || exit
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
CHANNEL="stable"

# Build main binary
CGO_ENABLED=0 go build -trimpath \
  -ldflags="-w -s -X github.com/sirrobot01/debrid-blackhole/pkg/version.Version=${VERSION} -X github.com/sirrobot01/debrid-blackhole/pkg/version.Channel=${CHANNEL}" \
  -o /usr/bin/blackhole

# Build healthcheck
CGO_ENABLED=0 go build -trimpath -ldflags="-w -s" \
  -o /usr/bin/healthcheck cmd/healthcheck/main.go

# Set permissions
chown nonroot:nonroot /usr/bin/blackhole /usr/bin/healthcheck
chmod +x /usr/bin/blackhole /usr/bin/healthcheck
chown -R nonroot:nonroot /app
msg_ok "Built Debrid-Blackhole"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/debrid-blackhole.service
[Unit]
Description=Debrid Blackhole Service
After=network.target

[Service]
Type=simple
User=nonroot
Group=nonroot
Environment="LOG_PATH=/app/logs"
ExecStart=/usr/bin/blackhole --config /app
Restart=on-failure
RestartSec=5
SyslogIdentifier=debrid-blackhole

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now debrid-blackhole
msg_ok "Created Service"

msg_info "Setting Up Healthcheck"
cat <<EOF >/etc/systemd/system/debrid-blackhole-healthcheck.service
[Unit]
Description=Debrid Blackhole Healthcheck
After=debrid-blackhole.service

[Service]
Type=oneshot
User=nonroot
Group=nonroot
ExecStart=/usr/bin/healthcheck
SyslogIdentifier=debrid-blackhole-healthcheck

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/debrid-blackhole-healthcheck.timer
[Unit]
Description=Run Debrid Blackhole Healthcheck periodically

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=debrid-blackhole-healthcheck.service

[Install]
WantedBy=timers.target
EOF

systemctl enable -q --now debrid-blackhole-healthcheck.timer
msg_ok "Set Up Healthcheck"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf /tmp/debrid-blackhole
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
