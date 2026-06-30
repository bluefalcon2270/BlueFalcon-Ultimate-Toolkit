#!/bin/bash

# Add user to Xray and Hysteria
SYS_NAME=$1
UUID=$2

if [ -z "$SYS_NAME" ] || [ -z "$UUID" ]; then
    echo "Usage: $0 <sys_name> <uuid>"
    exit 1
fi

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    apt-get update && apt-get install -y jq >/dev/null 2>&1
fi

# Add to Xray (Inbound 0: TCP, Inbound 1: xHTTP)
jq --arg uuid "$UUID" --arg email "$SYS_NAME" '.inbounds[0].settings.clients += [{"id": $uuid, "flow": "xtls-rprx-vision", "email": $email}]' /etc/xray/config.json > /tmp/xray_temp.json && mv /tmp/xray_temp.json /etc/xray/config.json
jq --arg uuid "$UUID" --arg email "$SYS_NAME" '.inbounds[1].settings.clients += [{"id": $uuid, "email": $email}]' /etc/xray/config.json > /tmp/xray_temp.json && mv /tmp/xray_temp.json /etc/xray/config.json

# Add to Hysteria
sed -i "/placeholder_do_not_remove/a \    - $UUID" /etc/hysteria/config.yaml

# Restart Services
systemctl restart xray
systemctl restart hysteria-server.service

echo "User $SYS_NAME added successfully."
