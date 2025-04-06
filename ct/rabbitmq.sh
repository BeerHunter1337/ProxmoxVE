#!/usr/bin/env bash
source <(curl -fsSL n/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck | Co-Author: MickLesk (Canbiz)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.rabbitmq.com/

APP="RabbitMQ"
var_tags="mqtt"
var_cpu="1"
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
    if [[ ! -d /etc/rabbitmq ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Stopping ${APP} Service"
    systemctl stop rabbitmq-server
    msg_ok "Stopped ${APP} Service"

    msg_info "Updating..."
    $STD apt install --only-upgrade rabbitmq-server
    msg_ok "Update Successfully"

    msg_info "Starting ${APP}"
    systemctl start rabbitmq-server
    msg_ok "Started ${APP}"
    msg_ok "Updated Successfully"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:15672${CL}"