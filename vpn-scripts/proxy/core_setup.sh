#!/usr/bin/env bash
# ==============================================================================
# Xray & Hysteria Core Setup Script
# ==============================================================================
set -e
umask 077

PORT="${1:-443}"
SNI="${2:-www.microsoft.com}"

echo "🚀 STARTING XRAY & HYSTERIA INSTALLATION..."
echo "-----------------------------------------------------"
echo "  Downloading Core Engines"
echo "-----------------------------------------------------"
apt-get update -y > /dev/null 2>&1
apt-get install -y unzip jq curl qrencode > /dev/null 2>&1
mkdir -p /usr/local/bin /etc/xray /etc/hysteria /var/log/xray /var/log/hysteria

# Install Xray
wget -qO xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
unzip -q -o xray.zip xray -d /usr/local/bin/
rm xray.zip
chmod +x /usr/local/bin/xray

# Install Hysteria 2
wget -qO /usr/local/bin/hysteria "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64"
chmod +x /usr/local/bin/hysteria

echo "  Generating Xray REALITY Keys"
echo "-----------------------------------------------------"
XRAY_KEYS=$(/usr/local/bin/xray x25519)
XRAY_PRIV=$(echo "$XRAY_KEYS" | grep "Private key" | awk '{print $3}')
XRAY_PUB=$(echo "$XRAY_KEYS" | grep "Public key" | awk '{print $3}')
XRAY_SHORTID=$(openssl rand -hex 8)

echo "  Generating Hysteria Certificates"
echo "-----------------------------------------------------"
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=${SNI}"

echo "  Configuring Xray (VLESS-TCP-REALITY + VLESS-xHTTP-REALITY)"
echo "-----------------------------------------------------"
cat > /etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning", "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log" },
  "inbounds": [
    {
      "tag": "vless-tcp",
      "port": ${PORT},
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
          "dest": "${SNI}:443",
          "xver": 0,
          "serverNames": ["${SNI}"],
          "privateKey": "${XRAY_PRIV}",
          "shortIds": ["${XRAY_SHORTID}"]
        }
      },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
    },
    {
      "tag": "vless-xhttp",
      "port": 2053,
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
          "dest": "${SNI}:443",
          "xver": 0,
          "serverNames": ["${SNI}"],
          "privateKey": "${XRAY_PRIV}",
          "shortIds": ["${XRAY_SHORTID}"]
        }
      },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

echo "  Configuring Hysteria 2"
echo "-----------------------------------------------------"
cat > /etc/hysteria/config.yaml <<EOF
listen: :${PORT}
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
auth:
  type: password
  passwords:
    - "INIT_DUMMY"
masquerade:
  type: proxy
  proxy:
    url: https://${SNI}
    rewriteHost: true
EOF

echo "  Creating Systemd Services"
echo "-----------------------------------------------------"
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria 2 Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
WorkingDirectory=/etc/hysteria
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray hysteria > /dev/null 2>&1
systemctl restart xray hysteria > /dev/null 2>&1

echo "  Configuring Firewall"
echo "-----------------------------------------------------"
ufw allow ${PORT}/tcp > /dev/null 2>&1 || true
ufw allow 2053/tcp > /dev/null 2>&1 || true
ufw allow ${PORT}/udp > /dev/null 2>&1 || true

# Update SQLite Database
sqlite3 /opt/bluefalcon-ultimate-toolkit/panel.db "UPDATE settings SET is_installed=1, port=${PORT}, dns='${SNI}', dns2='${XRAY_PUB}|${XRAY_SHORTID}' WHERE server_name='proxy';"

echo "[ ✔ ] Xray & Hysteria successfully installed on TCP/UDP ${PORT} and TCP 2053!"
