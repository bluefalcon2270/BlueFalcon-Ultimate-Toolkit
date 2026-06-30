#!/bin/bash

# ==============================================================================
# BlueFalcon Xray & Proxies Installer (via 3x-ui)
# ==============================================================================

set -uo pipefail

echo "====================================================="
echo "   Installing 3x-ui (Xray/REALITY/Hysteria2)         "
echo "====================================================="

XRAY_SNI=$1
if [ -z "$XRAY_SNI" ]; then
    XRAY_SNI="yahoo.com"
fi

# 1. Install 3x-ui
echo "  -> Downloading and Installing 3x-ui..."
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) > /dev/null 2>&1

# 2. Reset 3x-ui Admin Credentials and Port
echo "  -> Configuring 3x-ui Default Admin (admin/admin on port 2053)..."
/usr/local/x-ui/x-ui setting -username admin -password admin -port 2053 > /dev/null 2>&1

# 3. Restart 3x-ui
echo "  -> Restarting 3x-ui Service..."
systemctl restart x-ui

# 4. Open Firewall for Panel
echo "  -> Configuring Firewall..."
ufw allow 2053/tcp >/dev/null 2>&1

echo "✅ [3X-UI] Deployment Complete! The backend will now initialize the inbounds."
