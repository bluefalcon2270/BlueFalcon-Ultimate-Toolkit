#!/usr/bin/env bash
# ==============================================================================
# Next-Gen Proxy Action Script
# ==============================================================================
ACTION=$1

if [ "$ACTION" == "stop" ]; then
    systemctl stop xray hysteria > /dev/null 2>&1
    systemctl disable xray hysteria > /dev/null 2>&1
    echo "Xray & Hysteria Stopped."
elif [ "$ACTION" == "start" ]; then
    systemctl start xray hysteria > /dev/null 2>&1
    systemctl enable xray hysteria > /dev/null 2>&1
    echo "Xray & Hysteria Started."
elif [ "$ACTION" == "purge" ]; then
    systemctl stop xray hysteria > /dev/null 2>&1
    systemctl disable xray hysteria > /dev/null 2>&1
    rm -rf /usr/local/bin/xray /usr/local/bin/hysteria /etc/xray /etc/hysteria /etc/systemd/system/xray.service /etc/systemd/system/hysteria.service
    systemctl daemon-reload
    
    DB_FILE="/opt/bluefalcon-ultimate-toolkit/panel.db"
    sqlite3 "$DB_FILE" "UPDATE settings SET is_installed=0 WHERE server_name='proxy';"
    sqlite3 "$DB_FILE" "DELETE FROM proxy_users;"
    echo "Xray & Hysteria Purged."
fi
