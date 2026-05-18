# Black-Tools

Black-Tools is an all-in-one, menu-driven Linux server administration toolkit. It bundles the most common sysadmin tasks — SSH hardening, user management, firewall control, port checks, service control, diagnostics, package updates, backups and more — behind a single interactive menu, so you can run a healthy server without memorizing commands.

Works on **Ubuntu, Debian, Mint, Pop!_OS, Kali, CentOS, RHEL, Rocky, AlmaLinux, Fedora, Arch, Manjaro, openSUSE, and Alpine** — the distro is auto-detected and the right package manager (`apt` / `dnf` / `yum` / `pacman` / `zypper` / `apk`) is used automatically.

## ⚡ One-Click Installation

Connect to your remote server and paste the following block into the terminal. It writes the entire toolkit into `/usr/local/bin/black-tools` and makes it executable:

```
cat << 'EOF' | sudo tee /usr/local/bin/black-tools > /dev/null
#!/usr/bin/env bash
# ... (paste the full black-tools.sh contents here) ...
EOF
sudo chmod +x /usr/local/bin/black-tools
```

> 💡 The full installer block is in [`install-black-tools.sh`](./install-black-tools.sh) — open it, copy everything, paste into your server's terminal in one go.

Alternative — one-liner directly from GitHub:

```
sudo curl -fsSL https://raw.githubusercontent.com/saeederamy/black-tools/main/black-tools.sh -o /usr/local/bin/black-tools && sudo chmod +x /usr/local/bin/black-tools
```

## 🛠️ Usage

After installation, run the tool from anywhere in your terminal:

```
black-tools
```

You'll get an interactive menu. **Example session:**

```
   ____  __    ___   ________ __    ______________  ____  __   _____
  / __ )/ /   /   | / ____/ //_/   /_  __/ __ \ __ \/ __ \/ /  / ___/
 / __  / /   / /| |/ /   / ,<       / / / / / / / / / / / / /   \__ \
/ /_/ / /___/ ___ / /___/ /| |     / / / /_/ / /_/ / /_/ / /______/ /
/_____/_____/_/  |_\____/_/ |_|    /_/  \____/\____/\____/_____/____/

  Linux Admin Toolkit v1.0.0
  Distro: ubuntu | Family: debian | PM: apt | User: root | Host: server01
────────────────────────────────────────────────────────────
» MAIN MENU
────────────────────────────────────────────────────────────
   1) System info
   2) Top processes
   3) Live monitor (htop/top)
   4) System diagnostics (auto-check)
   5) View logs
────────────────────────────────────────────────────────────
   6) SSH management
   7) User management (passwd/create/delete)
   8) Root password recovery guide
   9) Firewall
  10) Listening ports
  ...
black-tools >
```

Pick a number, and a focused sub-menu opens. All dangerous actions are confirmed first, all config files are backed up before edits, and every action is logged to `/var/log/black-tools.log`.

## ✨ Features

| Section | What's inside |
|---|---|
| **Monitoring** | System info, top processes, live `htop`/`top`, **auto-diagnostics** (CPU load, RAM, disk, inodes, failed services, OOM kills, DNS, kernel errors) |
| **Logs** | journalctl, auth log, dmesg, boot log, errors-only, live-follow |
| **SSH** | Change port (backup + syntax-test + auto firewall/SELinux update), enable/disable root login, add public keys, disable password auth |
| **Users** | List, create, delete, lock/unlock, change any user's password, **set/reset root password** |
| **Root Recovery** | Step-by-step guide for GRUB single-user mode, `systemd.unit=rescue.target`, and VPS rescue-console workflows |
| **Firewall** | Auto-detects `ufw` / `firewalld` / `iptables` — open / close ports, enable / disable |
| **Ports** | List all listeners, inspect a specific port (process + firewall rule) |
| **Processes** | Kill by PID / name / **port** (finds and kills whatever is using a port) / interactive search |
| **Services** | Full `systemd` control — start, stop, restart, enable, disable, status, logs |
| **Disk** | Usage, largest directories, largest files, cache cleanup, journal vacuum, `/tmp` cleanup, file search |
| **Network** | Interfaces, DNS, public IP, ping, traceroute |
| **Settings** | Hostname, timezone, DNS servers, swap on/off, create swap file |
| **Security** | Install Fail2ban, view failed logins, last logins, enable unattended-upgrades, key-only SSH |
| **Packages** | System update + upgrade, install, remove, search — across all major package managers |
| **Backups** | Quick `tar.gz` of any directory |

## 🛡️ Safety Notes

- Every action that edits a config file (especially `sshd_config`) creates a timestamped backup first.
- SSH changes are validated with `sshd -t` before restarting — if the config is broken, the backup is restored automatically.
- All actions are logged to `/var/log/black-tools.log` (or `~/.black-tools.log` if the user can't write to `/var/log`).
- Destructive actions ask for `y/N` confirmation before running.

## 🗑️ Uninstallation

To completely remove Black-Tools, run:

```
sudo rm /usr/local/bin/black-tools
```

Or from inside the menu, choose `88) Install black-tools globally` → it has an `--uninstall` flag too:

```
sudo black-tools --uninstall
```

## 📋 Requirements

- Bash 4+ (default on all supported distros)
- `sudo` access (or run as root)
- Standard utilities: `ss` or `netstat`, `systemctl` (for service management), the distro's native package manager

Optional but recommended: `htop`, `curl`, `bc` (auto-installable from inside the menu).

## ⚠️ Disclaimer

This tool changes system configuration. Always have a backup or a working console access (KVM / VPS rescue console) before making changes to SSH, firewall, or boot-related settings. The author is not responsible for misuse.

## 📜 License

MIT
