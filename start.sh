#!/bin/bash

# Iranian Servers Toolkit
# DNS switching, Docker install/setup, and registry mirrors for servers in Iran.
# Author: https://github.com/aminrpg

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
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

# Main menu options (top-level categories). "Exit" is option 0, handled separately.
main_menu_items=("Show Status" "DNS Tools" "Docker Tools" "Package Registries" "Server Setup" "Diagnostics")

# Iranian NTP servers for time sync
ntp_servers=("ntp.day.ir" "ir.pool.ntp.org" "0.ir.pool.ntp.org")

# Base packages installed by the "Install Base Packages" option
base_packages=("curl" "wget" "git" "vim" "htop" "unzip" "ca-certificates" "nano" "net-tools")

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

# Composer (PHP / Packagist) mirrors — full repo URL
composer_options=("Liara" "Kargadan" "Reset to Official")
declare -A composer_urls=(
    ["Liara"]="https://repo.liara.ir/composer"
    ["Kargadan"]="https://composer.kargadan.ir"
    ["Reset to Official"]="https://repo.packagist.org"
)

# Go module proxy (GOPROXY) mirrors — full proxy URL
go_proxy_options=("Liara" "Kargadan" "Reset to Official")
declare -A go_proxy_urls=(
    ["Liara"]="https://repo.liara.ir/go"
    ["Kargadan"]="https://goproxy.kargadan.ir"
    ["Reset to Official"]="https://proxy.golang.org"
)

# NuGet (.NET) mirrors — full v3 index URL
nuget_options=("Kargadan" "Pardisco" "Reset to Official")
declare -A nuget_urls=(
    ["Kargadan"]="https://nuget.kargadan.ir/v3/index.json"
    ["Pardisco"]="https://mirrors.pardisco.co/nuget/v3/index.json"
    ["Reset to Official"]="https://api.nuget.org/v3/index.json"
)

# Maven / Gradle mirrors — full repository URL (written to ~/.m2/settings.xml)
maven_options=("Myket" "Kargadan" "Reset to Official")
declare -A maven_urls=(
    ["Myket"]="https://maven.myket.ir"
    ["Kargadan"]="https://maven.kargadan.ir"
    ["Reset to Official"]="https://repo1.maven.org/maven2"
)

# DNF/YUM mirror base hosts (Fedora/Rocky/CentOS) — used to rewrite repo baseurls
dnf_mirror_options=("ArvanCloud" "IUT" "Zero-One Cloud" "Reset to Official")
declare -A dnf_mirror_hosts=(
    ["ArvanCloud"]="mirror.arvancloud.ir"
    ["IUT"]="repo.iut.ac.ir"
    ["Zero-One Cloud"]="mirror.0-1.cloud"
    ["Reset to Official"]="download.fedoraproject.org"
)

# Pacman mirror Server lines (Arch/Manjaro) — full Server= URL template
pacman_mirror_options=("ArvanCloud" "IUT" "Zero-One Cloud" "Reset to Official")
declare -A pacman_mirror_urls=(
    ["ArvanCloud"]="https://mirror.arvancloud.ir/archlinux/\$repo/os/\$arch"
    ["IUT"]="https://repo.iut.ac.ir/repo/archlinux/\$repo/os/\$arch"
    ["Zero-One Cloud"]="https://mirror.0-1.cloud/archlinux/\$repo/os/\$arch"
    ["Reset to Official"]="https://geo.mirror.pkgbuild.com/\$repo/os/\$arch"
)

# GitHub proxy prefixes — used with git's url.<proxy>.insteadOf for clones/downloads
github_proxy_options=("IranGit (scorpian)" "theazizi (releases)" "Reset to Official")
declare -A github_proxy_urls=(
    ["IranGit (scorpian)"]="https://scorpian.ir/https://github.com/"
    ["theazizi (releases)"]="https://gitdl.theazizi.ir/https://github.com/"
    ["Reset to Official"]="https://github.com/"
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
dns_options=("Shecan" "Shecan Pro" "Radar" "Electro" "Begzar" "DNSPro" "403" "XODNS" "Bertina" "DynX" "Google" "Cloudflare" "Reset to Default")
declare -A dns_servers=(
    ["Shecan"]="178.22.122.100 185.51.200.2"
	["Shecan Pro"]="178.22.122.101 185.51.200.1"
    ["Radar"]="10.202.10.10 10.202.10.11"
    ["Electro"]="78.157.42.100 78.157.42.101"
    ["Begzar"]="185.55.226.26 185.55.226.25"
    ["DNSPro"]="87.107.110.109 87.107.110.110"
    ["403"]="10.202.10.202 10.202.10.102"
    ["XODNS"]="85.208.255.182 85.208.255.71"
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

# containerd / Kubernetes registry mirrors.
# These configure the containerd runtime directly (/etc/containerd/certs.d),
# which is what Kubernetes nodes (kubeadm, k3s, RKE2) and the containerd CRI
# use — the classic Docker daemon.json does NOT apply there. (Podman/Buildah
# read their own containers-registries.conf instead; see set_podman_mirror.)
#
# containerd's hosts.toml maps ONE upstream registry per host file:
#   - upstream "_default": a universal gateway that proxies EVERY registry at
#     once via containerd's ?ns= fallback (one file covers docker.io,
#     registry.k8s.io, gcr.io, quay.io, ...). Only mirrors that explicitly
#     advertise this behavior belong here.
#   - upstream "docker.io" / "registry.k8s.io" / ...: scopes the mirror to
#     that single registry.
#
# Each entry is keyed by display name with a matching host + upstream.
#
# "Universal" and K8s-specific entries are the XODNS endpoints that document
# multi-registry support (see https://mirror.xodns.net, https://k8s-mirror.xodns.net).
#
# The Iranian Docker Hub mirrors from $registry_proxies are offered too, but
# scoped to docker.io only — they mirror Docker Hub, not registry.k8s.io/gcr/quay.
containerd_mirror_options=("XODNS Universal (all registries)" "XODNS Kubernetes (registry.k8s.io)" "XODNS Docker Hub" "GitLab Registry (Liara)" "GitLab Registry (mirrorlist.ir)")
declare -A containerd_mirror_hosts=(
    ["XODNS Universal (all registries)"]="mirror.xodns.net"
    ["XODNS Kubernetes (registry.k8s.io)"]="k8s-mirror.xodns.net"
    ["XODNS Docker Hub"]="docker-mirror.xodns.net"
    ["GitLab Registry (Liara)"]="gitlab-mirror.liara.ir"
    ["GitLab Registry (mirrorlist.ir)"]="gitlab.mirrorlist.ir"
)
declare -A containerd_mirror_upstreams=(
    ["XODNS Universal (all registries)"]="_default"
    ["XODNS Kubernetes (registry.k8s.io)"]="registry.k8s.io"
    ["XODNS Docker Hub"]="docker.io"
    ["GitLab Registry (Liara)"]="registry.gitlab.com"
    ["GitLab Registry (mirrorlist.ir)"]="registry.gitlab.com"
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

        # Extract registry-mirrors from daemon.json if present.
        # A configured mirror means the Docker proxy has been CHANGED from
        # the default, so flag it clearly and use a distinct color.
        local mirror=""
        if [ -f /etc/docker/daemon.json ]; then
            mirror=$(grep -oE 'https?://[^"]+' /etc/docker/daemon.json 2>/dev/null | paste -sd ', ' -)
        fi
        if [ -n "$mirror" ]; then
            echo -e "${GREEN}Docker Proxy:${NC}    ${YELLOW}CHANGED${NC} -> ${YELLOW}${mirror}${NC}"
        else
            echo -e "${GREEN}Docker Proxy:${NC}    ${CYAN}default (none configured)${NC}"
        fi
    else
        echo -e "${GREEN}Docker:${NC}          ${RED}not installed${NC}"
    fi

    # containerd / Kubernetes registry mirror (separate from Docker daemon)
    local containerd_mirror=""
    if [ -d /etc/containerd/certs.d ]; then
        containerd_mirror=$(grep -rhoE '\[host\."https?://[^"]+' /etc/containerd/certs.d 2>/dev/null \
            | sed -E 's#.*https?://##' | sort -u | paste -sd ', ' -)
    fi
    if [ -n "$containerd_mirror" ]; then
        echo -e "${GREEN}containerd mirror:${NC} ${YELLOW}CHANGED${NC} -> ${YELLOW}${containerd_mirror}${NC}"
    elif command -v containerd >/dev/null 2>&1 || [ -S /run/containerd/containerd.sock ]; then
        echo -e "${GREEN}containerd mirror:${NC} ${CYAN}default (none configured)${NC}"
    fi

    # Podman registry mirror (containers-registries.conf drop-in we write)
    local podman_mirror=""
    if [ -f /etc/containers/registries.conf.d/001-iran-mirror.conf ]; then
        podman_mirror=$(grep -oE 'location = "[^"]+"' /etc/containers/registries.conf.d/001-iran-mirror.conf 2>/dev/null \
            | sed -E 's/location = "//; s/"$//' | sort -u | grep -vE '^(docker\.io|registry\.k8s\.io|gcr\.io|quay\.io|nvcr\.io)$' | paste -sd ', ' -)
    fi
    if [ -n "$podman_mirror" ]; then
        echo -e "${GREEN}Podman mirror:${NC}   ${YELLOW}CHANGED${NC} -> ${YELLOW}${podman_mirror}${NC}"
    elif command -v podman >/dev/null 2>&1; then
        echo -e "${GREEN}Podman mirror:${NC}   ${CYAN}default (none configured)${NC}"
    fi

    # Package registries: show only the ones that have been changed from
    # their defaults. Each line is highlighted so changes stand out.
    echo
    echo -e "${GREEN}Package Registries:${NC}"
    local changed=0

    # npm registry (~/.npmrc)
    local npmrc="$TARGET_HOME/.npmrc" npm_reg=""
    if [ -f "$npmrc" ]; then
        npm_reg=$(grep -E '^\s*registry\s*=' "$npmrc" 2>/dev/null | tail -1 | sed -E 's/^\s*registry\s*=\s*//')
    fi
    if [ -n "$npm_reg" ] && [[ "$npm_reg" != *"registry.npmjs.org"* ]]; then
        echo -e "  ${YELLOW}npm:${NC}       ${YELLOW}CHANGED${NC} -> $npm_reg"
        changed=$((changed + 1))
    fi

    # pip index (~/.config/pip/pip.conf)
    local pipconf="$TARGET_HOME/.config/pip/pip.conf" pip_idx=""
    if [ -f "$pipconf" ]; then
        pip_idx=$(grep -E '^\s*index-url\s*=' "$pipconf" 2>/dev/null | tail -1 | sed -E 's/^\s*index-url\s*=\s*//')
    fi
    if [ -n "$pip_idx" ] && [[ "$pip_idx" != *"pypi.org"* ]]; then
        echo -e "  ${YELLOW}pip:${NC}       ${YELLOW}CHANGED${NC} -> $pip_idx"
        changed=$((changed + 1))
    fi

    # Maven mirror (~/.m2/settings.xml)
    local m2="$TARGET_HOME/.m2/settings.xml" mvn_url=""
    if [ -f "$m2" ]; then
        mvn_url=$(grep -oE '<url>[^<]+</url>' "$m2" 2>/dev/null | head -1 | sed -E 's#</?url>##g')
    fi
    if [ -n "$mvn_url" ] && [[ "$mvn_url" != *"repo1.maven.org"* ]]; then
        echo -e "  ${YELLOW}Maven:${NC}     ${YELLOW}CHANGED${NC} -> $mvn_url"
        changed=$((changed + 1))
    fi

    # Composer global repo (~/.config/composer/config.json or ~/.composer/config.json)
    local comp_url=""
    for comp_cfg in "$TARGET_HOME/.config/composer/config.json" "$TARGET_HOME/.composer/config.json"; do
        if [ -f "$comp_cfg" ]; then
            comp_url=$(grep -oE 'https?://[^"]+' "$comp_cfg" 2>/dev/null | grep -v 'packagist.org' | head -1)
            [ -n "$comp_url" ] && break
        fi
    done
    if [ -n "$comp_url" ]; then
        echo -e "  ${YELLOW}Composer:${NC}  ${YELLOW}CHANGED${NC} -> $comp_url"
        changed=$((changed + 1))
    fi

    # Go proxy (go env GOPROXY)
    if command -v go >/dev/null 2>&1; then
        local goproxy
        goproxy=$(run_as_user go env GOPROXY 2>/dev/null)
        if [ -n "$goproxy" ] && [[ "$goproxy" != *"proxy.golang.org"* ]]; then
            echo -e "  ${YELLOW}Go:${NC}        ${YELLOW}CHANGED${NC} -> $goproxy"
            changed=$((changed + 1))
        fi
    fi

    # NuGet mirror (our named "iran-mirror" source in NuGet.Config)
    local nuget_cfg="" nuget_url=""
    for nc in "$TARGET_HOME/.nuget/NuGet/NuGet.Config" "$TARGET_HOME/.config/NuGet/NuGet.Config"; do
        [ -f "$nc" ] && nuget_cfg="$nc" && break
    done
    if [ -n "$nuget_cfg" ]; then
        nuget_url=$(grep -i 'iran-mirror' "$nuget_cfg" 2>/dev/null | grep -oE 'https?://[^"]+' | head -1)
    fi
    if [ -n "$nuget_url" ]; then
        echo -e "  ${YELLOW}NuGet:${NC}     ${YELLOW}CHANGED${NC} -> $nuget_url"
        changed=$((changed + 1))
    fi

    # GitHub proxy (git insteadOf rule for github.com)
    if command -v git >/dev/null 2>&1; then
        local gh_proxy
        gh_proxy=$(run_as_user git config --global --get-regexp 'url\..*\.insteadof' 2>/dev/null \
            | grep -i 'https://github.com/' | awk '{print $1}' | sed -E 's#^url\.##; s#\.insteadof$##I' | head -1)
        if [ -n "$gh_proxy" ] && [[ "$gh_proxy" != "https://github.com/" ]]; then
            echo -e "  ${YELLOW}GitHub:${NC}    ${YELLOW}CHANGED${NC} -> $gh_proxy"
            changed=$((changed + 1))
        fi
    fi

    # System package manager mirror (apt sources / dnf repos)
    local sys_mirror=""
    if [ "$PKG_MANAGER" = "apt" ]; then
        local apt_src="/etc/apt/sources.list"
        [ -f /etc/apt/sources.list.d/ubuntu.sources ] && apt_src="/etc/apt/sources.list.d/ubuntu.sources"
        if [ -f "$apt_src" ]; then
            sys_mirror=$(grep -hoE 'https?://[a-zA-Z0-9._-]+' "$apt_src" 2>/dev/null \
                | grep -viE 'archive\.ubuntu\.com|security\.ubuntu\.com|debian\.org' \
                | sort -u | paste -sd ', ' -)
        fi
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        if [ -d /etc/yum.repos.d ]; then
            sys_mirror=$(grep -rhoE '^baseurl=https?://[^/]+' /etc/yum.repos.d/*.repo 2>/dev/null \
                | sed -E 's#^baseurl=https?://##' \
                | grep -viE 'fedoraproject\.org|centos\.org|rockylinux\.org' \
                | sort -u | paste -sd ', ' -)
        fi
    fi
    if [ -n "$sys_mirror" ]; then
        echo -e "  ${YELLOW}${PKG_MANAGER}:${NC}       ${YELLOW}CHANGED${NC} -> $sys_mirror"
        changed=$((changed + 1))
    fi

    if [ "$changed" -eq 0 ]; then
        echo -e "  ${CYAN}all at defaults (no mirrors configured)${NC}"
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

# Install one or more packages via the detected package manager, trying each
# candidate name in order until one succeeds (names differ across distros).
# Usage: install_pkg_any "Display name" pkg1 [pkg2 ...]
install_pkg_any() {
    local label="$1"; shift
    if [ "$PKG_MANAGER" = "unknown" ]; then
        echo -e "${RED}Error:${NC} Unsupported distro — install $label manually."
        return 1
    fi
    local pkg
    for pkg in "$@"; do
        echo -e "${GREEN}Trying package:${NC} $pkg"
        if eval "$PKG_INSTALL $pkg" >/dev/null 2>&1; then
            echo -e "${GREEN}Installed:${NC} $pkg"
            return 0
        fi
    done
    echo -e "${RED}Error:${NC} Could not install $label (tried: $*)."
    return 1
}

# Install Podman (and optionally the rest of the containers toolset).
install_podman() {
    if command -v podman >/dev/null 2>&1; then
        echo -e "${GREEN}Podman is already installed. Version: $(podman --version 2>/dev/null | awk '{print $3}')${NC}"
        return
    fi

    if [ "$PKG_MANAGER" = "unknown" ]; then
        echo -e "${RED}Error:${NC} Unsupported distro — no known package manager found."
        echo -e "${CYAN}See:${NC} https://podman.io/docs/installation"
        return 1
    fi

    echo -e "${CYAN}Installing Podman via $PKG_MANAGER...${NC}"
    echo -e "${GREEN}Updating package lists...${NC}"
    eval "$PKG_UPDATE" >/dev/null 2>&1

    # The package name is "podman" on every supported distro.
    if ! install_pkg_any "Podman" podman; then
        return 1
    fi

    if command -v podman >/dev/null 2>&1; then
        echo -e "${GREEN}Podman installed successfully. Version: $(podman --version 2>/dev/null | awk '{print $3}')${NC}"
        echo -e "${CYAN}Tip:${NC} set an Iranian mirror via Docker Tools -> Set Podman Mirror."
    else
        echo -e "${RED}Error:${NC} podman command not found after installation."
        return 1
    fi
}

# Install the containerd runtime (used directly by Kubernetes nodes).
install_containerd() {
    if command -v containerd >/dev/null 2>&1; then
        echo -e "${GREEN}containerd is already installed. Version: $(containerd --version 2>/dev/null | awk '{print $3}')${NC}"
        return
    fi

    if [ "$PKG_MANAGER" = "unknown" ]; then
        echo -e "${RED}Error:${NC} Unsupported distro — no known package manager found."
        echo -e "${CYAN}See:${NC} https://github.com/containerd/containerd/blob/main/docs/getting-started.md"
        return 1
    fi

    echo -e "${CYAN}Installing containerd via $PKG_MANAGER...${NC}"
    echo -e "${GREEN}Updating package lists...${NC}"
    eval "$PKG_UPDATE" >/dev/null 2>&1

    # dnf/yum call it containerd.io (Docker CE repo) or containerd (Fedora);
    # apt/pacman/zypper use containerd. Try the common names in order.
    if ! install_pkg_any "containerd" containerd containerd.io; then
        echo -e "${CYAN}Tip:${NC} on RHEL/CentOS you may need the Docker CE repo for containerd.io."
        return 1
    fi

    if ! command -v containerd >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC} containerd command not found after installation."
        return 1
    fi

    # Generate a default config if none exists, so certs.d mirrors work.
    if [ ! -f /etc/containerd/config.toml ]; then
        mkdir -p /etc/containerd
        if containerd config default >/etc/containerd/config.toml 2>/dev/null; then
            echo -e "${GREEN}Wrote default config:${NC} /etc/containerd/config.toml"
        fi
    fi

    # Enable and start the service
    systemctl enable --now containerd >/dev/null 2>&1

    echo -e "${GREEN}containerd installed successfully. Version: $(containerd --version 2>/dev/null | awk '{print $3}')${NC}"
    echo -e "${CYAN}Tip:${NC} set an Iranian mirror via Docker Tools -> Set containerd / K8s Mirror."
}

# Install Buildah and Skopeo (the rest of the containers.git toolset).
install_buildah_skopeo() {
    if [ "$PKG_MANAGER" = "unknown" ]; then
        echo -e "${RED}Error:${NC} Unsupported distro — install buildah/skopeo manually."
        return 1
    fi

    echo -e "${CYAN}Installing Buildah and Skopeo via $PKG_MANAGER...${NC}"
    eval "$PKG_UPDATE" >/dev/null 2>&1

    local ok=1
    if command -v buildah >/dev/null 2>&1; then
        echo -e "${GREEN}Buildah already installed:${NC} $(buildah --version 2>/dev/null | awk '{print $3}')"
    else
        install_pkg_any "Buildah" buildah || ok=0
    fi
    if command -v skopeo >/dev/null 2>&1; then
        echo -e "${GREEN}Skopeo already installed:${NC} $(skopeo --version 2>/dev/null | awk '{print $3}')"
    else
        install_pkg_any "Skopeo" skopeo || ok=0
    fi

    if [ "$ok" -eq 1 ]; then
        echo -e "${GREEN}Buildah/Skopeo ready.${NC} They share Podman's registries.conf mirror."
    else
        echo -e "${CYAN}Finished with some failures — see messages above.${NC}"
    fi
}

# Fix broken APT sources that return HTTP 403 in Iran.
# Handles: packages.gitlab.com (gitlab-ce → Framasoft mirror, gitlab-ee → DNS advice)
#          ubuntu.bigbluebutton.org  (no public mirror → DNS advice)
#
# The function scans all APT source files, identifies known blocked domains,
# applies a mirror rewrite where one exists, and explains options where none does.
fix_blocked_apt_sources() {
    if [ "$PKG_MANAGER" != "apt" ]; then
        echo -e "${CYAN}This fix only applies to Debian/Ubuntu (apt) systems.${NC}"
        return
    fi

    # Detect distro codename once — used for mirror URL construction
    local codename os_id
    codename=$(. /etc/os-release 2>/dev/null && echo "${VERSION_CODENAME:-}")
    [ -z "$codename" ] && codename=$(lsb_release -cs 2>/dev/null)
    os_id=$(. /etc/os-release 2>/dev/null && echo "${ID:-debian}")

    echo
    echo -e "${CYAN}Scanning APT sources for known blocked domains...${NC}"

    local found_any=0

    # ── Helper: collect files referencing a pattern ──────────────────────────
    _apt_files_for() {
        grep -rlE "$1" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
    }

    # ── Helper: comment out matching lines + append a replacement ─────────────
    _rewrite_apt_files() {
        local pattern="$1" new_line="$2"
        local f
        while IFS= read -r f; do
            cp "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)"
            sed -i -E "s|^(deb[[:space:]].*${pattern}.*)|# \1  # disabled by Iranian Servers Toolkit|g" "$f"
            echo "$new_line" >> "$f"
            echo -e "${GREEN}Updated:${NC} $f"
        done < <(_apt_files_for "$pattern")
    }

    # ════════════════════════════════════════════════════════════════════════
    # 1. packages.gitlab.com
    # ════════════════════════════════════════════════════════════════════════
    local gitlab_files
    mapfile -t gitlab_files < <(_apt_files_for 'packages\.gitlab\.com')

    if [ ${#gitlab_files[@]} -gt 0 ]; then
        found_any=1
        echo
        echo -e "${YELLOW}── GitLab APT source ──────────────────────────────────${NC}"
        local f
        for f in "${gitlab_files[@]}"; do
            echo "  $f"
            grep -E 'packages\.gitlab\.com' "$f" | sed 's/^/    /'
        done

        # Detect edition
        local gl_edition=""
        for f in "${gitlab_files[@]}"; do
            grep -qE 'gitlab-ee' "$f" 2>/dev/null && { gl_edition="ee"; break; }
            grep -qE 'gitlab-ce' "$f" 2>/dev/null && gl_edition="ce"
        done

        if [ "$gl_edition" = "ee" ]; then
            echo
            echo -e "${RED}GitLab EE detected — no public APT mirror exists for EE packages.${NC}"
            echo -e "Options:"
            echo -e "  ${CYAN}1)${NC} Switch DNS to XODNS or Shecan (DNS Tools -> Set DNS) to"
            echo -e "     unblock packages.gitlab.com, then retry: sudo apt update && sudo apt upgrade"
            echo -e "  ${CYAN}2)${NC} Migrate EE → CE (CE packages are mirrored):"
            echo -e "     https://docs.gitlab.com/ee/downgrade_ee_to_ce/"
        else
            # CE: rewrite to Framasoft mirror
            local mirror_path=""
            case "$codename" in
                noble|jammy|focal)            mirror_path="ubuntu/$codename" ;;
                trixie|bookworm|bullseye)     mirror_path="debian/$codename" ;;
                *)
                    echo -e "${RED}Unsupported codename '$codename' for Framasoft GitLab CE mirror.${NC}"
                    echo -e "Supported: Ubuntu noble/jammy/focal, Debian trixie/bookworm/bullseye."
                    echo -e "Fallback: switch DNS (DNS Tools -> Set DNS) to unblock packages.gitlab.com."
                    ;;
            esac

            if [ -n "$mirror_path" ]; then
                local gl_base="https://apt.gitlab.mirror.framasoft.org/gitlab/gitlab-ce"
                local gl_line="deb [signed-by=/usr/share/keyrings/gitlab-mirror-framasoft.gpg] ${gl_base}/${mirror_path} ${codename} main"
                echo
                echo -e "${CYAN}Fix: rewrite to Framasoft GitLab CE mirror (${codename}).${NC}"
                echo -e "New line: $gl_line"
                read -rp "Apply? (y/N): " go
                if [[ "$go" =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Fetching Framasoft GPG key...${NC}"
                    if curl -fsSL "${gl_base}/gpgkey" \
                            | gpg --dearmor -o /usr/share/keyrings/gitlab-mirror-framasoft.gpg 2>/dev/null; then
                        echo -e "${GREEN}GPG key installed.${NC}"
                        _rewrite_apt_files 'packages\.gitlab\.com' "$gl_line"
                    else
                        echo -e "${RED}Error:${NC} Failed to fetch GPG key. Check DNS / network and retry."
                    fi
                else
                    echo -e "${CYAN}Skipped.${NC}"
                fi
            fi
        fi
    fi

    # ════════════════════════════════════════════════════════════════════════
    # 2. ubuntu.bigbluebutton.org
    # ════════════════════════════════════════════════════════════════════════
    local bbb_files
    mapfile -t bbb_files < <(_apt_files_for 'ubuntu\.bigbluebutton\.org')

    if [ ${#bbb_files[@]} -gt 0 ]; then
        found_any=1
        echo
        echo -e "${YELLOW}── BigBlueButton APT source ───────────────────────────${NC}"
        local f
        for f in "${bbb_files[@]}"; do
            echo "  $f"
            grep -E 'ubuntu\.bigbluebutton\.org' "$f" | sed 's/^/    /'
        done
        echo
        echo -e "${RED}No public APT mirror exists for ubuntu.bigbluebutton.org.${NC}"
        echo -e "BigBlueButton packages are only served from the official domain."
        echo -e "Options:"
        echo -e "  ${CYAN}1)${NC} Switch DNS to XODNS or Shecan (DNS Tools -> Set DNS) to"
        echo -e "     unblock ubuntu.bigbluebutton.org, then retry:"
        echo -e "     sudo apt update && sudo apt upgrade"
        echo -e "  ${CYAN}2)${NC} Install via the official bbb-install.sh script after switching DNS:"
        echo -e "     https://docs.bigbluebutton.org/administration/install/"
        echo -e "  ${CYAN}3)${NC} Temporarily disable the source until DNS is fixed:"
        read -rp "  Disable (comment out) the BigBlueButton source now? (y/N): " go
        if [[ "$go" =~ ^[Yy]$ ]]; then
            for f in "${bbb_files[@]}"; do
                cp "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)"
                sed -i -E 's|^(deb[[:space:]].*ubuntu\.bigbluebutton\.org.*)|# \1  # disabled by Iranian Servers Toolkit — no public mirror|g' "$f"
                echo -e "${GREEN}Commented out:${NC} $f"
            done
            echo -e "${CYAN}apt update will no longer fail on this source.${NC}"
            echo -e "Re-enable it after fixing DNS by removing the '# disabled' lines."
        else
            echo -e "${CYAN}Left unchanged.${NC}"
        fi
    fi

    # ════════════════════════════════════════════════════════════════════════
    # Summary
    # ════════════════════════════════════════════════════════════════════════
    if [ "$found_any" -eq 0 ]; then
        echo -e "${GREEN}No known blocked APT sources found — nothing to fix.${NC}"
        return
    fi

    echo
    echo -e "${CYAN}Running apt-get update to verify...${NC}"
    local update_out
    update_out=$(apt-get update 2>&1)
    local bad_lines
    bad_lines=$(echo "$update_out" | grep -E '(Err:|403|Failed to fetch)' | grep -iE 'gitlab|bigbluebutton')
    if [ -n "$bad_lines" ]; then
        echo -e "${RED}Still seeing errors:${NC}"
        echo "$bad_lines"
        echo -e "Remaining fix: switch DNS (DNS Tools -> Set DNS) then retry apt."
    else
        echo -e "${GREEN}apt update clean — no more GitLab/BigBlueButton errors.${NC}"
        echo -e "${CYAN}You can now run:${NC} sudo apt upgrade"
    fi
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

# Configure the containerd runtime to pull images through a mirror.
# This is what Kubernetes nodes (kubeadm/k3s/RKE2) and the containerd CRI use —
# docker daemon.json does NOT affect them. We write a hosts.toml under
# /etc/containerd/certs.d and make sure containerd's config_path points there.
# (For Podman/Buildah/Skopeo, use set_podman_mirror instead.)
set_containerd_mirror() {
    if ! command -v containerd >/dev/null 2>&1 && [ ! -S /run/containerd/containerd.sock ]; then
        echo -e "${CYAN}containerd not detected.${NC} This option targets Kubernetes/containerd nodes."
        read -rp "Configure anyway (write the files for a later containerd install)? (y/N): " go
        [[ "$go" =~ ^[Yy]$ ]] || return
    fi

    # Build a combined menu:
    #   1) curated containerd gateways (XODNS: universal, k8s, docker hub)
    #   2) the Iranian Docker Hub mirrors from $registry_proxies, each scoped
    #      to docker.io (they mirror Docker Hub only, not k8s/gcr/quay).
    # Parallel arrays keep the host + upstream for whatever the user picks.
    local menu_hosts=() menu_upstreams=() menu_labels=()
    local name
    for name in "${containerd_mirror_options[@]}"; do
        menu_hosts+=("${containerd_mirror_hosts[$name]}")
        menu_upstreams+=("${containerd_mirror_upstreams[$name]}")
        menu_labels+=("$name")
    done
    for proxy in "${registry_proxies[@]}"; do
        menu_hosts+=("$proxy")
        menu_upstreams+=("docker.io")
        menu_labels+=("$proxy  (Docker Hub only)")
    done

    echo
    echo -e "${CYAN}Select containerd / Kubernetes registry mirror:${NC}"
    echo -e "${CYAN}  Universal/K8s gateways cover all registries; the rest mirror Docker Hub only.${NC}"
    local i
    for i in "${!menu_labels[@]}"; do
        echo "  $((i + 1))) ${menu_labels[$i]}"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-${#menu_labels[@]}): " c_choice

    if [[ "$c_choice" == "0" ]]; then return; fi
    if [[ ! "$c_choice" =~ ^[0-9]+$ ]] || (( c_choice < 1 || c_choice > ${#menu_labels[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local host upstream
    host="${menu_hosts[$((c_choice - 1))]}"
    upstream="${menu_upstreams[$((c_choice - 1))]}"

    local certs_dir="/etc/containerd/certs.d"
    local target="$certs_dir/$upstream"
    mkdir -p "$target"

    local hosts_file="$target/hosts.toml"
    # Back up any existing hosts.toml for this upstream
    [ -f "$hosts_file" ] && cp "$hosts_file" "${hosts_file}.bak.$(date +%Y%m%d_%H%M%S)"

    # For the "_default" fallback, containerd forwards the real registry via
    # ?ns=<upstream>, so server must be "https://_default". Otherwise the
    # server is the real upstream registry and the mirror serves it.
    local server_url
    if [ "$upstream" = "_default" ]; then
        server_url="https://_default"
    else
        server_url="https://$upstream"
    fi

    cat > "$hosts_file" <<EOF
server = "$server_url"

[host."https://$host"]
  capabilities = ["pull", "resolve"]
EOF

    echo -e "${GREEN}Wrote:${NC} $hosts_file"

    # Make sure containerd actually reads certs.d (older default is empty).
    local cfg="/etc/containerd/config.toml"
    if [ -f "$cfg" ]; then
        if grep -qE 'config_path\s*=\s*""' "$cfg"; then
            cp "$cfg" "${cfg}.bak.$(date +%Y%m%d_%H%M%S)"
            sed -i -E 's#config_path\s*=\s*""#config_path = "/etc/containerd/certs.d"#g' "$cfg"
            echo -e "${CYAN}Enabled certs.d path in${NC} $cfg"
        elif ! grep -q "/etc/containerd/certs.d" "$cfg"; then
            echo -e "${CYAN}Note:${NC} Could not confirm config_path in $cfg."
            echo -e "       Ensure the CRI registry section has: config_path = \"/etc/containerd/certs.d\""
        fi
    else
        echo -e "${CYAN}Note:${NC} $cfg not found. If containerd uses a generated/default config,"
        echo -e "       run: containerd config default | tee $cfg  then set config_path to /etc/containerd/certs.d"
    fi

    # Restart containerd to apply
    echo -e "${CYAN}Restarting containerd...${NC}"
    if systemctl restart containerd 2>/dev/null; then
        echo -e "${GREEN}containerd restarted.${NC}"
    else
        echo -e "${RED}Warning:${NC} containerd restart failed (or not managed by systemd)."
        echo -e "         Restart it manually to apply the mirror."
    fi

    echo -e "${GREEN}containerd mirror set:${NC} $host  (upstream: $upstream)"
    # Show a verify command that matches the chosen upstream
    case "$upstream" in
        _default|registry.k8s.io)
            echo -e "${CYAN}Verify with:${NC} crictl pull registry.k8s.io/pause:3.10" ;;
        docker.io)
            echo -e "${CYAN}Verify with:${NC} crictl pull docker.io/library/nginx:alpine" ;;
        *)
            echo -e "${CYAN}Verify with:${NC} crictl pull ${upstream}/<some-image>" ;;
    esac
}

# Remove all containerd mirror config we may have written and restart containerd.
reset_containerd_mirror() {
    local certs_dir="/etc/containerd/certs.d"
    if [ ! -d "$certs_dir" ]; then
        echo -e "${CYAN}No $certs_dir found — nothing to reset.${NC}"
        return
    fi

    echo
    echo -e "${RED}This removes ALL mirror files under $certs_dir.${NC}"
    read -rp "Continue? (y/N): " go
    [[ "$go" =~ ^[Yy]$ ]] || { echo -e "${CYAN}Cancelled.${NC}"; return; }

    # Back up the whole certs.d tree before removing it
    local backup="${certs_dir}.bak.$(date +%Y%m%d_%H%M%S)"
    cp -r "$certs_dir" "$backup"
    echo -e "${CYAN}Backed up to:${NC} $backup"

    rm -rf "${certs_dir:?}/"*

    echo -e "${CYAN}Restarting containerd...${NC}"
    if systemctl restart containerd 2>/dev/null; then
        echo -e "${GREEN}containerd mirrors removed and service restarted.${NC}"
    else
        echo -e "${RED}Warning:${NC} Config cleared but containerd restart failed. Restart it manually."
    fi
}

# Upstream registries covered by a "universal" gateway. Podman has no
# equivalent of containerd's _default fallback, so for a universal mirror we
# write one [[registry]] pull-through block per upstream, all pointing at it.
podman_universal_upstreams=("docker.io" "registry.k8s.io" "gcr.io" "quay.io" "nvcr.io" "registry.gitlab.com")

# Configure Podman (and other github.com/containers tools: Buildah, Skopeo,
# CRI-O) to pull images through a mirror. Podman does NOT read Docker's
# daemon.json or containerd's certs.d — it uses containers-registries.conf.
# We write a drop-in file under /etc/containers/registries.conf.d/ so the
# main registries.conf is left untouched.
set_podman_mirror() {
    if ! command -v podman >/dev/null 2>&1; then
        echo -e "${CYAN}Podman not detected.${NC} This writes containers-registries.conf (also used by Buildah/Skopeo/CRI-O)."
        read -rp "Configure anyway? (y/N): " go
        [[ "$go" =~ ^[Yy]$ ]] || return
    fi

    # Same combined list as the containerd option: curated gateways first,
    # then the Iranian Docker Hub mirrors (docker.io only).
    local menu_hosts=() menu_upstreams=() menu_labels=()
    local name
    for name in "${containerd_mirror_options[@]}"; do
        menu_hosts+=("${containerd_mirror_hosts[$name]}")
        menu_upstreams+=("${containerd_mirror_upstreams[$name]}")
        menu_labels+=("$name")
    done
    for proxy in "${registry_proxies[@]}"; do
        menu_hosts+=("$proxy")
        menu_upstreams+=("docker.io")
        menu_labels+=("$proxy  (Docker Hub only)")
    done

    echo
    echo -e "${CYAN}Select Podman registry mirror:${NC}"
    echo -e "${CYAN}  Universal/K8s gateways cover all registries; the rest mirror Docker Hub only.${NC}"
    local i
    for i in "${!menu_labels[@]}"; do
        echo "  $((i + 1))) ${menu_labels[$i]}"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-${#menu_labels[@]}): " p_choice

    if [[ "$p_choice" == "0" ]]; then return; fi
    if [[ ! "$p_choice" =~ ^[0-9]+$ ]] || (( p_choice < 1 || p_choice > ${#menu_labels[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local host upstream
    host="${menu_hosts[$((p_choice - 1))]}"
    upstream="${menu_upstreams[$((p_choice - 1))]}"

    local confdir="/etc/containers/registries.conf.d"
    mkdir -p "$confdir"
    local conffile="$confdir/001-iran-mirror.conf"
    [ -f "$conffile" ] && cp "$conffile" "${conffile}.bak.$(date +%Y%m%d_%H%M%S)"

    # Build the list of upstreams to remap. A "_default" (universal) gateway
    # mirrors several registries; anything else mirrors just its one upstream.
    local upstreams=()
    if [ "$upstream" = "_default" ]; then
        upstreams=("${podman_universal_upstreams[@]}")
    else
        upstreams=("$upstream")
    fi

    {
        echo "# Iranian registry mirror(s) — written by Iranian Servers Toolkit on $(date)"
        echo "# Mirror host: $host"
        local u
        for u in "${upstreams[@]}"; do
            echo
            echo "[[registry]]"
            echo "prefix = \"$u\""
            echo "location = \"$u\""
            echo
            echo "[[registry.mirror]]"
            echo "location = \"$host\""
        done
    } > "$conffile"

    echo -e "${GREEN}Wrote:${NC} $conffile"
    echo -e "${GREEN}Podman mirror set:${NC} $host"
    if [ "$upstream" = "_default" ]; then
        echo -e "${CYAN}Covers:${NC} ${podman_universal_upstreams[*]}"
    else
        echo -e "${CYAN}Covers:${NC} $upstream"
    fi
    echo -e "${CYAN}Verify with:${NC} podman pull docker.io/library/nginx:alpine"
    echo -e "${CYAN}(No restart needed — Podman reads this config per pull.)${NC}"
}

# Remove the Podman mirror drop-in we wrote.
reset_podman_mirror() {
    local conffile="/etc/containers/registries.conf.d/001-iran-mirror.conf"
    if [ ! -f "$conffile" ]; then
        echo -e "${CYAN}No $conffile found — nothing to reset.${NC}"
        return
    fi
    cp "$conffile" "${conffile}.bak.$(date +%Y%m%d_%H%M%S)"
    rm -f "$conffile"
    echo -e "${GREEN}Podman mirror removed:${NC} $conffile"
    echo -e "${CYAN}(A timestamped backup was kept alongside it.)${NC}"
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
    local items=("Install Docker" "Update Docker" "Install Podman" "Install containerd" "Install Buildah & Skopeo" "Fix Blocked APT Sources (403)" "Install Docker Compose" "Set Docker Proxy" "Reset Docker Proxy" "Set containerd / K8s Mirror" "Reset containerd / K8s Mirror" "Set Podman Mirror" "Reset Podman Mirror" "Test Mirror Health")
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
            3) install_podman ;;
            4) install_containerd ;;
            5) install_buildah_skopeo ;;
            6) fix_blocked_apt_sources ;;
            7) install_compose ;;
            8) set_docker_proxy ;;
            9) reset_docker_proxy ;;
            10) set_containerd_mirror ;;
            11) reset_containerd_mirror ;;
            12) set_podman_mirror ;;
            13) reset_podman_mirror ;;
            14) test_mirror_health ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}

# registries_menu is defined later (appended) with the full set of registries.

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


# ---- Server Setup functions ----

# Set timezone to Asia/Tehran and enable NTP time sync
set_timezone_tehran() {
    echo
    echo -e "${CYAN}Setting timezone to Asia/Tehran...${NC}"

    if command -v timedatectl >/dev/null 2>&1; then
        if timedatectl set-timezone Asia/Tehran; then
            echo -e "${GREEN}Timezone set to Asia/Tehran${NC}"
        else
            echo -e "${RED}Error:${NC} Failed to set timezone via timedatectl."
        fi
        # Enable NTP sync
        timedatectl set-ntp true 2>/dev/null
    else
        # Fallback for systems without systemd
        if [ -f /usr/share/zoneinfo/Asia/Tehran ]; then
            ln -sf /usr/share/zoneinfo/Asia/Tehran /etc/localtime
            echo "Asia/Tehran" > /etc/timezone 2>/dev/null
            echo -e "${GREEN}Timezone set to Asia/Tehran (via symlink)${NC}"
        else
            echo -e "${RED}Error:${NC} Timezone data not found."
            return 1
        fi
    fi

    # Configure an Iranian NTP server if a client is available
    local ntp_primary="${ntp_servers[0]}"
    if command -v timedatectl >/dev/null 2>&1 && [ -d /etc/systemd ]; then
        mkdir -p /etc/systemd
        if [ -f /etc/systemd/timesyncd.conf ]; then
            cp /etc/systemd/timesyncd.conf "/etc/systemd/timesyncd.conf.bak.$(date +%Y%m%d_%H%M%S)"
        fi
        {
            echo "[Time]"
            echo "NTP=${ntp_servers[*]}"
        } > /etc/systemd/timesyncd.conf
        systemctl restart systemd-timesyncd 2>/dev/null
        echo -e "${GREEN}NTP servers set to:${NC} ${ntp_servers[*]}"
    else
        echo -e "${CYAN}Tip:${NC} install an NTP client and point it at $ntp_primary"
    fi

    echo -e "${GREEN}Current time:${NC} $(date)"
}

# Create and enable a swap file (helpful on low-RAM Iranian VPSes)
setup_swap() {
    # If swap is already active, report and offer to continue
    if swapon --show 2>/dev/null | grep -q .; then
        echo -e "${CYAN}Swap is already active:${NC}"
        swapon --show
        read -rp "Create an additional swap file anyway? (y/N): " cont
        [[ "$cont" =~ ^[Yy]$ ]] || return
    fi

    echo
    read -rp "Swap size in GB (e.g. 2) [0 to cancel]: " swap_gb
    if [[ ! "$swap_gb" =~ ^[0-9]+$ ]] || [ "$swap_gb" -eq 0 ]; then
        echo -e "${CYAN}Cancelled.${NC}"; return
    fi

    local swapfile="/swapfile"
    if [ -e "$swapfile" ]; then
        swapfile="/swapfile.$(date +%s)"
    fi

    echo -e "${CYAN}Creating ${swap_gb}G swap file at ${swapfile}...${NC}"

    # Prefer fallocate; fall back to dd
    if command -v fallocate >/dev/null 2>&1 && fallocate -l "${swap_gb}G" "$swapfile" 2>/dev/null; then
        :
    else
        echo -e "${CYAN}fallocate unavailable, using dd (slower)...${NC}"
        if ! dd if=/dev/zero of="$swapfile" bs=1M count=$((swap_gb * 1024)) status=none; then
            echo -e "${RED}Error:${NC} Failed to allocate swap file."
            rm -f "$swapfile"
            return 1
        fi
    fi

    chmod 600 "$swapfile"
    if ! mkswap "$swapfile" >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC} mkswap failed."; rm -f "$swapfile"; return 1
    fi
    if ! swapon "$swapfile"; then
        echo -e "${RED}Error:${NC} swapon failed."; rm -f "$swapfile"; return 1
    fi

    # Persist across reboots
    if ! grep -q "^$swapfile " /etc/fstab 2>/dev/null; then
        cp /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"
        echo "$swapfile none swap sw 0 0" >> /etc/fstab
    fi

    echo -e "${GREEN}Swap enabled:${NC}"
    swapon --show
}

# Harden SSH: optionally change port, disable password auth, add a public key.
# High-risk: a wrong setting can lock you out, so we confirm and never disable
# password auth unless a usable key is present.
harden_ssh() {
    local sshd_config="/etc/ssh/sshd_config"
    if [ ! -f "$sshd_config" ]; then
        echo -e "${RED}Error:${NC} $sshd_config not found. Is OpenSSH server installed?"
        return 1
    fi

    echo
    echo -e "${RED}============== WARNING ==============${NC}"
    echo -e "SSH hardening can ${RED}lock you out${NC} of this server if misconfigured."
    echo -e "Keep your current SSH session open and test a NEW connection before closing it."
    echo -e "${RED}====================================${NC}"
    read -rp "Continue? (y/N): " go
    [[ "$go" =~ ^[Yy]$ ]] || { echo -e "${CYAN}Cancelled.${NC}"; return; }

    # Always back up first
    cp "$sshd_config" "${sshd_config}.bak.$(date +%Y%m%d_%H%M%S)"

    # 1) Optionally add a public key for the target user
    read -rp "Paste a public SSH key to authorize (blank to skip): " pubkey
    if [ -n "$pubkey" ]; then
        local ssh_dir="$TARGET_HOME/.ssh"
        mkdir -p "$ssh_dir"
        echo "$pubkey" >> "$ssh_dir/authorized_keys"
        chmod 700 "$ssh_dir"; chmod 600 "$ssh_dir/authorized_keys"
        [ "$TARGET_USER" != "root" ] && chown -R "$TARGET_USER" "$ssh_dir"
        echo -e "${GREEN}Key added to${NC} $ssh_dir/authorized_keys"
    fi

    # 2) Optionally change the SSH port
    read -rp "New SSH port (blank to keep current): " new_port
    if [[ "$new_port" =~ ^[0-9]+$ ]] && (( new_port >= 1 && new_port <= 65535 )); then
        if grep -qE '^\s*#?\s*Port\s+' "$sshd_config"; then
            sed -i -E "s/^\s*#?\s*Port\s+.*/Port $new_port/" "$sshd_config"
        else
            echo "Port $new_port" >> "$sshd_config"
        fi
        echo -e "${GREEN}SSH port set to:${NC} $new_port"
        echo -e "${RED}Remember to open port $new_port in your firewall before reconnecting!${NC}"
    fi

    # 3) Optionally disable password authentication (only if a key exists)
    local keyfile="$TARGET_HOME/.ssh/authorized_keys"
    if [ -s "$keyfile" ]; then
        read -rp "Disable password authentication (key-only login)? (y/N): " nopass
        if [[ "$nopass" =~ ^[Yy]$ ]]; then
            if grep -qE '^\s*#?\s*PasswordAuthentication\s+' "$sshd_config"; then
                sed -i -E "s/^\s*#?\s*PasswordAuthentication\s+.*/PasswordAuthentication no/" "$sshd_config"
            else
                echo "PasswordAuthentication no" >> "$sshd_config"
            fi
            echo -e "${GREEN}Password authentication disabled.${NC}"
        fi
    else
        echo -e "${CYAN}No authorized key found — leaving password auth enabled (safer).${NC}"
    fi

    # Validate config before restarting to avoid breaking SSH
    if command -v sshd >/dev/null 2>&1 && ! sshd -t 2>/dev/null; then
        echo -e "${RED}Error:${NC} sshd config test failed. Restoring backup."
        cp "$(ls -1t ${sshd_config}.bak.* | head -1)" "$sshd_config"
        return 1
    fi

    echo -e "${CYAN}Restarting SSH service...${NC}"
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    echo -e "${GREEN}Done.${NC} Test a new SSH session now, before closing this one."
}

# Set up a basic firewall (UFW on Debian/Ubuntu, firewalld on RHEL family)
setup_firewall() {
    echo
    echo -e "${CYAN}Firewall setup${NC}"
    echo -e "This will allow SSH (22), HTTP (80), HTTPS (443) and enable the firewall."
    read -rp "Also allow a custom SSH port? (blank to skip): " custom_ssh

    if command -v ufw >/dev/null 2>&1; then
        echo -e "${CYAN}Configuring UFW...${NC}"
        ufw allow 22/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        if [[ "$custom_ssh" =~ ^[0-9]+$ ]]; then ufw allow "${custom_ssh}/tcp"; fi
        # --force avoids the interactive y/n prompt
        ufw --force enable
        echo -e "${GREEN}UFW enabled.${NC}"
        ufw status verbose
    elif command -v firewall-cmd >/dev/null 2>&1; then
        echo -e "${CYAN}Configuring firewalld...${NC}"
        systemctl enable --now firewalld 2>/dev/null
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        if [[ "$custom_ssh" =~ ^[0-9]+$ ]]; then firewall-cmd --permanent --add-port="${custom_ssh}/tcp"; fi
        firewall-cmd --reload
        echo -e "${GREEN}firewalld configured.${NC}"
        firewall-cmd --list-all
    else
        # Offer to install UFW via the detected package manager
        if [ "$PKG_MANAGER" = "unknown" ]; then
            echo -e "${RED}No firewall tool found and no known package manager to install one.${NC}"
            return 1
        fi
        read -rp "No firewall found. Install UFW now? (y/N): " inst
        if [[ "$inst" =~ ^[Yy]$ ]]; then
            eval "$PKG_UPDATE" >/dev/null 2>&1
            eval "$PKG_INSTALL ufw" && setup_firewall
        fi
    fi
}

# Install a set of commonly needed base packages
install_base_packages() {
    if [ "$PKG_MANAGER" = "unknown" ]; then
        echo -e "${RED}Error:${NC} Unsupported distro — no known package manager."
        return 1
    fi

    echo -e "${CYAN}Installing base packages:${NC} ${base_packages[*]}"
    eval "$PKG_UPDATE" >/dev/null 2>&1

    local failed=()
    for pkg in "${base_packages[@]}"; do
        printf "  %-18s " "$pkg"
        if eval "$PKG_INSTALL $pkg" >/dev/null 2>&1; then
            echo -e "${GREEN}ok${NC}"
        else
            echo -e "${RED}failed${NC}"
            failed+=("$pkg")
        fi
    done

    if [ ${#failed[@]} -eq 0 ]; then
        echo -e "${GREEN}All base packages installed.${NC}"
    else
        echo -e "${CYAN}Finished with some failures:${NC} ${failed[*]}"
        echo -e "(Some package names differ per distro; install those manually if needed.)"
    fi
}

# Full system update/upgrade via the detected package manager
full_system_update() {
    if [ "$PKG_MANAGER" = "unknown" ]; then
        echo -e "${RED}Error:${NC} Unsupported distro — no known package manager."
        return 1
    fi

    echo -e "${CYAN}Updating package lists...${NC}"
    eval "$PKG_UPDATE" || { echo -e "${RED}Update failed.${NC}"; return 1; }

    echo -e "${CYAN}Upgrading installed packages (this may take a while)...${NC}"
    if eval "$PKG_UPGRADE"; then
        echo -e "${GREEN}System upgrade complete.${NC}"
    else
        echo -e "${RED}Upgrade reported errors.${NC} Review the output above."
    fi
}

# ---- Server Setup submenu ----

server_setup_menu() {
    local items=("Set Timezone & NTP (Tehran)" "Create / Enable Swap" "Harden SSH" "Setup Firewall" "Install Base Packages" "Full System Update")
    while true; do
        echo
        echo -e "${CYAN}Server Setup:${NC}"
        for i in "${!items[@]}"; do echo "  $((i + 1))) ${items[$i]}"; done
        echo "  0) Back"
        echo
        read -rp "Select (0-${#items[@]}): " c
        case "$c" in
            1) set_timezone_tehran ;;
            2) setup_swap ;;
            3) harden_ssh ;;
            4) setup_firewall ;;
            5) install_base_packages ;;
            6) full_system_update ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}


# ---- Extra package registry setters (Composer, Go, NuGet, Maven) ----

# Generic selector: echoes the chosen "name|url" or empty on back/invalid.
# Usage: pick_registry "Title" options_array_name urls_assoc_name
pick_registry() {
    local title="$1"; local -n _opts="$2"; local -n _urls="$3"
    echo
    echo -e "${CYAN}${title} (applies for user: $TARGET_USER):${NC}" >&2
    local i
    for i in "${!_opts[@]}"; do
        echo "  $((i + 1))) ${_opts[$i]}  (${_urls[${_opts[$i]}]})" >&2
    done
    echo "  0) Back" >&2
    echo >&2
    local sel
    read -rp "Select (0-${#_opts[@]}): " sel
    if [[ "$sel" == "0" ]]; then return 1; fi
    if [[ ! "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#_opts[@]} )); then
        echo -e "${RED}Invalid option${NC}" >&2; return 1
    fi
    local name="${_opts[$((sel - 1))]}"
    echo "${name}|${_urls[$name]}"
}

# Composer (PHP): set or reset the global packagist repository
set_composer_mirror() {
    if ! command -v composer >/dev/null 2>&1; then
        echo -e "${CYAN}Composer is not installed.${NC}"
        return
    fi
    local picked name url
    picked=$(pick_registry "Select Composer mirror" composer_options composer_urls) || return
    name="${picked%%|*}"; url="${picked#*|}"

    if [ "$name" = "Reset to Official" ]; then
        run_as_user composer config -g --unset repos.packagist 2>/dev/null
        echo -e "${GREEN}Composer reset to official Packagist.${NC}"
    else
        run_as_user composer config -g repo.packagist composer "$url"
        echo -e "${GREEN}Composer mirror set to:${NC} $url"
    fi
}

# Go: set the GOPROXY environment / go env value
set_go_proxy() {
    if ! command -v go >/dev/null 2>&1; then
        echo -e "${CYAN}Go is not installed.${NC}"
        return
    fi
    local picked name url
    picked=$(pick_registry "Select Go module proxy (GOPROXY)" go_proxy_options go_proxy_urls) || return
    name="${picked%%|*}"; url="${picked#*|}"

    if [ "$name" = "Reset to Official" ]; then
        run_as_user go env -w GOPROXY="https://proxy.golang.org,direct"
        echo -e "${GREEN}GOPROXY reset to official.${NC}"
    else
        run_as_user go env -w GOPROXY="${url},direct"
        echo -e "${GREEN}GOPROXY set to:${NC} ${url},direct"
    fi
}

# NuGet (.NET): add/replace a package source named "iran-mirror"
set_nuget_mirror() {
    if ! command -v dotnet >/dev/null 2>&1; then
        echo -e "${CYAN}.NET SDK (dotnet) is not installed.${NC}"
        return
    fi
    local picked name url
    picked=$(pick_registry "Select NuGet mirror" nuget_options nuget_urls) || return
    name="${picked%%|*}"; url="${picked#*|}"

    local src_name="iran-mirror"
    # Remove any existing source with our name first (ignore errors)
    run_as_user dotnet nuget remove source "$src_name" >/dev/null 2>&1

    if [ "$name" = "Reset to Official" ]; then
        # Ensure the default nuget.org source is enabled
        run_as_user dotnet nuget enable source nuget.org >/dev/null 2>&1
        echo -e "${GREEN}NuGet reset — using official nuget.org.${NC}"
    else
        run_as_user dotnet nuget add source "$url" --name "$src_name"
        echo -e "${GREEN}NuGet source added:${NC} $url (name: $src_name)"
    fi
}

# Maven / Gradle: write a mirror into the user's ~/.m2/settings.xml
set_maven_mirror() {
    local picked name url
    picked=$(pick_registry "Select Maven mirror" maven_options maven_urls) || return
    name="${picked%%|*}"; url="${picked#*|}"

    local m2dir="$TARGET_HOME/.m2"
    local settings="$m2dir/settings.xml"
    [ -f "$settings" ] && cp "$settings" "${settings}.bak.$(date +%Y%m%d_%H%M%S)"

    if [ "$name" = "Reset to Official" ]; then
        # Write a settings.xml with no mirror (Maven then uses Maven Central)
        write_as_user "$settings" <<'EOF'
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
  <mirrors>
  </mirrors>
</settings>
EOF
        echo -e "${GREEN}Maven reset — using Maven Central.${NC}"
    else
        write_as_user "$settings" <<EOF
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
  <mirrors>
    <mirror>
      <id>iran-mirror</id>
      <name>Iran Maven Mirror</name>
      <url>${url}</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
</settings>
EOF
        echo -e "${GREEN}Maven mirror set to:${NC} $url"
        echo -e "${CYAN}(written to ${settings})${NC}"
    fi
}

# ---- Package Registries submenu (full set) ----

# registries_menu (full set), extra mirror functions, and main_menu are at the end of the file.

# ---- System package-manager mirrors for non-apt distros + GitHub proxy ----

# Point DNF/YUM (Fedora/Rocky/CentOS) at an Iranian mirror by rewriting baseurls
set_dnf_mirror() {
    if [ "$PKG_MANAGER" != "dnf" ] && [ "$PKG_MANAGER" != "yum" ]; then
        echo -e "${CYAN}DNF/YUM mirror switching only applies to Fedora/Rocky/CentOS systems.${NC}"
        return
    fi

    echo
    echo -e "${CYAN}Select DNF/YUM mirror:${NC}"
    for i in "${!dnf_mirror_options[@]}"; do
        name="${dnf_mirror_options[$i]}"
        echo "  $((i + 1))) $name  (${dnf_mirror_hosts[$name]})"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-${#dnf_mirror_options[@]}): " dnf_choice

    if [[ "$dnf_choice" == "0" ]]; then return; fi
    if [[ ! "$dnf_choice" =~ ^[0-9]+$ ]] || (( dnf_choice < 1 || dnf_choice > ${#dnf_mirror_options[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local name host
    name="${dnf_mirror_options[$((dnf_choice - 1))]}"
    host="${dnf_mirror_hosts[$name]}"

    local repodir="/etc/yum.repos.d"
    if [ ! -d "$repodir" ]; then
        echo -e "${RED}Error:${NC} $repodir not found."; return
    fi

    # Back up all repo files once
    local backup="/etc/yum.repos.d.bak.$(date +%Y%m%d_%H%M%S)"
    cp -r "$repodir" "$backup"
    echo -e "${CYAN}Backed up repo files to:${NC} $backup"

    if [ "$name" = "Reset to Official" ]; then
        echo -e "${CYAN}To fully reset, restore from a backup or reinstall the *-release package.${NC}"
        echo -e "${CYAN}Re-enabling mirrorlist is distro-specific; no automatic rewrite performed.${NC}"
        return
    fi

    # Best-effort: disable mirrorlist lines and repoint baseurl hosts to the mirror.
    sed -i -E 's|^([[:space:]]*)mirrorlist=|\1#mirrorlist=|' "$repodir"/*.repo 2>/dev/null
    sed -i -E "s|(baseurl=https?://)[^/]*|\1${host}|g" "$repodir"/*.repo 2>/dev/null

    echo -e "${GREEN}DNF/YUM baseurls repointed to:${NC} $host"
    echo -e "${CYAN}Refreshing metadata...${NC}"
    eval "$PKG_UPDATE" || echo -e "${RED}Warning:${NC} metadata refresh failed. Restore from $backup if needed."
}

# Prepend an Iranian Server line to the Pacman mirrorlist (Arch/Manjaro)
set_pacman_mirror() {
    if [ "$PKG_MANAGER" != "pacman" ]; then
        echo -e "${CYAN}Pacman mirror switching only applies to Arch/Manjaro systems.${NC}"
        return
    fi

    echo
    echo -e "${CYAN}Select Pacman mirror:${NC}"
    for i in "${!pacman_mirror_options[@]}"; do
        name="${pacman_mirror_options[$i]}"
        echo "  $((i + 1))) $name"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-${#pacman_mirror_options[@]}): " pac_choice

    if [[ "$pac_choice" == "0" ]]; then return; fi
    if [[ ! "$pac_choice" =~ ^[0-9]+$ ]] || (( pac_choice < 1 || pac_choice > ${#pacman_mirror_options[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local name url mirrorlist="/etc/pacman.d/mirrorlist"
    name="${pacman_mirror_options[$((pac_choice - 1))]}"
    url="${pacman_mirror_urls[$name]}"

    if [ ! -f "$mirrorlist" ]; then
        echo -e "${RED}Error:${NC} $mirrorlist not found."; return
    fi

    cp "$mirrorlist" "${mirrorlist}.bak.$(date +%Y%m%d_%H%M%S)"

    # Prepend the chosen Server line so it takes priority
    local tmp
    tmp=$(mktemp)
    {
        echo "# Added by Iranian Servers Toolkit on $(date)"
        echo "Server = $url"
        echo
        cat "$mirrorlist"
    } > "$tmp"
    mv "$tmp" "$mirrorlist"

    echo -e "${GREEN}Pacman mirror added:${NC} $url"
    echo -e "${CYAN}Refreshing databases...${NC}"
    pacman -Syy >/dev/null 2>&1 && echo -e "${GREEN}Done.${NC}" || echo -e "${RED}Warning:${NC} pacman -Syy failed."
}

# Route GitHub traffic through an Iranian proxy using git's insteadOf (reversible)
set_github_proxy() {
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${CYAN}git is not installed.${NC}"
        return
    fi

    echo
    echo -e "${CYAN}Select GitHub proxy (applies for user: $TARGET_USER):${NC}"
    for i in "${!github_proxy_options[@]}"; do
        name="${github_proxy_options[$i]}"
        echo "  $((i + 1))) $name  (${github_proxy_urls[$name]})"
    done
    echo "  0) Back"
    echo
    read -rp "Select (0-${#github_proxy_options[@]}): " gh_choice

    if [[ "$gh_choice" == "0" ]]; then return; fi
    if [[ ! "$gh_choice" =~ ^[0-9]+$ ]] || (( gh_choice < 1 || gh_choice > ${#github_proxy_options[@]} )); then
        echo -e "${RED}Invalid option${NC}"; return
    fi

    local name url
    name="${github_proxy_options[$((gh_choice - 1))]}"
    url="${github_proxy_urls[$name]}"

    if [ "$name" = "Reset to Official" ]; then
        # Remove any insteadOf rules we may have added for github.com
        run_as_user git config --global --unset-all url."https://github.com/".insteadOf 2>/dev/null
        run_as_user git config --global --remove-section url."https://scorpian.ir/https://github.com/" 2>/dev/null
        run_as_user git config --global --remove-section url."https://gitdl.theazizi.ir/https://github.com/" 2>/dev/null
        echo -e "${GREEN}GitHub proxy reset — using github.com directly.${NC}"
    else
        # Clear previous proxy sections first, then set the new one
        run_as_user git config --global --remove-section url."https://scorpian.ir/https://github.com/" 2>/dev/null
        run_as_user git config --global --remove-section url."https://gitdl.theazizi.ir/https://github.com/" 2>/dev/null
        run_as_user git config --global url."$url".insteadOf "https://github.com/"
        echo -e "${GREEN}GitHub proxy set to:${NC} $url"
        echo -e "${CYAN}(git clone https://github.com/... will now route through the proxy)${NC}"
    fi
}

# ---- Package Registries submenu (full set) ----

registries_menu() {
    local items=("Set APT Mirror" "Set DNF/YUM Mirror" "Set Pacman Mirror" "Set npm Registry" "Set pip (PyPI) Mirror" "Set Yarn Registry" "Set Composer Mirror" "Set Go Proxy (GOPROXY)" "Set NuGet Mirror" "Set Maven Mirror" "Set GitHub Proxy")
    while true; do
        echo
        echo -e "${CYAN}Package Registries:${NC}"
        for i in "${!items[@]}"; do echo "  $((i + 1))) ${items[$i]}"; done
        echo "  0) Back"
        echo
        read -rp "Select (0-${#items[@]}): " c
        case "$c" in
            1) set_apt_mirror ;;
            2) set_dnf_mirror ;;
            3) set_pacman_mirror ;;
            4) set_npm_registry ;;
            5) set_pip_mirror ;;
            6) set_yarn_registry ;;
            7) set_composer_mirror ;;
            8) set_go_proxy ;;
            9) set_nuget_mirror ;;
            10) set_maven_mirror ;;
            11) set_github_proxy ;;
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
        echo "  0) Exit"
        echo
        read -rp "Select an option (0-${#main_menu_items[@]}): " choice

        case "$choice" in
            1) show_status ;;
            2) dns_menu ;;
            3) docker_menu ;;
            4) registries_menu ;;
            5) server_setup_menu ;;
            6) diagnostics_menu ;;
            0)
                echo
                echo -e "${CYAN}Thanks for using the Iranian Servers Toolkit.${NC}"
                echo -e "${GREEN}Made with love by Amin Sepehri${NC} — https://github.com/aminrpg"
                echo -e "${CYAN}Goodbye!${NC}"
                exit 0
                ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    done
}

# Start the program
main_menu
