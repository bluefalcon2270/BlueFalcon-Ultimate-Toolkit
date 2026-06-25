#!/bin/bash
# ==============================================================================
# --- MODULE 6: Logs Manager ---
# ==============================================================================

view_logs() {
    local log_name="$1"
    local systemd_unit="$2"
    
    clear
    echo -e "${BOLD_BLUE}--- ${log_name} ---${NC}\nStreaming real-time service logs. Press Ctrl+C to exit.\n"
    trap 'true' SIGINT
    if [ "$systemd_unit" == "syslog" ]; then
        if [ -f /var/log/syslog ]; then
            tail -f -n 50 /var/log/syslog
        elif [ -f /var/log/messages ]; then
            tail -f -n 50 /var/log/messages
        fi
    else
        journalctl -u "$systemd_unit" -f -n 50
    fi
    trap cleanup SIGINT SIGTERM
}

manage_logs() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}                   Log Center                        ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. View Web Panel Logs"
        echo "2. View OpenVPN Logs"
        echo "3. View WARP Logs"
        echo "4. View System Logs"
        echo "0. Return to Main Menu"
        echo ""
        
        read -rp "Select option: " o_choice
        case "$o_choice" in
            1) view_logs "Web Panel Logs" "bluefalcon-panel" ;;
            2) view_logs "OpenVPN Logs" "openvpn-server@server" ;;
            3) view_logs "WARP Logs" "wg-quick@wgcf" ;;
            4) view_logs "System Logs" "syslog" ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}
