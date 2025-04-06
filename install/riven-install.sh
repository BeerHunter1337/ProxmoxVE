#!/usr/bin/env bash

# Copyright (c) 2021-2025 beerhunter1337
# Author: beerhunter1337
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/rivenmedia/riven

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing System Dependencies"
$STD apt-get update
$STD apt-get install -y \
  curl \
  wget \
  git \
  python3 \
  python3-pip \
  python3-dev \
  python3-venv \
  ffmpeg \
  unzip \
  rclone \
  build-essential \
  libffi-dev \
  libpq-dev
msg_ok "Installed System Dependencies"

msg_info "Installing Python Poetry"
$STD pip install poetry==1.8.3
msg_ok "Installed Python Poetry"

msg_info "Creating Directory Structure"
mkdir -p /riven/data
mkdir -p /riven/config
mkdir -p /app/.venv
msg_ok "Created Directory Structure"

msg_info "Setting Up User"
groupadd -g 1605 mediagroup
useradd -u 1605 -g mediagroup mediauser
chown -R 1605:1605 /riven
chown -R 1605:1605 /app
msg_ok "Set Up User"

msg_info "Setting Up Riven"
cd /tmp || exit
git clone https://github.com/rivenmedia/riven.git
cd riven || exit

# Set up virtual environment
python3 -m venv /app/.venv
source /app/.venv/bin/activate

# Install dependencies
export POETRY_VIRTUALENVS_IN_PROJECT=1
export POETRY_VIRTUALENVS_CREATE=1
export POETRY_NO_INTERACTION=1
$STD poetry install --without dev --no-root

# Copy application files
cp -r src/ /riven/
cp pyproject.toml poetry.lock /riven/

# Create entrypoint script
cat <<'EOF' >/riven/entrypoint.sh
#!/bin/bash
source /app/.venv/bin/activate
cd /riven
python -m src.main
EOF
chmod +x /riven/entrypoint.sh

# Set proper ownership
chown -R 1605:1605 /riven
chown -R 1605:1605 /app/.venv
msg_ok "Set Up Riven"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/riven.service
[Unit]
Description=Riven Media Server
After=network.target

[Service]
Type=simple
User=1605
Group=1605
WorkingDirectory=/riven
Environment="PYTHONUNBUFFERED=1"
Environment="FORCE_COLOR=1"
Environment="TERM=xterm-256color"
Environment="PUID=1000"
Environment="PGID=1000"
Environment="TZ=Etc/UTC"
Environment="RIVEN_FORCE_ENV=true"
Environment="RIVEN_DATABASE_HOST=postgresql+psycopg2://postgres:postgres@YOUR_POSTGRES_IP:5432/riven"
ExecStart=/riven/entrypoint.sh
Restart=on-failure
RestartSec=5
SyslogIdentifier=riven

[Install]
WantedBy=multi-user.target
EOF

echo -e "${WARN} Please edit the database connection string in /etc/systemd/system/riven.service"
echo -e "${WARN} Replace YOUR_POSTGRES_IP with your actual PostgreSQL LXC IP address"

systemctl enable -q riven
msg_ok "Created Service"

msg_info "Setting Up Frontend"
cd /tmp || exit
mkdir -p /riven/frontend
cd /riven/frontend || exit

# Download the latest frontend release
FRONTEND_URL=$(curl -s https://api.github.com/repos/rivenmedia/riven-frontend/releases/latest | grep "browser_download_url.*tar.gz" | cut -d '"' -f 4)
if [ -z "$FRONTEND_URL" ]; then
  msg_error "Failed to get frontend download URL"
  FRONTEND_URL="https://github.com/rivenmedia/riven-frontend/releases/download/latest/riven-frontend.tar.gz"
fi

wget -q "$FRONTEND_URL" -O frontend.tar.gz
tar -xzf frontend.tar.gz
rm frontend.tar.gz

# Create frontend service
cat <<EOF >/etc/systemd/system/riven-frontend.service
[Unit]
Description=Riven Frontend
After=network.target riven.service

[Service]
Type=simple
User=1605
Group=1605
WorkingDirectory=/riven/frontend
Environment="PORT=3000"
Environment="TZ=Etc/UTC"
ExecStart=/usr/bin/node /riven/frontend/server.js
Restart=on-failure
RestartSec=5
SyslogIdentifier=riven-frontend

[Install]
WantedBy=multi-user.target
EOF

# Install Node.js for the frontend
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
$STD apt-get install -y nodejs

systemctl enable -q riven-frontend
msg_ok "Set Up Frontend"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf /tmp/riven
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

echo -e "${WARN} Important: You need to edit the database connection in /etc/systemd/system/riven.service"
echo -e "${WARN} After editing, start the services with: systemctl start riven && systemctl start riven-frontend"
