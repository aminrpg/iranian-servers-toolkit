<div align="center">

# 🇮🇷 Iranian Servers Toolkit

**A single, interactive Bash script that makes DNS switching and Docker setup painless on Iranian servers.**

Check your system status, change your DNS, install or update Docker, and point Docker at a fast Iranian registry mirror — all from one simple terminal menu, no manual config editing required.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux-blue.svg)
![Distros](https://img.shields.io/badge/distros-apt%20%7C%20dnf%20%7C%20yum%20%7C%20pacman%20%7C%20zypper-informational.svg)
![Language](https://img.shields.io/badge/made%20with-Bash-121011.svg?logo=gnu-bash&logoColor=white)
![Root](https://img.shields.io/badge/requires-root-red.svg)

</div>

---

## 📖 Why this tool?

Working with Docker on servers hosted in Iran is painful: Docker Hub is frequently unreachable, and `docker pull` either hangs or fails. The usual workarounds are to switch to a sanctions-friendly DNS resolver and/or point Docker at a local registry mirror — but doing that by hand means editing `/etc/resolv.conf` and `/etc/docker/daemon.json`, restarting services, and remembering a dozen IP addresses.

This script wraps all of that into one menu. Pick an option, and it handles the file edits, backups, and service restarts for you.

## ✨ Features

- 📊 **Status dashboard** — see your OS, package manager, current DNS, Docker version, and active registry mirror at a glance.
- 🌐 **One-key DNS switching** — jump between 12 popular resolvers (Shecan, Radar, Electro, Begzar, Google, Cloudflare, and more).
- 💾 **Automatic DNS backup** — every change saves a timestamped copy of `/etc/resolv.conf` first, so you can always roll back.
- ⏪ **Restore from backup** — browse your saved `resolv.conf` backups and roll back to any of them in one step.
- 🐧 **Multi-distro support** — auto-detects `apt`, `dnf`, `yum`, `pacman`, or `zypper`, so it runs beyond Debian/Ubuntu.
- 🐳 **One-command Docker install** — refreshes package lists, installs prerequisites, and runs the official Docker install script.
- ⬆️ **Docker updater** — pull the latest Docker Engine with a single menu option.
- 🪞 **Iranian registry mirrors** — configure Docker to pull images through 15 local mirrors (ArvanCloud, Liara, Haiocloud, Iranserver, and others).
- ⚡ **Auto-pick the fastest mirror** — benchmarks every mirror with `ping` and selects the lowest-latency one for you.
- 🔁 **Automatic service restart** — applies the mirror config and restarts the Docker daemon automatically.
- 🛡️ **Safe by design** — refuses to run without root, validates every menu choice, and never overwrites config without a backup.

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/aminrpg/iranian-servers-toolkit.git
cd iranian-servers-toolkit

# 2. Make the script executable
chmod +x start.sh

# 3. Run it as root
sudo ./start.sh
```

> **Note:** The script must be run with root privileges (via `sudo`) because it edits system files (`/etc/resolv.conf`, `/etc/docker/daemon.json`) and restarts the Docker service. It will exit immediately if run as a normal user.

### Run it directly (one-liner)

If you just want to run it without keeping the repo around:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/aminrpg/iranian-servers-toolkit/main/start.sh)"
```

## 🧭 Menu Options

When you launch the script, you'll see the main menu:

```
Main Menu:
  1) Show Status
  2) Set DNS
  3) Restore DNS Backup
  4) Install Docker
  5) Update Docker
  6) Set Docker Proxy
  7) Exit
```

| # | Option | What it does |
|---|--------|--------------|
| 1 | **Show Status** | Dashboard view: OS, package manager, kernel, current DNS, number of DNS backups, Docker version, and active registry mirror. |
| 2 | **Set DNS** | Pick a DNS provider; the script backs up and rewrites `/etc/resolv.conf`. |
| 3 | **Restore DNS Backup** | List saved `/etc/resolv.conf.bak.*` files (with timestamps) and restore any of them. |
| 4 | **Install Docker** | Refreshes packages, installs `curl`, then installs Docker via `get.docker.com`. Skips if Docker is already present. |
| 5 | **Update Docker** | Re-runs the official installer to upgrade Docker to the latest version. |
| 6 | **Set Docker Proxy** | Choose a registry mirror (or auto-select the fastest) and write `/etc/docker/daemon.json`, then restart Docker. |
| 7 | **Exit** | Quit the script. |

## 🌐 Supported DNS Providers

Iranian "smart" DNS resolvers unblock many developer services (Docker Hub, npm, Google, etc.). Choose any of the following from the **Set DNS** menu:

| Provider | Nameservers |
|----------|-------------|
| Shecan | `178.22.122.100`, `185.51.200.2` |
| Shecan Pro | `178.22.122.101`, `185.51.200.1` |
| Radar | `10.202.10.10`, `10.202.10.11` |
| Electro | `78.157.42.100`, `78.157.42.101` |
| Begzar | `185.55.226.26`, `185.55.226.25` |
| DNSPro | `87.107.110.109`, `87.107.110.110` |
| 403 | `10.202.10.202`, `10.202.10.102` |
| XCR9 | `85.208.255.182`, `85.208.255.71` |
| Bertina | `193.186.32.32` |
| DynX | `10.70.95.150`, `10.70.95.162` |
| Google | `8.8.8.8`, `8.8.4.4` |
| Cloudflare | `1.1.1.1`, `1.0.0.1` |
| **Reset to Default** | restores `127.0.0.53` (systemd-resolved) |

> Before each change, the current `/etc/resolv.conf` is copied to `/etc/resolv.conf.bak.YYYYMMDD_HHMMSS` so you can always restore it.

## 🪞 Supported Docker Registry Mirrors

When Docker Hub is slow or blocked, these Iranian mirrors proxy image pulls. Select one from the **Set Docker Proxy** menu, or let the script benchmark them all and pick the fastest:

| Mirror | Mirror |
|--------|--------|
| `docker.kernel.ir` | `hub.mecan.ir` |
| `focker.ir` | `docker.nrp.co` |
| `registry.docker.ir` | `docker-mirror.liara.ir` |
| `docker.arvancloud.ir` | `ghcr-mirror.liara.ir` |
| `docker.haiocloud.com` | `mirrors.pardisco.co` |
| `docker.iranserver.com` | `mirror2.chabokan.net` |
| `docker.mobinhost.com` | `docker.abrha.net` |
| | `mirror-docker.runflare.com` |

⚡ **Auto-select fastest proxy** — choose option `00` in the proxy menu. The script `ping`s every mirror three times, reports the latency of each, and configures the one with the lowest response time.

The selected mirror is written to `/etc/docker/daemon.json` like this:

```json
{
  "registry-mirrors": ["https://docker.arvancloud.ir"]
}
```

Docker is then restarted automatically with `systemctl restart docker` to apply the change.

## 🔧 How It Works

- **Distro detection** — on startup, `detect_distro()` reads `/etc/os-release` for the OS name and probes for `apt`, `dnf`, `yum`, `pacman`, or `zypper`, then wires the right update/install commands for that package manager.
- **Status dashboard** — `show_status()` reads the detected OS, parses `nameserver` lines from `/etc/resolv.conf`, counts backups, queries the Docker version, and extracts `registry-mirrors` from `/etc/docker/daemon.json`.
- **DNS** — `set_dns()` backs up `/etc/resolv.conf`, then writes new `nameserver` lines for the chosen provider (adding `options edns0 trust-ad` and preserving any `search` domains, except on reset).
- **Restore** — `restore_dns_backup()` lists every `/etc/resolv.conf.bak.*` (newest first, with timestamps) and copies the chosen one back — after backing up the current file so the restore is itself reversible.
- **Docker install/update** — refreshes package lists via the detected package manager, installs `curl`, and pipes the official `https://get.docker.com` script into `sh`. Installation is skipped if Docker is already detected.
- **Registry mirror** — writes `/etc/docker/daemon.json` and restarts the Docker daemon. The auto-select mode uses `ping` + `awk` to compare float latencies across all mirrors.

## ✅ Requirements

- A Linux distribution with one of these package managers: **apt** (Debian/Ubuntu), **dnf**/**yum** (Fedora/RHEL/CentOS), **pacman** (Arch), or **zypper** (openSUSE).
- `systemd` (`systemctl`) for the Docker service restart step.
- **Root** access (`sudo`).
- `curl`, `ping`, and `awk` available (the script installs `curl` automatically if missing).

> The official `get.docker.com` installer supports the major distros above. If you're on an unsupported distro, the script will tell you and skip the install rather than guess.

## 🩺 Troubleshooting

- **"Please run this script as root"** — rerun with `sudo ./start.sh`.
- **DNS change didn't stick** — some systems manage `/etc/resolv.conf` via `systemd-resolved` or NetworkManager and may overwrite it. Restore a backup from `/etc/resolv.conf.bak.*` if needed.
- **Docker won't restart after setting a mirror** — run `sudo systemctl restart docker` manually and check `sudo journalctl -u docker` for errors.
- **All mirrors time out in auto-select** — your network may be blocking ICMP (`ping`); pick a mirror manually instead.

## 🤝 Contributing

Contributions are very welcome — whether it's a new DNS resolver, a faster Docker mirror, a bug fix, or an improvement to the docs. Here's how to get started.

### 1. Fork & clone

```bash
# Fork the repo on GitHub first, then:
git clone https://github.com/<your-username>/iranian-servers-toolkit.git
cd iranian-servers-toolkit
git checkout -b my-feature
```

### 2. Make your change

The whole project is a single file: [`start.sh`](./start.sh). The most common contributions are adding a DNS provider or a registry mirror.

**Add a DNS provider** — add it to both the `dns_options` list and the `dns_servers` map:

```bash
# 1) Add the display name to the options list
dns_options=( ... "YourProvider" "Reset to Default")

# 2) Add its nameservers to the associative array
declare -A dns_servers=(
    ...
    ["YourProvider"]="1.2.3.4 5.6.7.8"
)
```

**Add a Docker registry mirror** — append the hostname (no `https://`) to the `registry_proxies` array:

```bash
registry_proxies=(
    ...
    "mirror.example.ir"
)
```

### 3. Test it

Before opening a PR, make sure the script still runs and your addition shows up and works:

```bash
# Lint for shell issues (install via: apt-get install shellcheck)
shellcheck start.sh

# Run it and manually verify your new entry appears and applies correctly
sudo ./start.sh
```

Please confirm that:
- The script starts without syntax errors.
- Your new DNS/mirror appears in the menu and applies correctly.
- A new DNS entry has a matching key in **both** `dns_options` and `dns_servers`.

### 4. Commit & open a Pull Request

```bash
git add start.sh
git commit -m "Add YourProvider DNS" 
git push origin my-feature
```

Then open a Pull Request on GitHub with a short description of what you added and why (e.g. a link proving the mirror/resolver is publicly available and reliable).

### Contribution guidelines

- **Keep it POSIX-friendly Bash** and match the existing style (indentation, quoting, the `${COLOR}...${NC}` helpers).
- **One logical change per PR** so it's easy to review.
- **Only add resolvers/mirrors that are publicly operated and trustworthy** — this tool touches system DNS and Docker config, so reliability matters.
- **Report bugs & request features** via the [issue tracker](https://github.com/aminrpg/iranian-servers-toolkit/issues); include your OS, the menu option used, and any error output.

## 📜 License

Released under the **MIT License** — free for personal and commercial use.
See [`LICENSE`](./LICENSE) for the full text.

## 👤 Author

Made with ❤️ by **Amin Sepehri**

- 🏢 Company: **Netramz**
- 📍 Location: Tehran, Iran
- 🌐 Website: [AminSepehri.com](http://AminSepehri.com)

## 📬 Contact

Questions, ideas, or just want to say hi? Reach out through any of these:

| Platform | Link |
|----------|------|
| 🐙 GitHub | [@aminrpg](https://github.com/aminrpg) |
| 🐦 X / Twitter | [@AMIN_RPG](https://twitter.com/AMIN_RPG) |
| 🌐 Website | [AminSepehri.com](http://AminSepehri.com) |

For bug reports and feature requests, please use the [GitHub issue tracker](https://github.com/aminrpg/iranian-servers-toolkit/issues).

---

<div align="center">

⭐ **If this tool saved you some headaches, consider starring the repo!** ⭐

</div>
