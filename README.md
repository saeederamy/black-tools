# Black-Tools

An interactive, menu-driven Linux server administration toolkit. No need to memorize commands — just pick a number.

Two editions:

| | black-tools | black-tools PRO |
|---|---|---|
| File | `black-tools.sh` | `install_pro.sh` |
| Command | `black-tools` | `black-tools-pro` |
| Focus | Core admin tasks | Advanced tools + software installer |

---

## ⚡ Quick Install — black-tools PRO

### Method 1 — Copy & Paste (no git, no download needed)

Open the raw link below, select all (`Ctrl+A`), copy (`Ctrl+C`), paste into your terminal and press Enter:

```
https://raw.githubusercontent.com/saeederamy/black-tools/main/install-pro.sh
```

### Method 2 — curl

```bash
curl -fsSL https://raw.githubusercontent.com/saeederamy/black-tools/main/install_pro.sh | sudo bash -s -- --install
```

### Method 3 — wget

```bash
wget -qO- https://raw.githubusercontent.com/saeederamy/black-tools/main/install_pro.sh | sudo bash -s -- --install
```

After installation, run from anywhere:

```bash
black-tools-pro
```

---

## ⚡ Quick Install — black-tools (base edition)

```bash
sudo curl -fsSL https://raw.githubusercontent.com/saeederamy/black-tools/main/black-tools.sh -o /usr/local/bin/black-tools && sudo chmod +x /usr/local/bin/black-tools
```

After installation:

```bash
black-tools
```

---

## ✨ Features — black-tools PRO

| Section | What's inside |
|---|---|
| **Monitoring** | System info, top processes, live htop/top, auto-diagnostics (CPU load, RAM, disk, failed services, OOM kills, DNS, kernel errors) |
| **Logs** | journalctl, auth log, dmesg, boot log, errors-only, live-follow |
| **SSH (Advanced)** | Change port, root login toggle, add authorized key, **generate SSH key pair** (Ed25519/RSA/ECDSA), view/remove keys, ssh-copy-id |
| **Users** | List, create, delete, lock/unlock, change password |
| **Firewall (Full)** | UFW / iptables / nftables / firewalld — open/close ports, block IPs, rate-limit, save/restore rules, safe defaults |
| **Advanced Network** | **Static IPv4/IPv6**, assign/remove IPs, change DNS, **IP Forwarding**, routing, network stats |
| **Cron Manager** | List, add (guided), remove, edit, view cron logs |
| **Temp Download Link** | Python HTTP server with auto-timeout and public URL |
| **tmux** | Create/attach/kill sessions, rename, keybindings reference |
| **Docker** | Containers, images, volumes, networks, Compose up/down/logs, prune, exec into container |
| **Software Installer** | Nginx, MySQL, MariaDB, PostgreSQL, MongoDB, Redis, Python, Node.js, Docker |
| **Custom Repos** | 3x-ui (paqctl), Madmail, StormDNS |
| **Services** | systemd — start, stop, restart, enable, disable, status, logs |
| **Disk** | Usage, largest files/dirs, cache cleanup, journal vacuum, /tmp cleanup, file search |
| **Security** | Fail2ban, failed login audit, last logins, unattended-upgrades, key-only SSH |
| **System Settings** | Hostname, timezone, swap on/off, create swap file |
| **Packages** | Update/upgrade, install, remove, search — all major package managers |
| **Backup** | Quick tar.gz of any directory |

---

## ✨ Features — black-tools (base edition)

| Section | What's inside |
|---|---|
| **Monitoring** | System info, top processes, live htop/top, auto-diagnostics |
| **Logs** | journalctl, auth log, dmesg, boot log, errors-only, live-follow |
| **SSH** | Change port, root login toggle, add authorized key, disable password auth |
| **Users** | List, create, delete, lock/unlock, change password |
| **Firewall** | UFW / firewalld / iptables — open/close ports, enable/disable |
| **Ports** | List all listeners, inspect a specific port |
| **Processes** | Kill by PID / name / port |
| **Services** | Full systemd control |
| **Disk** | Usage, cleanup, large file search |
| **Network** | Interfaces, DNS, public IP, ping, traceroute |
| **Settings** | Hostname, timezone, DNS, swap |
| **Security** | Fail2ban, auditing, hardening |
| **Packages** | Update/upgrade, install, remove, search |
| **Backup** | tar.gz of any directory |

---

## 🖥️ Supported Distros

Ubuntu · Debian · Mint · Pop!_OS · Kali · CentOS · RHEL · Rocky · AlmaLinux · Fedora · Arch · Manjaro · openSUSE · Alpine

The distro is auto-detected and the right package manager (`apt` / `dnf` / `yum` / `pacman` / `zypper` / `apk`) is used automatically.

---

## 🛡️ Safety Notes

- Every config edit (especially `sshd_config`) creates a timestamped backup first.
- SSH changes are validated with `sshd -t` before restarting — if the config is broken, the backup is restored automatically.
- All actions are logged to `/var/log/black-tools-pro.log` (or `~/.black-tools-pro.log` if `/var/log` is not writable).
- Destructive actions always ask for `y/N` confirmation before running.

---

## 🗑️ Uninstall

```bash
# PRO
sudo black-tools-pro --uninstall

# Base
sudo black-tools --uninstall
```

---

## 📋 Requirements

- Bash 4+
- `sudo` access or root
- Standard utilities: `ss` or `netstat`, `systemctl`, native package manager
- Optional: `htop`, `curl`, `python3` (required for the temp download link feature)

---

## ⚠️ Disclaimer

This tool modifies system configuration. Always ensure you have working console access (KVM / VPS rescue console) before changing SSH, firewall, or boot-related settings. The author is not responsible for misuse.

---

## 📜 License

MIT
