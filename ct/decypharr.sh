#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/beerhunter1337/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 beerhunter1337
# Author: beerhunter1337
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/sirrobot01/decypharr

APP="Decypharr"
var_tags="downloader"
var_cpu="2"
var_ram="1024"
var_disk="4"
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

  if [[ ! -d /opt/decypharr ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating $APP LXC"
  cd /tmp || exit
  
  # Get latest release URL
  RELEASE_URL=$(curl -s https://api.github.com/repos/sirrobot01/decypharr/releases/latest | grep "browser_download_url.*decypharr_Linux_x86_64.tar.gz" | cut -d '"' -f 4)
  
  if [[ -z "$RELEASE_URL" ]]; then
    msg_error "Failed to get latest release URL"
    exit
  fi
  
  msg_info "Downloading latest Decypharr release"
  wget -q "$RELEASE_URL" -O decypharr_Linux_x86_64.tar.gz
  
  if [[ ! -f decypharr_Linux_x86_64.tar.gz ]]; then
    msg_error "Failed to download Decypharr release"
    exit
  fi
  
  msg_info "Extracting Decypharr binary"
  tar -xzf decypharr_Linux_x86_64.tar.gz
  
  if [[ ! -f decypharr ]]; then
    msg_error "Decypharr binary not found in archive"
    exit
  fi
  
  # Stop service before updating binary
  systemctl stop decypharr
  
  # Install binary
  mv decypharr /usr/bin/decypharr
  chown 1605:1605 /usr/bin/decypharr
  chmod +x /usr/bin/decypharr

  # Start service
  systemctl start decypharr

  msg_info "Cleaning up"
  rm -f /tmp/decypharr_Linux_x86_64.tar.gz
  msg_ok "Updated $APP LXC"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URLs:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8181${CL} (Web UI)"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8282${CL} (API)"
