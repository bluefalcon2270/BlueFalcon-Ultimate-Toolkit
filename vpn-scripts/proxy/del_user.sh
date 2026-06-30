#!/usr/bin/env bash
# ==============================================================================
# Next-Gen Proxy Delete User Script (Xray & Hysteria 2)
# Usage: ./del_user.sh <client_name>
# ==============================================================================
set -e
umask 077

CLIENT_NAME=$1
DB_FILE="/opt/bluefalcon-ultimate-toolkit/panel.db"
UUID=$(sqlite3 "$DB_FILE" "SELECT uuid FROM proxy_users WHERE display_name='${CLIENT_NAME}';")

if [ -z "$UUID" ]; then
    echo "Error: User ${CLIENT_NAME} not found in database."
    exit 1
fi

# 1. Remove from Xray config.json
python3 -c "
import json
import sys

uuid = sys.argv[1]

with open('/etc/xray/config.json', 'r') as f:
    data = json.load(f)

for inbound in data.get('inbounds', []):
    if inbound.get('protocol') == 'vless' and 'settings' in inbound and 'clients' in inbound['settings']:
        inbound['settings']['clients'] = [c for c in inbound['settings']['clients'] if c.get('id') != uuid]

with open('/etc/xray/config.json', 'w') as f:
    json.dump(data, f, indent=2)
" "$UUID"

# 2. Remove from Hysteria config.yaml
sed -i "/- \"$UUID\"/d" /etc/hysteria/config.yaml

# 3. Restart services
systemctl restart xray hysteria > /dev/null 2>&1

# 4. Remove from DB
sqlite3 "$DB_FILE" "DELETE FROM proxy_users WHERE display_name='${CLIENT_NAME}';"

echo "[ ✔ ] User ${CLIENT_NAME} deleted successfully."
