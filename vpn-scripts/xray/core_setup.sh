#!/bin/bash

# BlueFalcon Ultimate Toolkit - Xray & Hysteria Core Setup
# --------------------------------------------------------

APP_DIR="/opt/bluefalcon-ultimate-toolkit"
DB_PATH="${APP_DIR}/panel.db"

echo "🦅 [XRAY & HYSTERIA] Initialization Sequence Started..."

# 1. Fetch Configuration from Database
echo "  -> Reading Database Configuration..."
XRAY_PORT=$(sqlite3 ${DB_PATH} "SELECT port FROM settings WHERE server_name='xray';")
XRAY_SNI=$(sqlite3 ${DB_PATH} "SELECT sni FROM settings WHERE server_name='xray';")

if [ -z "$XRAY_PORT" ]; then XRAY_PORT=443; fi
if [ -z "$XRAY_SNI" ]; then XRAY_SNI="www.microsoft.com"; fi

echo "     - Primary Port: ${XRAY_PORT}"
echo "     - REALITY Target: ${XRAY_SNI}"

# 2. Install Xray-Core
echo "  -> Installing Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
mkdir -p /etc/xray

# Generate REALITY Keys
echo "  -> Generating x25519 Keys for REALITY..."
XRAY_BIN=$(command -v xray || echo /usr/local/bin/xray)
$XRAY_BIN x25519 > /tmp/xray_keys.txt

# Use Python to strictly parse the keys, stripping all ANSI/newlines, and ensure they are 43-character base64url strings.
python3 -c "
import re, json, os, binascii
try:
    with open('/tmp/xray_keys.txt', 'r', encoding='utf-8', errors='ignore') as f:
        data = f.read()
    # Find base64url strings that are exactly 43 chars long
    prv = re.search(r'(?i)Private key.*?(?P<key>[A-Za-z0-9_-]{43})', data).group('key')
    pub = re.search(r'(?i)Public key.*?(?P<key>[A-Za-z0-9_-]{43})', data).group('key')
    sid = binascii.b2a_hex(os.urandom(4)).decode('utf-8')
    with open('/etc/xray/reality.json', 'w') as f:
        json.dump({'pbk': pub, 'sid': sid}, f)
    with open('/tmp/xray_parsed_keys.txt', 'w') as f:
        f.write(prv + '\n' + sid)
    os.chmod('/etc/xray/reality.json', 0o644)
    os.chmod('/tmp/xray_parsed_keys.txt', 0o644)
except Exception as e:
    print('Failed to parse keys:', e)
"

PRV_KEY=$(sed -n '1p' /tmp/xray_parsed_keys.txt)
SHORT_ID=$(sed -n '2p' /tmp/xray_parsed_keys.txt)

# 3. Write Xray Configuration (config.json)
echo "  -> Writing Xray config.json..."
cat <<EOF > /etc/xray/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${XRAY_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${XRAY_SNI}:443",
          "xver": 0,
          "serverNames": ["${XRAY_SNI}"],
          "privateKey": "${PRV_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    },
    {
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${XRAY_SNI}:443",
          "xver": 0,
          "serverNames": ["${XRAY_SNI}"],
          "privateKey": "${PRV_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF

# 4. Install Hysteria 2
echo "  -> Installing Hysteria 2..."
bash <(curl -fsSL https://get.hy2.sh/) > /dev/null 2>&1
mkdir -p /etc/hysteria

# 5. Write Hysteria Configuration (config.yaml)
echo "  -> Writing Hysteria config.yaml..."
# Hysteria requires a certificate. We use self-signed for stealth against active probing (with obfuscation)
openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -days 3650 -subj "/CN=${XRAY_SNI}" > /dev/null 2>&1

# Generate the SHA256 pin for clients to avoid "insecure" MITM warnings
openssl x509 -noout -fingerprint -sha256 -in /etc/hysteria/server.crt | awk -F= '{gsub(/:/, "", $2); print tolower($2)}' > /etc/hysteria/cert_pin.txt
chmod 644 /etc/hysteria/cert_pin.txt
chmod 644 /etc/hysteria/server.crt

cat <<EOF > /etc/hysteria/config.yaml
listen: :443
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
  sni: ${XRAY_SNI}

auth:
  type: password
  password:
    - placeholder_do_not_remove

masquerade:
  type: proxy
  proxy:
    url: https://${XRAY_SNI}
    rewriteHost: true
EOF

# 6. Set up systemd services
echo "  -> Restarting Services..."
systemctl enable --now xray > /dev/null 2>&1
systemctl restart xray

systemctl enable --now hysteria-server.service > /dev/null 2>&1
systemctl restart hysteria-server.service

echo "  -> Configuring Firewall..."
ufw allow ${XRAY_PORT}/tcp >/dev/null 2>&1
ufw allow 8443/tcp >/dev/null 2>&1
ufw allow 443/udp >/dev/null 2>&1

echo "✅ [XRAY & HYSTERIA] Deployment Complete!"
