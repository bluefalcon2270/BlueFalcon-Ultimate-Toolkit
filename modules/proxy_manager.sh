#!/usr/bin/env bash
# ==============================================================================
# Next-Gen Proxy Manager Module
# ==============================================================================
manage_proxy() {
    clear
    echo -e "${BOLD_BLUE}=====================================================${NC}"
    echo -e "${BOLD_BLUE}             Next-Gen Proxy (Xray/Hysteria)          ${NC}"
    echo -e "${BOLD_BLUE}=====================================================${NC}"
    echo ""
    
    DB_FILE="/opt/bluefalcon-ultimate-toolkit/panel.db"
    if [ ! -f "$DB_FILE" ]; then
        echo -e "[ ${RED}✖${NC} ] Database not found. Please initialize the web panel first."
        sleep 2
        return
    fi
    
    IS_INST=$(sqlite3 "$DB_FILE" "SELECT is_installed FROM settings WHERE server_name='proxy';")
    
    if [ "$IS_INST" == "1" ]; then
        echo -e "Status: [ ${GREEN}ONLINE${NC} ]"
        echo ""
        echo "1. Add User"
        echo "2. Delete User"
        echo "3. Restart Services"
        echo "4. Uninstall Proxy Suite"
    else
        echo -e "Status: [ ${RED}OFFLINE${NC} ]"
        echo ""
        echo "1. Install Next-Gen Proxy (VLESS+REALITY & Hysteria 2)"
    fi
    echo "0. Back to Main Menu"
    echo ""
    read -rp "Select option: " proxy_choice
    
    if [ "$IS_INST" == "1" ]; then
        case "${proxy_choice}" in
            1) 
                read -rp "Enter new client name: " c_name
                bash /opt/bluefalcon-ultimate-toolkit/vpn-scripts/proxy/add_user.sh "$c_name" 365
                read -rp "Press Enter to continue..."
                ;;
            2) 
                read -rp "Enter client name to delete: " d_name
                bash /opt/bluefalcon-ultimate-toolkit/vpn-scripts/proxy/del_user.sh "$d_name"
                read -rp "Press Enter to continue..."
                ;;
            3) 
                bash /opt/bluefalcon-ultimate-toolkit/vpn-scripts/proxy/action.sh start
                read -rp "Press Enter to continue..."
                ;;
            4) 
                read -rp "Type 'yes' to fully purge the Proxy suite: " conf
                if [ "$conf" == "yes" ]; then
                    bash /opt/bluefalcon-ultimate-toolkit/vpn-scripts/proxy/action.sh purge
                fi
                ;;
            0) return ;;
        esac
    else
        case "${proxy_choice}" in
            1) 
                read -rp "Enter listening Port (Default 443): " p_port
                p_port=${p_port:-443}
                read -rp "Enter Camouflage SNI (Default www.microsoft.com): " p_sni
                p_sni=${p_sni:-www.microsoft.com}
                bash /opt/bluefalcon-ultimate-toolkit/vpn-scripts/proxy/core_setup.sh "$p_port" "$p_sni"
                read -rp "Press Enter to continue..."
                ;;
            0) return ;;
        esac
    fi
}
