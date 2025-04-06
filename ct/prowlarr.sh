#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/beerhunter1337/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://prowlarr.com/

APP="Prowlarr"
var_tags="arr"
var_cpu="2"
var_ram="1024"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /var/lib/prowlarr/ ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating $APP LXC"
  temp_file="$(mktemp)"
  rm -rf /opt/Prowlarr
  RELEASE=$(curl -fsSL https://api.github.com/repos/Prowlarr/Prowlarr/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
  curl -fsSL "https://github.com/Prowlarr/Prowlarr/releases/download/v${RELEASE}/Prowlarr.master.${RELEASE}.linux-core-x64.tar.gz" -o "$temp_file"
  $STD tar -xvzf "$temp_file"
  mv Prowlarr /opt
  chmod 775 /opt/Prowlarr
  msg_ok "Updated $APP LXC"

  msg_info "Cleaning up"
  rm -f "$temp_file"
  msg_ok "Cleaned up"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9696${CL}"
