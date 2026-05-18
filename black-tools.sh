#!/usr/bin/env bash
# ============================================================================
#  black-tools  —  Interactive Linux Server Management Toolkit
#  Author: Built for use across major distros (Ubuntu/Debian/RHEL/Arch/...)
#  Usage:
#      Install :  bash <(curl -fsSL <RAW_URL>)        # or cat black-tools.sh | bash
#      Run     :  black-tools
# ============================================================================

set -o pipefail

# ----------------------------- Colors & UI -----------------------------------
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m';   C_BOLD=$'\033[1m';   C_DIM=$'\033[2m'
    C_RED=$'\033[0;31m';  C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'; C_MAGENTA=$'\033[0;35m'; C_CYAN=$'\033[0;36m'
    C_WHITE=$'\033[0;37m'; C_GRAY=$'\033[0;90m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''
    C_BLUE=''; C_MAGENTA=''; C_CYAN=''; C_WHITE=''; C_GRAY=''
fi

VERSION="1.0.0"
INSTALL_PATH="/usr/local/bin/black-tools"
LOG_FILE="/var/log/black-tools.log"
[[ ! -w "$(dirname "$LOG_FILE")" ]] && LOG_FILE="$HOME/.black-tools.log"

# ----------------------------- Logging ---------------------------------------
log() {
    local level="$1"; shift
    local msg="$*"
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

info()    { echo -e "${C_CYAN}[i]${C_RESET} $*"; log INFO "$*"; }
ok()      { echo -e "${C_GREEN}[✓]${C_RESET} $*"; log OK "$*"; }
warn()    { echo -e "${C_YELLOW}[!]${C_RESET} $*"; log WARN "$*"; }
err()     { echo -e "${C_RED}[✗]${C_RESET} $*" >&2; log ERROR "$*"; }
hr()      { echo -e "${C_GRAY}────────────────────────────────────────────────────────────${C_RESET}"; }

pause() {
    echo
    read -rp "$(echo -e "${C_DIM}Press Enter to continue...${C_RESET}")" _ || true
}

confirm() {
    local prompt="${1:-Are you sure?}"
    local ans
    read -rp "$(echo -e "${C_YELLOW}?${C_RESET} $prompt [y/N]: ")" ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# ----------------------------- Root / Sudo -----------------------------------
SUDO=""
require_root() {
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            SUDO="sudo"
        else
            err "This action needs root, and sudo is not installed."
            return 1
        fi
    fi
    return 0
}

# Run as root, prompting via sudo if needed
run_root() {
    require_root || return 1
    $SUDO "$@"
}

# ----------------------------- Distro Detect ---------------------------------
DISTRO=""        # ubuntu, debian, centos, rhel, rocky, almalinux, fedora, arch, manjaro, opensuse, alpine
DISTRO_FAMILY="" # debian, rhel, arch, suse, alpine
PKG_MGR=""       # apt, dnf, yum, pacman, zypper, apk
PKG_INSTALL=""
PKG_UPDATE=""
PKG_UPGRADE=""
PKG_REMOVE=""
PKG_SEARCH=""

detect_distro() {
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        DISTRO="${ID:-unknown}"
    elif command -v lsb_release &>/dev/null; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    else
        DISTRO="unknown"
    fi

    case "$DISTRO" in
        ubuntu|debian|raspbian|linuxmint|pop|kali)
            DISTRO_FAMILY="debian"
            PKG_MGR="apt"
            PKG_INSTALL="apt-get install -y"
            PKG_UPDATE="apt-get update"
            PKG_UPGRADE="apt-get upgrade -y"
            PKG_REMOVE="apt-get remove -y"
            PKG_SEARCH="apt-cache search"
            ;;
        centos|rhel|rocky|almalinux|ol)
            DISTRO_FAMILY="rhel"
            if command -v dnf &>/dev/null; then
                PKG_MGR="dnf"
                PKG_INSTALL="dnf install -y"
                PKG_UPDATE="dnf check-update"
                PKG_UPGRADE="dnf upgrade -y"
                PKG_REMOVE="dnf remove -y"
                PKG_SEARCH="dnf search"
            else
                PKG_MGR="yum"
                PKG_INSTALL="yum install -y"
                PKG_UPDATE="yum check-update"
                PKG_UPGRADE="yum update -y"
                PKG_REMOVE="yum remove -y"
                PKG_SEARCH="yum search"
            fi
            ;;
        fedora)
            DISTRO_FAMILY="rhel"
            PKG_MGR="dnf"
            PKG_INSTALL="dnf install -y"
            PKG_UPDATE="dnf check-update"
            PKG_UPGRADE="dnf upgrade -y"
            PKG_REMOVE="dnf remove -y"
            PKG_SEARCH="dnf search"
            ;;
        arch|manjaro|endeavouros)
            DISTRO_FAMILY="arch"
            PKG_MGR="pacman"
            PKG_INSTALL="pacman -S --noconfirm"
            PKG_UPDATE="pacman -Sy"
            PKG_UPGRADE="pacman -Syu --noconfirm"
            PKG_REMOVE="pacman -R --noconfirm"
            PKG_SEARCH="pacman -Ss"
            ;;
        opensuse*|sles|suse)
            DISTRO_FAMILY="suse"
            PKG_MGR="zypper"
            PKG_INSTALL="zypper install -y"
            PKG_UPDATE="zypper refresh"
            PKG_UPGRADE="zypper update -y"
            PKG_REMOVE="zypper remove -y"
            PKG_SEARCH="zypper search"
            ;;
        alpine)
            DISTRO_FAMILY="alpine"
            PKG_MGR="apk"
            PKG_INSTALL="apk add"
            PKG_UPDATE="apk update"
            PKG_UPGRADE="apk upgrade"
            PKG_REMOVE="apk del"
            PKG_SEARCH="apk search"
            ;;
        *)
            DISTRO_FAMILY="unknown"
            PKG_MGR="unknown"
            ;;
    esac
}

# Get package name for a given service across distros
pkgname() {
    local generic="$1"
    case "$generic:$DISTRO_FAMILY" in
        ssh:debian)   echo "openssh-server" ;;
        ssh:rhel)     echo "openssh-server" ;;
        ssh:arch)     echo "openssh" ;;
        ssh:suse)     echo "openssh" ;;
        ssh:alpine)   echo "openssh" ;;
        firewall:debian) echo "ufw" ;;
        firewall:rhel)   echo "firewalld" ;;
        firewall:arch)   echo "ufw" ;;
        firewall:suse)   echo "firewalld" ;;
        firewall:alpine) echo "iptables" ;;
        *) echo "$generic" ;;
    esac
}

# Get ssh service name
ssh_service() {
    case "$DISTRO_FAMILY" in
        debian) echo "ssh" ;;
        *)      echo "sshd" ;;
    esac
}

# ----------------------------- Header / Banner --------------------------------
banner() {
    clear
    echo -e "${C_RED}${C_BOLD}"
    cat <<'INNER_EOF'
   ____  __    ___   ________ __    ______________  ____  __   _____
  / __ )/ /   /   | / ____/ //_/   /_  __/ __ \ __ \/ __ \/ /  / ___/
 / __  / /   / /| |/ /   / ,<       / / / / / / / / / / / / /   \__ \
/ /_/ / /___/ ___ / /___/ /| |     / / / /_/ / /_/ / /_/ / /______/ /
/_____/_____/_/  |_\____/_/ |_|    /_/  \____/\____/\____/_____/____/
INNER_EOF
    echo -e "${C_RESET}"
    echo -e "  ${C_BOLD}Linux Admin Toolkit${C_RESET} ${C_DIM}v${VERSION}${C_RESET}"
    echo -e "  ${C_GRAY}Distro: ${C_WHITE}${DISTRO}${C_GRAY} | Family: ${C_WHITE}${DISTRO_FAMILY}${C_GRAY} | PM: ${C_WHITE}${PKG_MGR}${C_GRAY} | User: ${C_WHITE}$(whoami)${C_GRAY} | Host: ${C_WHITE}$(hostname)${C_RESET}"
    hr
}

# ============================================================================
#  SYSTEM INFO & MONITORING
# ============================================================================
show_system_info() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» System Information${C_RESET}"
    hr
    echo -e "${C_BOLD}OS:${C_RESET}        $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
    echo -e "${C_BOLD}Kernel:${C_RESET}    $(uname -r)"
    echo -e "${C_BOLD}Arch:${C_RESET}      $(uname -m)"
    echo -e "${C_BOLD}Hostname:${C_RESET}  $(hostname)"
    echo -e "${C_BOLD}Uptime:${C_RESET}    $(uptime -p 2>/dev/null || uptime)"
    echo -e "${C_BOLD}Load:${C_RESET}      $(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)"
    echo
    echo -e "${C_BOLD}CPU:${C_RESET}       $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)"
    echo -e "${C_BOLD}Cores:${C_RESET}     $(nproc 2>/dev/null)"
    echo
    echo -e "${C_BOLD}Memory:${C_RESET}"
    free -h 2>/dev/null | sed 's/^/  /'
    echo
    echo -e "${C_BOLD}Disk:${C_RESET}"
    df -hT -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | sed 's/^/  /'
    echo
    echo -e "${C_BOLD}Network:${C_RESET}"
    ip -brief addr 2>/dev/null | sed 's/^/  /' || ifconfig | grep -E 'inet |^[a-z]' | sed 's/^/  /'
    echo
    echo -e "${C_BOLD}Public IP:${C_RESET} $(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo 'N/A')"
    pause
}

show_top_processes() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Top Processes${C_RESET}"
    hr
    echo -e "${C_BOLD}Top 15 by CPU:${C_RESET}"
    ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -16
    echo
    echo -e "${C_BOLD}Top 15 by Memory:${C_RESET}"
    ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | head -16
    pause
}

live_monitor() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Live Monitor${C_RESET}"
    hr
    if command -v htop &>/dev/null; then
        htop
    elif command -v top &>/dev/null; then
        top
    else
        warn "Neither htop nor top found."
        if confirm "Install htop?"; then
            run_root $PKG_INSTALL htop && htop
        fi
    fi
}

# ============================================================================
#  PACKAGE / SYSTEM UPDATES
# ============================================================================
system_update() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» System Update & Upgrade${C_RESET}"
    hr
    info "Using package manager: $PKG_MGR"
    if ! confirm "Run full system update + upgrade now?"; then
        return
    fi
    info "Refreshing package lists..."
    run_root $PKG_UPDATE
    info "Upgrading installed packages..."
    run_root $PKG_UPGRADE
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        run_root apt-get autoremove -y
        run_root apt-get autoclean -y
    fi
    ok "System update complete."
    pause
}

install_package() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Install Package${C_RESET}"
    hr
    read -rp "Package name (space-separated for multiple): " pkgs
    [[ -z "$pkgs" ]] && { warn "Nothing entered."; pause; return; }
    run_root $PKG_INSTALL $pkgs
    pause
}

remove_package() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Remove Package${C_RESET}"
    hr
    read -rp "Package name to remove: " pkg
    [[ -z "$pkg" ]] && { warn "Nothing entered."; pause; return; }
    confirm "Remove $pkg?" || { pause; return; }
    run_root $PKG_REMOVE $pkg
    pause
}

search_package() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Search Package${C_RESET}"
    hr
    read -rp "Search term: " term
    [[ -z "$term" ]] && { pause; return; }
    $PKG_SEARCH "$term" | head -50
    pause
}

# ============================================================================
#  SSH MANAGEMENT
# ============================================================================
ssh_change_port() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Change SSH Port${C_RESET}"
    hr
    local current_port
    current_port=$(run_root grep -E '^\s*Port\s+' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
    [[ -z "$current_port" ]] && current_port="22 (default)"
    info "Current SSH port: $current_port"
    echo
    read -rp "New SSH port (1024-65535): " new_port
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
        err "Invalid port."
        pause; return
    fi
    if (( new_port < 1024 )); then
        warn "Port < 1024 is privileged. Continue?"
        confirm "Continue?" || { pause; return; }
    fi

    # Backup
    run_root cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"

    # Replace or add Port line
    if run_root grep -qE '^\s*#?\s*Port\s+' /etc/ssh/sshd_config; then
        run_root sed -i -E "s/^\s*#?\s*Port\s+.*/Port $new_port/" /etc/ssh/sshd_config
    else
        echo "Port $new_port" | run_root tee -a /etc/ssh/sshd_config >/dev/null
    fi

    # Open firewall (if active)
    if command -v ufw &>/dev/null && run_root ufw status 2>/dev/null | grep -q "Status: active"; then
        run_root ufw allow "$new_port"/tcp
        info "Allowed $new_port in UFW."
    elif command -v firewall-cmd &>/dev/null && run_root firewall-cmd --state &>/dev/null; then
        run_root firewall-cmd --permanent --add-port="$new_port"/tcp
        run_root firewall-cmd --reload
        info "Allowed $new_port in firewalld."
    fi

    # SELinux
    if command -v semanage &>/dev/null; then
        run_root semanage port -a -t ssh_port_t -p tcp "$new_port" 2>/dev/null || \
        run_root semanage port -m -t ssh_port_t -p tcp "$new_port" 2>/dev/null || true
        info "Updated SELinux SSH port context."
    fi

    # Test config
    if run_root sshd -t; then
        ok "sshd_config syntax OK."
        info "Restarting SSH service..."
        run_root systemctl restart "$(ssh_service)" || run_root service "$(ssh_service)" restart
        ok "SSH now listening on port $new_port"
        warn "Do NOT close your current session until you confirm the new port works!"
        warn "Test in a new terminal: ssh -p $new_port user@<host>"
    else
        err "sshd_config has errors. Restoring backup."
        run_root cp "$(ls -t /etc/ssh/sshd_config.bak.* | head -1)" /etc/ssh/sshd_config
    fi
    pause
}

ssh_enable_root_login() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Enable Root SSH Login${C_RESET}"
    hr
    warn "Allowing root SSH login is a security risk. Use key-based auth at minimum."
    confirm "Continue?" || { pause; return; }

    run_root cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"

    if run_root grep -qE '^\s*#?\s*PermitRootLogin\s+' /etc/ssh/sshd_config; then
        run_root sed -i -E 's/^\s*#?\s*PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin yes" | run_root tee -a /etc/ssh/sshd_config >/dev/null
    fi

    if run_root grep -qE '^\s*#?\s*PasswordAuthentication\s+' /etc/ssh/sshd_config; then
        if confirm "Also enable password authentication for root?"; then
            run_root sed -i -E 's/^\s*#?\s*PasswordAuthentication\s+.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        fi
    fi

    if run_root sshd -t; then
        run_root systemctl restart "$(ssh_service)" || run_root service "$(ssh_service)" restart
        ok "Root SSH login enabled and SSH restarted."
    else
        err "sshd_config has errors. Restoring backup."
        run_root cp "$(ls -t /etc/ssh/sshd_config.bak.* | head -1)" /etc/ssh/sshd_config
    fi
    pause
}

ssh_disable_root_login() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Disable Root SSH Login${C_RESET}"
    hr
    run_root cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"
    if run_root grep -qE '^\s*#?\s*PermitRootLogin\s+' /etc/ssh/sshd_config; then
        run_root sed -i -E 's/^\s*#?\s*PermitRootLogin\s+.*/PermitRootLogin no/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin no" | run_root tee -a /etc/ssh/sshd_config >/dev/null
    fi
    run_root sshd -t && run_root systemctl restart "$(ssh_service)"
    ok "Root SSH login disabled."
    pause
}

ssh_add_key() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Add SSH Public Key${C_RESET}"
    hr
    read -rp "Target user (leave empty for current user '$(whoami)'): " target_user
    target_user="${target_user:-$(whoami)}"

    if ! id "$target_user" &>/dev/null; then
        err "User $target_user does not exist."
        pause; return
    fi

    local home_dir
    home_dir=$(getent passwd "$target_user" | cut -d: -f6)
    local ssh_dir="$home_dir/.ssh"
    local auth_file="$ssh_dir/authorized_keys"

    echo "Paste the public key (single line, ssh-rsa/ssh-ed25519/...), then Enter:"
    read -r pubkey
    if [[ -z "$pubkey" || ! "$pubkey" =~ ^(ssh-|ecdsa-) ]]; then
        err "Invalid key format."
        pause; return
    fi

    run_root mkdir -p "$ssh_dir"
    run_root chmod 700 "$ssh_dir"
    echo "$pubkey" | run_root tee -a "$auth_file" >/dev/null
    run_root chmod 600 "$auth_file"
    run_root chown -R "$target_user:$target_user" "$ssh_dir"

    ok "Key added for $target_user."
    pause
}

ssh_view_config() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» SSH Config Summary${C_RESET}"
    hr
    run_root grep -E '^\s*(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AllowUsers|DenyUsers|MaxAuthTries|ClientAliveInterval)' /etc/ssh/sshd_config 2>/dev/null
    hr
    echo "Listening ports:"
    run_root ss -tlnp 2>/dev/null | grep -E 'sshd|:22\b' || true
    pause
}

ssh_menu() {
    while true; do
        banner
        echo -e "${C_BOLD}${C_MAGENTA}» SSH Management${C_RESET}"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} View current SSH config"
        echo -e "  ${C_CYAN}2)${C_RESET} Change SSH port"
        echo -e "  ${C_CYAN}3)${C_RESET} Enable root SSH login"
        echo -e "  ${C_CYAN}4)${C_RESET} Disable root SSH login"
        echo -e "  ${C_CYAN}5)${C_RESET} Add SSH public key"
        echo -e "  ${C_CYAN}6)${C_RESET} Restart SSH service"
        echo -e "  ${C_CYAN}7)${C_RESET} Show SSH logs (last 50)"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr
        read -rp "Choice: " c
        case "$c" in
            1) ssh_view_config ;;
            2) ssh_change_port ;;
            3) ssh_enable_root_login ;;
            4) ssh_disable_root_login ;;
            5) ssh_add_key ;;
            6) run_root systemctl restart "$(ssh_service)" && ok "SSH restarted." ; pause ;;
            7) run_root journalctl -u "$(ssh_service)" -n 50 --no-pager 2>/dev/null || run_root tail -50 /var/log/auth.log 2>/dev/null; pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  USER MANAGEMENT
# ============================================================================
change_user_password() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Change User Password${C_RESET}"
    hr
    read -rp "Username (default: root): " uname
    uname="${uname:-root}"
    if ! id "$uname" &>/dev/null; then
        err "User '$uname' does not exist."
        pause; return
    fi
    run_root passwd "$uname"
    pause
}

set_root_password() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Set / Reset Root Password${C_RESET}"
    hr
    warn "You'll be prompted for the new root password."
    run_root passwd root
    pause
}

create_user() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Create New User${C_RESET}"
    hr
    read -rp "Username: " uname
    [[ -z "$uname" ]] && { warn "No name."; pause; return; }
    if id "$uname" &>/dev/null; then
        err "User exists."
        pause; return
    fi
    case "$DISTRO_FAMILY" in
        debian|rhel|suse) run_root useradd -m -s /bin/bash "$uname" ;;
        arch)             run_root useradd -m -s /bin/bash "$uname" ;;
        alpine)           run_root adduser -s /bin/sh "$uname" ;;
        *)                run_root useradd -m "$uname" ;;
    esac
    info "Set password for $uname:"
    run_root passwd "$uname"
    if confirm "Grant sudo/wheel privileges?"; then
        case "$DISTRO_FAMILY" in
            debian)        run_root usermod -aG sudo "$uname" ;;
            rhel|arch|suse) run_root usermod -aG wheel "$uname" ;;
            alpine)        run_root addgroup "$uname" wheel ;;
        esac
        ok "User added to admin group."
    fi
    ok "User $uname created."
    pause
}

delete_user() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Delete User${C_RESET}"
    hr
    read -rp "Username to delete: " uname
    [[ -z "$uname" ]] && { pause; return; }
    confirm "Delete user '$uname' and their home directory?" || { pause; return; }
    if command -v userdel &>/dev/null; then
        run_root userdel -r "$uname"
    elif command -v deluser &>/dev/null; then
        run_root deluser --remove-home "$uname"
    fi
    ok "User deleted."
    pause
}

list_users() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» System Users (UID ≥ 1000)${C_RESET}"
    hr
    awk -F: '$3 >= 1000 && $3 < 65534 {printf "  %-20s UID:%-6s Shell:%s\n", $1, $3, $7}' /etc/passwd
    echo
    echo -e "${C_BOLD}Currently logged in:${C_RESET}"
    who
    pause
}

user_menu() {
    while true; do
        banner
        echo -e "${C_BOLD}${C_MAGENTA}» User Management${C_RESET}"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} List users"
        echo -e "  ${C_CYAN}2)${C_RESET} Create user"
        echo -e "  ${C_CYAN}3)${C_RESET} Delete user"
        echo -e "  ${C_CYAN}4)${C_RESET} Change a user's password"
        echo -e "  ${C_CYAN}5)${C_RESET} Set / reset root password"
        echo -e "  ${C_CYAN}6)${C_RESET} Lock a user account"
        echo -e "  ${C_CYAN}7)${C_RESET} Unlock a user account"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr
        read -rp "Choice: " c
        case "$c" in
            1) list_users ;;
            2) create_user ;;
            3) delete_user ;;
            4) change_user_password ;;
            5) set_root_password ;;
            6) read -rp "User to lock: " u; run_root passwd -l "$u" && ok "Locked." ; pause ;;
            7) read -rp "User to unlock: " u; run_root passwd -u "$u" && ok "Unlocked." ; pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  ROOT RECOVERY HELP
# ============================================================================
root_recovery_help() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Root Password Recovery (Console Access Required)${C_RESET}"
    hr
    cat <<'INNER_EOF'

This tool can only RESET a root password when you ALREADY have sudo or are root.
If you've lost root and have NO sudo user, you need PHYSICAL or VIRTUAL CONSOLE
access (KVM, IPMI, cloud console, or a bootable USB). Steps:

GRUB METHOD (most distros):
  1. Reboot the server and at the GRUB menu press 'e' on the default entry.
  2. Find the line starting with 'linux' (or 'linux16'/'linuxefi').
  3. At the end of that line, replace 'ro' with 'rw' and append:  init=/bin/bash
       (Optional: also add  single  for some distros)
  4. Press Ctrl-X (or F10) to boot.
  5. Once you have a root shell:
         mount -o remount,rw /
         passwd root
         exec /sbin/init        # or just reboot

SYSTEMD-RESCUE METHOD:
  Same as above but append:  systemd.unit=rescue.target

CLOUD VPS (no console):
  - Use the provider's "VNC console" / "rescue mode" / "recovery image".
  - Most providers (DigitalOcean, Hetzner, Linode, AWS Lightsail, Vultr,
    OVH, etc.) have a rescue-boot option in their control panel.
  - Boot the rescue image, mount your root partition, chroot in, run passwd.

ENCRYPTED DISK:
  You will need the LUKS passphrase. There is no bypass — that is by design.

INNER_EOF
    pause
}

# ============================================================================
#  PORT / NETWORK / FIREWALL
# ============================================================================
list_listening_ports() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Listening Ports${C_RESET}"
    hr
    if command -v ss &>/dev/null; then
        run_root ss -tulnp
    elif command -v netstat &>/dev/null; then
        run_root netstat -tulnp
    else
        warn "Neither ss nor netstat found."
    fi
    pause
}

port_status_check() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Check Specific Port${C_RESET}"
    hr
    read -rp "Port number: " p
    [[ -z "$p" ]] && { pause; return; }
    echo
    echo -e "${C_BOLD}Local listeners on port $p:${C_RESET}"
    if command -v ss &>/dev/null; then
        run_root ss -tulnp | grep -E "[:.]${p}\b" || echo "  (none)"
    else
        run_root netstat -tulnp 2>/dev/null | grep -E "[:.]${p}\b" || echo "  (none)"
    fi
    echo
    echo -e "${C_BOLD}Firewall status for port $p:${C_RESET}"
    if command -v ufw &>/dev/null && run_root ufw status &>/dev/null; then
        run_root ufw status | grep -E "\b${p}\b" || echo "  (no UFW rule)"
    fi
    if command -v firewall-cmd &>/dev/null && run_root firewall-cmd --state &>/dev/null; then
        run_root firewall-cmd --list-ports | tr ' ' '\n' | grep -E "^${p}/" || echo "  (no firewalld rule)"
    fi
    pause
}

firewall_menu() {
    while true; do
        banner
        echo -e "${C_BOLD}${C_MAGENTA}» Firewall${C_RESET}"
        hr
        # Detect active firewall
        local fw="none"
        if command -v ufw &>/dev/null && run_root ufw status 2>/dev/null | grep -q "Status: active"; then
            fw="ufw"
        elif command -v firewall-cmd &>/dev/null && run_root firewall-cmd --state 2>/dev/null | grep -q running; then
            fw="firewalld"
        elif command -v iptables &>/dev/null; then
            fw="iptables"
        fi
        info "Active firewall: $fw"
        echo
        echo -e "  ${C_CYAN}1)${C_RESET} Show current rules"
        echo -e "  ${C_CYAN}2)${C_RESET} Open a port"
        echo -e "  ${C_CYAN}3)${C_RESET} Close a port"
        echo -e "  ${C_CYAN}4)${C_RESET} Enable firewall"
        echo -e "  ${C_CYAN}5)${C_RESET} Disable firewall"
        echo -e "  ${C_CYAN}6)${C_RESET} Install UFW (Debian/Ubuntu/Arch)"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr
        read -rp "Choice: " c
        case "$c" in
            1)
                case "$fw" in
                    ufw)       run_root ufw status verbose ;;
                    firewalld) run_root firewall-cmd --list-all ;;
                    iptables)  run_root iptables -L -n -v ;;
                esac
                pause ;;
            2)
                read -rp "Port to open: " p
                read -rp "Protocol (tcp/udp, default tcp): " proto
                proto="${proto:-tcp}"
                case "$fw" in
                    ufw)       run_root ufw allow "$p/$proto" ;;
                    firewalld) run_root firewall-cmd --permanent --add-port="$p/$proto" && run_root firewall-cmd --reload ;;
                    iptables)  run_root iptables -A INPUT -p "$proto" --dport "$p" -j ACCEPT ;;
                esac
                pause ;;
            3)
                read -rp "Port to close: " p
                read -rp "Protocol (tcp/udp, default tcp): " proto
                proto="${proto:-tcp}"
                case "$fw" in
                    ufw)       run_root ufw delete allow "$p/$proto" ;;
                    firewalld) run_root firewall-cmd --permanent --remove-port="$p/$proto" && run_root firewall-cmd --reload ;;
                    iptables)  run_root iptables -D INPUT -p "$proto" --dport "$p" -j ACCEPT ;;
                esac
                pause ;;
            4)
                case "$DISTRO_FAMILY" in
                    debian|arch) command -v ufw &>/dev/null && run_root ufw enable || warn "UFW not installed." ;;
                    rhel|suse)   run_root systemctl enable --now firewalld ;;
                esac
                pause ;;
            5)
                case "$fw" in
                    ufw)       run_root ufw disable ;;
                    firewalld) run_root systemctl disable --now firewalld ;;
                esac
                pause ;;
            6) run_root $PKG_INSTALL ufw ; pause ;;
            0) return ;;
        esac
    done
}

network_info() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Network Info${C_RESET}"
    hr
    echo -e "${C_BOLD}Interfaces:${C_RESET}"
    ip -brief addr 2>/dev/null || ifconfig
    echo
    echo -e "${C_BOLD}Default route:${C_RESET}"
    ip route show default 2>/dev/null
    echo
    echo -e "${C_BOLD}DNS:${C_RESET}"
    grep -E '^nameserver' /etc/resolv.conf 2>/dev/null || true
    echo
    echo -e "${C_BOLD}Public IP:${C_RESET} $(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo 'N/A')"
    echo
    read -rp "Run a ping/traceroute test? Host (or empty to skip): " host
    if [[ -n "$host" ]]; then
        echo "--- ping ---"; ping -c 4 "$host"
        if command -v traceroute &>/dev/null; then
            echo "--- traceroute ---"; traceroute -n "$host"
        elif command -v tracepath &>/dev/null; then
            tracepath "$host"
        fi
    fi
    pause
}

# ============================================================================
#  PROCESS MANAGEMENT (KILL)
# ============================================================================
kill_process_menu() {
    banner
    echo -e "${C_BOLD}${C_MAGENTA}» Kill Process${C_RESET}"
    hr
    echo -e "  ${C_CYAN}1)${C_RESET} Kill by PID"
    echo -e "  ${C_CYAN}2)${C_RESET} Kill by name (killall)"
    echo -e "  ${C_CYAN}3)${C_RESET} Kill by port (find what's using a port)"
    echo -e "  ${C_CYAN}4)${C_RESET} Search & kill (interactive)"
    echo -e "  ${C_CYAN}0)${C_RESET} Back"
    hr
    read -rp "Choice: " c
    case "$c" in
        1)
            read -rp "PID: " pid
            read -rp "Signal (default 15=TERM, 9=KILL): " sig
            sig="${sig:-15}"
            run_root kill -"$sig" "$pid" && ok "Sent SIG$sig to PID $pid."
            pause ;;
        2)
            read -rp "Process name: " pname
            confirm "Kill all '$pname' processes?" && run_root pkill -f "$pname" && ok "Killed."
            pause ;;
        3)
            read -rp "Port: " p
            local pids
            pids=$(run_root ss -tlnp 2>/dev/null | grep ":$p " | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u)
            [[ -z "$pids" ]] && pids=$(run_root lsof -ti:"$p" 2>/dev/null)
            if [[ -z "$pids" ]]; then
                warn "No process found on port $p."
            else
                echo "PIDs using port $p: $pids"
                confirm "Kill them?" && run_root kill -9 $pids && ok "Killed."
            fi
            pause ;;
        4)
            read -rp "Search term: " term
            ps -eo pid,user,%cpu,%mem,comm,args | grep -i "$term" | grep -v grep | head -20
            echo
            read -rp "PID to kill (or empty to cancel): " pid
            [[ -n "$pid" ]] && run_root kill -9 "$pid" && ok "Killed PID $pid."
            pause ;;
    esac
}

# ============================================================================
#  SERVICE MANAGEMENT
# ============================================================================
service_menu() {
    while true; do
        banner
        echo -e "${C_BOLD}${C_MAGENTA}» Service Management (systemd)${C_RESET}"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} List running services"
        echo -e "  ${C_CYAN}2)${C_RESET} List failed services"
        echo -e "  ${C_CYAN}3)${C_RESET} Start a service"
        echo -e "  ${C_CYAN}4)${C_RESET} Stop a service"
        echo -e "  ${C_CYAN}5)${C_RESET} Restart a service"
        echo -e "  ${C_CYAN}6)${C_RESET} Enable on boot"
        echo -e "  ${C_CYAN}7)${C_RESET} Disable on boot"
        echo -e "  ${C_CYAN}8)${C_RESET} Service status"
        echo -e "  ${C_CYAN}9)${C_RESET} Service logs (journalctl)"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr
        read -rp "Choice: " c
        case "$c" in
            1) systemctl list-units --type=service --state=running | head -40; pause ;;
            2) systemctl --failed; pause ;;
            3) read -rp "Service name: " s; run_root systemctl start "$s" && ok "Started." ; pause ;;
            4) read -rp "Service name: " s; run_root systemctl stop "$s" && ok "Stopped." ; pause ;;
            5) read -rp "Service name: " s; run_root systemctl restart "$s" && ok "Restarted." ; pause ;;
            6) read -rp "Service name: " s; run_root systemctl enable "$s" && ok "Enabled." ; pause ;;
            7) read -rp "Service name: " s; run_root systemctl disable "$s" && ok "Disabled." ; pause ;;
            8) read -rp "Service name: " s; run_root systemctl status "$s" --no-pager ; pause ;;
            9) read -rp "Service name: " s; run_root journalctl -u "$s" -n 100 --no-pager ; pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  DISK / FILES
# ============================================================================
disk_menu() {
    while true; do
        banner
        echo -e "${C_BOLD}${C_MAGENTA}» Disk & Files${C_RESET}"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} Disk usage (df)"
        echo -e "  ${C_CYAN}2)${C_RESET} Largest directories under /"
        echo -e "  ${C_CYAN}3)${C_RESET} Largest files (top 30)"
        echo -e "  ${C_CYAN}4)${C_RESET} Clean apt/dnf cache"
        echo -e "  ${C_CYAN}5)${C_RESET} Clean systemd journal logs"
        echo -e "  ${C_CYAN}6)${C_RESET} Clean /tmp"
        echo -e "  ${C_CYAN}7)${C_RESET} Find files by name"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr
        read -rp "Choice: " c
        case "$c" in
            1) df -hT -x tmpfs -x devtmpfs -x squashfs ; pause ;;
            2)
                info "This may take a while..."
                run_root du -h --max-depth=2 / 2>/dev/null | sort -hr | head -20
                pause ;;
            3)
                read -rp "Search path (default /): " sp
                sp="${sp:-/}"
                run_root find "$sp" -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -30 | awk '{ printf "%10.2f MB  %s\n", $1/1024/1024, $2 }'
                pause ;;
            4)
                case "$DISTRO_FAMILY" in
                    debian) run_root apt-get clean ;;
                    rhel)   run_root $PKG_MGR clean all ;;
                    arch)   run_root pacman -Sc --noconfirm ;;
                    suse)   run_root zypper clean ;;
                esac
                ok "Cache cleaned."
                pause ;;
            5) run_root journalctl --vacuum-time=7d ; pause ;;
            6) run_root find /tmp -mindepth 1 -mtime +7 -delete 2>/dev/null ; ok "Cleaned old /tmp files." ; pause ;;
            7)
                read -rp "Filename pattern: " pat
                read -rp "Search path (default /): " sp
                sp="${sp:-/}"
                run_root find "$sp" -name "$pat" 2>/dev/null | head -50
                pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  DIAGNOSTICS / TROUBLESHOOTING
# ============================================================================
diagnostics() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» System Diagnostics${C_RESET}"
    hr
    local issues=0

    echo -e "${C_BOLD}● Load average:${C_RESET}"
    local load1; load1=$(cut -d' ' -f1 /proc/loadavg)
    local cores; cores=$(nproc)
    echo "  Load 1min: $load1, Cores: $cores"
    if (( $(echo "$load1 > $cores" | bc -l 2>/dev/null || echo 0) )); then
        warn "  Load exceeds CPU cores."
        issues=$((issues+1))
    fi

    echo
    echo -e "${C_BOLD}● Memory:${C_RESET}"
    local mem_used_pct; mem_used_pct=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
    echo "  Used: ${mem_used_pct}%"
    (( mem_used_pct > 90 )) && { warn "  Memory > 90% used."; issues=$((issues+1)); }

    echo
    echo -e "${C_BOLD}● Disk usage (warn at 85%):${C_RESET}"
    df -h -x tmpfs -x devtmpfs -x squashfs | awk 'NR>1 {gsub("%","",$5); if ($5 > 85) print "  WARN: " $0; else print "  OK:   " $0}'
    df -h -x tmpfs -x devtmpfs -x squashfs | awk 'NR>1 {gsub("%","",$5); if ($5 > 85) exit 1}' || issues=$((issues+1))

    echo
    echo -e "${C_BOLD}● Inodes:${C_RESET}"
    df -i -x tmpfs -x devtmpfs -x squashfs | awk 'NR>1 {gsub("%","",$5); if ($5 > 85) print "  WARN: " $0}'

    echo
    echo -e "${C_BOLD}● Failed services:${C_RESET}"
    local failed
    failed=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    echo "  Failed units: $failed"
    (( failed > 0 )) && { systemctl --failed --no-legend; issues=$((issues+1)); }

    echo
    echo -e "${C_BOLD}● Recent OOM kills:${C_RESET}"
    local ooms
    ooms=$(run_root dmesg 2>/dev/null | grep -ic "killed process" || echo 0)
    echo "  Count in dmesg: $ooms"
    (( ooms > 0 )) && { warn "  OOM killer has been triggered."; issues=$((issues+1)); }

    echo
    echo -e "${C_BOLD}● Network connectivity:${C_RESET}"
    if ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
        echo "  Internet (1.1.1.1):   OK"
    else
        warn "  Cannot reach 1.1.1.1"; issues=$((issues+1))
    fi
    if getent hosts google.com &>/dev/null; then
        echo "  DNS (google.com):    OK"
    else
        warn "  DNS resolution failing"; issues=$((issues+1))
    fi

    echo
    echo -e "${C_BOLD}● Recent kernel errors:${C_RESET}"
    run_root dmesg --level=err,crit,alert,emerg 2>/dev/null | tail -5 || true

    echo
    hr
    if (( issues == 0 )); then
        ok "No issues detected. System looks healthy."
    else
        warn "Found $issues potential issue(s) — review above."
    fi
    pause
}

view_logs() {
    while true; do
        banner
        echo -e "${C_BOLD}${C_MAGENTA}» View Logs${C_RESET}"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} Recent syslog/journal (last 100)"
        echo -e "  ${C_CYAN}2)${C_RESET} Auth log (logins, sudo)"
        echo -e "  ${C_CYAN}3)${C_RESET} Kernel messages (dmesg)"
        echo -e "  ${C_CYAN}4)${C_RESET} Boot log"
        echo -e "  ${C_CYAN}5)${C_RESET} Errors only (journalctl -p err)"
        echo -e "  ${C_CYAN}6)${C_RESET} Follow live (Ctrl+C to stop)"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr
        read -rp "Choice: " c
        case "$c" in
            1) run_root journalctl -n 100 --no-pager ; pause ;;
            2) run_root journalctl -u ssh -u sshd -u sudo -n 100 --no-pager 2>/dev/null || run_root tail -100 /var/log/auth.log 2>/dev/null ; pause ;;
            3) run_root dmesg | tail -50 ; pause ;;
            4) run_root journalctl -b --no-pager | tail -50 ; pause ;;
            5) run_root journalctl -p err -n 50 --no-pager ; pause ;;
            6) run_root journalctl -f ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  HOSTNAME / TIMEZONE
# ============================================================================
system_settings_menu() {
    while true; do
        banner
        echo -e "${C_BOLD}${C_MAGENTA}» System Settings${C_RESET}"
        hr
        echo -e "  Current hostname: ${C_WHITE}$(hostname)${C_RESET}"
        echo -e "  Current timezone: ${C_WHITE}$(timedatectl 2>/dev/null | grep 'Time zone' | awk '{print $3}' || cat /etc/timezone 2>/dev/null)${C_RESET}"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} Change hostname"
        echo -e "  ${C_CYAN}2)${C_RESET} Change timezone"
        echo -e "  ${C_CYAN}3)${C_RESET} Set DNS servers"
        echo -e "  ${C_CYAN}4)${C_RESET} Enable/disable swap"
        echo -e "  ${C_CYAN}5)${C_RESET} Create swap file"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr
        read -rp "Choice: " c
        case "$c" in
            1)
                read -rp "New hostname: " hn
                [[ -n "$hn" ]] && run_root hostnamectl set-hostname "$hn" && ok "Hostname set."
                pause ;;
            2)
                read -rp "Timezone (e.g. Asia/Tehran, UTC, America/New_York): " tz
                [[ -n "$tz" ]] && run_root timedatectl set-timezone "$tz" && ok "Timezone set."
                pause ;;
            3)
                read -rp "DNS server(s) space-separated (e.g. 1.1.1.1 8.8.8.8): " dnsv
                if [[ -n "$dnsv" ]]; then
                    run_root cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
                    : | run_root tee /etc/resolv.conf >/dev/null
                    for d in $dnsv; do
                        echo "nameserver $d" | run_root tee -a /etc/resolv.conf >/dev/null
                    done
                    ok "DNS updated."
                fi
                pause ;;
            4)
                if [[ $(swapon --show | wc -l) -gt 0 ]]; then
                    confirm "Swap is on. Turn off?" && run_root swapoff -a && ok "Swap off."
                else
                    confirm "Swap is off. Turn on?" && run_root swapon -a && ok "Swap on."
                fi
                pause ;;
            5)
                read -rp "Swap size (e.g. 2G, 4G): " sz
                if [[ -n "$sz" ]]; then
                    run_root fallocate -l "$sz" /swapfile && \
                    run_root chmod 600 /swapfile && \
                    run_root mkswap /swapfile && \
                    run_root swapon /swapfile && \
                    echo "/swapfile none swap sw 0 0" | run_root tee -a /etc/fstab >/dev/null && \
                    ok "Swap file of $sz created and enabled."
                fi
                pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  SECURITY HARDENING
# ============================================================================
security_menu() {
    while true; do
        banner
        echo -e "${C_BOLD}${C_MAGENTA}» Security${C_RESET}"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} Install & configure Fail2ban"
        echo -e "  ${C_CYAN}2)${C_RESET} Show failed login attempts"
        echo -e "  ${C_CYAN}3)${C_RESET} Show last logins (last command)"
        echo -e "  ${C_CYAN}4)${C_RESET} Audit open ports + processes"
        echo -e "  ${C_CYAN}5)${C_RESET} Run unattended-upgrades setup (Debian)"
        echo -e "  ${C_CYAN}6)${C_RESET} Disable SSH password auth (key-only)"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr
        read -rp "Choice: " c
        case "$c" in
            1)
                run_root $PKG_INSTALL fail2ban && \
                run_root systemctl enable --now fail2ban && \
                ok "Fail2ban installed and running."
                pause ;;
            2)
                run_root journalctl _COMM=sshd | grep -i 'failed\|invalid' | tail -30 2>/dev/null || \
                run_root grep -i 'failed\|invalid' /var/log/auth.log 2>/dev/null | tail -30
                pause ;;
            3) last -n 20 ; pause ;;
            4) run_root ss -tulnp ; pause ;;
            5)
                if [[ "$DISTRO_FAMILY" == "debian" ]]; then
                    run_root $PKG_INSTALL unattended-upgrades && \
                    run_root dpkg-reconfigure --priority=low unattended-upgrades
                else
                    warn "This option is Debian/Ubuntu only."
                fi
                pause ;;
            6)
                confirm "Make SURE you have working SSH keys first. Continue?" || { pause; return; }
                run_root cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"
                run_root sed -i -E 's/^\s*#?\s*PasswordAuthentication\s+.*/PasswordAuthentication no/' /etc/ssh/sshd_config
                grep -qE '^\s*PasswordAuthentication' /etc/ssh/sshd_config || echo "PasswordAuthentication no" | run_root tee -a /etc/ssh/sshd_config >/dev/null
                run_root sshd -t && run_root systemctl restart "$(ssh_service)" && ok "Password auth disabled."
                pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  BACKUP HELPER
# ============================================================================
backup_helper() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Quick Backup${C_RESET}"
    hr
    read -rp "Directory to back up: " src
    [[ ! -d "$src" ]] && { err "Not a directory."; pause; return; }
    read -rp "Destination directory (default /root/backups): " dst
    dst="${dst:-/root/backups}"
    run_root mkdir -p "$dst"
    local name; name="backup-$(basename "$src")-$(date +%Y%m%d-%H%M%S).tar.gz"
    info "Creating $dst/$name ..."
    run_root tar -czf "$dst/$name" -C "$(dirname "$src")" "$(basename "$src")"
    ok "Backup created: $dst/$name ($(run_root du -h "$dst/$name" | cut -f1))"
    pause
}

# ============================================================================
#  SELF-INSTALL / UPDATE
# ============================================================================
self_install() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Install black-tools as global command${C_RESET}"
    hr
    local src="${BASH_SOURCE[0]}"
    if [[ ! -f "$src" ]]; then
        err "Cannot find source script path."
        pause; return
    fi
    run_root cp "$src" "$INSTALL_PATH"
    run_root chmod +x "$INSTALL_PATH"
    ok "Installed to $INSTALL_PATH"
    info "Run anywhere with: ${C_BOLD}black-tools${C_RESET}"
    pause
}

self_uninstall() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» Uninstall${C_RESET}"
    hr
    confirm "Remove $INSTALL_PATH?" || { pause; return; }
    run_root rm -f "$INSTALL_PATH"
    ok "Removed."
    pause
}

show_about() {
    banner
    echo -e "${C_BOLD}${C_BLUE}» About black-tools${C_RESET}"
    hr
    cat <<INNER_EOF
  Version:  $VERSION
  Log file: $LOG_FILE
  Distro:   $DISTRO ($DISTRO_FAMILY)
  PkgMgr:   $PKG_MGR

  black-tools is an interactive admin toolkit covering common
  Linux server tasks without remembering commands:

    • System info, monitoring, diagnostics
    • SSH (port, root login, keys, password auth)
    • Users (create / delete / password / lock)
    • Root password reset (when you have sudo) + recovery guide
    • Firewall (ufw / firewalld / iptables)
    • Ports & processes (kill by PID / port / name)
    • Services (systemd start/stop/enable/logs)
    • Disk (usage, cleanup, find large files)
    • Network (IPs, DNS, ping/traceroute)
    • Security (fail2ban, audits, hardening)
    • System settings (hostname, timezone, swap)
    • System update / upgrade
    • Backups
INNER_EOF
    pause
}

# ============================================================================
#  MAIN MENU
# ============================================================================
main_menu() {
    while true; do
        banner
        echo -e "${C_BOLD}${C_GREEN}» MAIN MENU${C_RESET}"
        hr
        echo -e "  ${C_CYAN} 1)${C_RESET} System info"
        echo -e "  ${C_CYAN} 2)${C_RESET} Top processes"
        echo -e "  ${C_CYAN} 3)${C_RESET} Live monitor (htop/top)"
        echo -e "  ${C_CYAN} 4)${C_RESET} System diagnostics (auto-check)"
        echo -e "  ${C_CYAN} 5)${C_RESET} View logs"
        hr
        echo -e "  ${C_CYAN} 6)${C_RESET} SSH management"
        echo -e "  ${C_CYAN} 7)${C_RESET} User management (passwd/create/delete)"
        echo -e "  ${C_CYAN} 8)${C_RESET} Root password recovery guide"
        echo -e "  ${C_CYAN} 9)${C_RESET} Firewall"
        echo -e "  ${C_CYAN}10)${C_RESET} Listening ports"
        echo -e "  ${C_CYAN}11)${C_RESET} Check port status"
        echo -e "  ${C_CYAN}12)${C_RESET} Kill process"
        echo -e "  ${C_CYAN}13)${C_RESET} Service management (systemd)"
        hr
        echo -e "  ${C_CYAN}14)${C_RESET} Disk & files"
        echo -e "  ${C_CYAN}15)${C_RESET} Network info"
        echo -e "  ${C_CYAN}16)${C_RESET} System settings (hostname/tz/swap/DNS)"
        echo -e "  ${C_CYAN}17)${C_RESET} Security"
        echo -e "  ${C_CYAN}18)${C_RESET} Backup helper"
        hr
        echo -e "  ${C_CYAN}19)${C_RESET} System update & upgrade"
        echo -e "  ${C_CYAN}20)${C_RESET} Install package"
        echo -e "  ${C_CYAN}21)${C_RESET} Remove package"
        echo -e "  ${C_CYAN}22)${C_RESET} Search package"
        hr
        echo -e "  ${C_CYAN}88)${C_RESET} Install black-tools globally"
        echo -e "  ${C_CYAN}99)${C_RESET} About"
        echo -e "  ${C_RED} 0)${C_RESET} Exit"
        hr
        read -rp "$(echo -e "${C_BOLD}black-tools >${C_RESET} ")" c
        case "$c" in
            1)  show_system_info ;;
            2)  show_top_processes ;;
            3)  live_monitor ;;
            4)  diagnostics ;;
            5)  view_logs ;;
            6)  ssh_menu ;;
            7)  user_menu ;;
            8)  root_recovery_help ;;
            9)  firewall_menu ;;
            10) list_listening_ports ;;
            11) port_status_check ;;
            12) kill_process_menu ;;
            13) service_menu ;;
            14) disk_menu ;;
            15) network_info ;;
            16) system_settings_menu ;;
            17) security_menu ;;
            18) backup_helper ;;
            19) system_update ;;
            20) install_package ;;
            21) remove_package ;;
            22) search_package ;;
            88) self_install ;;
            99) show_about ;;
            0)  echo -e "${C_GREEN}Bye.${C_RESET}"; exit 0 ;;
            *)  warn "Invalid option."; sleep 1 ;;
        esac
    done
}

# ----------------------------- Entrypoint -----------------------------------
trap 'echo; echo -e "${C_RED}Interrupted.${C_RESET}"; exit 130' INT

# Handle CLI flags
case "${1:-}" in
    --install)
        detect_distro
        self_install
        exit 0
        ;;
    --uninstall)
        detect_distro
        self_uninstall
        exit 0
        ;;
    --version|-v)
        echo "black-tools v$VERSION"
        exit 0
        ;;
    --help|-h)
        cat <<INNER_EOF
black-tools v$VERSION — Linux admin toolkit

Usage:
    black-tools             Launch interactive menu
    black-tools --install   Install as /usr/local/bin/black-tools
    black-tools --uninstall Remove the installed copy
    black-tools --version   Print version
    black-tools --help      This help

One-liner install:
    bash <(curl -fsSL <raw-url>/black-tools.sh) --install
    # or:  cat black-tools.sh | sudo bash -s -- --install
INNER_EOF
        exit 0
        ;;
esac

detect_distro
if [[ "$DISTRO_FAMILY" == "unknown" ]]; then
    warn "Unknown distribution ($DISTRO). Some features may not work."
    sleep 1
fi

main_menu
