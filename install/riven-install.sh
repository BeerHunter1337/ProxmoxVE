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
$STD poetry install --without dev

# Copy the entire repository to ensure all modules are available
cp -r * /riven/
cp .* /riven/ 2>/dev/null || true

# Create entrypoint script
cat <<'EOF' >/riven/entrypoint.sh
#!/bin/bash
source /app/.venv/bin/activate
cd /riven
export PYTHONPATH=/riven
python backend/main.py
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
Environment="PYTHONPATH=/riven"
Environment="RIVEN_DATABASE_HOST=postgresql+psycopg2://postgres:postgres@YOUR_POSTGRES_IP:5432/riven"
ExecStart=/riven/entrypoint.sh
Restart=on-failure
RestartSec=5
SyslogIdentifier=riven

[Install]
WantedBy=multi-user.target
EOF

echo -e "${INFO} Please edit the database connection string in /etc/systemd/system/riven.service"
echo -e "${INFO} Replace YOUR_POSTGRES_IP with your actual PostgreSQL LXC IP address"

systemctl enable -q riven
msg_ok "Created Service"

msg_info "Installing Node.js for the frontend"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Setting Up Frontend"
mkdir -p /riven/frontend
cd /riven/frontend || exit

# Clone the frontend repository
git clone https://github.com/rivenmedia/riven-frontend.git .

# Run npm commands without using $STD
msg_info "Installing npm packages"
su - mediauser -c "cd /riven/frontend && npm install"
msg_info "Building frontend"
su - mediauser -c "cd /riven/frontend && npm run build"

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
Environment="ORIGIN=http://localhost:3000"
Environment="BACKEND_URL=http://127.0.0.1:8080"
ExecStart=/usr/bin/node build
Restart=on-failure
RestartSec=5
SyslogIdentifier=riven-frontend

[Install]
WantedBy=multi-user.target
EOF

# Set ownership for frontend files
chown -R 1605:1605 /riven/frontend

systemctl enable -q riven-frontend
msg_ok "Set Up Frontend"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf /tmp/riven
apt-get -y autoremove
apt-get -y autoclean
msg_ok "Cleaned"

echo -e "${INFO} Important: You need to edit the database connection in /etc/systemd/system/riven.service"
echo -e "${INFO} After editing, start the services with: systemctl start riven && systemctl start riven-frontend"
