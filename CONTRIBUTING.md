# Contributing to Iranian Servers Toolkit

Contributions are very welcome — whether it's a new DNS resolver, a faster Docker mirror, a bug fix, or an improvement to the docs. Thanks for helping make the toolkit better.

> 🇮🇷 راهنمای مشارکت به فارسی: [CONTRIBUTING.fa.md](./CONTRIBUTING.fa.md)

## Ways to contribute

- Add a DNS provider, Docker registry mirror, or package-registry mirror.
- Fix a bug or improve error handling in [`start.sh`](./start.sh).
- Improve the documentation (English or Persian).
- Report a bug or request a feature via the [issue tracker](https://github.com/aminrpg/iranian-servers-toolkit/issues).

## 1. Fork & clone

```bash
# Fork the repo on GitHub first, then:
git clone https://github.com/<your-username>/iranian-servers-toolkit.git
cd iranian-servers-toolkit
git checkout -b my-feature
```

## 2. Make your change

The whole project is a single file: [`start.sh`](./start.sh). The most common contributions are adding a DNS provider or a mirror.

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

**Add a package registry mirror** — add a display name to the matching options list and its URL/host to the matching map, near the top of the script:

```bash
# APT (host only)
apt_mirror_options=( ... "YourMirror" "Reset to Official")
declare -A apt_mirror_hosts=( ... ["YourMirror"]="mirror.example.ir" )

# npm / Yarn (full URL)
npm_registry_options=( ... "YourMirror" "Reset to Official")
declare -A npm_registry_urls=( ... ["YourMirror"]="https://npm.example.ir/" )

# pip (full index URL ending in /simple)
pip_index_options=( ... "YourMirror" "Reset to Official")
declare -A pip_index_urls=( ... ["YourMirror"]="https://pypi.example.ir/simple" )
```

> Prefer mirrors hosted inside Iran and reachable without a VPN. A good source of candidates is the [Mirava](https://github.com/MiravaOrg/Mirava) list.

## 3. Test it

Before opening a PR, make sure the script still runs and your addition shows up and works:

```bash
# Check syntax (fast, no root needed)
bash -n start.sh

# Lint for shell issues (install via: apt-get install shellcheck)
shellcheck start.sh

# Run it and manually verify your new entry appears and applies correctly
sudo ./start.sh
```

Please confirm that:

- The script starts without syntax errors (`bash -n start.sh`).
- Your new entry appears in the right submenu and applies correctly.
- Any new entry has a matching key in **both** its options list and its map (e.g. `dns_options` + `dns_servers`, `apt_mirror_options` + `apt_mirror_hosts`).

## 4. Commit & open a Pull Request

```bash
git add start.sh
git commit -m "Add YourProvider DNS"
git push origin my-feature
```

Then open a Pull Request on GitHub with a short description of what you added and why (e.g. a link proving the mirror/resolver is publicly available and reliable).

## Contribution guidelines

- **Keep it POSIX-friendly Bash** and match the existing style (indentation, quoting, the `${COLOR}...${NC}` helpers).
- **One logical change per PR** so it's easy to review.
- **Only add resolvers/mirrors that are publicly operated and trustworthy** — this tool touches system DNS and Docker config, so reliability matters.
- **Report bugs & request features** via the [issue tracker](https://github.com/aminrpg/iranian-servers-toolkit/issues); include your OS, the menu option used, and any error output.

## Code of conduct

Be respectful and constructive. We're all here to make working on Iranian servers less painful.
