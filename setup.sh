#!/usr/bin/env bash

# ==============================================================================
# BlueFalcon Ultimate Toolkit (God Script)
# Version: v1.9
# Architecture: Optimized for Debian & Ubuntu (Bash/Python/SQLite Stack)
# ==============================================================================

set -uo pipefail

# --- Constants & Configuration ---
readonly SCRIPT_VERSION="v1.9"
readonly APP_DIR="/opt/bluefalcon-ultimate-toolkit"
readonly LOG_FILE="/var/log/bluefalcon_toolkit.log"
readonly WARP_LOG="/var/log/bluefalcon_warp.log"
readonly SSH_CONFIG="/etc/ssh/sshd_config"

# --- Colors ---
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BOLD_BLUE='\033[1;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# --- Initialization & Traps ---
touch "${LOG_FILE}" "${WARP_LOG}"

cleanup() {
    echo -e "${NC}\n[!] Process interrupted. Cleaning up..."
    local jobs=$(jobs -p)
    [ -n "$jobs" ] && kill $jobs 2>/dev/null
    tput cnorm
    rm -f /tmp/wgcf.sh
    exit 1
}
trap cleanup SIGINT SIGTERM

# --- Core Utility Functions ---
pause_execution() {
    tput cnorm
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
    echo ""
}

run_with_spinner() {
    local msg="$1"
    shift
    local log_tgt="${CURRENT_LOG:-$LOG_FILE}"
    "$@" >> "$log_tgt" 2>&1 &
    local pid=$!
    local delay=0.1
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    
    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        for frame in "${frames[@]}"; do
            printf "\r[ ${CYAN}%s${NC} ] %s" "$frame" "$msg"
            sleep $delay
        done
    done
    wait "$pid"
    local exit_status=$?
    
    if [ $exit_status -eq 0 ]; then
        printf "\r[ ${GREEN}✔${NC} ] %s\n" "$msg"
    else
        printf "\r[ ${RED}✖${NC} ] %s\n" "$msg"
        tput cnorm
        return 1
    fi
    tput cnorm
}

check_preflight() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "[ ${RED}✖${NC} ] Error: This script requires root privileges. Execute with sudo or as root."
        exit 1
    fi
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "[ ${RED}✖${NC} ] Error: No active internet connection detected."
        exit 1
    fi
    if lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || lsof /var/lib/apt/lists/lock >/dev/null 2>&1; then
        echo -e "[ ${RED}✖${NC} ] Error: Package manager is currently locked by another process."
        exit 1
    fi
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "${ID}" == "ubuntu" && ("${VERSION_ID}" == "22.04" || "${VERSION_ID}" == "24.04") ]] || \
           [[ "${ID}" == "debian" && ("${VERSION_ID}" == "11" || "${VERSION_ID}" == "12" || "${VERSION_ID}" == "13") ]]; then
            :
        else
            echo -e "[ ${RED}✖${NC} ] Error: Toolkit strictly supports Ubuntu 22.04/24.04 or Debian 11/12/13."
            exit 1
        fi
    else
        echo -e "[ ${RED}✖${NC} ] Error: Cannot detect OS. /etc/os-release missing."
        exit 1
    fi
}

# ==============================================================================
# --- MODULE 1: Essential Tools & SSH Configuration ---
# ==============================================================================
update_ssh_config() {
    local key="$1"
    local value="$2"
    cp "${SSH_CONFIG}" "${SSH_CONFIG}.bak"
    if grep -iqE "^#?${key}\s+" "${SSH_CONFIG}"; then
        sed -i -E "s/^#?${key}\s+.*/${key} ${value}/I" "${SSH_CONFIG}"
    else
        echo "${key} ${value}" >> "${SSH_CONFIG}"
    fi
    if sshd -t; then
        systemctl restart ssh sshd 2>/dev/null || true
        echo -e "[ ${GREEN}✔${NC} ] SSH configuration updated to: ${key} ${value}"
    else
        echo -e "[ ${RED}✖${NC} ] Invalid SSH configuration detected. Restoring backup..."
        mv "${SSH_CONFIG}.bak" "${SSH_CONFIG}"
    fi
}

get_ssh_status() {
    local key="$1"
    local default_value="$2"
    local status
    status=$(sshd -T 2>/dev/null | grep -i "^${key} " | awk '{print $2}')
    echo "${status:-$default_value}"
}

format_ssh_status() {
    if [[ "${1,,}" == "yes" ]]; then
        echo -e "${GREEN}ON${NC}"
    elif [[ "${1,,}" == "no" ]]; then
        echo -e "${RED}OFF${NC}"
    else
        echo -e "${YELLOW}${1}${NC}"
    fi
}

manage_ssh_access() {
    while true; do
        clear
        local current_port pw_auth_raw key_auth_raw pw_auth key_auth
        current_port=$(get_ssh_status "port" "Unknown")
        pw_auth_raw=$(get_ssh_status "passwordauthentication" "Unknown")
        key_auth_raw=$(get_ssh_status "pubkeyauthentication" "Unknown")
        pw_auth=$(format_ssh_status "${pw_auth_raw}")
        key_auth=$(format_ssh_status "${key_auth_raw}")

        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}                    SSH Settings                     ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e " Port:             ${current_port}"
        echo -e " Password Login:   ${pw_auth}"
        echo -e " Key Login:        ${key_auth}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Change Password"
        echo "2. Change Port"
        echo "3. Toggle Password Login"
        echo "4. Toggle Key Login"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " ssh_choice
        case "${ssh_choice}" in
            1)
                echo ""
                read -rp "Enter username to change password (leave empty for 'root'): " target_user
                passwd "${target_user:-root}"
                pause_execution ;;
            2)
                echo ""
                read -rp "Enter new SSH port (1024-65535): " new_port
                if [[ "${new_port}" =~ ^[0-9]+$ ]] && [ "${new_port}" -ge 1024 ] && [ "${new_port}" -le 65535 ]; then
                    update_ssh_config "Port" "${new_port}"
                else
                    echo -e "[ ${RED}✖${NC} ] Invalid port range."
                fi
                pause_execution ;;
            3)
                echo ""
                local new_pw_auth="yes"
                [[ "${pw_auth_raw,,}" == "yes" ]] && new_pw_auth="no"
                update_ssh_config "PasswordAuthentication" "${new_pw_auth}"
                pause_execution ;;
            4)
                echo ""
                local new_key_auth="yes"
                [[ "${key_auth_raw,,}" == "yes" ]] && new_key_auth="no"
                update_ssh_config "PubkeyAuthentication" "${new_key_auth}"
                pause_execution ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}

update_system() {
    clear
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo -e "${BOLD_BLUE}                    Update System                    ${NC}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo ""
    echo -e "${BOLD_BLUE}--- Updating Repositories ---${NC}"
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a || true
    apt-get update -y
    
    echo -e "\n${BOLD_BLUE}--- Upgrading Packages ---${NC}"
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    echo -e "\n[ ${GREEN}✔${NC} ] System update and upgrade successfully finished!"
    pause_execution
}

install_docker_engine() {
    export DEBIAN_FRONTEND=noninteractive
    . /etc/os-release
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_utilities() {
    clear
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo -e "${BOLD_BLUE}                   System Packages                   ${NC}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo ""
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a >> "${LOG_FILE}" 2>&1 || true
    
    local std_pkgs=(curl wget git htop unzip zip nano net-tools tmux screen socat cron ufw iptables nftables qrencode dnsutils)
    
    for pkg in "${std_pkgs[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            run_with_spinner "$pkg" apt-get install -yq "$pkg"
        else
            echo -e "[ ${GREEN}✔${NC} ] ${pkg}"
        fi
    done
    
    if ! command -v docker >/dev/null 2>&1 || ! dpkg-query -W -f='${Status}' "docker-compose-plugin" 2>/dev/null | grep -q "ok installed"; then
        run_with_spinner "Docker Engine & Compose" install_docker_engine
    else
        echo -e "[ ${GREEN}✔${NC} ] Docker Engine & Compose"
    fi

    echo -e "\nInstallation process finished,"
    pause_execution
}

manage_utilities() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}                   System Packages                   ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        
        local std_pkgs=(curl wget git htop unzip zip nano net-tools tmux screen socat cron ufw iptables nftables qrencode dnsutils)
        for pkg in "${std_pkgs[@]}"; do
            if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
                echo -e "[ ${GREEN}✔${NC} ] ${pkg}"
            else
                echo -e "[ ${RED}✖${NC} ] ${pkg}"
            fi
        done
        
        if command -v docker >/dev/null 2>&1 && dpkg-query -W -f='${Status}' "docker-compose-plugin" 2>/dev/null | grep -q "ok installed"; then
            echo -e "[ ${GREEN}✔${NC} ] Docker Engine & Compose"
        else
            echo -e "[ ${RED}✖${NC} ] Docker Engine & Compose"
        fi
        
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Install Missing Packages"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " util_choice
        case "${util_choice}" in
            1) install_utilities ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}

manage_essential() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}                   Essential Tools                   ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Update System"
        echo "2. System Packages"
        echo "3. SSH Settings"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " ess_choice
        case "${ess_choice}" in
            1) update_system ;;
            2) manage_utilities ;;
            3) manage_ssh_access ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}

# ==============================================================================
# --- MODULE 2: WARP Routing Utility ---
# ==============================================================================
WGCF_conf="/etc/wireguard/wgcf.conf"
Profile_conf="/etc/warp/wgcf-profile.conf"
Wgcf_account="/etc/warp/wgcf-account.toml"
CF_Trace_URL='https://www.cloudflare.com/cdn-cgi/trace'

install_warp_prereqs() {
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a >> "${WARP_LOG}" 2>&1 || true
    apt-get update -y >> "${WARP_LOG}" 2>&1
    apt-get install -y curl gnupg lsb-release ca-certificates >> "${WARP_LOG}" 2>&1
}

install_wgcf() {
    if command -v wgcf >/dev/null 2>&1; then return 0; fi
    curl -fsSL git.io/wgcf.sh -o /tmp/wgcf.sh >> "${WARP_LOG}" 2>&1
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Installing WGCF Binary" bash /tmp/wgcf.sh >> "${WARP_LOG}" 2>&1
}

install_cloudflare_packages() {
    if command -v warp-cli >/dev/null 2>&1; then return 0; fi
    export DEBIAN_FRONTEND=noninteractive
    . /etc/os-release
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg >> "${WARP_LOG}" 2>&1
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
    apt-get update -y >> "${WARP_LOG}" 2>&1
    local dns_pkg="resolvconf"
    if apt-cache show openresolv >/dev/null 2>&1; then dns_pkg="openresolv"; fi
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Installing Cloudflare Packages" apt-get install cloudflare-warp iproute2 "${dns_pkg}" wireguard-tools -y >> "${WARP_LOG}" 2>&1
}

register_account() {
    mkdir -p /etc/warp
    cd /etc/warp || exit
    if [[ -f "$Wgcf_account" ]]; then return 0; fi
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Registering Free Account" wgcf register --accept-tos >> "${WARP_LOG}" 2>&1
}

build_config() {
    cd /etc/warp || exit
    wgcf generate >> "${WARP_LOG}" 2>&1
    [ -d "/etc/wireguard" ] || mkdir -p "/etc/wireguard"
    
    local PrivateKey=$(grep ^PrivateKey "${Profile_conf}" | cut -d= -f2- | awk '$1=$1')
    local Address=$(grep ^Address "${Profile_conf}" | cut -d= -f2- | awk '$1=$1' | sed ":a;N;s/\n/,/g;ta")
    local PublicKey=$(grep ^PublicKey "${Profile_conf}" | cut -d= -f2- | awk '$1=$1')
    local MTU=1280
    
    cat <<EOF >${WGCF_conf}
[Interface]
PrivateKey = ${PrivateKey}
Address = ${Address}
DNS = 8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844
MTU = ${MTU}
EOF

    local IPv4_addr=$(hostname -I | awk '{print $1}')
    local IPv6_addr=$(hostname -I | awk '{ for(i=1;i<=NF;i++) if($i~/^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{1,4}$/) {print $i; exit} }')

    case $1 in
        1)
            cat <<EOF >>${WGCF_conf}
PreUp = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -4 rule add from ${IPv4_addr} lookup main prio 18
PostDown = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
[Peer]
PublicKey = ${PublicKey}
AllowedIPs = 0.0.0.0/0
Endpoint = 162.159.192.1:2408
EOF
            ;;
        2)
            cat <<EOF >>${WGCF_conf}
PreUp = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -6 rule add from ${IPv6_addr} lookup main prio 18
PostDown = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
[Peer]
PublicKey = ${PublicKey}
AllowedIPs = ::/0
Endpoint = [2606:4700:d0::a29f:c001]:2408
EOF
            ;;
        3)
            cat <<EOF >>${WGCF_conf}
PreUp = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -4 rule add from ${IPv4_addr} lookup main prio 18
PostDown = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
PreUp = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -6 rule add from ${IPv6_addr} lookup main prio 18
PostDown = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
[Peer]
PublicKey = ${PublicKey}
AllowedIPs = 0.0.0.0/0,::/0
Endpoint = engage.cloudflareclient.com:2408
EOF
            ;;
    esac
}

execute_warp_install() {
    local target=$1
    echo ""
    install_warp_prereqs
    install_wgcf
    if ! install_cloudflare_packages; then
        echo -e "\n[ ${RED}✖${NC} ] Critical failure during package installation. Aborting."
        sleep 3
        return
    fi
    register_account
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Building wgcf.conf" build_config "$target"
    (crontab -l 2>/dev/null | grep -v "wg-quick@wgcf"; echo "0 4 * * * systemctl restart wg-quick@wgcf;systemctl restart warp-svc") | crontab -
    
    if CURRENT_LOG="${WARP_LOG}" run_with_spinner "Enabling WireGuard Service" systemctl enable --now wg-quick@wgcf >> "${WARP_LOG}" 2>&1; then
        echo -e "\n[ ${GREEN}✔${NC} ] WARP Installation Completed Successfully!"
    else
        echo -e "\n[ ${RED}✖${NC} ] Failed to start WireGuard. Check 'View WARP Logs'."
    fi
    sleep 3
}

toggle_warp_service() {
    echo ""
    if [ ! -f "/etc/wireguard/wgcf.conf" ]; then 
        echo -e "[ ${RED}✖${NC} ] WARP is not installed."
        sleep 2; return
    fi
    
    if ip link show wgcf >/dev/null 2>&1; then
        systemctl disable --now wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        wg-quick down wgcf >> "${WARP_LOG}" 2>&1
        ip link delete wgcf >/dev/null 2>&1
        echo -e "[ ${RED}✖${NC} ] WARP Service Stopped."
    else
        wg-quick down wgcf >/dev/null 2>&1
        systemctl enable --now wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        if ! ip link show wgcf >/dev/null 2>&1; then wg-quick up wgcf >> "${WARP_LOG}" 2>&1; fi
        echo -e "[ ${GREEN}✔${NC} ] WARP Service Started."
    fi
    sleep 2
}

uninstall_warp() {
    echo ""
    if [ -f "/etc/wireguard/wgcf.conf" ] || command -v wgcf >/dev/null 2>&1; then
        systemctl stop wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        systemctl disable wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        export DEBIAN_FRONTEND=noninteractive
        CURRENT_LOG="${WARP_LOG}" run_with_spinner "Purging Packages" apt-get purge cloudflare-warp -y >> "${WARP_LOG}" 2>&1
        rm -rf /etc/warp /etc/wireguard/wgcf* /usr/local/bin/wgcf
        ip link delete wgcf >/dev/null 2>&1
        echo -e "\n[ ${GREEN}✔${NC} ] WARP Uninstalled."
    else
        echo -e "[ ${RED}✖${NC} ] WARP is not installed."
    fi
    pause_execution
}

draw_warp_dashboard() {
    local VPS_IPv4_Int=$(hostname -I | awk '{print $1}')
    [ -z "$VPS_IPv4_Int" ] && VPS_IPv4_Int="N/A"
    
    local VPS_IPv6_Int=$(hostname -I | awk '{ for(i=1;i<=NF;i++) if($i~/^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{1,4}$/) {print $i; exit} }')
    [ -z "$VPS_IPv6_Int" ] && VPS_IPv6_Int="N/A"

    local WARP_IPv4_Status=$(curl -s4 ${CF_Trace_URL} --connect-timeout 2 | grep warp | cut -d= -f2 || echo "off")
    local WARP_IPv4_IP=$(curl -s4 ${CF_Trace_URL} --connect-timeout 2 | grep ip | cut -d= -f2 || echo "------------")
    local WARP_IPv6_Status=$(curl -s6 ${CF_Trace_URL} --connect-timeout 2 | grep warp | cut -d= -f2 || echo "off")
    local WARP_IPv6_IP=$(curl -s6 ${CF_Trace_URL} --connect-timeout 2 | grep ip | cut -d= -f2 || echo "------------")

    local active_tag="  ${GREEN}(🟢 Active)${NC}"
    local v4_vps_out v4_warp_out v6_vps_out v6_warp_out

    if [[ ${WARP_IPv4_Status} == "on" || ${WARP_IPv4_Status} == "plus" ]]; then
        v4_vps_out="${YELLOW}${VPS_IPv4_Int}${NC}"
        v4_warp_out="${GREEN}${WARP_IPv4_IP}${NC}${active_tag}"
    else
        v4_vps_out="${GREEN}${VPS_IPv4_Int}${NC}${active_tag}"
        v4_warp_out="${RED}------------${NC}"
    fi

    if [[ ${WARP_IPv6_Status} == "on" || ${WARP_IPv6_Status} == "plus" ]]; then
        v6_vps_out="${YELLOW}${VPS_IPv6_Int}${NC}"
        v6_warp_out="${GREEN}${WARP_IPv6_IP}${NC}${active_tag}"
    else
        v6_vps_out="${GREEN}${VPS_IPv6_Int}${NC}${active_tag}"
        v6_warp_out="${RED}------------${NC}"
    fi

    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo -e "${BOLD_BLUE}                   Cloudflare WARP                   ${NC}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo -e " VPS  (IPv4) : ${v4_vps_out}"
    echo -e " WARP (IPv4) : ${v4_warp_out}\n"
    echo -e " VPS  (IPv6) : ${v6_vps_out}"
    echo -e " WARP (IPv6) : ${v6_warp_out}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
}

manage_warp() {
    while true; do
        clear
        draw_warp_dashboard
        echo ""
        echo "1. Install WARP (Free)"
        echo "2. Install WARP+ (Key)"
        echo "3. Toggle WARP On/Off"
        echo "4. Uninstall WARP"
        echo "5. View WARP Logs"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " choice
        case "$choice" in
            1)
                echo -e "\nTarget: "
                echo -e "1- IPv4 "
                echo -e "2- IPv6"
                echo -e "3- IPv4 & IPv6 (Both)\n"
                read -rp "Select option: " t
                if [[ "$t" =~ ^[1-3]$ ]]; then execute_warp_install "$t"; fi ;;
            2)
                echo ""
                read -rp "Enter WARP+ Key: " k
                if [ -n "$k" ]; then
                    echo -e "\nTarget: "
                    echo -e "1- IPv4 "
                    echo -e "2- IPv6"
                    echo -e "3- IPv4 & IPv6 (Both)\n"
                    read -rp "Select option: " t
                    if [[ "$t" =~ ^[1-3]$ ]]; then
                        install_warp_prereqs
                        install_wgcf
                        if install_cloudflare_packages; then
                            register_account
                            sed -i "s/\(license_key = \).*/\1'${k}'/" "/etc/warp/wgcf-account.toml"
                            CURRENT_LOG="${WARP_LOG}" run_with_spinner "Applying WARP+ License" wgcf update --config /etc/warp/wgcf-account.toml
                            execute_warp_install "$t"
                        fi
                    fi
                fi ;;
            3) toggle_warp_service ;;
            4) uninstall_warp ;;
            5) 
                clear
                echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
                echo -e "${BOLD_BLUE}                   WARP Debug Logs                   ${NC}"
                echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
                echo -e "Streaming last 50 lines. Press Ctrl+C to exit.\n"
                trap 'true' SIGINT
                tail -n 50 -f "${WARP_LOG}"
                trap cleanup SIGINT SIGTERM
                ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}

# ==============================================================================
# --- MODULE 3: Universal Web Panel & OpenVPN ---
# ==============================================================================
extract_panel_files() {
    mkdir -p "${APP_DIR}/templates" "${APP_DIR}/scripts" "${APP_DIR}/configs" /var/log/bluefalcon-panel

    cat << 'EOF_APP' > "${APP_DIR}/app.py"
# /opt/bluefalcon-ultimate-toolkit/app.py
from flask import Flask, render_template, request, redirect, url_for, session, send_file, Response
import sqlite3, os, time, subprocess, re, psutil

app = Flask(__name__)
app.secret_key = 'BlueFalcon_Enterprise_Secret_Key_2026'
APP_DIR = '/opt/bluefalcon-ultimate-toolkit'
DB_PATH = f'{APP_DIR}/panel.db'
LOG_PATH = '/var/log/openvpn/status.log'

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    conn.execute('CREATE TABLE IF NOT EXISTS admin (username TEXT, password TEXT)')
    conn.execute('CREATE TABLE IF NOT EXISTS settings (server_name TEXT, protocol TEXT, port INTEGER, dns TEXT, dns2 TEXT, conn_limit TEXT, panel_port INTEGER, is_installed INTEGER DEFAULT 0)')
    try: conn.execute('ALTER TABLE settings ADD COLUMN dns2 TEXT')
    except: pass
    conn.execute('CREATE TABLE IF NOT EXISTS users (display_name TEXT, system_name TEXT, password TEXT, exp_days INTEGER, status TEXT, rx INTEGER DEFAULT 0, tx INTEGER DEFAULT 0)')
    try: conn.execute('ALTER TABLE users ADD COLUMN rx INTEGER DEFAULT 0')
    except: pass
    try: conn.execute('ALTER TABLE users ADD COLUMN tx INTEGER DEFAULT 0')
    except: pass
    conn.commit()
    conn.close()

init_db()

def get_traffic():
    live_traffic = {}; live_rx = 0; live_tx = 0
    try:
        with open(LOG_PATH, "r") as f:
            for line in f.readlines():
                parts = line.strip().split(",")
                if parts[0] == "CLIENT_LIST" and len(parts) >= 7:
                    user = parts[1]
                    try:
                        rx = int(parts[5]); tx = int(parts[6])
                        live_traffic[user] = {"rx": rx, "tx": tx}
                        live_rx += rx; live_tx += tx
                    except ValueError: pass
    except Exception: pass
    return live_traffic, live_rx, live_tx

def format_bytes(b):
    if not isinstance(b, (int, float)): return "0.0 KB"
    if b < 1048576: return f"{b/1024:.1f} KB"
    elif b < 1073741824: return f"{b/1048576:.1f} MB"
    else: return f"{b/1073741824:.2f} GB"

app.jinja_env.filters['format_bytes'] = format_bytes

@app.route('/api/sysinfo')
def sysinfo():
    if 'admin_logged_in' not in session: return {"error": "unauthorized"}, 401
    return {
        "cpu": psutil.cpu_percent(interval=None),
        "cpu_cores": psutil.cpu_percent(interval=None, percpu=True),
        "ram_percent": psutil.virtual_memory().percent,
        "ram_used": format_bytes(psutil.virtual_memory().used),
        "ram_total": format_bytes(psutil.virtual_memory().total),
        "disk_percent": psutil.disk_usage('/').percent,
        "disk_used": format_bytes(psutil.disk_usage('/').used),
        "disk_total": format_bytes(psutil.disk_usage('/').total),
        "net_rx": psutil.net_io_counters().bytes_recv,
        "net_tx": psutil.net_io_counters().bytes_sent
    }

@app.route('/')
def index():
    admin = get_db().execute('SELECT * FROM admin').fetchone()
    if not admin: return redirect(url_for('setup_wizard'))
    settings = get_db().execute('SELECT * FROM settings').fetchone()
    if settings and settings['is_installed'] == 0: return render_template('loading.html')
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    return redirect(url_for('dashboard'))

@app.route('/setup', methods=['GET', 'POST'])
def setup_wizard():
    if request.method == 'POST':
        conn = get_db()
        preset = request.form['dns_preset']
        dns1 = request.form.get('custom_dns1', '8.8.8.8') if preset == 'custom' else preset
        dns2 = request.form.get('custom_dns2', '') if preset == 'custom' else '1.0.0.1' if dns1=='1.1.1.1' else '8.8.4.4' if dns1=='8.8.8.8' else '149.112.112.112' if dns1=='9.9.9.9' else '94.140.15.15' if dns1=='94.140.14.14' else ''
        selected_protocol = request.form.get('protocol')
        selected_port = request.form.get('port')

        os.system(f"ufw allow {selected_port}/{selected_protocol} >/dev/null 2>&1")
        os.system(f"iptables -I INPUT -p {selected_protocol} --dport {selected_port} -j ACCEPT")
        os.system("netfilter-persistent save > /dev/null 2>&1")

        conn.execute('INSERT INTO admin (username, password) VALUES (?, ?)', (request.form['admin_user'], request.form['admin_pass']))
        conn.execute('INSERT INTO settings (server_name, protocol, port, dns, dns2, conn_limit, panel_port, is_installed) VALUES (?, ?, ?, ?, ?, ?, 2020, 0)', 
                    (request.form.get('server_name'), selected_protocol, selected_port, dns1, dns2, request.form.get('conn_limit')))
        conn.commit(); conn.close()
        return redirect(url_for('index'))
    return render_template('setup.html')

@app.route('/stream')
def stream():
    conn = get_db()
    settings = conn.execute('SELECT is_installed FROM settings').fetchone()
    conn.close()
    if settings and settings['is_installed'] == 1:
        def fake_generate(): yield "data: [DONE]\n\n"
        return Response(fake_generate(), mimetype='text/event-stream')

    def generate():
        process = subprocess.Popen(['bash', f'{APP_DIR}/scripts/core_setup.sh'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in iter(process.stdout.readline, ''): yield f"data: {line}\n\n"
        process.stdout.close()
        conn = get_db()
        conn.execute('UPDATE settings SET is_installed = 1')
        conn.commit(); conn.close()
        yield "data: [DONE]\n\n"
    return Response(generate(), mimetype='text/event-stream')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        conn = get_db()
        admin = conn.execute('SELECT * FROM admin WHERE username = ? AND password = ?', (request.form['username'], request.form['password'])).fetchone()
        conn.close()
        if admin:
            session['admin_logged_in'] = True
            return redirect(url_for('dashboard'))
        return render_template('login.html', error="Invalid Credentials")
    return render_template('login.html')

@app.route('/dashboard', methods=['GET', 'POST'])
def dashboard():
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    conn = get_db()
    if request.method == 'POST':
        disp_name = request.form.get('new_user')
        sys_name = re.sub(r'[^a-zA-Z0-9]', '_', disp_name).lower()
        p = request.form.get('new_pass')
        exp = int(request.form.get('exp_days', 0))
        ts = 0 if exp == 0 else int(time.time()) + (exp * 86400)
        
        if not conn.execute('SELECT 1 FROM users WHERE system_name = ?', (sys_name,)).fetchone():
            conn.execute('INSERT INTO users (display_name, system_name, password, exp_days, status, rx, tx) VALUES (?, ?, ?, ?, ?, 0, 0)', (disp_name, sys_name, p, ts, 'active'))
            conn.commit()
            with open("/etc/openvpn/server/auth/users.db", "w") as f:
                for u in conn.execute('SELECT system_name, password, exp_days, status FROM users').fetchall():
                    f.write(f"{u['system_name']}:{u['password']}:{u['exp_days']}:{u['status']}\n")
            os.system(f"bash {APP_DIR}/scripts/add_user.sh {sys_name} {p}")
        return redirect(url_for('dashboard'))

    users = conn.execute('SELECT * FROM users').fetchall()
    settings = conn.execute('SELECT * FROM settings').fetchone()
    conn.close()
    
    live_traffic, live_t_rx, live_t_tx = get_traffic()
    user_stats = {}
    total_server_rx = live_t_rx
    total_server_tx = live_t_tx
    
    for u in users:
        sys = u['system_name']
        saved_rx = int(u['rx']) if u['rx'] else 0
        saved_tx = int(u['tx']) if u['tx'] else 0
        active_rx = live_traffic.get(sys, {}).get('rx', 0)
        active_tx = live_traffic.get(sys, {}).get('tx', 0)
        user_stats[sys] = {"usage": saved_rx + saved_tx + active_rx + active_tx, "online": sys in live_traffic}
        total_server_rx += saved_rx; total_server_tx += saved_tx

    psutil.cpu_percent(interval=None); psutil.cpu_percent(interval=None, percpu=True)
    return render_template('dashboard.html', users=users, settings=settings, stats=user_stats, t_rx=total_server_rx, t_tx=total_server_tx, current_time=int(time.time()))

@app.route('/settings', methods=['GET', 'POST'])
def sys_settings():
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    conn = get_db()
    if request.method == 'POST':
        curr_settings = conn.execute('SELECT * FROM settings').fetchone()
        old_panel_port = curr_settings['panel_port']
        old_vpn_port = curr_settings['port']
        old_vpn_proto = curr_settings['protocol']
        
        preset = request.form['dns_preset']
        dns1 = request.form.get('custom_dns1', '8.8.8.8') if preset == 'custom' else preset
        dns2 = request.form.get('custom_dns2', '') if preset == 'custom' else '1.0.0.1' if dns1=='1.1.1.1' else '8.8.4.4' if dns1=='8.8.8.8' else '149.112.112.112' if dns1=='9.9.9.9' else '94.140.15.15' if dns1=='94.140.14.14' else ''

        new_limit = request.form.get('conn_limit')
        new_panel_port = int(request.form.get('panel_port'))
        new_vpn_port = int(request.form.get('vpn_port'))
        new_vpn_proto = request.form.get('vpn_protocol')
        
        conn.execute('UPDATE settings SET dns=?, dns2=?, conn_limit=?, panel_port=?, port=?, protocol=?', (dns1, dns2, new_limit, new_panel_port, new_vpn_port, new_vpn_proto))
                     
        if request.form.get('admin_user') and request.form.get('admin_pass'):
            conn.execute('DELETE FROM admin')
            conn.execute('INSERT INTO admin (username, password) VALUES (?, ?)', (request.form['admin_user'], request.form['admin_pass']))
        conn.commit()

        needs_vpn_restart = False
        if dns1 != curr_settings['dns'] or dns2 != dict(curr_settings).get('dns2') or new_limit != curr_settings['conn_limit']:
            try:
                with open('/etc/openvpn/server/server.conf', 'r') as f:
                    lines = f.readlines()
                with open('/etc/openvpn/server/server.conf', 'w') as f:
                    for line in lines:
                        if 'push "dhcp-option DNS' in line or 'duplicate-cn' in line:
                            continue
                        f.write(line)
                    f.write(f'push "dhcp-option DNS {dns1}"\n')
                    if dns2: f.write(f'push "dhcp-option DNS {dns2}"\n')
                    if new_limit == "unlimited": f.write('duplicate-cn\n')
                needs_vpn_restart = True
            except Exception as e:
                pass

        if new_vpn_port != old_vpn_port or new_vpn_proto != old_vpn_proto:
            os.system(f"sed -i 's/^port .*/port {new_vpn_port}/' /etc/openvpn/server/server.conf")
            os.system(f"sed -i 's/^proto .*/proto {new_vpn_proto}/' /etc/openvpn/server/server.conf")
            os.system(f"ufw delete allow {old_vpn_port}/{old_vpn_proto} >/dev/null 2>&1")
            os.system(f"ufw allow {new_vpn_port}/{new_vpn_proto} >/dev/null 2>&1")
            os.system(f"iptables -D INPUT -p {old_vpn_proto} --dport {old_vpn_port} -j ACCEPT")
            os.system(f"iptables -I INPUT -p {new_vpn_proto} --dport {new_vpn_port} -j ACCEPT")
            os.system("netfilter-persistent save > /dev/null 2>&1")
            needs_vpn_restart = True

        if needs_vpn_restart: os.system("systemctl restart openvpn-server@server")

        all_users = conn.execute('SELECT system_name, password FROM users').fetchall()
        for u in all_users: os.system(f"bash {APP_DIR}/scripts/add_user.sh {u['system_name']} {u['password']}")

        if new_panel_port != old_panel_port:
            os.system(f"ufw delete allow {old_panel_port}/tcp >/dev/null 2>&1")
            os.system(f"ufw allow {new_panel_port}/tcp >/dev/null 2>&1")
            os.system(f"iptables -D INPUT -p tcp --dport {old_panel_port} -j ACCEPT")
            os.system(f"iptables -I INPUT -p tcp --dport {new_panel_port} -j ACCEPT")
            os.system("netfilter-persistent save > /dev/null 2>&1")
            os.system(f"sed -i 's/:{old_panel_port} /:{new_panel_port} /g' /etc/systemd/system/bluefalcon-panel.service")
            os.system("nohup bash -c 'sleep 1 && systemctl daemon-reload && systemctl restart bluefalcon-panel' >/dev/null 2>&1 &")
            
        return redirect(url_for('dashboard'))
        
    settings = conn.execute('SELECT * FROM settings').fetchone()
    admin = conn.execute('SELECT * FROM admin').fetchone()
    return render_template('settings.html', settings=settings, admin=admin)

@app.route('/toggle/<sys_name>')
def toggle(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    conn = get_db()
    user = conn.execute('SELECT status FROM users WHERE system_name = ?', (sys_name,)).fetchone()
    new_status = 'paused' if user['status'] == 'active' else 'active'
    conn.execute('UPDATE users SET status = ? WHERE system_name = ?', (new_status, sys_name))
    conn.commit()
    with open("/etc/openvpn/server/auth/users.db", "w") as f:
        for u in conn.execute('SELECT system_name, password, exp_days, status FROM users').fetchall(): 
            f.write(f"{u['system_name']}:{u['password']}:{u['exp_days']}:{u['status']}\n")
    if new_status == 'paused': os.system(f"echo -e 'kill {sys_name}\\nquit' | nc -w 1 127.0.0.1 7505 > /dev/null 2>&1 &")
    return redirect(url_for('dashboard'))

@app.route('/revoke/<sys_name>')
def revoke(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    get_db().execute('DELETE FROM users WHERE system_name = ?', (sys_name,)).connection.commit()
    os.system(f"sed -i '/^{sys_name}:/d' /etc/openvpn/server/auth/users.db")
    os.system(f"echo -e 'kill {sys_name}\\nquit' | nc -w 1 127.0.0.1 7505 > /dev/null 2>&1 &")
    os.system(f"cd {APP_DIR}/easy-rsa && ./easyrsa --batch revoke {sys_name} && ./easyrsa gen-crl")
    os.system(f"cp {APP_DIR}/easy-rsa/pki/crl.pem /etc/openvpn/server/ && chmod 644 /etc/openvpn/server/crl.pem")
    os.system(f"rm -f {APP_DIR}/configs/{sys_name}.ovpn")
    os.system(f"rm -f {APP_DIR}/configs/{sys_name}_manual.ovpn")
    return redirect(url_for('dashboard'))

@app.route('/download/<sys_name>')
def download(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    u = get_db().execute('SELECT display_name FROM users WHERE system_name = ?', (sys_name,)).fetchone()
    s = get_db().execute('SELECT server_name FROM settings').fetchone()
    file_path = f'{APP_DIR}/configs/{sys_name}.ovpn'
    if not os.path.exists(file_path): return "Error 404: Configuration file not found.", 404
    custom_name = f"{s['server_name']} - {u['display_name']} (Auto-Login).ovpn"
    try: return send_file(file_path, as_attachment=True, download_name=custom_name)
    except TypeError: return send_file(file_path, as_attachment=True, attachment_filename=custom_name)

@app.route('/download_manual/<sys_name>')
def download_manual(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    u = get_db().execute('SELECT display_name FROM users WHERE system_name = ?', (sys_name,)).fetchone()
    s = get_db().execute('SELECT server_name FROM settings').fetchone()
    file_path = f'{APP_DIR}/configs/{sys_name}_manual.ovpn'
    if not os.path.exists(file_path): return "Error 404: Configuration file not found.", 404
    custom_name = f"{s['server_name']} - {u['display_name']} (User-Login).ovpn"
    try: return send_file(file_path, as_attachment=True, download_name=custom_name)
    except TypeError: return send_file(file_path, as_attachment=True, attachment_filename=custom_name)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

if __name__ == '__main__': app.run(host='0.0.0.0', port=2020)
EOF_APP

    cat << 'EOF_SETUP_HTML' > "${APP_DIR}/templates/setup.html"
<!DOCTYPE html><html lang="en"><head><title>Setup | BlueFalcon OpenVPN Panel</title><script src="https://cdn.tailwindcss.com"></script></head>
<body class="bg-gray-900 text-gray-200 min-h-screen flex items-center justify-center p-6">
<div class="bg-gray-800 p-8 rounded-xl shadow-2xl w-full max-w-2xl border border-gray-700">
<h1 class="text-3xl font-bold text-emerald-400 text-center mb-8">🦅 BlueFalcon OpenVPN Panel</h1>
<form action="/setup" method="POST" class="space-y-6">
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
<input type="text" name="admin_user" placeholder="Admin Username" required class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="password" name="admin_pass" placeholder="Admin Password" required class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="text" name="server_name" value="OpenVPN-Server" required class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<select name="protocol" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white"><option value="udp">UDP</option><option value="tcp">TCP</option></select>
<input type="number" name="port" value="1194" required class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<select name="conn_limit" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white"><option value="1">Limit: 1 Device per User</option><option value="unlimited">Limit: Unlimited Devices</option></select>
<select name="dns_preset" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white md:col-span-2" onchange="document.getElementById('custom_dns_div').style.display = this.value === 'custom' ? 'grid' : 'none';">
<option value="1.1.1.1">Cloudflare (1.1.1.1 / 1.0.0.1)</option><option value="8.8.8.8">Google (8.8.8.8 / 8.8.4.4)</option><option value="9.9.9.9">Quad9 (9.9.9.9)</option><option value="94.140.14.14">AdGuard (94.140.14.14)</option><option value="custom">Custom IP...</option></select>
<div id="custom_dns_div" class="grid grid-cols-1 md:grid-cols-2 gap-4 md:col-span-2" style="display:none;">
<input type="text" name="custom_dns1" placeholder="Primary DNS (e.g. 1.0.0.1)" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="text" name="custom_dns2" placeholder="Secondary DNS (Optional)" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
</div></div>
<button type="submit" class="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-3 px-4 rounded-lg">Initialize System</button>
</form></div></body></html>
EOF_SETUP_HTML

    cat << 'EOF_SETTINGS_HTML' > "${APP_DIR}/templates/settings.html"
<!DOCTYPE html><html lang="en"><head><title>Settings | BlueFalcon OpenVPN Panel</title><script src="https://cdn.tailwindcss.com"></script></head>
<body class="bg-gray-900 text-gray-200 font-sans min-h-screen">
<nav class="bg-gray-800 border-b border-gray-700 px-6 py-4 flex justify-between items-center">
<div class="text-2xl font-bold text-emerald-400 tracking-wider">🦅 BlueFalcon OpenVPN Panel</div>
<a href="/dashboard" class="text-gray-400 hover:text-white transition">Back to Dashboard</a>
</nav>
<div class="max-w-2xl mx-auto px-6 py-8">
<form action="/settings" method="POST" class="space-y-6">
<div class="bg-gray-800 p-6 rounded-xl border border-gray-700"><h2 class="text-xl font-bold text-white mb-4">VPN Routing & Limits</h2>
<div class="space-y-4">
<div><label class="block text-gray-400 text-sm mb-1">OpenVPN Protocol</label>
<select name="vpn_protocol" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white"><option value="udp" {% if settings['protocol'] == 'udp' %}selected{% endif %}>UDP</option><option value="tcp" {% if settings['protocol'] == 'tcp' %}selected{% endif %}>TCP</option></select></div>
<div><label class="block text-gray-400 text-sm mb-1">OpenVPN Port</label><input type="number" name="vpn_port" value="{{ settings['port'] }}" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white"></div>
<div><label class="block text-gray-400 text-sm mb-1">Connection Limit</label><select name="conn_limit" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white"><option value="1" {% if settings['conn_limit'] == '1' %}selected{% endif %}>1 Device</option><option value="unlimited" {% if settings['conn_limit'] == 'unlimited' %}selected{% endif %}>Unlimited</option></select></div>
<div><label class="block text-gray-400 text-sm mb-1">DNS Server</label>
<select name="dns_preset" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white" onchange="document.getElementById('custom_dns_div').style.display = this.value === 'custom' ? 'grid' : 'none';">
<option value="1.1.1.1" {% if settings['dns'] == '1.1.1.1' %}selected{% endif %}>Cloudflare</option><option value="8.8.8.8" {% if settings['dns'] == '8.8.8.8' %}selected{% endif %}>Google</option><option value="9.9.9.9" {% if settings['dns'] == '9.9.9.9' %}selected{% endif %}>Quad9</option><option value="custom" {% if settings['dns'] not in ['1.1.1.1', '8.8.8.8', '9.9.9.9', '94.140.14.14'] %}selected{% endif %}>Custom IP...</option></select>
<div id="custom_dns_div" class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2" style="display: {% if settings['dns'] not in ['1.1.1.1', '8.8.8.8', '9.9.9.9', '94.140.14.14'] %}grid{% else %}none{% endif %};">
<input type="text" name="custom_dns1" value="{{ settings['dns'] if settings['dns'] not in ['1.1.1.1', '8.8.8.8', '9.9.9.9', '94.140.14.14'] else '' }}" placeholder="Primary DNS" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="text" name="custom_dns2" value="{{ settings['dns2'] if settings['dns2'] else '' }}" placeholder="Secondary DNS (Optional)" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
</div></div>
</div></div>
<div class="bg-gray-800 p-6 rounded-xl border border-gray-700"><h2 class="text-xl font-bold text-white mb-4">Panel Configuration</h2>
<div class="space-y-4">
<div><label class="block text-gray-400 text-sm mb-1">Web Panel Port</label><input type="number" name="panel_port" value="{{ settings['panel_port'] }}" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white"></div>
<div><label class="block text-gray-400 text-sm mb-1">Update Admin Credentials</label>
<div class="grid grid-cols-2 gap-4">
<input type="text" name="admin_user" value="{{ admin['username'] }}" required class="bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="password" name="admin_pass" placeholder="New Password" required class="bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
</div></div></div></div>
<button type="submit" class="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-3 rounded-lg">Save & Apply System Changes</button>
</form></div></body></html>
EOF_SETTINGS_HTML

    cat << 'EOF_LOGIN_HTML' > "${APP_DIR}/templates/login.html"
<!DOCTYPE html><html lang="en"><head><title>Login | BlueFalcon OpenVPN Panel</title><script src="https://cdn.tailwindcss.com"></script></head>
<body class="bg-gray-900 text-gray-200 min-h-screen flex items-center justify-center p-6">
<div class="bg-gray-800 p-8 rounded-xl shadow-2xl w-full max-w-sm border border-gray-700">
<h1 class="text-2xl font-bold text-emerald-400 mb-6 text-center">🦅 BlueFalcon OpenVPN<br><span class="text-lg text-gray-400">Panel Login</span></h1>
{% if error %}<p class="text-red-400 text-sm text-center mb-4">{{ error }}</p>{% endif %}
<form action="/login" method="POST" class="space-y-4">
<input type="text" name="username" placeholder="Username" required class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="password" name="password" placeholder="Password" required class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
<button type="submit" class="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-2 rounded-lg">Authenticate</button>
</form></div></body></html>
EOF_LOGIN_HTML

    cat << 'EOF_LOADING_HTML' > "${APP_DIR}/templates/loading.html"
<!DOCTYPE html><html lang="en"><head><title>Installing | BlueFalcon OpenVPN Panel</title><script src="https://cdn.tailwindcss.com"></script></head>
<body class="bg-gray-900 text-gray-200 min-h-screen flex items-center justify-center p-6">
<div class="bg-gray-800 p-8 rounded-xl shadow-2xl w-full max-w-3xl border border-gray-700">
<h1 class="text-2xl font-bold text-emerald-400 mb-4 animate-pulse">Installing OpenVPN Core...</h1>
<div id="terminal" class="bg-black p-4 rounded-lg h-80 overflow-y-auto font-mono text-sm text-green-400 border border-gray-700 whitespace-pre-wrap"></div>
</div>
<script>
const terminal = document.getElementById('terminal');
const source = new EventSource('/stream');
source.onmessage = function(event) {
    if(event.data === '[DONE]') {
        terminal.innerHTML += '\n<span class="text-white bg-emerald-600 px-2 py-1 rounded">INSTALLATION COMPLETE. REDIRECTING...</span>';
        source.close(); setTimeout(() => window.location.href = '/login', 2000); return;
    }
    terminal.innerHTML += event.data + '\n'; terminal.scrollTop = terminal.scrollHeight;
};
</script></body></html>
EOF_LOADING_HTML

    cat << 'EOF_DASHBOARD_HTML' > "${APP_DIR}/templates/dashboard.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Dashboard | BlueFalcon OpenVPN Panel</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body class="bg-gray-900 text-gray-200 font-sans min-h-screen">
<nav class="bg-gray-800 border-b border-gray-700 px-6 py-4 flex justify-between items-center">
    <div class="text-2xl font-bold text-emerald-400 tracking-wider">🦅 BlueFalcon OpenVPN Panel <span class="text-xs text-gray-500 ml-2">v2.4</span></div>
    <div class="flex items-center gap-4">
        <a href="/settings" class="text-gray-400 hover:text-emerald-400 transition">⚙️ Settings</a>
        <a href="/logout" class="text-gray-400 hover:text-white transition">Logout</a>
    </div>
</nav>
<div class="max-w-6xl mx-auto px-6 py-8">
    <div class="bg-gray-800 rounded-xl border border-gray-700 shadow-lg mb-8 p-6">
        <h2 class="text-lg font-bold text-white mb-6">Live System Monitor</h2>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div class="bg-gray-900 p-4 rounded-lg border border-gray-700 flex flex-col items-center justify-start h-full">
                <div class="relative w-full max-w-[160px] aspect-[2/1] mt-2">
                    <canvas id="cpuChart"></canvas>
                    <div class="absolute inset-0 flex items-end justify-center pb-1">
                        <span class="text-xl font-bold text-emerald-400" id="cpu_val">--%</span>
                    </div>
                </div>
                <p class="text-sm text-gray-400 mt-4 font-bold tracking-wider mb-2">CPU</p>
                <div id="cpu_cores_container" class="w-full mt-auto grid grid-cols-2 gap-x-3 gap-y-2">
                    </div>
            </div>
            <div class="bg-gray-900 p-4 rounded-lg border border-gray-700 flex flex-col items-center justify-start h-full">
                <div class="relative w-full max-w-[160px] aspect-[2/1] mt-2">
                    <canvas id="ramChart"></canvas>
                    <div class="absolute inset-0 flex items-end justify-center pb-1">
                        <span class="text-xl font-bold text-blue-400" id="ram_val">--%</span>
                    </div>
                </div>
                <p class="text-sm text-gray-400 mt-4 font-bold tracking-wider">RAM</p>
                <p class="text-xs text-gray-500 mt-1 font-mono" id="ram_detail">-- / --</p>
            </div>
            <div class="bg-gray-900 p-4 rounded-lg border border-gray-700 flex flex-col items-center justify-start h-full">
                <div class="relative w-full max-w-[160px] aspect-[2/1] mt-2">
                    <canvas id="diskChart"></canvas>
                    <div class="absolute inset-0 flex items-end justify-center pb-1">
                        <span class="text-xl font-bold text-purple-400" id="disk_val">--%</span>
                    </div>
                </div>
                <p class="text-sm text-gray-400 mt-4 font-bold tracking-wider">STORAGE</p>
                <p class="text-xs text-gray-500 mt-1 font-mono" id="disk_detail">-- / --</p>
            </div>
            <div class="bg-gray-900 p-4 rounded-lg border border-gray-700 flex flex-col items-center justify-center h-full">
                <p class="text-sm text-gray-400 mb-4 font-bold tracking-wider">NETWORK TRAFFIC</p>
                <div class="flex flex-col gap-3 w-full px-4">
                    <div class="bg-gray-800 p-3 rounded border border-gray-700 flex justify-between items-center">
                        <span class="text-emerald-400 font-bold">↓ DL</span>
                        <span class="text-emerald-400 font-mono" id="net_rx_val">0 KB/s</span>
                    </div>
                    <div class="bg-gray-800 p-3 rounded border border-gray-700 flex justify-between items-center">
                        <span class="text-rose-400 font-bold">↑ UL</span>
                        <span class="text-rose-400 font-mono" id="net_tx_val">0 KB/s</span>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div class="bg-gray-800 p-5 rounded-xl border border-gray-700"><h3 class="text-gray-400 text-sm font-medium">Server Name</h3><p class="text-xl text-white mt-1">{{ settings['server_name'] }}</p></div>
        <div class="bg-gray-800 p-5 rounded-xl border border-gray-700"><h3 class="text-gray-400 text-sm font-medium">Protocol / Port</h3><p class="text-xl text-white mt-1 uppercase">{{ settings['protocol'] }} <span class="text-emerald-400">/ {{ settings['port'] }}</span></p></div>
        <div class="bg-gray-800 p-5 rounded-xl border border-gray-700"><h3 class="text-gray-400 text-sm font-medium">Connection Limit</h3><p class="text-xl text-white mt-1 capitalize">{{ settings['conn_limit'] }}</p></div>
        <div class="bg-emerald-900/20 p-5 rounded-xl border border-emerald-700/50"><h3 class="text-emerald-400/80 text-sm font-medium">Total Server Traffic</h3><p class="text-xl text-emerald-400 mt-1">↓ {{ t_rx|format_bytes }} &nbsp; ↑ {{ t_tx|format_bytes }}</p></div>
    </div>
    <div class="bg-gray-800 rounded-xl border border-gray-700 shadow-lg overflow-hidden">
        <div class="p-6 border-b border-gray-700 bg-gray-900">
            <form action="/dashboard" method="POST" class="flex flex-wrap gap-4 items-end">
                <div><label class="block text-sm font-medium text-gray-400 mb-1">Display Name (Spaces Allowed)</label><input type="text" name="new_user" required class="bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white"></div>
                <div><label class="block text-sm font-medium text-gray-400 mb-1">Password</label><input type="text" name="new_pass" required class="bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white"></div>
                <div><label class="block text-sm font-medium text-gray-400 mb-1">Expiry (Days)</label><input type="number" name="exp_days" value="0" min="0" required class="bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white w-24"></div>
                <button type="submit" class="bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-2 px-4 rounded transition">+ Generate Profile</button>
            </form>
        </div>
        <div class="p-6 overflow-x-auto">
            <table class="w-full text-left border-collapse">
                <thead>
                    <tr class="text-gray-400 text-sm border-b border-gray-700">
                        <th class="pb-3">User</th>
                        <th class="pb-3">Status</th>
                        <th class="pb-3">Total Data Usage</th>
                        <th class="pb-3">Time Left</th>
                        <th class="pb-3 text-right">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    {% for user in users %}
                    <tr class="border-b border-gray-700/50">
                        <td class="py-4 text-white font-medium">{{ user['display_name'] }} <span class="text-xs text-gray-500 block">sys: {{ user['system_name'] }}</span></td>
                        <td class="py-4">
                            {% if user['status'] == 'paused' %}
                                <span class="bg-orange-900/50 text-orange-400 px-2 py-1 rounded text-xs">⏸ Paused</span>
                            {% elif stats[user['system_name']]['online'] %}
                                <span class="bg-green-900/50 text-green-400 px-2 py-1 rounded text-xs">● Online</span>
                            {% else %}
                                <span class="bg-gray-700/50 text-gray-400 px-2 py-1 rounded text-xs">Offline</span>
                            {% endif %}
                        </td>
                        <td class="py-4 text-sm text-gray-300">{{ stats[user['system_name']]['usage']|format_bytes }}</td>
                        <td class="py-4 text-sm text-gray-400">
                            {% if user['exp_days'] == 0 %} 
                                Unlimited 
                            {% elif user['exp_days'] < current_time %} 
                                <span class="text-red-400">Expired</span> 
                            {% else %} 
                                {{ ((user['exp_days'] - current_time) / 86400) | round(1) }} Days 
                            {% endif %}
                        </td>
                        <td class="py-4 text-right space-x-2 whitespace-nowrap">
                            <a href="/toggle/{{ user['system_name'] }}" class="bg-gray-700 hover:bg-gray-600 text-white px-2.5 py-1.5 rounded text-sm transition">{% if user['status'] == 'paused' %}▶ Resume{% else %}⏸ Pause{% endif %}</a>
                            <a href="/download/{{ user['system_name'] }}" class="bg-blue-600 hover:bg-blue-500 text-white px-2.5 py-1.5 rounded text-sm transition font-medium">Auto-Login</a>
                            <a href="/download_manual/{{ user['system_name'] }}" class="bg-indigo-600 hover:bg-indigo-500 text-white px-2.5 py-1.5 rounded text-sm transition font-medium">User-Login</a>
                            <a href="/revoke/{{ user['system_name'] }}" onclick="return confirm('Delete and revoke user forever?')" class="bg-red-600 hover:bg-red-500 text-white px-2.5 py-1.5 rounded text-sm transition">Revoke</a>
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
</div>
<script>
    const chartOptions = {
        responsive: true, 
        maintainAspectRatio: false,
        cutout: '82%', 
        circumference: 180, 
        rotation: -90,
        plugins: { tooltip: { enabled: false }, legend: { display: false } },
        animation: { duration: 0 }
    };
    const createDonut = (ctxId, color) => new Chart(document.getElementById(ctxId).getContext('2d'), {
        type: 'doughnut',
        data: { datasets: [{ data: [0, 100], backgroundColor: [color, '#374151'], borderWidth: 0, borderRadius: 2 }] },
        options: chartOptions
    });
    const cpuChart = createDonut('cpuChart', '#34d399');
    const ramChart = createDonut('ramChart', '#60a5fa');
    const diskChart = createDonut('diskChart', '#c084fc');
    let lastRx = 0, lastTx = 0, firstPoll = true;
    function formatSpeed(bytes) {
        if (bytes < 1024) return bytes + " B/s";
        else if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB/s";
        else return (bytes / 1048576).toFixed(2) + " MB/s";
    }
    setInterval(() => {
        fetch('/api/sysinfo')
        .then(r => r.json())
        .then(data => {
            document.getElementById('cpu_val').innerText = data.cpu + '%';
            cpuChart.data.datasets[0].data = [data.cpu, 100 - data.cpu];
            cpuChart.update();
            const coresContainer = document.getElementById('cpu_cores_container');
            coresContainer.innerHTML = '';
            if (data.cpu_cores && data.cpu_cores.length > 0) {
                data.cpu_cores.forEach((coreLoad, index) => {
                    coresContainer.insertAdjacentHTML('beforeend', `
                        <div class="flex flex-col">
                            <div class="flex justify-between text-[10px] text-gray-500 mb-0.5">
                                <span>C${index}</span>
                                <span class="text-emerald-400/80">${coreLoad.toFixed(1)}%</span>
                            </div>
                            <div class="w-full bg-gray-800 rounded-full h-1">
                                <div class="bg-emerald-500 h-1 rounded-full" style="width: ${coreLoad}%"></div>
                            </div>
                        </div>
                    `);
                });
            }
            document.getElementById('ram_val').innerText = data.ram_percent + '%';
            document.getElementById('ram_detail').innerText = data.ram_used + ' / ' + data.ram_total;
            ramChart.data.datasets[0].data = [data.ram_percent, 100 - data.ram_percent];
            ramChart.update();
            document.getElementById('disk_val').innerText = data.disk_percent + '%';
            document.getElementById('disk_detail').innerText = data.disk_used + ' / ' + data.disk_total;
            diskChart.data.datasets[0].data = [data.disk_percent, 100 - data.disk_percent];
            diskChart.update();
            if (!firstPoll) {
                let rxSpeed = (data.net_rx - lastRx) / 2;
                let txSpeed = (data.net_tx - lastTx) / 2;
                document.getElementById('net_rx_val').innerText = formatSpeed(Math.max(0, rxSpeed));
                document.getElementById('net_tx_val').innerText = formatSpeed(Math.max(0, txSpeed));
            }
            lastRx = data.net_rx;
            lastTx = data.net_tx;
            firstPoll = false;
        }).catch(err => console.error("Error fetching sysinfo:", err));
    }, 2000);
</script>
</body>
</html>
EOF_DASHBOARD_HTML

    cat << 'EOF_SETUP' > "${APP_DIR}/scripts/core_setup.sh"
#!/bin/bash
readonly APP_DIR="/opt/bluefalcon-ultimate-toolkit"
echo "[INFO] Commencing OpenVPN Core Installation..."
sleep 1
if ! command -v openvpn >/dev/null 2>&1; then
    apt-get install -y openvpn openssl iptables iptables-persistent iproute2 > /dev/null 2>&1
fi
echo " - Network and core packages installed [OK]"
echo "[INFO] Initializing Easy-RSA PKI Cryptography..."
mkdir -p "${APP_DIR}/easy-rsa"
if [ ! -f "${APP_DIR}/easy-rsa/easyrsa" ]; then
    wget -qO- https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.6/EasyRSA-3.2.6.tgz | tar xz -C "${APP_DIR}/easy-rsa" --strip-components 1 > /dev/null 2>&1
    cd "${APP_DIR}/easy-rsa"
    ./easyrsa --batch init-pki > /dev/null 2>&1
    ./easyrsa --batch build-ca nopass > /dev/null 2>&1
    ./easyrsa --batch build-server-full server nopass > /dev/null 2>&1
    ./easyrsa gen-crl > /dev/null 2>&1
else
    cd "${APP_DIR}/easy-rsa"
fi
echo " - Authority Certificates built [OK]"
echo "[INFO] Generating Diffie-Hellman Parameters (Takes ~1 minute)..."
if [ ! -f "/etc/openvpn/server/dh.pem" ]; then openssl dhparam -out /etc/openvpn/server/dh.pem 2048 > /dev/null 2>&1; fi
mkdir -p /etc/openvpn/server/auth
cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/server/
if [ ! -f "/etc/openvpn/server/tc.key" ]; then openvpn --genkey secret /etc/openvpn/server/tc.key; fi
chmod 644 /etc/openvpn/server/crl.pem
echo " - Key generation complete [OK]"
echo "[INFO] Setting up Pause/Resume Authentication Engine..."
cat > /etc/openvpn/server/auth/verify.sh << 'EOF_V'
#!/bin/bash
user=$(head -n 1 "$1"); pass=$(tail -n 1 "$1")
line=$(grep "^${user}:${pass}:" /etc/openvpn/server/auth/users.db)
if [ -n "$line" ]; then
    status=$(echo "$line" | cut -d':' -f4)
    if [ "$status" == "active" ]; then exit 0; fi
fi
exit 1
EOF_V
chmod +x /etc/openvpn/server/auth/verify.sh
touch /etc/openvpn/server/auth/users.db
chmod 666 /etc/openvpn/server/auth/users.db
echo " - Live DB verification logic attached [OK]"
echo "[INFO] Engineering Data Persistence Hook..."
cat > /etc/openvpn/server/disconnect.sh << 'EOF_D'
#!/bin/bash
/usr/bin/sqlite3 -cmd ".timeout 5000" /opt/bluefalcon-ultimate-toolkit/panel.db "UPDATE users SET rx = rx + ${bytes_received:-0}, tx = tx + ${bytes_sent:-0} WHERE system_name = '${common_name}';"
EOF_D
chmod +x /etc/openvpn/server/disconnect.sh
echo " - Disconnect database injector deployed [OK]"
echo "[INFO] Writing Server Configuration & NAT Firewalls..."
PROTOCOL=$(sqlite3 "${APP_DIR}/panel.db" "SELECT protocol FROM settings LIMIT 1;")
PORT=$(sqlite3 "${APP_DIR}/panel.db" "SELECT port FROM settings LIMIT 1;")
DNS=$(sqlite3 "${APP_DIR}/panel.db" "SELECT dns FROM settings LIMIT 1;")
DNS2=$(sqlite3 "${APP_DIR}/panel.db" "SELECT dns2 FROM settings LIMIT 1;")
cat > /etc/openvpn/server/server.conf << EOCONF
port $PORT
proto $PROTOCOL
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-crypt tc.key
crl-verify crl.pem
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $DNS"
EOCONF
if [ -n "$DNS2" ] && [ "$DNS2" != "None" ] && [ "$DNS2" != "" ]; then echo "push \"dhcp-option DNS $DNS2\"" >> /etc/openvpn/server/server.conf; fi
cat >> /etc/openvpn/server/server.conf << EOCONF
keepalive 10 120
cipher AES-256-GCM
persist-key
persist-tun
script-security 2
auth-user-pass-verify /etc/openvpn/server/auth/verify.sh via-file
client-disconnect /etc/openvpn/server/disconnect.sh
management 127.0.0.1 7505
status /var/log/openvpn/status.log 5
status-version 2
verb 3
EOCONF
LIMIT=$(sqlite3 "${APP_DIR}/panel.db" "SELECT conn_limit FROM settings LIMIT 1;")
if [ "$LIMIT" == "unlimited" ]; then echo "duplicate-cn" >> /etc/openvpn/server/server.conf; fi
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf > /dev/null 2>&1
if command -v ufw >/dev/null 2>&1; then
    sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
    ufw reload >/dev/null 2>&1
fi
if ! iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -j MASQUERADE 2>/dev/null; then
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE
    netfilter-persistent save > /dev/null 2>&1
fi
systemctl restart openvpn-server@server
systemctl enable openvpn-server@server > /dev/null 2>&1
echo -e "\n[OK] OPENVPN CORE DEPLOYED SUCCESSFULLY."
EOF_SETUP

    cat << 'EOF_ADD' > "${APP_DIR}/scripts/add_user.sh"
#!/bin/bash
u=$1; p=$2
readonly APP_DIR="/opt/bluefalcon-ultimate-toolkit"
IPV4=$(curl -s -4 ifconfig.me)
PROTOCOL=$(sqlite3 "${APP_DIR}/panel.db" "SELECT protocol FROM settings LIMIT 1;")
PORT=$(sqlite3 "${APP_DIR}/panel.db" "SELECT port FROM settings LIMIT 1;")
cd "${APP_DIR}/easy-rsa"
./easyrsa --batch build-client-full "$u" nopass > /dev/null 2>&1
cat > "${APP_DIR}/configs/${u}.ovpn" << EOCONF
client
dev tun
proto $PROTOCOL
remote $IPV4 $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
ignore-unknown-option block-outside-dns
block-outside-dns
auth-user-pass
<auth-user-pass>
$u
$p
</auth-user-pass>
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' pki/issued/${u}.crt)
</cert>
<key>
$(sed -n '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/p' pki/private/${u}.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/server/tc.key)
</tls-crypt>
EOCONF
cat > "${APP_DIR}/configs/${u}_manual.ovpn" << EOCONF
client
dev tun
proto $PROTOCOL
remote $IPV4 $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
ignore-unknown-option block-outside-dns
block-outside-dns
auth-user-pass
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' pki/issued/${u}.crt)
</cert>
<key>
$(sed -n '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/p' pki/private/${u}.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/server/tc.key)
</tls-crypt>
EOCONF
EOF_ADD

    cat << 'EOF_EXP' > "${APP_DIR}/scripts/expiry.py"
import sqlite3, time, os
APP_DIR = '/opt/bluefalcon-ultimate-toolkit'
conn = sqlite3.connect(f'{APP_DIR}/panel.db')
users = conn.execute('SELECT system_name, exp_days FROM users WHERE exp_days > 0').fetchall()
now = int(time.time())
for u in users:
    if u[1] < now:
        sys_name = u[0]
        conn.execute('DELETE FROM users WHERE system_name = ?', (sys_name,))
        os.system(f"sed -i '/^{sys_name}:/d' /etc/openvpn/server/auth/users.db")
        os.system(f"echo -e 'kill {sys_name}\\nquit' | nc -w 1 127.0.0.1 7505 > /dev/null 2>&1 &")
        os.system(f"cd {APP_DIR}/easy-rsa && ./easyrsa --batch revoke {sys_name} && ./easyrsa gen-crl")
        os.system(f"cp {APP_DIR}/easy-rsa/pki/crl.pem /etc/openvpn/server/ && chmod 644 /etc/openvpn/server/crl.pem")
        os.system(f"rm -f {APP_DIR}/configs/{sys_name}.ovpn")
conn.commit()
conn.close()
EOF_EXP

    chmod +x "${APP_DIR}/scripts/"*.sh
}

install_panel() {
    clear
    echo ""
    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Updating repositories" apt-get update -y
    echo "iptables-persistent iptables-persistent/ensure-ipv4-rules boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/ensure-ipv6-rules boolean true" | debconf-set-selections
    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Installing dependencies" apt-get install -y python3 python3-flask python3-gunicorn python3-psutil sqlite3 curl cron gunicorn iptables iptables-persistent iproute2 netcat-openbsd

    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Extracting panel files" extract_panel_files

    if ! grep -q "/swapfile" /etc/fstab; then
        CURRENT_LOG="${LOG_FILE}" run_with_spinner "Creating Swapfile" bash -c "fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab"
    fi

    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Securing Web Panel Port" bash -c "iptables -I INPUT -p tcp --dport 2020 -j ACCEPT && netfilter-persistent save"

    cat > /etc/cron.daily/bluefalcon-panel-expiry << EOF
#!/bin/bash
python3 ${APP_DIR}/scripts/expiry.py
EOF
    chmod +x /etc/cron.daily/bluefalcon-panel-expiry

    GUNICORN_CMD=$(command -v gunicorn)
    if [ -z "$GUNICORN_CMD" ]; then GUNICORN_CMD="/usr/local/bin/gunicorn"; fi

    cat > /etc/systemd/system/bluefalcon-panel.service << EOF
[Unit]
Description=BlueFalcon Universal Web Panel
After=network.target

[Service]
User=root
WorkingDirectory=${APP_DIR}
ExecStart=$GUNICORN_CMD -w 2 -b 0.0.0.0:2020 --timeout 600 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Starting Web Panel Engine" bash -c "systemctl daemon-reload && systemctl enable bluefalcon-panel && systemctl restart bluefalcon-panel"

    IPV4=$(curl -s -4 ifconfig.me || echo "Unknown")
    echo -e "\n[ ${GREEN}✔${NC} ] BLUEFALCON PANEL DEPLOYED SUCCESSFULLY!"
    echo -e "Open your browser to complete OpenVPN setup: ${YELLOW}http://$IPV4:2020${NC}\n"
    pause_execution
}

uninstall_panel() {
    clear
    echo ""
    read -rp "Uninstall OpenVPN & Web Panel? All user data will be lost. (y/N): " confirm
    if [[ "${confirm,,}" == "y" ]]; then
        echo ""
        CURRENT_LOG="${LOG_FILE}" run_with_spinner "Removing files, services, and packages" bash -c "systemctl stop bluefalcon-panel openvpn-server@server; systemctl disable bluefalcon-panel openvpn-server@server; apt-get remove --purge -y openvpn iptables-persistent python3-psutil; rm -rf ${APP_DIR} /etc/openvpn /etc/systemd/system/bluefalcon-panel.service /var/log/bluefalcon-panel /var/log/openvpn /etc/cron.daily/bluefalcon-panel-expiry; systemctl daemon-reload"
        echo -e "\n[ ${GREEN}✔${NC} ] System cleanly wiped."
    else
        echo -e "\n[ ${YELLOW}✖${NC} ] Uninstallation canceled."
    fi
    pause_execution
}

manage_panel() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}                 OpenVPN & Web Panel                 ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        
        IPV4=$(curl -s -4 ifconfig.me || echo "Unknown")
        PANEL_PORT="2020"
        ADMIN_USER="Not Set"
        ADMIN_PASS="Not Set"
        
        if [ -f "${APP_DIR}/panel.db" ]; then
            PANEL_PORT=$(sqlite3 "${APP_DIR}/panel.db" "SELECT panel_port FROM settings LIMIT 1;" 2>/dev/null)
            PANEL_PORT=${PANEL_PORT:-2020}
            
            ADMIN_USER=$(sqlite3 "${APP_DIR}/panel.db" "SELECT username FROM admin LIMIT 1;" 2>/dev/null)
            ADMIN_USER=${ADMIN_USER:-"Not Set"}
            
            ADMIN_PASS=$(sqlite3 "${APP_DIR}/panel.db" "SELECT password FROM admin LIMIT 1;" 2>/dev/null)
            ADMIN_PASS=${ADMIN_PASS:-"Not Set"}
        fi
        
        echo -e " Panel Link:          ${YELLOW}http://$IPV4:$PANEL_PORT${NC}"
        echo -e " Admin Username:      ${CYAN}${ADMIN_USER}${NC}"
        echo -e " Admin Password:      ${CYAN}${ADMIN_PASS}${NC}"
        
        if systemctl is-active --quiet bluefalcon-panel; then echo -e " Web Panel:           [ ${GREEN}✔${NC} ] Active"; else echo -e " Web Panel:           [ ${RED}✖${NC} ] Offline"; fi
        if systemctl is-active --quiet openvpn-server@server; then echo -e " OpenVPN Core:        [ ${GREEN}✔${NC} ] Active"; else echo -e " OpenVPN Core:        [ ${RED}✖${NC} ] Offline"; fi
        if [ -d "$APP_DIR" ]; then echo -e " Installation Files:  [ ${GREEN}✔${NC} ] Installed"; else echo -e " Installation Files:  [ ${RED}✖${NC} ] Missing"; fi
        
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Install OpenVPN"
        echo "2. Uninstall OpenVPN"
        echo "3. View Installation Logs"
        echo "4. View OpenVPN Core Logs"
        echo "5. View Web Panel Logs"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " p_choice
        case "$p_choice" in
            1) install_panel ;;
            2) uninstall_panel ;;
            3) 
                clear
                echo -e "${BOLD_BLUE}--- Installation Logs ---${NC}\nStreaming last 50 lines. Press Ctrl+C to exit.\n"
                trap 'true' SIGINT
                tail -n 50 -f "${LOG_FILE}"
                trap cleanup SIGINT SIGTERM
                ;;
            4) 
                clear
                echo -e "${BOLD_BLUE}--- OpenVPN Core Logs ---${NC}\nStreaming real-time service logs. Press Ctrl+C to exit.\n"
                trap 'true' SIGINT
                journalctl -u openvpn-server@server -f -n 50
                trap cleanup SIGINT SIGTERM
                ;;
            5) 
                clear
                echo -e "${BOLD_BLUE}--- Web Panel Logs ---${NC}\nStreaming real-time service logs. Press Ctrl+C to exit.\n"
                trap 'true' SIGINT
                journalctl -u bluefalcon-panel -f -n 50
                trap cleanup SIGINT SIGTERM
                ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}

# ==============================================================================
# --- God Script Main Execution ---
# ==============================================================================
show_main_menu() {
    clear
    echo -e "${BOLD_BLUE}=====================================================${NC}"
    echo -e "${BOLD_BLUE}       🧰 BlueFalcon Ultimate Toolkit (v1.9) 🧰       ${NC}"
    echo -e "${BOLD_BLUE}=====================================================${NC}"
    echo ""
    echo "1. Essential Tools"
    echo "2. OpenVPN & Web Panel"
    echo "3. Cloudflare WARP"
    echo "0. Exit"
    echo ""
}

main() {
    check_preflight
    while true; do
        show_main_menu
        read -rp "Select option: " choice

        case "${choice}" in
            1) manage_essential ;;
            2) manage_panel ;;
            3) manage_warp ;;
            0) 
                echo -e "\n[ ${GREEN}✔${NC} ] Exiting toolkit. Session terminated cleanly.\n"
                tput cnorm
                exit 0 
                ;;
            *) 
                echo -e "\n[ ${RED}✖${NC} ] Invalid option."
                sleep 1.5 
                ;;
        esac
    done
}

main "$@"