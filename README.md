<div align="center">

# 🇮🇷 Iranian Servers Toolkit

**A single, interactive Bash script that makes DNS switching and Docker setup painless on Iranian servers.**

Check your system status, change your DNS, install or update Docker, and point Docker at a fast Iranian registry mirror — all from one simple terminal menu, no manual config editing required.

**🌐 Languages:** English (this page) · [فارسی / Persian](./README.fa.md)

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

- 📊 **Status dashboard** — see your OS, package manager, current DNS, Docker version, and more at a glance. Any changed Docker proxy or package registry is highlighted so you instantly know what's been switched away from its default.
- 🌐 **One-key DNS switching** — jump between 12 popular resolvers (Shecan, Radar, Electro, Begzar, Google, Cloudflare, and more).
- 💾 **Automatic DNS backup** — every change saves a timestamped copy of `/etc/resolv.conf` first, so you can always roll back.
- ⏪ **Restore from backup** — browse your saved `resolv.conf` backups and roll back to any of them in one step.
- 🐧 **Multi-distro support** — auto-detects `apt`, `dnf`, `yum`, `pacman`, or `zypper`, so it runs beyond Debian/Ubuntu.
- 🐳 **One-command Docker install / update** — refreshes packages, installs prerequisites, and runs the official Docker script.
- 🪞 **Iranian Docker registry mirrors** — pull images through 15 local mirrors, with an unset option to remove them again.
- ⚡ **Auto-pick the fastest mirror** — benchmarks every mirror with `ping` and selects the lowest-latency one.
- 🩺 **Mirror health test** — checks your configured Docker mirror's latency, HTTP reachability, and a real test pull.
- ☸️ **containerd / Kubernetes mirror** — configure the containerd runtime (what k8s nodes, k3s, RKE2, CRI-O and Podman actually use) to pull through an Iranian/anti-sanctions mirror via `/etc/containerd/certs.d` — covering Docker Hub, `registry.k8s.io`, `gcr.io`, `quay.io` and more. `daemon.json` alone does not reach these.
- 🧩 **Docker Compose installer** — install or update the Compose plugin in one step.
- 📦 **Package registry mirrors** — point **APT, DNF/YUM, Pacman, npm, Yarn, pip, Composer, Go, NuGet, and Maven/Gradle** at fast Iranian mirrors (per-user configs land in the right home, not root's).
- 🐙 **GitHub proxy** — route `git clone`/fetch through an Iranian GitHub proxy when GitHub is slow or blocked (reversible, via git's `insteadOf`).
- 🧰 **Server setup toolkit** — one place for the chores every fresh Iranian VPS needs: Tehran timezone + Iranian NTP, swap file, SSH hardening, firewall, base packages, and a full system update.
- 🧪 **Connectivity doctor** — one check that probes Docker Hub, GitHub, npm, PyPI, and Google, flagging sanction-style `403` blocks.
- 📡 **DNS benchmark** — pings every resolver, tests which can resolve Docker Hub, and recommends the fastest working one.
- 🗂️ **Organized submenus** — tidy categories (DNS, Docker, Package Registries, Diagnostics) instead of one long list.
- 🔁 **Automatic service restart** — applies mirror config and restarts the Docker daemon automatically.
- 🛡️ **Safe by design** — refuses to run without root, validates every menu choice, and backs up each config before changing it.

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

> **Note:** The script must be run with root privileges (via `sudo`) because it edits system files (`/etc/resolv.conf`, `/etc/docker/daemon.json`, `/etc/apt/sources.list`) and restarts the Docker service. It will exit immediately if run as a normal user.
>
> Per-user tools (npm, Yarn, pip) are written to the **invoking user's** home — detected via `$SUDO_USER` — so configs don't end up owned by root in `/root`.

### Run it directly (one-liner)

If you just want to run it without keeping the repo around:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/aminrpg/iranian-servers-toolkit/master/start.sh)"
```

## 🧭 Menu Structure

The toolkit is organized into a main menu with category submenus:

```
===== Iranian Servers Toolkit =====
  1) Show Status
  2) DNS Tools
  3) Docker Tools
  4) Package Registries
  5) Server Setup
  6) Diagnostics
  0) Exit
```

> Choose **`0`** to exit. The script prints a short goodbye (toolkit name + author) and exits with status `0` (success).

### 1 · Show Status
A one-screen dashboard: OS, package manager, kernel, current DNS servers, number of DNS backups, and Docker version. It also reports the **Docker Proxy**, the **containerd mirror** (for Kubernetes nodes), and any **package registries** (npm, pip, Maven, Composer, Go, NuGet, GitHub proxy, and the system package manager) — anything changed from its default is flagged `CHANGED` in a highlight color, so you can see at a glance what's been switched. If nothing has been changed, it says so.

### 2 · DNS Tools

| Option | What it does |
|--------|--------------|
| **Set DNS** | Pick a provider; backs up and rewrites `/etc/resolv.conf`. |
| **Restore DNS Backup** | List saved `/etc/resolv.conf.bak.*` files (with timestamps) and restore any of them. |
| **DNS Benchmark** | Ping every resolver, test which can resolve `registry-1.docker.io`, and recommend the fastest. |

### 3 · Docker Tools

| Option | What it does |
|--------|--------------|
| **Install Docker** | Refreshes packages, installs `curl`, then installs Docker via `get.docker.com`. Skips if already present. |
| **Update Docker** | Re-runs the official installer to upgrade Docker. |
| **Set Docker Proxy** | Choose a registry mirror (or auto-select the fastest) and write `/etc/docker/daemon.json`, then restart Docker. |
| **Reset Docker Proxy** | Remove the mirror from `daemon.json` (backing it up first) and restart Docker. |
| **Set containerd / K8s Mirror** | Configure the **containerd** runtime (Kubernetes nodes, k3s, RKE2, CRI-O, Podman) via `/etc/containerd/certs.d`, enable `config_path`, and restart containerd. Pick the XODNS universal gateway (all registries via containerd's `_default` fallback), Docker Hub, or `registry.k8s.io`. |
| **Reset containerd / K8s Mirror** | Remove all mirror files under `/etc/containerd/certs.d` (backing up the tree first) and restart containerd. |
| **Test Mirror Health** | Report the configured mirror's latency, HTTP reachability, and a real `hello-world` test pull. |
| **Install Docker Compose** | Install or update the `docker-compose-plugin`. |

### 4 · Package Registries

| Option | What it does |
|--------|--------------|
| **Set APT Mirror** | Rewrite `sources.list` to an Iranian mirror (ArvanCloud, IranServer, Pardisco, Ubuntu IR archive), with backup. |
| **Set DNF/YUM Mirror** | Repoint Fedora/Rocky/CentOS repo `baseurl`s to an Iranian mirror (backs up `/etc/yum.repos.d` first). |
| **Set Pacman Mirror** | Prepend an Iranian `Server` line to Arch/Manjaro's `/etc/pacman.d/mirrorlist`, with backup. |
| **Set npm Registry** | Point npm at an Iranian registry (via `npm config` or `~/.npmrc`). |
| **Set pip (PyPI) Mirror** | Write `~/.config/pip/pip.conf` with an Iranian `index-url` + `trusted-host`. |
| **Set Yarn Registry** | Point Yarn at an Iranian registry (reuses the npm mirror list). |
| **Set Composer Mirror** | Point PHP/Composer's Packagist repo at an Iranian mirror (via `composer config -g`). |
| **Set Go Proxy (GOPROXY)** | Set `GOPROXY` to an Iranian module proxy via `go env -w` (keeps `,direct` fallback). |
| **Set NuGet Mirror** | Add a `.NET` package source named `iran-mirror` via `dotnet nuget add source`. |
| **Set Maven Mirror** | Write a `<mirror>` into `~/.m2/settings.xml` for Maven/Gradle, with backup. |
| **Set GitHub Proxy** | Route `git clone`/fetch through an Iranian GitHub proxy using git's `insteadOf` (fully reversible). |

### 5 · Server Setup

Common first-run chores for a fresh server. The riskier ones confirm before acting and back up every file they touch.

| Option | What it does |
|--------|--------------|
| **Set Timezone & NTP (Tehran)** | Set the timezone to `Asia/Tehran` and point time sync at Iranian NTP servers (`ntp.day.ir`, `ir.pool.ntp.org`). |
| **Create / Enable Swap** | Create a swap file of your chosen size, enable it, and persist it in `/etc/fstab` (backs up fstab first). |
| **Harden SSH** | Optionally change the SSH port, add a public key, and disable password auth — with a lockout warning, config test (`sshd -t`), and automatic backup/restore. |
| **Setup Firewall** | Configure UFW (Debian/Ubuntu) or firewalld (RHEL family) to allow SSH/HTTP/HTTPS and enable it; offers to install UFW if none is found. |
| **Install Base Packages** | Install common tools: `curl wget git vim htop unzip ca-certificates nano net-tools`. |
| **Full System Update** | Refresh package lists and upgrade all installed packages via the detected package manager. |

> ⚠️ **Harden SSH** and **Setup Firewall** change remote-access settings. Keep your current SSH session open and test a **new** connection before closing it — and open your new SSH port in the firewall before switching.

### 6 · Diagnostics

| Option | What it does |
|--------|--------------|
| **Connectivity Doctor** | Probe Docker Hub, GitHub, npm, PyPI, Google and `get.docker.com`; flag `403` sanction blocks vs. unreachable. |
| **DNS Benchmark** | Same resolver benchmark available under DNS Tools. |
| **Test Docker Mirror Health** | Same mirror health test available under Docker Tools. |

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
| XODNS | `85.208.255.182`, `85.208.255.71` |
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

## ☸️ containerd / Kubernetes Registry Mirror

Kubernetes nodes don't pull through the Docker daemon — they talk to **containerd** (or CRI-O / Podman) directly, so `/etc/docker/daemon.json` has no effect on `kubeadm`, k3s, RKE2, or `crictl` pulls. The **Set containerd / K8s Mirror** option (Docker Tools → 5) handles this by writing containerd's native `hosts.toml` under `/etc/containerd/certs.d`, enabling `config_path` in `/etc/containerd/config.toml`, and restarting containerd.

The menu is split into two groups. The first three are [XODNS](https://xodns.net) gateways that cover **all** registries (or the full Kubernetes registry); the rest are the Iranian Docker Hub mirrors (the same list used for the Docker daemon proxy), scoped to `docker.io`:

| Option | Mirror host | Upstream it serves |
|--------|-------------|--------------------|
| **XODNS Universal (all registries)** | `mirror.xodns.net` | `_default` — every registry at once (Docker Hub, `registry.k8s.io`, `gcr.io`, `quay.io`, `nvcr.io`, Helm…) via containerd's `?ns=` fallback |
| **XODNS Kubernetes** | `k8s-mirror.xodns.net` | `registry.k8s.io` |
| **XODNS Docker Hub** | `docker-mirror.xodns.net` | `docker.io` |
| **Iranian Docker Hub mirrors** | `docker.arvancloud.ir`, `focker.ir`, `mirrors.pardisco.co`, `docker.iranserver.com`, `mirror-docker.runflare.com`, and the rest of the registry-proxy list | `docker.io` only |

> **Why the split?** A containerd `hosts.toml` maps one upstream registry per file. Only a mirror that advertises multi-registry proxying can serve `registry.k8s.io`/`gcr.io`/`quay.io` — that's why those are scoped to the XODNS universal/K8s gateways. The Iranian Docker Hub mirrors are offered too, but only for `docker.io`; pointing them at `registry.k8s.io` would just fail.

The universal option writes a single `_default/hosts.toml` like this:

```toml
# /etc/containerd/certs.d/_default/hosts.toml
server = "https://_default"

[host."https://mirror.xodns.net"]
  capabilities = ["pull", "resolve"]
```

Verify a pull afterwards with:

```bash
crictl pull registry.k8s.io/pause:3.10
```

> **Reset containerd / K8s Mirror** removes everything under `/etc/containerd/certs.d` (backing up the whole tree first) and restarts containerd. XODNS mirror endpoints are sourced from [xodns.net](https://xodns.net); to add your own, edit the `containerd_mirror_*` arrays near the top of `start.sh`.
>
> XODNS DNS answers only **registered** IPs. If this is a cluster with a changing egress IP, keep it registered from your XODNS panel (they expose a `sync-ip` webhook you can run from cron or a CI step). That token is per-account and not stored by this toolkit.

## 📦 Supported Package Registry Mirrors

Available under **Package Registries**. Each writes a backup before changing anything, and each list includes a **Reset to Official** entry to revert.

| Tool | Mirrors offered | Config touched |
|------|-----------------|----------------|
| **APT** | ArvanCloud, IranServer, Pardisco, Ubuntu IR Archive | `/etc/apt/sources.list` (or `ubuntu.sources`) |
| **DNF/YUM** | ArvanCloud, IUT, Zero-One Cloud | `/etc/yum.repos.d/*.repo` |
| **Pacman** | ArvanCloud, IUT, Zero-One Cloud | `/etc/pacman.d/mirrorlist` |
| **npm** | Runflare, Kargadan | `npm config` / `~/.npmrc` |
| **Yarn** | Runflare, Kargadan | `yarn config` |
| **pip** | Runflare, Kargadan, ArvanCloud | `~/.config/pip/pip.conf` |
| **Composer** | Liara, Kargadan | `composer config -g` |
| **Go** | Liara, Kargadan | `go env -w GOPROXY` |
| **NuGet** | Kargadan, Pardisco | `dotnet nuget` source `iran-mirror` |
| **Maven/Gradle** | Myket, Kargadan | `~/.m2/settings.xml` |
| **GitHub** | IranGit, theazizi | git `url.<proxy>.insteadOf` (user config) |

> Mirror hostnames are sourced from the community-maintained [Mirava](https://github.com/MiravaOrg/Mirava) project. Each tool's option is skipped gracefully if its CLI (`composer`, `go`, `dotnet`, …) isn't installed, or if the system isn't the matching distro. If a mirror changes or a better one appears, edit the arrays near the top of `start.sh` (e.g. `apt_mirror_hosts`, `dnf_mirror_hosts`, `pacman_mirror_urls`, `github_proxy_urls`, …) — see [Contributing](./CONTRIBUTING.md).
>
> **Mirror URL paths** follow each provider's documented conventions; if a provider changes a sub-path, update the matching URL in the array.

## 🩺 Diagnostics

- **Connectivity Doctor** — issues a short-timeout `curl` to each key endpoint and classifies the result: `OK`, `reachable (401)`, `HTTP 403 (likely sanction block)`, or `unreachable / blocked`. A fast way to see *what* is blocked before changing anything.
- **DNS Benchmark** — pings each resolver's primary server and uses `nslookup`/`dig` to confirm it can resolve `registry-1.docker.io`, then recommends the fastest responsive one.
- **Test Mirror Health** — verifies the Docker mirror you already configured actually works end-to-end (latency + HTTP + a real pull).

## 🔧 How It Works

- **Distro detection** — on startup, `detect_distro()` reads `/etc/os-release` for the OS name and probes for `apt`, `dnf`, `yum`, `pacman`, or `zypper`, then wires the right update/install commands for that package manager.
- **Per-user configs** — `resolve_target_user()` reads `$SUDO_USER` so npm/Yarn/pip settings are written to the real user's home and `chown`ed back to them, not left root-owned.
- **Status dashboard** — `show_status()` reads the detected OS, parses `nameserver` lines from `/etc/resolv.conf`, counts backups, and queries the Docker version. It then inspects each config (`/etc/docker/daemon.json`, `~/.npmrc`, `~/.config/pip/pip.conf`, `~/.m2/settings.xml`, Composer/NuGet config, `go env GOPROXY`, git `insteadOf`, and the apt/dnf sources) and flags any that differ from their defaults as `CHANGED`.
- **Clean exit** — selecting `0` from the main menu prints the toolkit name and author, then exits with status `0` (success).
- **DNS** — `set_dns()` backs up `/etc/resolv.conf`, then writes new `nameserver` lines for the chosen provider (adding `options edns0 trust-ad` and preserving any `search` domains, except on reset).
- **Restore** — `restore_dns_backup()` lists every `/etc/resolv.conf.bak.*` (newest first, with timestamps) and copies the chosen one back — after backing up the current file so the restore is itself reversible.
- **Docker install/update** — refreshes package lists via the detected package manager, installs `curl`, and pipes the official `https://get.docker.com` script into `sh`. Installation is skipped if Docker is already detected.
- **Registry mirror** — writes `/etc/docker/daemon.json` and restarts the Docker daemon. The auto-select mode uses `ping` + `awk` to compare float latencies across all mirrors; the reset path uses `jq` when available (falling back to an empty config) and backs up `daemon.json` first.
- **containerd mirror** — `set_containerd_mirror()` writes a `hosts.toml` under `/etc/containerd/certs.d/<upstream>` (`_default` for the universal gateway), flips `config_path` to `/etc/containerd/certs.d` in `config.toml` if it's still empty, backs up any file it replaces, and restarts containerd. The reset backs up and clears the whole `certs.d` tree.
- **APT mirror** — `set_apt_mirror()` detects the classic `sources.list` or the newer deb822 `ubuntu.sources`, backs it up, and `sed`-rewrites known upstream hosts to the chosen Iranian mirror before running `apt-get update`.
- **Diagnostics** — the connectivity doctor and DNS benchmark are read-only (they change no config); they only probe endpoints and report.
- **Server setup** — timezone/NTP use `timedatectl` (with a symlink fallback), swap uses `fallocate` (falling back to `dd`) and persists via `/etc/fstab`, SSH hardening edits `sshd_config` behind a confirmation and validates with `sshd -t` before restarting, and firewall setup auto-selects UFW or firewalld. Every file touched is backed up first.

## ✅ Requirements

- A Linux distribution with one of these package managers: **apt** (Debian/Ubuntu), **dnf**/**yum** (Fedora/RHEL/CentOS), **pacman** (Arch), or **zypper** (openSUSE).
- `systemd` (`systemctl`) for the Docker service restart step.
- **Root** access (`sudo`).
- `curl`, `ping`, and `awk` available (the script installs `curl` automatically if missing).
- **Bash 4.3+** (for the registry selectors). Standard on all modern Linux servers.
- **Optional:** `jq` (cleaner Docker-proxy reset), `nslookup` or `dig` (DNS-benchmark resolution test), and the relevant CLI for each registry option (`npm`, `yarn`, `pip`, `composer`, `go`, `dotnet`, `mvn`). The script skips any option whose tool is missing.

> The official `get.docker.com` installer supports the major distros above. If you're on an unsupported distro, the script will tell you and skip the install rather than guess.

## 🩺 Troubleshooting

- **"Please run this script as root"** — rerun with `sudo ./start.sh`.
- **DNS change didn't stick** — some systems manage `/etc/resolv.conf` via `systemd-resolved` or NetworkManager and may overwrite it. Restore a backup from `/etc/resolv.conf.bak.*` if needed.
- **Docker won't restart after setting a mirror** — run `sudo systemctl restart docker` manually and check `sudo journalctl -u docker` for errors.
- **All mirrors time out in auto-select** — your network may be blocking ICMP (`ping`); pick a mirror manually instead.

## 🤝 Contributing

Contributions are very welcome — a new DNS resolver, a faster mirror, a bug fix, or a docs improvement. See the full guide in **[CONTRIBUTING.md](./CONTRIBUTING.md)** for how to add a provider or mirror, test your change, and open a pull request.

Quick version:

```bash
git checkout -b my-feature
# edit start.sh (arrays live near the top)
bash -n start.sh && shellcheck start.sh   # verify
git commit -am "Add YourProvider" && git push origin my-feature
```

Report bugs and request features via the [issue tracker](https://github.com/aminrpg/iranian-servers-toolkit/issues).

## 🙏 Acknowledgements

- Package-registry and APT mirror hostnames are drawn from the community-maintained [**Mirava**](https://github.com/MiravaOrg/Mirava) project — a curated list of Iranian package mirrors.
- Docker installation uses the official [get.docker.com](https://get.docker.com) convenience script.

## 📜 License

Released under the **MIT License** — free for personal and commercial use.
See [`LICENSE`](./LICENSE) for the full text.

## 👤 Author

Made with ❤️ by **Amin Sepehri**

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
