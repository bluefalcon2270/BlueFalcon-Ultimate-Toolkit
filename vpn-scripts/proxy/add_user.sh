#!/usr/bin/env bash
# ==============================================================================
# Next-Gen Proxy Add User Script (Xray & Hysteria 2)
# Usage: ./add_user.sh <client_name> <exp_days>
# ==============================================================================
set -e
umask 077

CLIENT_NAME=$1
EXP_DAYS=$2
EXP_DATE=$(date -d "+${EXP_DAYS} days" +%s)
UUID=$(cat /proc/sys/kernel/random/uuid)

DB_FILE="/opt/bluefalcon-ultimate-toolkit/panel.db"

# 1. Add to Xray config.json
python3 -c "
import json
import sys

uuid = sys.argv[1]
email = sys.argv[2]

with open('/etc/xray/config.json', 'r') as f:
    data = json.load(f)

for inbound in data.get('inbounds', []):
    if inbound.get('protocol') == 'vless':
        if 'settings' not in inbound: inbound['settings'] = {}
        if 'clients' not in inbound['settings']: inbound['settings']['clients'] = []
        inbound['settings']['clients'].append({
            'id': uuid,
            'email': email,
            'flow': 'xtls-rprx-vision' if inbound.get('streamSettings', {}).get('network') == 'tcp' else ''
        })

with open('/etc/xray/config.json', 'w') as f:
    json.dump(data, f, indent=2)
" "$UUID" "$CLIENT_NAME"

# 2. Add to Hysteria config.yaml
# We just append the UUID as a new password to the passwords list
# If it's the first real user, INIT_DUMMY will just sit there (or we can remove it)
sed -i "/passwords:/a \ \ \ \ - \"$UUID\"" /etc/hysteria/config.yaml

# 3. Restart services
systemctl restart xray hysteria > /dev/null 2>&1

# 4. Update SQLite database
sqlite3 "$DB_FILE" "INSERT INTO proxy_users (display_name, uuid, password, exp_days, status, rx, tx) VALUES ('${CLIENT_NAME}', '${UUID}', '', ${EXP_DAYS}, 'active', 0, 0);"

echo "[ ✔ ] User ${CLIENT_NAME} added successfully with UUID ${UUID}."
