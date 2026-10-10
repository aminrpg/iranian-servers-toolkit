#!/bin/bash

# Iranian Servers Toolkit
# DNS switching, Docker install/setup, and registry mirrors for servers in Iran.
# Author: https://github.com/aminrpg

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

# Check if script is running with root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error:${NC} Please run this script as root (use sudo)"
    exit 1
fi

# Detect the OS and its package manager so the script works across distros.
# Sets global variables: OS_NAME, OS_ID, PKG_MANAGER, PKG_UPDATE, PKG_UPGRADE, PKG_INSTALL
detect_distro() {
    # Pretty OS name from /etc/os-release when available
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_NAME="${PRETTY_NAME:-$NAME}"
        OS_ID="${ID:-unknown}"
    else
        OS_NAME="$(uname -s)"
        OS_ID="unknown"
    fi

    # Pick the first package manager we find and define matching commands
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt-get update"
        PKG_UPGRADE="apt-get upgrade -y"
        PKG_INSTALL="apt-get install -y"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf makecache"
        PKG_UPGRADE="dnf upgrade -y"
        PKG_INSTALL="dnf install -y"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum makecache"
        PKG_UPGRADE="yum update -y"
        PKG_INSTALL="yum install -y"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        PKG_UPDATE="pacman -Sy"
        PKG_UPGRADE="pacman -Syu --noconfirm"
        PKG_INSTALL="pacman -S --noconfirm"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
        PKG_UPDATE="zypper refresh"
        PKG_UPGRADE="zypper update -y"
        PKG_INSTALL="zypper install -y"
    else
        PKG_MANAGER="unknown"
    fi
}

detect_distro

# Main menu options
main_menu_items=("Show Status" "Set DNS" "Restore DNS Backup" "Install Docker" "Update Docker" "Set Docker Proxy" "Exit")

# Available DNS providers and their servers
dns_options=("Shecan" "Shecan Pro" "Radar" "Electro" "Begzar" "DNSPro" "403" "XCR9" "Bertina" "DynX" "Google" "Cloudflare" "Reset to Default")
declare -A dns_servers=(
    ["Shecan"]="178.22.122.100 185.51.200.2"
	["Shecan Pro"]="178.22.122.101 185.51.200.1"
    ["Radar"]="10.202.10.10 10.202.10.11"
    ["Electro"]="78.157.42.100 78.157.42.101"
    ["Begzar"]="185.55.226.26 185.55.226.25"
    ["DNSPro"]="87.107.110.109 87.107.110.110"
    ["403"]="10.202.10.202 10.202.10.102"
    ["XCR9"]="85.208.255.182 85.208.255.71"
	["Bertina"]="193.186.32.32"
	["DynX"]="10.70.95.150 10.70.95.162"
    ["Google"]="8.8.8.8 8.8.4.4"
    ["Cloudflare"]="1.1.1.1 1.0.0.1"
    ["Reset to Default"]="127.0.0.53"
)

# Iranian Docker registry mirrors
registry_proxies=(
    "docker.kernel.ir"
    "focker.ir"
    "registry.docker.ir"
    "docker.arvancloud.ir"
    "docker.haiocloud.com"
    "docker.iranserver.com"
    "docker.mobinhost.com"
    "hub.mecan.ir"
	"docker.nrp.co"
	"docker-mirror.liara.ir"
	"ghcr-mirror.liara.ir"
	"mirrors.pardisco.co"
	"mirror2.chabokan.net"
	"docker.abrha.net"
	"mirror-docker.runflare.com"
)

# DNS Management Functions
backup_resolv() {
    cp /etc/resolv.conf "/etc/resolv.conf.bak.$(date +%Y%m%d_%H%M%S)"
}

ping_proxy() {
    local domain="$1"
    local times=($(ping -c 3 -W 1 "$domain" 2>/dev/null | grep -oP 'time=\K[0-9.]+'))
    
    if [ ${#times[@]} -gt 0 ]; then
        printf '%s\n' "${times[@]}" | sort -n | head -1
    else
        echo "timeout"
    fi
}


# Set DNS servers based on user selection
set_dns() {
    echo
    for i in "${!dns_options[@]}"; do
        echo "  $((i + 1))) ${dns_options[$i]}"
    done
    echo "  0) Back"
    echo
    read -rp "Select DNS (0-${#dns_options[@]}): " dns_choice

    if [[ "$dns_choice" == "0" ]]; then return; fi
    if [[ ! "$dns_choice" =~ ^[0-9]+$ ]] || (( dns_choice < 1 || dns_choice > ${#dns_options[@]} )); then
        echo -e "${RED}Invalid DNS option${NC}"; return
    fi

    provider="${dns_options[$((dns_choice - 1))]}"
    dns_list="${dns_servers[$provider]}"

    # Create backup before making changes
    backup_resolv

    # Write new DNS configuration
    {
        echo "# DNS updated on $(date) by Iranian Servers Toolkit"
        for dns in $dns_list; do
            echo "nameserver $dns"
        done
        if [ "$provider" != "Reset to Default" ]; then
            echo "options edns0 trust-ad"
            grep "^search" /etc/resolv.conf 2>/dev/null
        fi
    } > /etc/resolv.conf

    echo -e "${GREEN}DNS updated to:${NC} $provider"
}

# Restore /etc/resolv.conf from a previously created backup
restore_dns_backup() {
    echo
    echo -e "${CYAN}Available DNS backups:${NC}"

    # Collect backups (newest first) into an array
    local backups=()
    while IFS= read -r line; do
        [ -n "$line" ] && backups+=("$line")
    done < <(ls -1t /etc/resolv.conf.bak.* 2>/dev/null)

    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}No backups found.${NC} (Backups are created automatically when you change DNS.)"
        return
    fi

    for i in "${!backups[@]}"; do
        # Show the backup name and when it was last modified
        local when
        when=$(date -r "${backups[$i]}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
        echo "  $((i + 1))) ${backups[$i]}  ${when:+($when)}"
    done
    echo "  0) Back"
    echo
    read -rp "Select a backup to restore (0-${#backups[@]}): " backup_choice

    if [[ "$backup_choice" == "0" ]]; then return; fi
    if [[ ! "$backup_choice" =~ ^[0-9]+$ ]] || (( backup_choice < 1 || backup_choice > ${#backups[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local selected="${backups[$((backup_choice - 1))]}"

    # Back up the current file before overwriting, so a restore is itself reversible
    backup_resolv
    if cp "$selected" /etc/resolv.conf; then
        echo -e "${GREEN}DNS restored from:${NC} $selected"
    else
        echo -e "${RED}Error:${NC} Failed to restore from $selected"
    fi
}

# Show a dashboard with the current system/DNS/Docker state
show_status() {
    echo
    echo -e "${CYAN}================ System Status ================${NC}"

    # Operating system and package manager
    echo -e "${GREEN}OS:${NC}              ${OS_NAME:-unknown}"
    echo -e "${GREEN}Package manager:${NC} ${PKG_MANAGER:-unknown}"
    echo -e "${GREEN}Kernel:${NC}          $(uname -r 2>/dev/null)"

    # Current DNS nameservers from /etc/resolv.conf
    echo
    local nameservers
    nameservers=$(grep -E '^\s*nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd ', ' -)
    if [ -n "$nameservers" ]; then
        echo -e "${GREEN}Current DNS:${NC}     $nameservers"
    else
        echo -e "${GREEN}Current DNS:${NC}     ${RED}none found${NC}"
    fi

    # Count available DNS backups
    local backup_count
    backup_count=$(ls -1 /etc/resolv.conf.bak.* 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}DNS backups:${NC}     ${backup_count:-0}"

    # Docker version and configured registry mirror
    echo
    if command -v docker >/dev/null 2>&1; then
        local dversion
        dversion=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
        if [ -n "$dversion" ]; then
            echo -e "${GREEN}Docker:${NC}          installed (v$dversion)"
        else
            echo -e "${GREEN}Docker:${NC}          installed (daemon not responding)"
        fi

        # Extract registry-mirrors from daemon.json if present
        if [ -f /etc/docker/daemon.json ]; then
            local mirror
            mirror=$(grep -oE 'https?://[^"]+' /etc/docker/daemon.json 2>/dev/null | paste -sd ', ' -)
            if [ -n "$mirror" ]; then
                echo -e "${GREEN}Docker mirror:${NC}   $mirror"
            else
                echo -e "${GREEN}Docker mirror:${NC}   ${CYAN}none configured${NC}"
            fi
        else
            echo -e "${GREEN}Docker mirror:${NC}   ${CYAN}none configured${NC}"
        fi
    else
        echo -e "${GREEN}Docker:${NC}          ${RED}not installed${NC}"
    fi

    echo -e "${CYAN}==============================================${NC}"
}

# Docker Management Functions

install_docker() {
    # Check if Docker is already installed
    if command -v docker >/dev/null 2>&1; then
        version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
        if [ -n "$version" ]; then
            echo -e "${GREEN}Docker is already installed. Version: $version${NC}"
            return
        fi
    fi

    echo -e "${CYAN}Starting Docker installation...${NC}"

    # Ensure we know how to install packages on this distro
    if [ "$PKG_MANAGER" = "unknown" ]; then
        echo -e "${RED}Error:${NC} Unsupported distro — no known package manager found."
        echo -e "${CYAN}Supported:${NC} apt, dnf, yum, pacman, zypper."
        return 1
    fi

    echo -e "${CYAN}Detected package manager:${NC} $PKG_MANAGER"

    # Update package lists
    echo -e "${GREEN}Updating package lists...${NC}"
    if ! eval "$PKG_UPDATE"; then
        echo -e "${RED}Error:${NC} Failed to update package lists."
        return 1
    fi

    # Install required dependencies
    echo -e "${GREEN}Installing required packages (curl)...${NC}"
    if ! eval "$PKG_INSTALL curl"; then
        echo -e "${RED}Error:${NC} Failed to install prerequisites."
        return 1
    fi

    # Download and run Docker installation script
    echo -e "${GREEN}Downloading and installing Docker...${NC}"
    if ! curl -fsSL https://get.docker.com | sh; then
        echo -e "${RED}Error:${NC} Docker installation script failed."
        return 1
    fi

    # Verify Docker installation
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC} Docker command not found after installation."
        return 1
    fi

    # Get and display Docker version
    version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    if [ -z "$version" ]; then
        echo -e "${RED}Error:${NC} Could not retrieve Docker version."
        return 1
    fi

    echo -e "${GREEN}Docker installed successfully. Version: $version${NC}"
}

# Update Docker to the latest version
update_docker() {
    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}Docker is not installed.${NC} Please install it first."
        return
    fi

    echo -e "${CYAN}Updating Docker to the latest version...${NC}"

    # Download and run Docker installation script (also works for updates)
    echo -e "${GREEN}Downloading and installing Docker...${NC}"
    if ! curl -fsSL https://get.docker.com | sh >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC} Docker update script failed."
        return 1
    fi

    # Display updated version
    version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    echo -e "${GREEN}Docker updated successfully. Version: $version${NC}"
}

# Find fastest proxy automatically
find_fastest_proxy() {
    echo -e "${CYAN}Testing proxies for best performance...${NC}" >&2
    
    local best_proxy=""
    local best_time="999999"
    
    for proxy in "${registry_proxies[@]}"; do
        printf "Testing %s... " "$proxy" >&2
        ping_time=$(ping_proxy "$proxy")
        
        if [[ "$ping_time" != "timeout" ]]; then
            echo "${ping_time}ms" >&2
            # Compare ping times using awk (standard on most systems) to handle floats
            if (( $(awk -v p="$ping_time" -v b="$best_time" 'BEGIN {if (p < b) print 1; else print 0}') )); then
                best_time="$ping_time"
                best_proxy="$proxy"
            fi
        else
            echo "timeout" >&2
        fi
    done
    
    if [[ -n "$best_proxy" ]]; then
        echo >&2
        echo -e "${GREEN}Fastest proxy found:${NC} $best_proxy (${best_time}ms)" >&2
        echo "$best_proxy"
    else
        echo -e "${RED}No responsive proxies found${NC}" >&2
        return 1
    fi
}

# Configure Docker to use Iranian registry mirrors
set_docker_proxy() {
    echo
    echo -e "${CYAN}Select Docker Registry Mirror:${NC}"
    echo "  00) Auto-select fastest proxy"
    for i in "${!registry_proxies[@]}"; do
        echo "  $((i + 1))) https://${registry_proxies[$i]}"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-$((${#registry_proxies[@]} + 1))): " proxy_choice

    if [[ "$proxy_choice" == "0" ]]; then return; fi
    if [[ "$proxy_choice" == "00" ]]; then
        # Auto-select fastest proxy
        fastest_output=$(find_fastest_proxy)
        mirror=$(echo "$fastest_output" | tail -n1)
        if [[ -z "$mirror" ]] || [[ "$mirror" == *"No responsive proxies found"* ]]; then
            echo -e "${RED}Failed to find fastest proxy${NC}"
            return
        fi
    else
        if [[ ! "$proxy_choice" =~ ^[0-9]+$ ]] || (( proxy_choice < 1 || proxy_choice > ${#registry_proxies[@]} )); then
            echo -e "${RED}Invalid option${NC}"; return
        fi
        mirror="${registry_proxies[$((proxy_choice - 1))]}"
    fi
    
    # Create Docker configuration directory
    mkdir -p /etc/docker
    
    # Create daemon.json with registry mirror configuration
    echo -e "{\n  \"registry-mirrors\": [\"https://$mirror\"]\n}" > /etc/docker/daemon.json

    # Restart Docker service to apply changes
    echo -e "${CYAN}Restarting Docker service...${NC}"
    if systemctl restart docker; then
        echo -e "${GREEN}Docker service restarted successfully${NC}"
    else
        echo -e "${RED}Warning:${NC} Docker service restart failed. Configuration saved but may need manual restart."
        echo -e "${CYAN}Try running:${NC} sudo systemctl restart docker"
    fi

    echo -e "${GREEN}Docker proxy set to:${NC} $mirror"
}

# Main Menu and Program Entry Point
main_menu() {
    while true; do
        echo
        echo -e "${CYAN}Main Menu:${NC}"
        for i in "${!main_menu_items[@]}"; do
            echo "  $((i + 1))) ${main_menu_items[$i]}"
        done
        echo
        read -rp "Select an option (1-${#main_menu_items[@]}): " choice

        case "$choice" in
            1) show_status ;;
            2) set_dns ;;
            3) restore_dns_backup ;;
            4) install_docker ;;
            5) update_docker ;;
            6) set_docker_proxy ;;
            7) echo -e "${CYAN}Bye.${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}

# Start the program
main_menu
