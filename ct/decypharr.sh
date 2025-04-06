#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/beerhunter1337/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 beerhunter1337
# Author: beerhunter1337
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/sirrobot01/debrid-blackhole

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

  if [[ ! -d /app ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating $APP LXC"
  cd /tmp || exit
  rm -rf /tmp/debrid-blackhole
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

  systemctl restart decypharr

  msg_info "Cleaning up"
  rm -rf /tmp/debrid-blackhole
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
