#!/bin/bash

# Remove user from Xray and Hysteria
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

# Remove from Xray (filter out by email)
jq --arg email "$SYS_NAME" '.inbounds[0].settings.clients |= map(select(.email != $email))' /etc/xray/config.json > /tmp/xray_temp.json && mv /tmp/xray_temp.json /etc/xray/config.json
jq --arg email "$SYS_NAME" '.inbounds[1].settings.clients |= map(select(.email != $email))' /etc/xray/config.json > /tmp/xray_temp.json && mv /tmp/xray_temp.json /etc/xray/config.json

# Remove from Hysteria
sed -i "/- $UUID/d" /etc/hysteria/config.yaml

# Restart Services
systemctl restart xray
systemctl restart hysteria-server.service

echo "User $SYS_NAME removed successfully."
