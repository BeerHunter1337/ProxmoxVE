#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/beerhunter1337/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 beerhunter1337
# Author: beerhunter1337
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/rivenmedia/riven

APP="Riven"
var_tags="media"
var_cpu="2"
var_ram="2048"
var_disk="8"
var_os="ubuntu"
var_version="24.04"
var_unprivileged="1"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /riven ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating $APP LXC"
  cd /tmp || exit
  rm -rf /tmp/riven-update
  git clone https://github.com/rivenmedia/riven.git /tmp/riven-update
  cd /tmp/riven-update || exit

  # Activate virtual environment
  source /app/.venv/bin/activate

  # Update dependencies
  poetry install --without dev --no-root

  # Copy updated files
  cp -r /tmp/riven-update/src/* /riven/src/
  cp /tmp/riven-update/pyproject.toml /tmp/riven-update/poetry.lock /riven/

  # Restart service
  systemctl restart riven

  msg_info "Cleaning up"
  rm -rf /tmp/riven-update
  msg_ok "Updated $APP LXC"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
