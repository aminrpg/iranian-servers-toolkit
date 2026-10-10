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

# Resolve the home directory of the human user who invoked sudo, so per-user
# configs (npm, pip, yarn) land in the right place instead of /root.
# Sets globals: TARGET_USER, TARGET_HOME
resolve_target_user() {
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        TARGET_USER="$SUDO_USER"
        TARGET_HOME=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)
        [ -z "$TARGET_HOME" ] && TARGET_HOME="/home/$SUDO_USER"
    else
        TARGET_USER="root"
        TARGET_HOME="${HOME:-/root}"
    fi
}

resolve_target_user

# Run a command as the invoking (non-root) user when possible, else as current user.
run_as_user() {
    if [ "$TARGET_USER" != "root" ] && command -v sudo >/dev/null 2>&1; then
        sudo -u "$TARGET_USER" "$@"
    else
        "$@"
    fi
}

# Write a file as the target user so ownership is correct (not root-owned).
write_as_user() {
    # Usage: write_as_user <path> <<< "content"  OR  piped stdin
    local path="$1"
    local dir
    dir=$(dirname "$path")
    mkdir -p "$dir"
    cat > "$path"
    if [ "$TARGET_USER" != "root" ]; then
        chown -R "$TARGET_USER" "$dir" 2>/dev/null
    fi
}

# Main menu options (top-level categories)
main_menu_items=("Show Status" "DNS Tools" "Docker Tools" "Package Registries" "Diagnostics" "Exit")

# ---- Mirror data (sourced from the Mirava project: github.com/MiravaOrg/Mirava) ----

# APT mirror base hosts (used to rewrite sources.list). Keyed by display name.
apt_mirror_options=("ArvanCloud" "IranServer" "Pardisco" "Ubuntu IR Archive" "Reset to Official")
declare -A apt_mirror_hosts=(
    ["ArvanCloud"]="mirror.arvancloud.ir"
    ["IranServer"]="mirror.iranserver.com"
    ["Pardisco"]="mirrors.pardisco.co"
    ["Ubuntu IR Archive"]="ir.archive.ubuntu.com"
    ["Reset to Official"]="archive.ubuntu.com"
)

# npm registry mirrors
npm_registry_options=("Runflare" "Kargadan" "Reset to Official")
declare -A npm_registry_urls=(
    ["Runflare"]="https://mirror-npm.runflare.com/"
    ["Kargadan"]="https://npm.kargadan.ir/"
    ["Reset to Official"]="https://registry.npmjs.org/"
)

# pip (PyPI) index mirrors
pip_index_options=("Runflare" "Kargadan" "ArvanCloud" "Reset to Official")
declare -A pip_index_urls=(
    ["Runflare"]="https://mirror-pypi.runflare.com/simple"
    ["Kargadan"]="https://pypi.kargadan.ir/simple"
    ["ArvanCloud"]="https://mirror.arvancloud.ir/pypi/web/simple"
    ["Reset to Official"]="https://pypi.org/simple"
)

# Endpoints used by the connectivity doctor (label|url)
connectivity_targets=(
    "Docker Hub|https://registry-1.docker.io/v2/"
    "GitHub|https://github.com"
    "npm registry|https://registry.npmjs.org/"
    "PyPI|https://pypi.org/simple/"
    "Google|https://www.google.com"
    "get.docker.com|https://get.docker.com"
)

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


# Remove the registry mirror from daemon.json and restart Docker
reset_docker_proxy() {
    if [ ! -f /etc/docker/daemon.json ]; then
        echo -e "${CYAN}No /etc/docker/daemon.json found — nothing to reset.${NC}"
        return
    fi

    # Back up current config before touching it
    cp /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%Y%m%d_%H%M%S)"

    # Remove the registry-mirrors key. If jq is available use it; otherwise
    # fall back to writing an empty config object.
    if command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        if jq 'del(."registry-mirrors")' /etc/docker/daemon.json > "$tmp" 2>/dev/null; then
            mv "$tmp" /etc/docker/daemon.json
        else
            rm -f "$tmp"
            echo "{}" > /etc/docker/daemon.json
        fi
    else
        echo "{}" > /etc/docker/daemon.json
    fi

    echo -e "${CYAN}Restarting Docker service...${NC}"
    if systemctl restart docker; then
        echo -e "${GREEN}Docker registry mirror removed and service restarted.${NC}"
    else
        echo -e "${RED}Warning:${NC} Config updated but Docker restart failed. Run: sudo systemctl restart docker"
    fi
}

# Test the currently configured Docker mirror: latency + a real pull
test_mirror_health() {
    if [ ! -f /etc/docker/daemon.json ]; then
        echo -e "${CYAN}No registry mirror configured (no daemon.json).${NC}"
        return
    fi

    local mirror_url mirror_host
    mirror_url=$(grep -oE 'https?://[^"]+' /etc/docker/daemon.json 2>/dev/null | head -1)
    if [ -z "$mirror_url" ]; then
        echo -e "${CYAN}No registry mirror set in daemon.json.${NC}"
        return
    fi

    mirror_host=$(echo "$mirror_url" | sed -E 's#https?://##; s#/.*##')
    echo -e "${GREEN}Configured mirror:${NC} $mirror_url"

    # Latency
    printf "Latency: "
    local ping_time
    ping_time=$(ping_proxy "$mirror_host")
    if [ "$ping_time" = "timeout" ]; then
        echo -e "${RED}unreachable (ping timeout)${NC}"
    else
        echo -e "${GREEN}${ping_time}ms${NC}"
    fi

    # HTTP reachability
    printf "HTTP check: "
    if curl -fsS --max-time 10 -o /dev/null "$mirror_url" 2>/dev/null; then
        echo -e "${GREEN}reachable${NC}"
    else
        echo -e "${RED}no HTTP response${NC}"
    fi

    # Test pull (small image) if Docker is available
    if command -v docker >/dev/null 2>&1; then
        printf "Test pull (hello-world): "
        if timeout 60 docker pull hello-world >/dev/null 2>&1; then
            echo -e "${GREEN}success${NC}"
        else
            echo -e "${RED}failed${NC} (mirror may be down or image unavailable)"
        fi
    fi
}

# Install or update the Docker Compose plugin
install_compose() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}Docker is not installed.${NC} Install Docker first."
        return
    fi

    if docker compose version >/dev/null 2>&1; then
        local cver
        cver=$(docker compose version --short 2>/dev/null)
        echo -e "${GREEN}Docker Compose already installed. Version: ${cver}${NC}"
        return
    fi

    if [ "$PKG_MANAGER" = "unknown" ]; then
        echo -e "${RED}Error:${NC} Unsupported distro — install docker-compose-plugin manually."
        return 1
    fi

    echo -e "${CYAN}Installing Docker Compose plugin...${NC}"
    eval "$PKG_UPDATE" >/dev/null 2>&1
    if eval "$PKG_INSTALL docker-compose-plugin"; then
        echo -e "${GREEN}Docker Compose installed:${NC} $(docker compose version --short 2>/dev/null)"
    else
        echo -e "${RED}Error:${NC} Failed to install docker-compose-plugin via $PKG_MANAGER."
    fi
}

# Point APT at an Iranian mirror by rewriting the official host in sources.list
set_apt_mirror() {
    if [ "$PKG_MANAGER" != "apt" ]; then
        echo -e "${CYAN}APT mirror switching only applies to Debian/Ubuntu (apt) systems.${NC}"
        return
    fi

    echo
    echo -e "${CYAN}Select APT mirror:${NC}"
    for i in "${!apt_mirror_options[@]}"; do
        name="${apt_mirror_options[$i]}"
        echo "  $((i + 1))) $name  (${apt_mirror_hosts[$name]})"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-${#apt_mirror_options[@]}): " apt_choice

    if [[ "$apt_choice" == "0" ]]; then return; fi
    if [[ ! "$apt_choice" =~ ^[0-9]+$ ]] || (( apt_choice < 1 || apt_choice > ${#apt_mirror_options[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local name host target
    name="${apt_mirror_options[$((apt_choice - 1))]}"
    host="${apt_mirror_hosts[$name]}"

    # Determine which sources file is in use (classic list vs deb822)
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        target="/etc/apt/sources.list.d/ubuntu.sources"
    else
        target="/etc/apt/sources.list"
    fi

    if [ ! -f "$target" ]; then
        echo -e "${RED}Error:${NC} $target not found."
        return
    fi

    # Backup before editing
    cp "$target" "${target}.bak.$(date +%Y%m%d_%H%M%S)"

    # Replace any known Ubuntu/mirror host with the chosen one
    sed -i -E "s#(https?://)[a-zA-Z0-9._-]*(archive\.ubuntu\.com|security\.ubuntu\.com|mirror\.arvancloud\.ir|mirror\.iranserver\.com|mirrors\.pardisco\.co|ir\.archive\.ubuntu\.com)#\1${host}#g" "$target"

    echo -e "${GREEN}APT mirror set to:${NC} $host"
    echo -e "${CYAN}Refreshing package lists...${NC}"
    if apt-get update; then
        echo -e "${GREEN}Done.${NC}"
    else
        echo -e "${RED}Warning:${NC} apt-get update failed. Restore from ${target}.bak.* if needed."
    fi
}

# Set the npm registry (written to the invoking user's ~/.npmrc)
set_npm_registry() {
    echo
    echo -e "${CYAN}Select npm registry (applies for user: $TARGET_USER):${NC}"
    for i in "${!npm_registry_options[@]}"; do
        name="${npm_registry_options[$i]}"
        echo "  $((i + 1))) $name  (${npm_registry_urls[$name]})"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-${#npm_registry_options[@]}): " npm_choice

    if [[ "$npm_choice" == "0" ]]; then return; fi
    if [[ ! "$npm_choice" =~ ^[0-9]+$ ]] || (( npm_choice < 1 || npm_choice > ${#npm_registry_options[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local name url
    name="${npm_registry_options[$((npm_choice - 1))]}"
    url="${npm_registry_urls[$name]}"

    # Prefer the npm CLI if available (keeps .npmrc valid); else write the file
    if command -v npm >/dev/null 2>&1; then
        run_as_user npm config set registry "$url"
    else
        local npmrc="$TARGET_HOME/.npmrc"
        [ -f "$npmrc" ] && cp "$npmrc" "${npmrc}.bak.$(date +%Y%m%d_%H%M%S)"
        write_as_user "$npmrc" <<EOF
registry=$url
EOF
    fi
    echo -e "${GREEN}npm registry set to:${NC} $url"
}

# Set the pip index-url (written to the invoking user's pip.conf)
set_pip_mirror() {
    echo
    echo -e "${CYAN}Select pip (PyPI) index (applies for user: $TARGET_USER):${NC}"
    for i in "${!pip_index_options[@]}"; do
        name="${pip_index_options[$i]}"
        echo "  $((i + 1))) $name  (${pip_index_urls[$name]})"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-${#pip_index_options[@]}): " pip_choice

    if [[ "$pip_choice" == "0" ]]; then return; fi
    if [[ ! "$pip_choice" =~ ^[0-9]+$ ]] || (( pip_choice < 1 || pip_choice > ${#pip_index_options[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local name url host
    name="${pip_index_options[$((pip_choice - 1))]}"
    url="${pip_index_urls[$name]}"
    host=$(echo "$url" | sed -E 's#https?://##; s#/.*##')

    local pipconf="$TARGET_HOME/.config/pip/pip.conf"
    [ -f "$pipconf" ] && cp "$pipconf" "${pipconf}.bak.$(date +%Y%m%d_%H%M%S)"

    if [ "$name" = "Reset to Official" ]; then
        write_as_user "$pipconf" <<EOF
[global]
index-url = $url
EOF
    else
        write_as_user "$pipconf" <<EOF
[global]
index-url = $url
trusted-host = $host
EOF
    fi
    echo -e "${GREEN}pip index set to:${NC} $url"
}

# Set the Yarn registry (reuses the npm mirror list)
set_yarn_registry() {
    if ! command -v yarn >/dev/null 2>&1; then
        echo -e "${CYAN}Yarn is not installed.${NC}"
        return
    fi

    echo
    echo -e "${CYAN}Select Yarn registry (applies for user: $TARGET_USER):${NC}"
    for i in "${!npm_registry_options[@]}"; do
        name="${npm_registry_options[$i]}"
        echo "  $((i + 1))) $name  (${npm_registry_urls[$name]})"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-${#npm_registry_options[@]}): " yarn_choice

    if [[ "$yarn_choice" == "0" ]]; then return; fi
    if [[ ! "$yarn_choice" =~ ^[0-9]+$ ]] || (( yarn_choice < 1 || yarn_choice > ${#npm_registry_options[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local name url
    name="${npm_registry_options[$((yarn_choice - 1))]}"
    url="${npm_registry_urls[$name]}"
    run_as_user yarn config set registry "$url"
    echo -e "${GREEN}Yarn registry set to:${NC} $url"
}

# Connectivity doctor: check reachability of key developer endpoints and flag
# sanction-style blocks (HTTP 403) vs. plain unreachability.
connectivity_doctor() {
    echo
    echo -e "${CYAN}============ Connectivity Doctor ============${NC}"
    printf "%-16s %s\n" "SERVICE" "RESULT"
    echo "---------------------------------------------"

    for entry in "${connectivity_targets[@]}"; do
        local label url code
        label="${entry%%|*}"
        url="${entry#*|}"

        # Grab the HTTP status code (follow redirects, short timeout)
        code=$(curl -s -o /dev/null -L --max-time 10 -w '%{http_code}' "$url" 2>/dev/null)

        if [ -z "$code" ] || [ "$code" = "000" ]; then
            printf "%-16s ${RED}%s${NC}\n" "$label" "unreachable / blocked"
        elif [ "$code" = "403" ]; then
            printf "%-16s ${RED}%s${NC}\n" "$label" "HTTP 403 (likely sanction block)"
        elif [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
            printf "%-16s ${GREEN}%s${NC}\n" "$label" "OK ($code)"
        elif [ "$code" = "401" ]; then
            # Registries often return 401 when reachable but unauthenticated
            printf "%-16s ${GREEN}%s${NC}\n" "$label" "reachable ($code)"
        else
            printf "%-16s ${CYAN}%s${NC}\n" "$label" "HTTP $code"
        fi
    done
    echo -e "${CYAN}=============================================${NC}"
    echo -e "Tip: if Docker Hub or PyPI show blocked/403, set a DNS or mirror from the menus."
}

# DNS benchmark: ping each provider's primary server and test whether it can
# resolve Docker Hub, then recommend the fastest working resolver.
dns_benchmark() {
    echo
    echo -e "${CYAN}============== DNS Benchmark ================${NC}"
    printf "%-14s %-10s %s\n" "PROVIDER" "LATENCY" "RESOLVES docker.io"
    echo "---------------------------------------------"

    local best_provider="" best_time="999999"

    for provider in "${dns_options[@]}"; do
        [ "$provider" = "Reset to Default" ] && continue
        local primary ping_time resolves
        primary=$(echo "${dns_servers[$provider]}" | awk '{print $1}')

        ping_time=$(ping_proxy "$primary")

        # Can this resolver answer for Docker Hub?
        if command -v nslookup >/dev/null 2>&1; then
            if nslookup -timeout=2 registry-1.docker.io "$primary" >/dev/null 2>&1; then
                resolves="${GREEN}yes${NC}"
            else
                resolves="${RED}no${NC}"
            fi
        elif command -v dig >/dev/null 2>&1; then
            if [ -n "$(dig +time=2 +tries=1 @"$primary" registry-1.docker.io +short 2>/dev/null)" ]; then
                resolves="${GREEN}yes${NC}"
            else
                resolves="${RED}no${NC}"
            fi
        else
            resolves="${CYAN}n/a${NC}"
        fi

        if [ "$ping_time" = "timeout" ]; then
            printf "%-14s ${RED}%-10s${NC} %b\n" "$provider" "timeout" "$resolves"
        else
            printf "%-14s %-10s %b\n" "$provider" "${ping_time}ms" "$resolves"
            if (( $(awk -v p="$ping_time" -v b="$best_time" 'BEGIN {print (p < b) ? 1 : 0}') )); then
                best_time="$ping_time"
                best_provider="$provider"
            fi
        fi
    done

    echo -e "${CYAN}=============================================${NC}"
    if [ -n "$best_provider" ]; then
        echo -e "${GREEN}Fastest resolver:${NC} $best_provider (${best_time}ms)"
        echo -e "Set it from: DNS Tools -> Set DNS"
    else
        echo -e "${RED}No resolver responded to ping.${NC}"
    fi
}

# ---- Submenus ----

dns_menu() {
    local items=("Set DNS" "Restore DNS Backup" "DNS Benchmark")
    while true; do
        echo
        echo -e "${CYAN}DNS Tools:${NC}"
        for i in "${!items[@]}"; do echo "  $((i + 1))) ${items[$i]}"; done
        echo "  0) Back"
        echo
        read -rp "Select (0-${#items[@]}): " c
        case "$c" in
            1) set_dns ;;
            2) restore_dns_backup ;;
            3) dns_benchmark ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}

docker_menu() {
    local items=("Install Docker" "Update Docker" "Set Docker Proxy" "Reset Docker Proxy" "Test Mirror Health" "Install Docker Compose")
    while true; do
        echo
        echo -e "${CYAN}Docker Tools:${NC}"
        for i in "${!items[@]}"; do echo "  $((i + 1))) ${items[$i]}"; done
        echo "  0) Back"
        echo
        read -rp "Select (0-${#items[@]}): " c
        case "$c" in
            1) install_docker ;;
            2) update_docker ;;
            3) set_docker_proxy ;;
            4) reset_docker_proxy ;;
            5) test_mirror_health ;;
            6) install_compose ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}

registries_menu() {
    local items=("Set APT Mirror" "Set npm Registry" "Set pip (PyPI) Mirror" "Set Yarn Registry")
    while true; do
        echo
        echo -e "${CYAN}Package Registries:${NC}"
        for i in "${!items[@]}"; do echo "  $((i + 1))) ${items[$i]}"; done
        echo "  0) Back"
        echo
        read -rp "Select (0-${#items[@]}): " c
        case "$c" in
            1) set_apt_mirror ;;
            2) set_npm_registry ;;
            3) set_pip_mirror ;;
            4) set_yarn_registry ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}

diagnostics_menu() {
    local items=("Connectivity Doctor" "DNS Benchmark" "Test Docker Mirror Health")
    while true; do
        echo
        echo -e "${CYAN}Diagnostics:${NC}"
        for i in "${!items[@]}"; do echo "  $((i + 1))) ${items[$i]}"; done
        echo "  0) Back"
        echo
        read -rp "Select (0-${#items[@]}): " c
        case "$c" in
            1) connectivity_doctor ;;
            2) dns_benchmark ;;
            3) test_mirror_health ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}

# Main Menu and Program Entry Point
main_menu() {
    while true; do
        echo
        echo -e "${CYAN}===== Iranian Servers Toolkit =====${NC}"
        for i in "${!main_menu_items[@]}"; do
            echo "  $((i + 1))) ${main_menu_items[$i]}"
        done
        echo
        read -rp "Select an option (1-${#main_menu_items[@]}): " choice

        case "$choice" in
            1) show_status ;;
            2) dns_menu ;;
            3) docker_menu ;;
            4) registries_menu ;;
            5) diagnostics_menu ;;
            6) echo -e "${CYAN}Bye.${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}

# Start the program
main_menu
