import requests
import json
import uuid

XUI_URL = "http://127.0.0.1:2053/xui/API/inbounds"
LOGIN_URL = "http://127.0.0.1:2053/login"

def get_session():
    try:
        session = requests.Session()
        # Default credentials set by our core_setup.sh
        resp = session.post(LOGIN_URL, data={"username": "admin", "password": "admin"}, timeout=3)
        if resp.json().get('success'):
            return session
    except:
        pass
    return None

def init_default_inbound():
    """Create a default VLESS REALITY inbound if none exists."""
    session = get_session()
    if not session:
        return False
    
    resp = session.get(XUI_URL)
    inbounds = resp.json().get('obj', [])
    if len(inbounds) > 0:
        return True # Inbound already exists
        
    # Create VLESS REALITY Inbound
    client_id = str(uuid.uuid4())
    inbound_data = {
        "up": 0,
        "down": 0,
        "total": 0,
        "remark": "BlueFalcon-VLESS",
        "enable": True,
        "expiryTime": 0,
        "listen": "",
        "port": 443,
        "protocol": "vless",
        "settings": json.dumps({
            "clients": [
                {
                    "id": client_id,
                    "flow": "xtls-rprx-vision",
                    "email": "admin",
                    "limitIp": 0,
                    "totalGB": 0,
                    "expiryTime": 0,
                    "enable": True,
                    "tgId": "",
                    "subId": ""
                }
            ],
            "decryption": "none",
            "fallbacks": []
        }),
        "streamSettings": json.dumps({
            "network": "tcp",
            "security": "reality",
            "realitySettings": {
                "show": False,
                "dest": "yahoo.com:443",
                "xver": 0,
                "serverNames": ["yahoo.com"],
                "privateKey": "", # 3x-ui auto-generates if empty
                "minClientVer": "",
                "maxClientVer": "",
                "maxTimeDiff": 0,
                "shortIds": [""]
            }
        }),
        "sniffing": json.dumps({
            "enabled": True,
            "destOverride": ["http", "tls", "quic"],
            "routeOnly": False
        })
    }
    
    res = session.post(f"{XUI_URL}/add", data=inbound_data)
    return res.json().get('success', False)

def add_client(sys_name, user_uuid):
    session = get_session()
    if not session: return False
    
    # Get inbound ID
    resp = session.get(XUI_URL)
    inbounds = resp.json().get('obj', [])
    if not inbounds:
        init_default_inbound()
        resp = session.get(XUI_URL)
        inbounds = resp.json().get('obj', [])
        
    if not inbounds: return False
    
    inbound_id = inbounds[0]['id']
    
    # Add client
    client_data = {
        "id": inbound_id,
        "settings": json.dumps({
            "clients": [
                {
                    "id": user_uuid,
                    "flow": "xtls-rprx-vision",
                    "email": sys_name,
                    "limitIp": 0,
                    "totalGB": 0,
                    "expiryTime": 0,
                    "enable": True,
                    "tgId": "",
                    "subId": ""
                }
            ]
        })
    }
    
    res = session.post(f"{XUI_URL}/addClient", data=client_data)
    return res.json().get('success', False)

def get_client_uri(sys_name):
    session = get_session()
    if not session: return None
    
    resp = session.get(XUI_URL)
    inbounds = resp.json().get('obj', [])
    if not inbounds: return None
    
    inbound = inbounds[0]
    settings = json.loads(inbound['settings'])
    stream = json.loads(inbound['streamSettings'])
    
    port = inbound['port']
    # If 3x-ui generated the public key, it usually puts it in streamSettings -> realitySettings -> settings?
    # Actually, we can fetch the full link from the panel or construct it.
    # But wait, 3x-ui stores public key in x-ui.db or we can extract it from realitySettings?
    # Let's extract what we can.
    
    for client in settings.get('clients', []):
        if client.get('email') == sys_name:
            return {
                "uuid": client['id'],
                "port": port,
                "stream": stream
            }
            
    return None

def remove_client(user_uuid):
    session = get_session()
    if not session: return False
    
    # Get inbound ID
    resp = session.get(XUI_URL)
    inbounds = resp.json().get('obj', [])
    if not inbounds: return False
    
    inbound_id = inbounds[0]['id']
    res = session.post(f"http://127.0.0.1:2053/xui/API/inbounds/delClient/{user_uuid}")
    return res.json().get('success', False)
