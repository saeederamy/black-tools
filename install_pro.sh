cat << 'EOF' | sudo tee /usr/local/bin/black-tools-pro > /dev/null
#!/usr/bin/env bash
# ============================================================================
#  black-tools PRO — Advanced Linux Server Management Toolkit
#  Version: 2.0.0-pro
#  Features: All black-tools + Network/Docker/Cron/tmux/Firewall/SSH-Keys/Installer
#
#  ── QUICK INSTALL ──────────────────────────────────────────────────────────
#
#  curl:
#    curl -fsSL https://raw.githubusercontent.com/saeederamy/black-tools/main/install_pro.sh | sudo bash -s -- --install
#
#  wget:
#    wget -qO- https://raw.githubusercontent.com/saeederamy/black-tools/main/install_pro.sh | sudo bash -s -- --install
#
#  اگه فایل رو دانلود کردی:
#    cat install_pro.sh | sudo bash -s -- --install
#
#  بعد از نصب، از هر جا اجرا کن:
#    black-tools-pro
#
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

VERSION="2.0.0-pro"
INSTALL_PATH="/usr/local/bin/black-tools-pro"
LOG_FILE="/var/log/black-tools-pro.log"
[[ ! -w "$(dirname "$LOG_FILE")" ]] && LOG_FILE="$HOME/.black-tools-pro.log"

# ----------------------------- Logging ---------------------------------------
log() { local level="$1"; shift; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE" 2>/dev/null || true; }
info()    { echo -e "${C_CYAN}[i]${C_RESET} $*"; log INFO "$*"; }
ok()      { echo -e "${C_GREEN}[✓]${C_RESET} $*"; log OK "$*"; }
warn()    { echo -e "${C_YELLOW}[!]${C_RESET} $*"; log WARN "$*"; }
err()     { echo -e "${C_RED}[✗]${C_RESET} $*" >&2; log ERROR "$*"; }
hr()      { echo -e "${C_GRAY}────────────────────────────────────────────────────────────${C_RESET}"; }

pause() { echo; read -rp "$(echo -e "${C_DIM}Press Enter to continue...${C_RESET}")" _ || true; }

confirm() {
    local ans
    read -rp "$(echo -e "${C_YELLOW}?${C_RESET} ${1:-Are you sure?} [y/N]: ")" ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# ----------------------------- Root / Sudo -----------------------------------
SUDO=""
require_root() {
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then SUDO="sudo"; else
            err "This action needs root, and sudo is not installed."; return 1; fi
    fi; return 0
}
run_root() { require_root || return 1; $SUDO "$@"; }

# ----------------------------- Distro Detect ---------------------------------
DISTRO="" DISTRO_FAMILY="" PKG_MGR="" PKG_INSTALL="" PKG_UPDATE="" PKG_UPGRADE="" PKG_REMOVE="" PKG_SEARCH=""

detect_distro() {
    if [[ -r /etc/os-release ]]; then . /etc/os-release; DISTRO="${ID:-unknown}"
    elif command -v lsb_release &>/dev/null; then DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    else DISTRO="unknown"; fi

    case "$DISTRO" in
        ubuntu|debian|raspbian|linuxmint|pop|kali)
            DISTRO_FAMILY="debian"; PKG_MGR="apt"
            PKG_INSTALL="apt-get install -y"; PKG_UPDATE="apt-get update"
            PKG_UPGRADE="apt-get upgrade -y"; PKG_REMOVE="apt-get remove -y"; PKG_SEARCH="apt-cache search" ;;
        centos|rhel|rocky|almalinux|ol)
            DISTRO_FAMILY="rhel"
            if command -v dnf &>/dev/null; then PKG_MGR="dnf"; PKG_INSTALL="dnf install -y"
                PKG_UPDATE="dnf check-update"; PKG_UPGRADE="dnf upgrade -y"
                PKG_REMOVE="dnf remove -y"; PKG_SEARCH="dnf search"
            else PKG_MGR="yum"; PKG_INSTALL="yum install -y"; PKG_UPDATE="yum check-update"
                PKG_UPGRADE="yum update -y"; PKG_REMOVE="yum remove -y"; PKG_SEARCH="yum search"; fi ;;
        fedora)
            DISTRO_FAMILY="rhel"; PKG_MGR="dnf"; PKG_INSTALL="dnf install -y"
            PKG_UPDATE="dnf check-update"; PKG_UPGRADE="dnf upgrade -y"
            PKG_REMOVE="dnf remove -y"; PKG_SEARCH="dnf search" ;;
        arch|manjaro|endeavouros)
            DISTRO_FAMILY="arch"; PKG_MGR="pacman"; PKG_INSTALL="pacman -S --noconfirm"
            PKG_UPDATE="pacman -Sy"; PKG_UPGRADE="pacman -Syu --noconfirm"
            PKG_REMOVE="pacman -R --noconfirm"; PKG_SEARCH="pacman -Ss" ;;
        opensuse*|sles|suse)
            DISTRO_FAMILY="suse"; PKG_MGR="zypper"; PKG_INSTALL="zypper install -y"
            PKG_UPDATE="zypper refresh"; PKG_UPGRADE="zypper update -y"
            PKG_REMOVE="zypper remove -y"; PKG_SEARCH="zypper search" ;;
        alpine)
            DISTRO_FAMILY="alpine"; PKG_MGR="apk"; PKG_INSTALL="apk add"
            PKG_UPDATE="apk update"; PKG_UPGRADE="apk upgrade"
            PKG_REMOVE="apk del"; PKG_SEARCH="apk search" ;;
        *) DISTRO_FAMILY="unknown"; PKG_MGR="unknown" ;;
    esac
}

pkgname() {
    local generic="$1"
    case "$generic:$DISTRO_FAMILY" in
        ssh:debian)   echo "openssh-server" ;; ssh:rhel) echo "openssh-server" ;;
        ssh:arch)     echo "openssh" ;;        ssh:suse) echo "openssh" ;;
        ssh:alpine)   echo "openssh" ;;
        firewall:debian) echo "ufw" ;; firewall:rhel) echo "firewalld" ;;
        firewall:arch)   echo "ufw" ;; firewall:suse) echo "firewalld" ;;
        firewall:alpine) echo "iptables" ;;
        *) echo "$generic" ;;
    esac
}

ssh_service() { case "$DISTRO_FAMILY" in debian) echo "ssh" ;; *) echo "sshd" ;; esac; }

# ----------------------------- Banner ----------------------------------------
banner() {
    clear
    echo -e "${C_RED}${C_BOLD}"
    cat <<'INNER_EOF'
  ____  __   ___   ________ __    ______________  ____  __   _____   ____  ____  ____
 / __ )/ /  /   | / ____/ //_/   /_  __/ __ \ __ \/ __ \/ /  / ___/  / __ \/ __ \/ __ \
/ __  / /  / /| |/ /   / ,<       / / / / / / / / / / / / /   \__ \  / /_/ / /_/ / / / /
/ /_/ / /__/ ___ / /___/ /| |     / / / /_/ / /_/ / /_/ / /______/ / / ____/ _, _/ /_/ /
/_____/_____/_/  |_\____/_/ |_|    /_/  \____/\____/\____/_____/____/ /_/   /_/ |_|\____/
INNER_EOF
    echo -e "${C_RESET}"
    echo -e "  ${C_BOLD}Linux Admin Toolkit PRO${C_RESET} ${C_DIM}v${VERSION}${C_RESET}"
    echo -e "  ${C_GRAY}Distro: ${C_WHITE}${DISTRO}${C_GRAY} | Family: ${C_WHITE}${DISTRO_FAMILY}${C_GRAY} | PM: ${C_WHITE}${PKG_MGR}${C_GRAY} | User: ${C_WHITE}$(whoami)${C_GRAY} | Host: ${C_WHITE}$(hostname)${C_RESET}"
    hr
}

# ============================================================================
#  SYSTEM INFO & MONITORING
# ============================================================================
show_system_info() {
    banner; echo -e "${C_BOLD}${C_BLUE}» System Information${C_RESET}"; hr
    echo -e "${C_BOLD}OS:${C_RESET}        $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
    echo -e "${C_BOLD}Kernel:${C_RESET}    $(uname -r)"
    echo -e "${C_BOLD}Arch:${C_RESET}      $(uname -m)"
    echo -e "${C_BOLD}Hostname:${C_RESET}  $(hostname)"
    echo -e "${C_BOLD}Uptime:${C_RESET}    $(uptime -p 2>/dev/null || uptime)"
    echo -e "${C_BOLD}Load:${C_RESET}      $(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)"
    echo
    echo -e "${C_BOLD}CPU:${C_RESET}       $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)"
    echo -e "${C_BOLD}Cores:${C_RESET}     $(nproc 2>/dev/null)"
    echo; echo -e "${C_BOLD}Memory:${C_RESET}"; free -h 2>/dev/null | sed 's/^/  /'
    echo; echo -e "${C_BOLD}Disk:${C_RESET}"; df -hT -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | sed 's/^/  /'
    echo; echo -e "${C_BOLD}Network:${C_RESET}"; ip -brief addr 2>/dev/null | sed 's/^/  /' || ifconfig | grep -E 'inet |^[a-z]' | sed 's/^/  /'
    echo; echo -e "${C_BOLD}Public IP:${C_RESET} $(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo 'N/A')"
    pause
}

show_top_processes() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Top Processes${C_RESET}"; hr
    echo -e "${C_BOLD}Top 15 by CPU:${C_RESET}"; ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -16
    echo; echo -e "${C_BOLD}Top 15 by Memory:${C_RESET}"; ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | head -16
    pause
}

live_monitor() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Live Monitor${C_RESET}"; hr
    if command -v htop &>/dev/null; then htop
    elif command -v top &>/dev/null; then top
    else warn "Neither htop nor top found."
        confirm "Install htop?" && run_root $PKG_INSTALL htop && htop; fi
}

# ============================================================================
#  PACKAGE / SYSTEM UPDATES
# ============================================================================
system_update() {
    banner; echo -e "${C_BOLD}${C_BLUE}» System Update & Upgrade${C_RESET}"; hr
    info "Using package manager: $PKG_MGR"
    confirm "Run full system update + upgrade now?" || return
    run_root $PKG_UPDATE; run_root $PKG_UPGRADE
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        run_root apt-get autoremove -y; run_root apt-get autoclean -y; fi
    ok "System update complete."; pause
}

install_package() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install Package${C_RESET}"; hr
    read -rp "Package name (space-separated): " pkgs
    [[ -z "$pkgs" ]] && { warn "Nothing entered."; pause; return; }
    run_root $PKG_INSTALL $pkgs; pause
}

remove_package() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Remove Package${C_RESET}"; hr
    read -rp "Package name to remove: " pkg
    [[ -z "$pkg" ]] && { warn "Nothing entered."; pause; return; }
    confirm "Remove $pkg?" || { pause; return; }
    run_root $PKG_REMOVE $pkg; pause
}

search_package() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Search Package${C_RESET}"; hr
    read -rp "Search term: " term; [[ -z "$term" ]] && { pause; return; }
    $PKG_SEARCH "$term" | head -50; pause
}

# ============================================================================
#  SSH MANAGEMENT (ENHANCED)
# ============================================================================
ssh_change_port() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Change SSH Port${C_RESET}"; hr
    local current_port; current_port=$(run_root grep -E '^\s*Port\s+' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
    [[ -z "$current_port" ]] && current_port="22 (default)"
    info "Current SSH port: $current_port"; echo
    read -rp "New SSH port (1024-65535): " new_port
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
        err "Invalid port."; pause; return; fi
    run_root cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"
    if run_root grep -qE '^\s*#?\s*Port\s+' /etc/ssh/sshd_config; then
        run_root sed -i -E "s/^\s*#?\s*Port\s+.*/Port $new_port/" /etc/ssh/sshd_config
    else echo "Port $new_port" | run_root tee -a /etc/ssh/sshd_config >/dev/null; fi
    if command -v ufw &>/dev/null && run_root ufw status 2>/dev/null | grep -q "Status: active"; then
        run_root ufw allow "$new_port"/tcp; fi
    if run_root sshd -t; then
        run_root systemctl restart "$(ssh_service)"
        ok "SSH now on port $new_port"; warn "Test in new terminal before closing this session!"
    else err "Config error, restoring backup."
        run_root cp "$(ls -t /etc/ssh/sshd_config.bak.* | head -1)" /etc/ssh/sshd_config; fi
    pause
}

ssh_enable_root_login() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Enable Root SSH Login${C_RESET}"; hr
    warn "Allowing root SSH login is a security risk."
    confirm "Continue?" || { pause; return; }
    run_root cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"
    if run_root grep -qE '^\s*#?\s*PermitRootLogin\s+' /etc/ssh/sshd_config; then
        run_root sed -i -E 's/^\s*#?\s*PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    else echo "PermitRootLogin yes" | run_root tee -a /etc/ssh/sshd_config >/dev/null; fi
    if run_root sshd -t; then
        run_root systemctl restart "$(ssh_service)" && ok "Root SSH login enabled."
    else err "Config error, restoring."; run_root cp "$(ls -t /etc/ssh/sshd_config.bak.* | head -1)" /etc/ssh/sshd_config; fi
    pause
}

ssh_disable_root_login() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Disable Root SSH Login${C_RESET}"; hr
    run_root cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"
    if run_root grep -qE '^\s*#?\s*PermitRootLogin\s+' /etc/ssh/sshd_config; then
        run_root sed -i -E 's/^\s*#?\s*PermitRootLogin\s+.*/PermitRootLogin no/' /etc/ssh/sshd_config
    else echo "PermitRootLogin no" | run_root tee -a /etc/ssh/sshd_config >/dev/null; fi
    run_root sshd -t && run_root systemctl restart "$(ssh_service)"
    ok "Root SSH login disabled."; pause
}

ssh_add_key() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Add SSH Public Key${C_RESET}"; hr
    read -rp "Target user (empty = current '$(whoami)'): " target_user
    target_user="${target_user:-$(whoami)}"
    if ! id "$target_user" &>/dev/null; then err "User not found."; pause; return; fi
    local home_dir; home_dir=$(getent passwd "$target_user" | cut -d: -f6)
    local auth_file="$home_dir/.ssh/authorized_keys"
    echo "Paste the public key (ssh-rsa / ssh-ed25519 / ...) then Enter:"
    read -r pubkey
    if [[ -z "$pubkey" || ! "$pubkey" =~ ^(ssh-|ecdsa-) ]]; then err "Invalid key."; pause; return; fi
    run_root mkdir -p "$home_dir/.ssh"; run_root chmod 700 "$home_dir/.ssh"
    echo "$pubkey" | run_root tee -a "$auth_file" >/dev/null
    run_root chmod 600 "$auth_file"; run_root chown -R "$target_user:$target_user" "$home_dir/.ssh"
    ok "Key added for $target_user."; pause
}

ssh_view_config() {
    banner; echo -e "${C_BOLD}${C_BLUE}» SSH Config Summary${C_RESET}"; hr
    run_root grep -E '^\s*(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AllowUsers|DenyUsers|MaxAuthTries|ClientAliveInterval)' /etc/ssh/sshd_config 2>/dev/null
    hr; echo "Listening ports:"; run_root ss -tlnp 2>/dev/null | grep -E 'sshd|:22\b' || true; pause
}

# NEW: SSH Key Generation
ssh_generate_key() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Generate SSH Key Pair${C_RESET}"; hr
    echo -e "  ${C_CYAN}1)${C_RESET} Ed25519 (recommended)"
    echo -e "  ${C_CYAN}2)${C_RESET} RSA 4096"
    echo -e "  ${C_CYAN}3)${C_RESET} ECDSA 521"
    read -rp "Key type [1-3]: " kt
    read -rp "Key file path (default: ~/.ssh/id_ed25519 or id_rsa): " kpath
    read -rp "Comment/label (e.g. user@host): " kcomment
    kcomment="${kcomment:-$(whoami)@$(hostname)}"
    local keytype="" defaultname=""
    case "$kt" in
        1|"") keytype="ed25519"; defaultname="$HOME/.ssh/id_ed25519" ;;
        2)    keytype="rsa";     defaultname="$HOME/.ssh/id_rsa"; extra_args="-b 4096" ;;
        3)    keytype="ecdsa";   defaultname="$HOME/.ssh/id_ecdsa"; extra_args="-b 521" ;;
        *)    err "Invalid."; pause; return ;;
    esac
    kpath="${kpath:-$defaultname}"
    mkdir -p "$(dirname "$kpath")"
    # shellcheck disable=SC2086
    ssh-keygen -t "$keytype" $extra_args -f "$kpath" -C "$kcomment"
    echo
    ok "Key pair generated: $kpath"
    echo -e "${C_BOLD}Public key:${C_RESET}"
    cat "${kpath}.pub"
    pause
}

ssh_show_keys() {
    banner; echo -e "${C_BOLD}${C_BLUE}» SSH Keys${C_RESET}"; hr
    echo -e "${C_BOLD}Your private keys (~/.ssh/):${C_RESET}"
    for f in "$HOME"/.ssh/id_*; do
        [[ "$f" == *.pub ]] && continue
        [[ -f "$f" ]] && echo "  Private: $f" && echo "  Public:  $(cat "${f}.pub" 2>/dev/null || echo 'no .pub found')" && echo
    done
    echo -e "${C_BOLD}Authorized keys:${C_RESET}"
    if [[ -f "$HOME/.ssh/authorized_keys" ]]; then
        nl -ba "$HOME/.ssh/authorized_keys"
    else echo "  (none)"; fi
    pause
}

ssh_remove_authorized_key() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Remove Authorized Key${C_RESET}"; hr
    if [[ ! -f "$HOME/.ssh/authorized_keys" ]]; then warn "No authorized_keys file."; pause; return; fi
    nl -ba "$HOME/.ssh/authorized_keys"
    echo; read -rp "Line number to remove: " lnum
    [[ ! "$lnum" =~ ^[0-9]+$ ]] && { err "Invalid number."; pause; return; }
    confirm "Remove line $lnum?" || { pause; return; }
    run_root sed -i "${lnum}d" "$HOME/.ssh/authorized_keys"
    ok "Line $lnum removed."; pause
}

ssh_copy_to_server() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Copy SSH Key to Remote Server${C_RESET}"; hr
    read -rp "Remote user@host (e.g. root@1.2.3.4): " remote
    read -rp "Key to copy (default: ~/.ssh/id_ed25519.pub): " keyf
    keyf="${keyf:-$HOME/.ssh/id_ed25519.pub}"
    [[ ! -f "$keyf" ]] && { err "Key file not found: $keyf"; pause; return; }
    ssh-copy-id -i "$keyf" "$remote"
    ok "Key copied."; pause
}

ssh_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» SSH Management${C_RESET}"; hr
        echo -e "  ${C_CYAN} 1)${C_RESET} View current SSH config"
        echo -e "  ${C_CYAN} 2)${C_RESET} Change SSH port"
        echo -e "  ${C_CYAN} 3)${C_RESET} Enable root SSH login"
        echo -e "  ${C_CYAN} 4)${C_RESET} Disable root SSH login"
        echo -e "  ${C_CYAN} 5)${C_RESET} Add SSH public key (authorized_keys)"
        echo -e "  ${C_CYAN} 6)${C_RESET} Restart SSH service"
        echo -e "  ${C_CYAN} 7)${C_RESET} Show SSH logs (last 50)"
        echo -e "  ${C_CYAN} 8)${C_RESET} Generate SSH key pair"
        echo -e "  ${C_CYAN} 9)${C_RESET} Show existing SSH keys"
        echo -e "  ${C_CYAN}10)${C_RESET} Remove authorized key"
        echo -e "  ${C_CYAN}11)${C_RESET} Copy key to remote server (ssh-copy-id)"
        echo -e "  ${C_CYAN} 0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1) ssh_view_config ;; 2) ssh_change_port ;; 3) ssh_enable_root_login ;;
            4) ssh_disable_root_login ;; 5) ssh_add_key ;;
            6) run_root systemctl restart "$(ssh_service)" && ok "SSH restarted."; pause ;;
            7) run_root journalctl -u "$(ssh_service)" -n 50 --no-pager 2>/dev/null || run_root tail -50 /var/log/auth.log 2>/dev/null; pause ;;
            8) ssh_generate_key ;; 9) ssh_show_keys ;; 10) ssh_remove_authorized_key ;; 11) ssh_copy_to_server ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  USER MANAGEMENT
# ============================================================================
change_user_password() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Change User Password${C_RESET}"; hr
    read -rp "Username (default: root): " uname; uname="${uname:-root}"
    if ! id "$uname" &>/dev/null; then err "User '$uname' does not exist."; pause; return; fi
    run_root passwd "$uname"; pause
}

create_user() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Create New User${C_RESET}"; hr
    read -rp "Username: " uname; [[ -z "$uname" ]] && { warn "No name."; pause; return; }
    id "$uname" &>/dev/null && { err "User exists."; pause; return; }
    case "$DISTRO_FAMILY" in
        debian|rhel|suse|arch) run_root useradd -m -s /bin/bash "$uname" ;;
        alpine) run_root adduser -s /bin/sh "$uname" ;;
        *) run_root useradd -m "$uname" ;;
    esac
    run_root passwd "$uname"
    if confirm "Grant sudo/wheel privileges?"; then
        case "$DISTRO_FAMILY" in
            debian) run_root usermod -aG sudo "$uname" ;;
            rhel|arch|suse) run_root usermod -aG wheel "$uname" ;;
            alpine) run_root addgroup "$uname" wheel ;;
        esac; ok "User added to admin group."; fi
    ok "User $uname created."; pause
}

delete_user() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Delete User${C_RESET}"; hr
    read -rp "Username to delete: " uname; [[ -z "$uname" ]] && { pause; return; }
    confirm "Delete '$uname' and home directory?" || { pause; return; }
    if command -v userdel &>/dev/null; then run_root userdel -r "$uname"
    elif command -v deluser &>/dev/null; then run_root deluser --remove-home "$uname"; fi
    ok "User deleted."; pause
}

list_users() {
    banner; echo -e "${C_BOLD}${C_BLUE}» System Users (UID ≥ 1000)${C_RESET}"; hr
    awk -F: '$3 >= 1000 && $3 < 65534 {printf "  %-20s UID:%-6s Shell:%s\n", $1, $3, $7}' /etc/passwd
    echo; echo -e "${C_BOLD}Currently logged in:${C_RESET}"; who; pause
}

user_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» User Management${C_RESET}"; hr
        echo -e "  ${C_CYAN}1)${C_RESET} List users"
        echo -e "  ${C_CYAN}2)${C_RESET} Create user"
        echo -e "  ${C_CYAN}3)${C_RESET} Delete user"
        echo -e "  ${C_CYAN}4)${C_RESET} Change user password"
        echo -e "  ${C_CYAN}5)${C_RESET} Set / reset root password"
        echo -e "  ${C_CYAN}6)${C_RESET} Lock a user account"
        echo -e "  ${C_CYAN}7)${C_RESET} Unlock a user account"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1) list_users ;; 2) create_user ;; 3) delete_user ;; 4) change_user_password ;;
            5) run_root passwd root; pause ;;
            6) read -rp "User to lock: " u; run_root passwd -l "$u" && ok "Locked."; pause ;;
            7) read -rp "User to unlock: " u; run_root passwd -u "$u" && ok "Unlocked."; pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  ADVANCED NETWORK MANAGEMENT
# ============================================================================
net_show_interfaces() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Network Interfaces${C_RESET}"; hr
    echo -e "${C_BOLD}Interfaces (brief):${C_RESET}"; ip -brief addr 2>/dev/null
    echo; echo -e "${C_BOLD}Detailed:${C_RESET}"; ip addr show
    echo; echo -e "${C_BOLD}Default routes:${C_RESET}"; ip route show
    echo; echo -e "${C_BOLD}DNS servers:${C_RESET}"; grep -E '^nameserver' /etc/resolv.conf 2>/dev/null
    echo; echo -e "${C_BOLD}Public IP:${C_RESET} $(curl -s --max-time 4 ifconfig.me 2>/dev/null || echo N/A)"
    pause
}

net_assign_ipv4() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Assign IPv4 Address${C_RESET}"; hr
    echo "Available interfaces:"; ip -brief addr | awk '{print "  " $1}'
    echo; read -rp "Interface (e.g. eth0, ens3): " iface
    [[ -z "$iface" ]] && { warn "No interface."; pause; return; }
    read -rp "IPv4 address with prefix (e.g. 192.168.1.100/24): " addr
    [[ -z "$addr" ]] && { warn "No address."; pause; return; }
    run_root ip addr add "$addr" dev "$iface"
    ok "Added $addr to $iface (temporary, lost on reboot)"
    echo
    if confirm "Make it persistent (write to config)?"; then
        net_persist_ip "$iface" "$addr" "4"
    fi
    pause
}

net_assign_ipv6() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Assign IPv6 Address${C_RESET}"; hr
    echo "Available interfaces:"; ip -brief addr | awk '{print "  " $1}'
    echo; read -rp "Interface (e.g. eth0, ens3): " iface
    [[ -z "$iface" ]] && { warn "No interface."; pause; return; }
    read -rp "IPv6 address with prefix (e.g. 2001:db8::1/64): " addr
    [[ -z "$addr" ]] && { warn "No address."; pause; return; }
    run_root ip -6 addr add "$addr" dev "$iface"
    ok "Added IPv6 $addr to $iface (temporary, lost on reboot)"
    echo
    if confirm "Make it persistent?"; then
        net_persist_ip "$iface" "$addr" "6"
    fi
    pause
}

net_set_static_ip() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Set Static IPv4 Address (Persistent)${C_RESET}"; hr
    echo "Available interfaces:"; ip -brief addr | awk '{print "  " $1}'
    echo; read -rp "Interface: " iface
    [[ -z "$iface" ]] && { warn "No interface."; pause; return; }
    read -rp "Static IP with prefix (e.g. 192.168.1.50/24): " addr
    read -rp "Gateway (e.g. 192.168.1.1): " gw
    read -rp "DNS servers space-separated (e.g. 1.1.1.1 8.8.8.8): " dns_servers
    [[ -z "$addr" ]] && { warn "No address."; pause; return; }
    net_persist_ip "$iface" "$addr" "4" "$gw" "$dns_servers"
    pause
}

net_persist_ip() {
    local iface="$1" addr="$2" ver="$3" gw="${4:-}" dns_servers="${5:-}"
    if command -v nmcli &>/dev/null && nmcli device status &>/dev/null 2>&1; then
        info "Applying via NetworkManager (nmcli)..."
        local con_name; con_name=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep ":$iface$" | cut -d: -f1 | head -1)
        con_name="${con_name:-$iface}"
        if [[ "$ver" == "4" ]]; then
            run_root nmcli con mod "$con_name" ipv4.addresses "$addr" ipv4.method manual
            [[ -n "$gw" ]] && run_root nmcli con mod "$con_name" ipv4.gateway "$gw"
            [[ -n "$dns_servers" ]] && run_root nmcli con mod "$con_name" ipv4.dns "${dns_servers// /,}"
        else
            run_root nmcli con mod "$con_name" ipv6.addresses "$addr" ipv6.method manual
        fi
        run_root nmcli con up "$con_name"
        ok "Applied via NetworkManager."
    elif ls /etc/netplan/*.yaml &>/dev/null 2>&1; then
        info "Applying via netplan..."
        local np_file="/etc/netplan/99-black-tools.yaml"
        local ip_only; ip_only=$(echo "$addr" | cut -d/ -f1)
        local prefix; prefix=$(echo "$addr" | cut -d/ -f2)
        if [[ "$ver" == "4" ]]; then
            cat > /tmp/btp_netplan.yaml <<NPEOF
network:
  version: 2
  ethernets:
    $iface:
      addresses: [$addr]
      routes:
        - to: default
          via: ${gw:-$(ip route show default | awk '/default/{print $3}' | head -1)}
      nameservers:
        addresses: [${dns_servers// /, }]
NPEOF
        else
            cat > /tmp/btp_netplan.yaml <<NPEOF
network:
  version: 2
  ethernets:
    $iface:
      addresses: [$addr]
NPEOF
        fi
        run_root cp /tmp/btp_netplan.yaml "$np_file"
        run_root chmod 600 "$np_file"
        run_root netplan apply
        ok "Netplan applied."
    elif [[ "$DISTRO_FAMILY" == "debian" ]] && [[ -f /etc/network/interfaces ]]; then
        info "Writing to /etc/network/interfaces..."
        run_root cp /etc/network/interfaces "/etc/network/interfaces.bak.$(date +%s)"
        cat | run_root tee -a /etc/network/interfaces >/dev/null <<IFEOF

auto $iface
iface $iface inet static
    address $addr
    gateway ${gw:-}
    dns-nameservers ${dns_servers:-8.8.8.8 1.1.1.1}
IFEOF
        ok "Written to /etc/network/interfaces. Restart networking to apply."
    elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then
        local cfg="/etc/sysconfig/network-scripts/ifcfg-$iface"
        info "Writing $cfg..."
        run_root tee "$cfg" >/dev/null <<CFGEOF
DEVICE=$iface
BOOTPROTO=none
ONBOOT=yes
IPADDR=$(echo "$addr" | cut -d/ -f1)
PREFIX=$(echo "$addr" | cut -d/ -f2)
GATEWAY=${gw:-}
DNS1=$(echo "$dns_servers" | awk '{print $1}')
DNS2=$(echo "$dns_servers" | awk '{print $2}')
CFGEOF
        run_root systemctl restart NetworkManager
        ok "Written to $cfg."
    else
        warn "Auto-persist not supported for this distro. Applied temporarily via ip command only."
    fi
}

net_remove_ip() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Remove IP from Interface${C_RESET}"; hr
    echo "Current addresses:"; ip -brief addr
    echo; read -rp "Interface: " iface; read -rp "IP with prefix to remove (e.g. 192.168.1.100/24): " addr
    [[ -z "$iface" || -z "$addr" ]] && { warn "Cancelled."; pause; return; }
    run_root ip addr del "$addr" dev "$iface" && ok "Removed $addr from $iface."
    pause
}

net_change_dns() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Change DNS Servers${C_RESET}"; hr
    echo -e "${C_BOLD}Current DNS:${C_RESET}"; grep -E '^nameserver' /etc/resolv.conf 2>/dev/null || echo "  (none)"
    echo; read -rp "New DNS servers space-separated (e.g. 1.1.1.1 8.8.8.8): " dnsv
    [[ -z "$dnsv" ]] && { warn "Cancelled."; pause; return; }

    if command -v nmcli &>/dev/null && nmcli device status &>/dev/null 2>&1; then
        read -rp "Interface to set DNS on: " iface
        local con_name; con_name=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep ":$iface$" | cut -d: -f1 | head -1)
        if [[ -n "$con_name" ]]; then
            run_root nmcli con mod "$con_name" ipv4.dns "${dnsv// /,}"
            run_root nmcli con up "$con_name"
            ok "DNS set via NetworkManager."
        fi
    fi

    if command -v systemd-resolve &>/dev/null || command -v resolvectl &>/dev/null; then
        if [[ -f /etc/systemd/resolved.conf ]]; then
            run_root cp /etc/systemd/resolved.conf "/etc/systemd/resolved.conf.bak.$(date +%s)"
            local dns_line="DNS=${dnsv// / }"
            if grep -q '^DNS=' /etc/systemd/resolved.conf; then
                run_root sed -i "s/^DNS=.*/$dns_line/" /etc/systemd/resolved.conf
            else
                echo "$dns_line" | run_root tee -a /etc/systemd/resolved.conf >/dev/null
            fi
            run_root systemctl restart systemd-resolved
            ok "DNS set via systemd-resolved."
        fi
    fi

    run_root cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
    : | run_root tee /etc/resolv.conf >/dev/null
    for d in $dnsv; do echo "nameserver $d" | run_root tee -a /etc/resolv.conf >/dev/null; done
    ok "DNS written to /etc/resolv.conf"
    pause
}

net_enable_forwarding() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Enable IP Forwarding${C_RESET}"; hr
    local current; current=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
    info "Current IPv4 forwarding: $current"
    run_root sysctl -w net.ipv4.ip_forward=1
    run_root sysctl -w net.ipv6.conf.all.forwarding=1
    if grep -q 'net.ipv4.ip_forward' /etc/sysctl.conf 2>/dev/null; then
        run_root sed -i 's/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    else echo "net.ipv4.ip_forward=1" | run_root tee -a /etc/sysctl.conf >/dev/null; fi
    if grep -q 'net.ipv6.conf.all.forwarding' /etc/sysctl.conf 2>/dev/null; then
        run_root sed -i 's/.*net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf
    else echo "net.ipv6.conf.all.forwarding=1" | run_root tee -a /etc/sysctl.conf >/dev/null; fi
    ok "IP Forwarding enabled (IPv4 + IPv6) and made persistent."; pause
}

net_disable_forwarding() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Disable IP Forwarding${C_RESET}"; hr
    run_root sysctl -w net.ipv4.ip_forward=0
    run_root sysctl -w net.ipv6.conf.all.forwarding=0
    run_root sed -i 's/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=0/' /etc/sysctl.conf 2>/dev/null
    run_root sed -i 's/.*net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=0/' /etc/sysctl.conf 2>/dev/null
    ok "IP Forwarding disabled."; pause
}

net_add_route() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Add Static Route${C_RESET}"; hr
    echo "Current routes:"; ip route show; echo
    read -rp "Destination network (e.g. 10.0.0.0/8): " dest
    read -rp "Via gateway (e.g. 192.168.1.1): " via
    read -rp "Interface (optional, leave empty): " riface
    [[ -z "$dest" || -z "$via" ]] && { warn "Cancelled."; pause; return; }
    if [[ -n "$riface" ]]; then
        run_root ip route add "$dest" via "$via" dev "$riface"
    else run_root ip route add "$dest" via "$via"; fi
    ok "Route added (temporary). Add to /etc/network/interfaces or netplan for persistence."
    pause
}

net_show_stats() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Network Statistics${C_RESET}"; hr
    echo -e "${C_BOLD}Interface stats:${C_RESET}"; ip -s link show
    echo; echo -e "${C_BOLD}Connections:${C_RESET}"; run_root ss -s
    echo; echo -e "${C_BOLD}Listening ports:${C_RESET}"; run_root ss -tulnp
    pause
}

network_advanced_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» Advanced Network Management${C_RESET}"; hr
        echo -e "  ${C_CYAN} 1)${C_RESET} Show all interfaces & addresses"
        echo -e "  ${C_CYAN} 2)${C_RESET} Set static IPv4 address (persistent)"
        echo -e "  ${C_CYAN} 3)${C_RESET} Assign IPv4 to interface"
        echo -e "  ${C_CYAN} 4)${C_RESET} Assign IPv6 to interface"
        echo -e "  ${C_CYAN} 5)${C_RESET} Remove IP from interface"
        echo -e "  ${C_CYAN} 6)${C_RESET} Change DNS servers"
        echo -e "  ${C_CYAN} 7)${C_RESET} Enable IP Forwarding"
        echo -e "  ${C_CYAN} 8)${C_RESET} Disable IP Forwarding"
        echo -e "  ${C_CYAN} 9)${C_RESET} View routing table"
        echo -e "  ${C_CYAN}10)${C_RESET} Add static route"
        echo -e "  ${C_CYAN}11)${C_RESET} Network statistics"
        echo -e "  ${C_CYAN} 0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1) net_show_interfaces ;; 2) net_set_static_ip ;; 3) net_assign_ipv4 ;;
            4) net_assign_ipv6 ;; 5) net_remove_ip ;; 6) net_change_dns ;;
            7) net_enable_forwarding ;; 8) net_disable_forwarding ;;
            9) ip route show; pause ;; 10) net_add_route ;; 11) net_show_stats ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  FIREWALL (FULL)
# ============================================================================
firewall_detect() {
    FW="none"
    if command -v ufw &>/dev/null && run_root ufw status 2>/dev/null | grep -q "Status: active"; then FW="ufw"
    elif command -v firewall-cmd &>/dev/null && run_root firewall-cmd --state 2>/dev/null | grep -q running; then FW="firewalld"
    elif command -v nft &>/dev/null && run_root nft list tables &>/dev/null 2>&1; then FW="nftables"
    elif command -v iptables &>/dev/null; then FW="iptables"; fi
}

fw_show_rules() {
    firewall_detect
    case "$FW" in
        ufw)       run_root ufw status verbose ;;
        firewalld) run_root firewall-cmd --list-all ;;
        nftables)  run_root nft list ruleset ;;
        iptables)  echo "=== IPv4 ==="; run_root iptables -L -n -v --line-numbers
                   echo "=== IPv6 ==="; run_root ip6tables -L -n -v --line-numbers 2>/dev/null ;;
        *) warn "No active firewall detected." ;;
    esac
    pause
}

fw_open_port() {
    firewall_detect
    read -rp "Port to open: " p; read -rp "Protocol tcp/udp (default tcp): " proto; proto="${proto:-tcp}"
    [[ -z "$p" ]] && { warn "No port."; return; }
    case "$FW" in
        ufw)       run_root ufw allow "$p/$proto" ;;
        firewalld) run_root firewall-cmd --permanent --add-port="$p/$proto" && run_root firewall-cmd --reload ;;
        nftables)  run_root nft add rule ip filter INPUT $proto dport "$p" accept ;;
        iptables)  run_root iptables -A INPUT -p "$proto" --dport "$p" -j ACCEPT
                   run_root ip6tables -A INPUT -p "$proto" --dport "$p" -j ACCEPT 2>/dev/null ;;
    esac
    ok "Port $p/$proto opened."
}

fw_close_port() {
    firewall_detect
    read -rp "Port to close: " p; read -rp "Protocol tcp/udp (default tcp): " proto; proto="${proto:-tcp}"
    [[ -z "$p" ]] && { warn "No port."; return; }
    case "$FW" in
        ufw)       run_root ufw delete allow "$p/$proto" ;;
        firewalld) run_root firewall-cmd --permanent --remove-port="$p/$proto" && run_root firewall-cmd --reload ;;
        iptables)  run_root iptables -D INPUT -p "$proto" --dport "$p" -j ACCEPT 2>/dev/null
                   run_root ip6tables -D INPUT -p "$proto" --dport "$p" -j ACCEPT 2>/dev/null ;;
    esac
    ok "Port $p/$proto closed."
}

fw_block_ip() {
    firewall_detect
    read -rp "IP address to block: " ip_addr
    [[ -z "$ip_addr" ]] && { warn "No IP."; return; }
    case "$FW" in
        ufw)       run_root ufw deny from "$ip_addr" ;;
        firewalld) run_root firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip_addr' drop" && run_root firewall-cmd --reload ;;
        iptables)  run_root iptables -A INPUT -s "$ip_addr" -j DROP
                   run_root iptables -A OUTPUT -d "$ip_addr" -j DROP ;;
    esac
    ok "Blocked $ip_addr."
}

fw_unblock_ip() {
    firewall_detect
    read -rp "IP address to unblock: " ip_addr
    [[ -z "$ip_addr" ]] && { warn "No IP."; return; }
    case "$FW" in
        ufw)       run_root ufw delete deny from "$ip_addr" ;;
        firewalld) run_root firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$ip_addr' drop" && run_root firewall-cmd --reload ;;
        iptables)  run_root iptables -D INPUT -s "$ip_addr" -j DROP 2>/dev/null
                   run_root iptables -D OUTPUT -d "$ip_addr" -j DROP 2>/dev/null ;;
    esac
    ok "Unblocked $ip_addr."
}

fw_rate_limit() {
    firewall_detect
    read -rp "Port to rate-limit: " p; read -rp "Max connections per minute (default 30): " rate; rate="${rate:-30}"
    case "$FW" in
        ufw)       run_root ufw limit "$p/tcp" ;;
        iptables)
            run_root iptables -A INPUT -p tcp --dport "$p" -m state --state NEW -m limit --limit "$rate"/min --limit-burst 10 -j ACCEPT
            run_root iptables -A INPUT -p tcp --dport "$p" -m state --state NEW -j DROP ;;
        *) warn "Rate limiting not automated for $FW — use manual rules." ;;
    esac
    ok "Rate limit applied for port $p."
}

fw_iptables_save() {
    if command -v iptables-save &>/dev/null; then
        local out="/etc/iptables/rules.v4"
        run_root mkdir -p /etc/iptables
        run_root iptables-save | run_root tee "$out" >/dev/null
        ok "iptables rules saved to $out"
        if command -v ip6tables-save &>/dev/null; then
            run_root ip6tables-save | run_root tee /etc/iptables/rules.v6 >/dev/null
            ok "ip6tables rules saved to /etc/iptables/rules.v6"
        fi
    else warn "iptables-save not available."; fi
}

fw_iptables_flush() {
    confirm "Flush ALL iptables rules? (will open up the firewall!)" || return
    run_root iptables -F; run_root iptables -X; run_root iptables -Z
    run_root iptables -P INPUT ACCEPT; run_root iptables -P FORWARD ACCEPT; run_root iptables -P OUTPUT ACCEPT
    run_root ip6tables -F 2>/dev/null; run_root ip6tables -X 2>/dev/null
    ok "All iptables rules flushed."
}

fw_enable() {
    case "$DISTRO_FAMILY" in
        debian|arch) command -v ufw &>/dev/null && run_root ufw enable || warn "UFW not installed." ;;
        rhel|suse)   run_root systemctl enable --now firewalld ;;
    esac; ok "Firewall enabled."
}

fw_disable() {
    firewall_detect
    case "$FW" in
        ufw)       run_root ufw disable ;;
        firewalld) run_root systemctl disable --now firewalld ;;
        iptables)  fw_iptables_flush ;;
    esac; ok "Firewall disabled."
}

fw_default_ssh_rules() {
    info "Applying safe default rules (allow SSH 22, allow established, drop rest)..."
    run_root iptables -F INPUT; run_root iptables -P INPUT DROP
    run_root iptables -A INPUT -i lo -j ACCEPT
    run_root iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    run_root iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    ok "Default safe iptables rules applied (SSH allowed, rest dropped)."
    warn "Run 'Save iptables rules' to persist."
}

firewall_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» Firewall Management${C_RESET}"; hr
        firewall_detect; info "Active firewall backend: ${C_WHITE}$FW${C_RESET}"
        echo
        echo -e "  ${C_CYAN} 1)${C_RESET} Show current rules"
        echo -e "  ${C_CYAN} 2)${C_RESET} Open a port"
        echo -e "  ${C_CYAN} 3)${C_RESET} Close a port"
        echo -e "  ${C_CYAN} 4)${C_RESET} Block an IP address"
        echo -e "  ${C_CYAN} 5)${C_RESET} Unblock an IP address"
        echo -e "  ${C_CYAN} 6)${C_RESET} Rate-limit a port"
        echo -e "  ${C_CYAN} 7)${C_RESET} Enable firewall"
        echo -e "  ${C_CYAN} 8)${C_RESET} Disable firewall"
        echo -e "  ${C_CYAN} 9)${C_RESET} Install UFW"
        echo -e "  ${C_CYAN}10)${C_RESET} Save iptables rules (persist)"
        echo -e "  ${C_CYAN}11)${C_RESET} Flush ALL iptables rules"
        echo -e "  ${C_CYAN}12)${C_RESET} Apply default safe rules (allow SSH + drop rest)"
        echo -e "  ${C_CYAN}13)${C_RESET} List listening ports"
        echo -e "  ${C_CYAN} 0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1) fw_show_rules ;;
            2) fw_open_port; pause ;;
            3) fw_close_port; pause ;;
            4) fw_block_ip; pause ;;
            5) fw_unblock_ip; pause ;;
            6) fw_rate_limit; pause ;;
            7) fw_enable; pause ;;
            8) fw_disable; pause ;;
            9) run_root $PKG_INSTALL ufw; pause ;;
            10) fw_iptables_save; pause ;;
            11) fw_iptables_flush; pause ;;
            12) fw_default_ssh_rules; pause ;;
            13) run_root ss -tulnp; pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  CRON JOB MANAGEMENT
# ============================================================================
cron_list() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Cron Jobs${C_RESET}"; hr
    echo -e "${C_BOLD}Current user crontab:${C_RESET}"; crontab -l 2>/dev/null || echo "  (empty)"
    echo; echo -e "${C_BOLD}Root crontab:${C_RESET}"; run_root crontab -l 2>/dev/null || echo "  (empty)"
    echo; echo -e "${C_BOLD}System cron (/etc/cron.d/):${C_RESET}"
    ls /etc/cron.d/ 2>/dev/null | sed 's/^/  /'
    echo; echo -e "${C_BOLD}/etc/crontab:${C_RESET}"; cat /etc/crontab 2>/dev/null | grep -v '^#' | grep -v '^$' || echo "  (empty)"
    pause
}

cron_add() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Add Cron Job${C_RESET}"; hr
    echo -e "${C_DIM}Format: minute hour day month weekday command${C_RESET}"
    echo -e "${C_DIM}Examples:${C_RESET}"
    echo -e "  ${C_GRAY}0 * * * *     command   (every hour)${C_RESET}"
    echo -e "  ${C_GRAY}*/5 * * * *   command   (every 5 minutes)${C_RESET}"
    echo -e "  ${C_GRAY}0 2 * * *     command   (daily at 2am)${C_RESET}"
    echo -e "  ${C_GRAY}0 2 * * 0     command   (every Sunday at 2am)${C_RESET}"
    echo -e "  ${C_GRAY}@reboot       command   (on every reboot)${C_RESET}"
    echo
    read -rp "Schedule (e.g. '0 2 * * *' or '@reboot'): " schedule
    [[ -z "$schedule" ]] && { warn "Cancelled."; pause; return; }
    read -rp "Command to run: " cmd
    [[ -z "$cmd" ]] && { warn "Cancelled."; pause; return; }
    read -rp "Add for which user? (empty = current '$(whoami)'): " cron_user
    local new_entry="$schedule $cmd"
    echo -e "\n${C_BOLD}Will add:${C_RESET} $new_entry"
    confirm "Confirm?" || { pause; return; }
    if [[ -z "$cron_user" || "$cron_user" == "$(whoami)" ]]; then
        (crontab -l 2>/dev/null; echo "$new_entry") | crontab -
        ok "Cron job added for $(whoami)."
    else
        (run_root crontab -u "$cron_user" -l 2>/dev/null; echo "$new_entry") | run_root crontab -u "$cron_user" -
        ok "Cron job added for $cron_user."
    fi
    pause
}

cron_remove() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Remove Cron Job${C_RESET}"; hr
    echo "Your current crontab:"; crontab -l 2>/dev/null | nl -ba || echo "  (empty)"; echo
    read -rp "Line number to remove: " lnum
    [[ ! "$lnum" =~ ^[0-9]+$ ]] && { err "Invalid."; pause; return; }
    confirm "Remove line $lnum?" || { pause; return; }
    local tmpf; tmpf=$(mktemp)
    crontab -l 2>/dev/null | sed "${lnum}d" > "$tmpf"
    crontab "$tmpf"; rm -f "$tmpf"
    ok "Line $lnum removed."; pause
}

cron_edit() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Edit Crontab${C_RESET}"; hr
    read -rp "Edit for user (empty = current): " cron_user
    if [[ -z "$cron_user" ]]; then crontab -e
    else run_root crontab -u "$cron_user" -e; fi
}

cron_view_logs() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Cron Logs${C_RESET}"; hr
    run_root journalctl -u cron -u crond -n 50 --no-pager 2>/dev/null || \
    run_root grep -i cron /var/log/syslog 2>/dev/null | tail -50 || \
    run_root tail -50 /var/log/cron 2>/dev/null || \
    warn "Could not find cron logs."
    pause
}

cron_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» Cron Job Manager${C_RESET}"; hr
        echo -e "  ${C_CYAN}1)${C_RESET} List all cron jobs"
        echo -e "  ${C_CYAN}2)${C_RESET} Add new cron job (guided)"
        echo -e "  ${C_CYAN}3)${C_RESET} Remove a cron job"
        echo -e "  ${C_CYAN}4)${C_RESET} Edit crontab (manual editor)"
        echo -e "  ${C_CYAN}5)${C_RESET} View cron logs"
        echo -e "  ${C_CYAN}6)${C_RESET} Enable cron service"
        echo -e "  ${C_CYAN}7)${C_RESET} Disable cron service"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1) cron_list ;; 2) cron_add ;; 3) cron_remove ;; 4) cron_edit ;;
            5) cron_view_logs ;;
            6) run_root systemctl enable --now cron 2>/dev/null || run_root systemctl enable --now crond; ok "Cron enabled."; pause ;;
            7) run_root systemctl disable --now cron 2>/dev/null || run_root systemctl disable --now crond; ok "Cron disabled."; pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  TEMPORARY DOWNLOAD LINK
# ============================================================================
temp_download_link() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Temporary Download Link (Python HTTP Server)${C_RESET}"; hr
    if ! command -v python3 &>/dev/null; then
        warn "python3 not found. Installing..."; run_root $PKG_INSTALL python3; fi
    read -rp "Full path to file or directory to share: " fpath
    [[ -z "$fpath" ]] && { warn "Cancelled."; pause; return; }
    if [[ ! -e "$fpath" ]]; then err "Path not found: $fpath"; pause; return; fi
    read -rp "Port (default 8080): " dl_port; dl_port="${dl_port:-8080}"
    read -rp "Timeout in minutes (default 30): " dl_timeout; dl_timeout="${dl_timeout:-30}"
    local timeout_secs=$(( dl_timeout * 60 ))
    local public_ip; public_ip=$(curl -s --max-time 4 ifconfig.me 2>/dev/null || echo "YOUR_IP")
    local is_file=false; local filename=""
    [[ -f "$fpath" ]] && { is_file=true; filename=$(basename "$fpath"); }
    echo
    ok "Starting temporary HTTP server..."
    if [[ "$is_file" == true ]]; then
        info "Download URL: ${C_WHITE}http://$public_ip:$dl_port/$filename${C_RESET}"
    else
        info "Browse URL:   ${C_WHITE}http://$public_ip:$dl_port/${C_RESET}"
    fi
    info "Will auto-stop after $dl_timeout minutes."
    warn "Press Ctrl+C to stop early."
    echo

    python3 - <<PYEOF
import http.server, os, sys, threading, time, socket

fpath = "$fpath"
port = $dl_port
timeout = $timeout_secs

if os.path.isfile(fpath):
    serve_dir = os.path.dirname(os.path.abspath(fpath))
    fname = os.path.basename(fpath)
else:
    serve_dir = os.path.abspath(fpath)
    fname = None

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=serve_dir, **kwargs)
    def log_message(self, fmt, *args):
        print(f"  [{time.strftime('%H:%M:%S')}] {args[0]} -> {args[1]}")

os.chdir(serve_dir)
with http.server.HTTPServer(('', port), Handler) as httpd:
    timer = threading.Timer(timeout, httpd.shutdown)
    timer.start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        timer.cancel()
    print("\n  Server stopped.")
PYEOF
    pause
}

# ============================================================================
#  TMUX
# ============================================================================
tmux_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» tmux Manager${C_RESET}"; hr
        if ! command -v tmux &>/dev/null; then
            warn "tmux is not installed."
            echo -e "  ${C_CYAN}1)${C_RESET} Install tmux"
            echo -e "  ${C_CYAN}0)${C_RESET} Back"
            hr; read -rp "Choice: " c
            case "$c" in
                1) run_root $PKG_INSTALL tmux && ok "tmux installed."; pause ;;
                0) return ;;
            esac; continue; fi

        echo -e "${C_BOLD}Active sessions:${C_RESET}"
        tmux ls 2>/dev/null || echo "  (none)"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} New session"
        echo -e "  ${C_CYAN}2)${C_RESET} Attach to session"
        echo -e "  ${C_CYAN}3)${C_RESET} Kill session"
        echo -e "  ${C_CYAN}4)${C_RESET} Kill all sessions"
        echo -e "  ${C_CYAN}5)${C_RESET} List sessions"
        echo -e "  ${C_CYAN}6)${C_RESET} Rename session"
        echo -e "  ${C_CYAN}7)${C_RESET} Show tmux key bindings reference"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1)
                read -rp "Session name (empty = auto): " sname
                if [[ -z "$sname" ]]; then tmux new-session
                else tmux new-session -s "$sname"; fi ;;
            2)
                read -rp "Session name (empty = first available): " sname
                if [[ -z "$sname" ]]; then tmux attach-session
                else tmux attach-session -t "$sname"; fi ;;
            3)
                tmux ls 2>/dev/null; echo
                read -rp "Session name to kill: " sname
                [[ -n "$sname" ]] && tmux kill-session -t "$sname" && ok "Session '$sname' killed."
                pause ;;
            4)
                confirm "Kill ALL tmux sessions?" && tmux kill-server && ok "All sessions killed."
                pause ;;
            5) tmux ls 2>/dev/null || echo "  (no sessions)"; pause ;;
            6)
                tmux ls; echo
                read -rp "Old name: " oname; read -rp "New name: " nname
                [[ -n "$oname" && -n "$nname" ]] && tmux rename-session -t "$oname" "$nname" && ok "Renamed."
                pause ;;
            7)
                echo -e "${C_BOLD}tmux Quick Reference:${C_RESET}"
                echo "  Prefix key: Ctrl+B"
                echo "  Ctrl+B d   — detach from session"
                echo "  Ctrl+B c   — new window"
                echo "  Ctrl+B n/p — next/prev window"
                echo "  Ctrl+B ,   — rename window"
                echo "  Ctrl+B %   — split vertically"
                echo "  Ctrl+B \"   — split horizontally"
                echo "  Ctrl+B o   — switch pane"
                echo "  Ctrl+B x   — kill pane"
                echo "  Ctrl+B [   — scroll mode (q to exit)"
                echo "  Ctrl+B ?   — show all keybindings"
                pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  DOCKER MANAGEMENT
# ============================================================================
docker_install() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install Docker${C_RESET}"; hr
    if command -v docker &>/dev/null; then ok "Docker already installed: $(docker --version)"; pause; return; fi
    info "Installing Docker using official script..."
    confirm "Download and run get.docker.com script?" || { pause; return; }
    curl -fsSL https://get.docker.com | run_root sh
    run_root systemctl enable --now docker
    if confirm "Add current user '$(whoami)' to docker group?"; then
        run_root usermod -aG docker "$(whoami)"
        warn "Log out and back in for group change to take effect."
    fi
    ok "Docker installed."; pause
}

docker_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» Docker Management${C_RESET}"; hr
        if ! command -v docker &>/dev/null; then
            warn "Docker is not installed."
            echo -e "  ${C_CYAN}1)${C_RESET} Install Docker"
            echo -e "  ${C_CYAN}0)${C_RESET} Back"; hr
            read -rp "Choice: " c
            case "$c" in 1) docker_install ;; 0) return ;; esac; continue; fi

        local status; status=$(run_root systemctl is-active docker 2>/dev/null || echo "unknown")
        info "Docker service: ${C_WHITE}$status${C_RESET} | $(docker --version 2>/dev/null)"
        echo
        echo -e "  ${C_BOLD}${C_CYAN}-- Containers --${C_RESET}"
        echo -e "  ${C_CYAN} 1)${C_RESET} List all containers"
        echo -e "  ${C_CYAN} 2)${C_RESET} List running containers"
        echo -e "  ${C_CYAN} 3)${C_RESET} Start container"
        echo -e "  ${C_CYAN} 4)${C_RESET} Stop container"
        echo -e "  ${C_CYAN} 5)${C_RESET} Restart container"
        echo -e "  ${C_CYAN} 6)${C_RESET} Remove container"
        echo -e "  ${C_CYAN} 7)${C_RESET} Container logs"
        echo -e "  ${C_CYAN} 8)${C_RESET} Exec into container (shell)"
        echo -e "  ${C_CYAN} 9)${C_RESET} Container inspect/stats"
        echo -e "  ${C_BOLD}${C_CYAN}-- Images --${C_RESET}"
        echo -e "  ${C_CYAN}10)${C_RESET} List images"
        echo -e "  ${C_CYAN}11)${C_RESET} Pull image"
        echo -e "  ${C_CYAN}12)${C_RESET} Remove image"
        echo -e "  ${C_BOLD}${C_CYAN}-- Other --${C_RESET}"
        echo -e "  ${C_CYAN}13)${C_RESET} List volumes"
        echo -e "  ${C_CYAN}14)${C_RESET} List networks"
        echo -e "  ${C_CYAN}15)${C_RESET} Docker info / disk usage"
        echo -e "  ${C_CYAN}16)${C_RESET} System prune (remove unused)"
        echo -e "  ${C_CYAN}17)${C_RESET} Docker Compose — up"
        echo -e "  ${C_CYAN}18)${C_RESET} Docker Compose — down"
        echo -e "  ${C_CYAN}19)${C_RESET} Docker Compose — logs"
        echo -e "  ${C_CYAN}20)${C_RESET} Start/Stop Docker service"
        echo -e "  ${C_CYAN} 0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1)  run_root docker ps -a; pause ;;
            2)  run_root docker ps; pause ;;
            3)  read -rp "Container name/ID: " cn; run_root docker start "$cn" && ok "Started."; pause ;;
            4)  read -rp "Container name/ID: " cn; run_root docker stop "$cn" && ok "Stopped."; pause ;;
            5)  read -rp "Container name/ID: " cn; run_root docker restart "$cn" && ok "Restarted."; pause ;;
            6)
                run_root docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
                read -rp "Container name/ID to remove: " cn
                confirm "Remove container '$cn'?" && run_root docker rm -f "$cn" && ok "Removed."
                pause ;;
            7)
                read -rp "Container name/ID: " cn; read -rp "Lines (default 100): " n; n="${n:-100}"
                run_root docker logs --tail "$n" -t "$cn"; pause ;;
            8)
                read -rp "Container name/ID: " cn; read -rp "Shell (default bash, try sh if fails): " sh_cmd; sh_cmd="${sh_cmd:-bash}"
                run_root docker exec -it "$cn" "$sh_cmd" ;;
            9)
                read -rp "Container name/ID (for inspect), or empty for stats: " cn
                if [[ -z "$cn" ]]; then run_root docker stats --no-stream
                else run_root docker inspect "$cn"; fi
                pause ;;
            10) run_root docker images; pause ;;
            11) read -rp "Image name:tag (e.g. nginx:latest): " img; run_root docker pull "$img"; pause ;;
            12)
                run_root docker images
                read -rp "Image name:tag to remove: " img
                confirm "Remove image '$img'?" && run_root docker rmi "$img" && ok "Removed."
                pause ;;
            13) run_root docker volume ls; pause ;;
            14) run_root docker network ls; pause ;;
            15) run_root docker info; echo; run_root docker system df; pause ;;
            16)
                confirm "Prune stopped containers, dangling images, unused networks?" || { pause; continue; }
                run_root docker system prune -f
                if confirm "Also remove unused volumes?"; then run_root docker volume prune -f; fi
                ok "Prune complete."; pause ;;
            17)
                read -rp "Path to docker-compose.yml dir (default .): " cdir; cdir="${cdir:-.}"
                run_root docker compose -f "$cdir/docker-compose.yml" up -d; pause ;;
            18)
                read -rp "Path to docker-compose.yml dir (default .): " cdir; cdir="${cdir:-.}"
                run_root docker compose -f "$cdir/docker-compose.yml" down; pause ;;
            19)
                read -rp "Path to docker-compose.yml dir (default .): " cdir; cdir="${cdir:-.}"
                read -rp "Lines (default 100): " n; n="${n:-100}"
                run_root docker compose -f "$cdir/docker-compose.yml" logs --tail "$n"; pause ;;
            20)
                if [[ "$status" == "active" ]]; then
                    run_root systemctl stop docker && ok "Docker stopped."
                else run_root systemctl start docker && ok "Docker started."; fi
                pause ;;
            0) return ;;
        esac
    done
}

# ============================================================================
#  SOFTWARE INSTALLER
# ============================================================================
installer_nginx() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install Nginx${C_RESET}"; hr
    run_root $PKG_INSTALL nginx
    run_root systemctl enable --now nginx
    ok "Nginx installed and started."
    info "Config: /etc/nginx/nginx.conf | Sites: /etc/nginx/sites-available/"
    echo
    if confirm "Show Nginx status?"; then run_root systemctl status nginx --no-pager; fi
    pause
}

installer_mysql() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install MySQL${C_RESET}"; hr
    case "$DISTRO_FAMILY" in
        debian) run_root $PKG_INSTALL mysql-server ;;
        rhel)   run_root $PKG_INSTALL mysql-server ;;
        arch)   run_root $PKG_INSTALL mysql; run_root mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql ;;
        *)      warn "MySQL install may require manual steps on $DISTRO."; run_root $PKG_INSTALL mysql-server ;;
    esac
    run_root systemctl enable --now mysql 2>/dev/null || run_root systemctl enable --now mysqld
    ok "MySQL installed."
    if confirm "Run mysql_secure_installation?"; then run_root mysql_secure_installation; fi
    pause
}

installer_mariadb() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install MariaDB${C_RESET}"; hr
    case "$DISTRO_FAMILY" in
        debian) run_root $PKG_INSTALL mariadb-server ;;
        rhel)   run_root $PKG_INSTALL mariadb-server ;;
        arch)   run_root $PKG_INSTALL mariadb; run_root mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql ;;
        *)      run_root $PKG_INSTALL mariadb-server ;;
    esac
    run_root systemctl enable --now mariadb
    ok "MariaDB installed."
    if confirm "Run mysql_secure_installation?"; then run_root mysql_secure_installation; fi
    pause
}

installer_postgresql() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install PostgreSQL${C_RESET}"; hr
    case "$DISTRO_FAMILY" in
        debian) run_root $PKG_INSTALL postgresql postgresql-contrib ;;
        rhel)   run_root $PKG_INSTALL postgresql-server postgresql-contrib
                run_root postgresql-setup --initdb 2>/dev/null || run_root postgresql-setup initdb 2>/dev/null ;;
        arch)   run_root $PKG_INSTALL postgresql
                run_root -u postgres initdb -D /var/lib/postgres/data 2>/dev/null ;;
        *)      run_root $PKG_INSTALL postgresql ;;
    esac
    run_root systemctl enable --now postgresql
    ok "PostgreSQL installed."
    info "Connect: sudo -u postgres psql"
    pause
}

installer_mongodb() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install MongoDB${C_RESET}"; hr
    case "$DISTRO_FAMILY" in
        debian)
            run_root $PKG_INSTALL gnupg curl
            curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | run_root gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
            echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | run_root tee /etc/apt/sources.list.d/mongodb-org-7.0.list
            run_root apt-get update; run_root $PKG_INSTALL mongodb-org ;;
        rhel)
            cat | run_root tee /etc/yum.repos.d/mongodb-org-7.0.repo <<'MEOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
MEOF
            run_root $PKG_INSTALL mongodb-org ;;
        arch) run_root $PKG_INSTALL mongodb 2>/dev/null || warn "Try AUR: yay -S mongodb-bin" ;;
        *)    warn "Manual MongoDB install required for $DISTRO. Visit: https://www.mongodb.com/docs/manual/installation/" ;;
    esac
    run_root systemctl enable --now mongod 2>/dev/null && ok "MongoDB installed." || warn "Check mongod service status."
    pause
}

installer_redis() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install Redis${C_RESET}"; hr
    run_root $PKG_INSTALL redis 2>/dev/null || run_root $PKG_INSTALL redis-server
    run_root systemctl enable --now redis 2>/dev/null || run_root systemctl enable --now redis-server
    ok "Redis installed."
    info "Config: /etc/redis/redis.conf"
    if confirm "Test connection (redis-cli ping)?"; then redis-cli ping && ok "Redis responded PONG."; fi
    pause
}

installer_python() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install Python${C_RESET}"; hr
    case "$DISTRO_FAMILY" in
        debian) run_root $PKG_INSTALL python3 python3-pip python3-venv python3-dev ;;
        rhel)   run_root $PKG_INSTALL python3 python3-pip python3-devel ;;
        arch)   run_root $PKG_INSTALL python python-pip ;;
        alpine) run_root $PKG_INSTALL python3 py3-pip ;;
        *)      run_root $PKG_INSTALL python3 python3-pip ;;
    esac
    ok "Python installed: $(python3 --version 2>/dev/null)"
    ok "pip: $(pip3 --version 2>/dev/null)"
    pause
}

installer_nodejs() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install Node.js${C_RESET}"; hr
    echo -e "  ${C_CYAN}1)${C_RESET} Install via package manager (may be older)"
    echo -e "  ${C_CYAN}2)${C_RESET} Install via NodeSource (LTS - recommended)"
    echo -e "  ${C_CYAN}3)${C_RESET} Install via nvm (Node Version Manager)"
    hr; read -rp "Choice [1-3]: " c
    case "$c" in
        1)
            case "$DISTRO_FAMILY" in
                debian) run_root $PKG_INSTALL nodejs npm ;;
                rhel)   run_root $PKG_INSTALL nodejs npm ;;
                arch)   run_root $PKG_INSTALL nodejs npm ;;
                *)      run_root $PKG_INSTALL nodejs npm ;;
            esac ;;
        2)
            info "Installing Node.js LTS via NodeSource..."
            curl -fsSL https://deb.nodesource.com/setup_lts.x | run_root bash -
            run_root $PKG_INSTALL nodejs ;;
        3)
            info "Installing nvm..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
            warn "Restart your shell or run: source ~/.bashrc"
            warn "Then: nvm install --lts"
            pause; return ;;
    esac
    ok "Node.js: $(node --version 2>/dev/null)"
    ok "npm: $(npm --version 2>/dev/null)"
    pause
}

installer_custom_repos() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» Install from Custom Repositories${C_RESET}"; hr
        echo -e "  ${C_CYAN}1)${C_RESET} ${C_BOLD}3x-ui (Sanaei)${C_RESET} — paqctl panel installer"
        echo -e "       ${C_GRAY}curl -fsSL https://raw.githubusercontent.com/SamNet-dev/paqctl/main/paqctl.sh | sudo bash${C_RESET}"
        echo
        echo -e "  ${C_CYAN}2)${C_RESET} ${C_BOLD}Madmail${C_RESET} — Maddy mail server (simple install)"
        echo -e "       ${C_GRAY}wget madmail binary + ./madmail install --simple${C_RESET}"
        echo
        echo -e "  ${C_CYAN}3)${C_RESET} ${C_BOLD}StormDNS${C_RESET} — DNS server installer"
        echo -e "       ${C_GRAY}bash <(curl -Ls .../StormDNS/main/server_linux_install.sh)${C_RESET}"
        echo
        echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1)
                banner; echo -e "${C_BOLD}${C_BLUE}» Installing 3x-ui (paqctl)${C_RESET}"; hr
                warn "This will run a remote install script."
                confirm "Proceed?" || { pause; continue; }
                curl -fsSL https://raw.githubusercontent.com/SamNet-dev/paqctl/main/paqctl.sh | run_root bash
                pause ;;
            2)
                banner; echo -e "${C_BOLD}${C_BLUE}» Installing Madmail${C_RESET}"; hr
                warn "This will download and run madmail installer."
                confirm "Proceed?" || { pause; continue; }
                cd /tmp && wget -q https://github.com/themadorg/madmail/releases/latest/download/madmail-linux-amd64.tar.gz && \
                tar -xzf madmail-linux-amd64.tar.gz && chmod +x madmail && \
                run_root ./madmail install --simple && run_root systemctl start maddy
                ok "Madmail installation complete."
                pause ;;
            3)
                banner; echo -e "${C_BOLD}${C_BLUE}» Installing StormDNS${C_RESET}"; hr
                warn "This will run a remote install script."
                confirm "Proceed?" || { pause; continue; }
                bash <(curl -Ls https://raw.githubusercontent.com/nullroute1970/StormDNS/main/server_linux_install.sh)
                pause ;;
            0) return ;;
        esac
    done
}

software_installer_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» Software Installer${C_RESET}"; hr
        echo -e "  ${C_BOLD}${C_CYAN}-- Web Server --${C_RESET}"
        echo -e "  ${C_CYAN} 1)${C_RESET} Install Nginx"
        echo -e "  ${C_BOLD}${C_CYAN}-- Databases --${C_RESET}"
        echo -e "  ${C_CYAN} 2)${C_RESET} Install MySQL"
        echo -e "  ${C_CYAN} 3)${C_RESET} Install MariaDB"
        echo -e "  ${C_CYAN} 4)${C_RESET} Install PostgreSQL"
        echo -e "  ${C_CYAN} 5)${C_RESET} Install MongoDB"
        echo -e "  ${C_CYAN} 6)${C_RESET} Install Redis"
        echo -e "  ${C_BOLD}${C_CYAN}-- Languages & Runtimes --${C_RESET}"
        echo -e "  ${C_CYAN} 7)${C_RESET} Install Python 3"
        echo -e "  ${C_CYAN} 8)${C_RESET} Install Node.js"
        echo -e "  ${C_CYAN} 9)${C_RESET} Install Docker"
        echo -e "  ${C_BOLD}${C_CYAN}-- Custom Repositories --${C_RESET}"
        echo -e "  ${C_CYAN}10)${C_RESET} Install from custom repos (3x-ui, Madmail, StormDNS)"
        echo -e "  ${C_CYAN} 0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1) installer_nginx ;; 2) installer_mysql ;; 3) installer_mariadb ;;
            4) installer_postgresql ;; 5) installer_mongodb ;; 6) installer_redis ;;
            7) installer_python ;; 8) installer_nodejs ;; 9) docker_install ;;
            10) installer_custom_repos ;; 0) return ;;
        esac
    done
}

# ============================================================================
#  ORIGINAL FEATURES (PORT/NETWORK/PROCESS/SERVICE/DISK/SECURITY/BACKUP)
# ============================================================================
list_listening_ports() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Listening Ports${C_RESET}"; hr
    if command -v ss &>/dev/null; then run_root ss -tulnp
    elif command -v netstat &>/dev/null; then run_root netstat -tulnp
    else warn "Neither ss nor netstat found."; fi
    pause
}

port_status_check() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Check Specific Port${C_RESET}"; hr
    read -rp "Port number: " p; [[ -z "$p" ]] && { pause; return; }
    echo -e "${C_BOLD}Local listeners on port $p:${C_RESET}"
    if command -v ss &>/dev/null; then run_root ss -tulnp | grep -E "[:.]${p}\b" || echo "  (none)"
    else run_root netstat -tulnp 2>/dev/null | grep -E "[:.]${p}\b" || echo "  (none)"; fi
    echo; echo -e "${C_BOLD}Firewall status:${C_RESET}"
    command -v ufw &>/dev/null && run_root ufw status | grep -E "\b${p}\b" || echo "  (no UFW rule)"
    pause
}

network_info() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Network Info${C_RESET}"; hr
    echo -e "${C_BOLD}Interfaces:${C_RESET}"; ip -brief addr 2>/dev/null || ifconfig
    echo; echo -e "${C_BOLD}Default route:${C_RESET}"; ip route show default 2>/dev/null
    echo; echo -e "${C_BOLD}DNS:${C_RESET}"; grep -E '^nameserver' /etc/resolv.conf 2>/dev/null || true
    echo; echo -e "${C_BOLD}Public IP:${C_RESET} $(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo 'N/A')"
    echo; read -rp "Run ping/traceroute test? Host (empty to skip): " host
    if [[ -n "$host" ]]; then
        echo "--- ping ---"; ping -c 4 "$host"
        command -v traceroute &>/dev/null && { echo "--- traceroute ---"; traceroute -n "$host"; } || \
        command -v tracepath &>/dev/null && tracepath "$host"
    fi
    pause
}

kill_process_menu() {
    banner; echo -e "${C_BOLD}${C_MAGENTA}» Kill Process${C_RESET}"; hr
    echo -e "  ${C_CYAN}1)${C_RESET} Kill by PID"; echo -e "  ${C_CYAN}2)${C_RESET} Kill by name"
    echo -e "  ${C_CYAN}3)${C_RESET} Kill by port"; echo -e "  ${C_CYAN}4)${C_RESET} Search & kill"
    echo -e "  ${C_CYAN}0)${C_RESET} Back"; hr; read -rp "Choice: " c
    case "$c" in
        1) read -rp "PID: " pid; read -rp "Signal (15=TERM, 9=KILL, default 15): " sig; sig="${sig:-15}"
           run_root kill -"$sig" "$pid" && ok "Sent SIG$sig to PID $pid."; pause ;;
        2) read -rp "Process name: " pname
           confirm "Kill all '$pname'?" && run_root pkill -f "$pname" && ok "Killed."; pause ;;
        3) read -rp "Port: " p
           local pids; pids=$(run_root ss -tlnp 2>/dev/null | grep ":$p " | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u)
           [[ -z "$pids" ]] && pids=$(run_root lsof -ti:"$p" 2>/dev/null)
           if [[ -z "$pids" ]]; then warn "No process on port $p."
           else echo "PIDs: $pids"; confirm "Kill them?" && run_root kill -9 $pids && ok "Killed."; fi; pause ;;
        4) read -rp "Search term: " term
           ps -eo pid,user,%cpu,%mem,comm,args | grep -i "$term" | grep -v grep | head -20; echo
           read -rp "PID to kill (empty=cancel): " pid
           [[ -n "$pid" ]] && run_root kill -9 "$pid" && ok "Killed."; pause ;;
    esac
}

service_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» Service Management${C_RESET}"; hr
        echo -e "  ${C_CYAN}1)${C_RESET} List running services"; echo -e "  ${C_CYAN}2)${C_RESET} List failed services"
        echo -e "  ${C_CYAN}3)${C_RESET} Start"; echo -e "  ${C_CYAN}4)${C_RESET} Stop"
        echo -e "  ${C_CYAN}5)${C_RESET} Restart"; echo -e "  ${C_CYAN}6)${C_RESET} Enable on boot"
        echo -e "  ${C_CYAN}7)${C_RESET} Disable on boot"; echo -e "  ${C_CYAN}8)${C_RESET} Status"
        echo -e "  ${C_CYAN}9)${C_RESET} Logs (journalctl)"; echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1) systemctl list-units --type=service --state=running | head -40; pause ;;
            2) systemctl --failed; pause ;;
            3) read -rp "Service: " s; run_root systemctl start "$s" && ok "Started."; pause ;;
            4) read -rp "Service: " s; run_root systemctl stop "$s" && ok "Stopped."; pause ;;
            5) read -rp "Service: " s; run_root systemctl restart "$s" && ok "Restarted."; pause ;;
            6) read -rp "Service: " s; run_root systemctl enable "$s" && ok "Enabled."; pause ;;
            7) read -rp "Service: " s; run_root systemctl disable "$s" && ok "Disabled."; pause ;;
            8) read -rp "Service: " s; run_root systemctl status "$s" --no-pager; pause ;;
            9) read -rp "Service: " s; run_root journalctl -u "$s" -n 100 --no-pager; pause ;;
            0) return ;;
        esac
    done
}

disk_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» Disk & Files${C_RESET}"; hr
        echo -e "  ${C_CYAN}1)${C_RESET} Disk usage (df)"; echo -e "  ${C_CYAN}2)${C_RESET} Largest directories under /"
        echo -e "  ${C_CYAN}3)${C_RESET} Largest files (top 30)"; echo -e "  ${C_CYAN}4)${C_RESET} Clean pkg cache"
        echo -e "  ${C_CYAN}5)${C_RESET} Clean systemd journal"; echo -e "  ${C_CYAN}6)${C_RESET} Clean /tmp"
        echo -e "  ${C_CYAN}7)${C_RESET} Find files by name"; echo -e "  ${C_CYAN}0)${C_RESET} Back"
        hr; read -rp "Choice: " c
        case "$c" in
            1) df -hT -x tmpfs -x devtmpfs -x squashfs; pause ;;
            2) run_root du -h --max-depth=2 / 2>/dev/null | sort -hr | head -20; pause ;;
            3) read -rp "Search path (default /): " sp; sp="${sp:-/}"
               run_root find "$sp" -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -30 | awk '{printf "%10.2f MB  %s\n",$1/1024/1024,$2}'; pause ;;
            4) case "$DISTRO_FAMILY" in
                   debian) run_root apt-get clean ;; rhel) run_root $PKG_MGR clean all ;;
                   arch) run_root pacman -Sc --noconfirm ;; suse) run_root zypper clean ;; esac
               ok "Cache cleaned."; pause ;;
            5) run_root journalctl --vacuum-time=7d; pause ;;
            6) run_root find /tmp -mindepth 1 -mtime +7 -delete 2>/dev/null; ok "Cleaned /tmp."; pause ;;
            7) read -rp "Pattern: " pat; read -rp "Path (default /): " sp; sp="${sp:-/}"
               run_root find "$sp" -name "$pat" 2>/dev/null | head -50; pause ;;
            0) return ;;
        esac
    done
}

diagnostics() {
    banner; echo -e "${C_BOLD}${C_BLUE}» System Diagnostics${C_RESET}"; hr; local issues=0
    echo -e "${C_BOLD}● Load:${C_RESET}"; local load1; load1=$(cut -d' ' -f1 /proc/loadavg); local cores; cores=$(nproc)
    echo "  Load 1min: $load1, Cores: $cores"
    echo; echo -e "${C_BOLD}● Memory:${C_RESET}"; local mp; mp=$(free | awk '/Mem:/{printf "%.0f",$3/$2*100}')
    echo "  Used: ${mp}%"; (( mp > 90 )) && { warn "Memory > 90%."; issues=$((issues+1)); }
    echo; echo -e "${C_BOLD}● Disk:${C_RESET}"
    df -h -x tmpfs -x devtmpfs -x squashfs | awk 'NR>1{gsub("%","",$5); if($5>85) print "  WARN: "$0; else print "  OK:   "$0}'
    echo; echo -e "${C_BOLD}● Failed services:${C_RESET}"
    local failed; failed=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    echo "  Failed: $failed"; (( failed > 0 )) && { systemctl --failed --no-legend; issues=$((issues+1)); }
    echo; echo -e "${C_BOLD}● Network:${C_RESET}"
    ping -c 1 -W 2 1.1.1.1 &>/dev/null && echo "  Internet: OK" || { warn "  Cannot reach 1.1.1.1"; issues=$((issues+1)); }
    getent hosts google.com &>/dev/null && echo "  DNS: OK" || { warn "  DNS failing"; issues=$((issues+1)); }
    echo; hr
    (( issues == 0 )) && ok "No issues detected." || warn "Found $issues potential issue(s)."
    pause
}

view_logs() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» View Logs${C_RESET}"; hr
        echo -e "  ${C_CYAN}1)${C_RESET} Recent syslog/journal"; echo -e "  ${C_CYAN}2)${C_RESET} Auth log"
        echo -e "  ${C_CYAN}3)${C_RESET} Kernel (dmesg)"; echo -e "  ${C_CYAN}4)${C_RESET} Boot log"
        echo -e "  ${C_CYAN}5)${C_RESET} Errors only"; echo -e "  ${C_CYAN}6)${C_RESET} Follow live (Ctrl+C)"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"; hr; read -rp "Choice: " c
        case "$c" in
            1) run_root journalctl -n 100 --no-pager; pause ;;
            2) run_root journalctl -u ssh -u sshd -u sudo -n 100 --no-pager 2>/dev/null || run_root tail -100 /var/log/auth.log 2>/dev/null; pause ;;
            3) run_root dmesg | tail -50; pause ;;
            4) run_root journalctl -b --no-pager | tail -50; pause ;;
            5) run_root journalctl -p err -n 50 --no-pager; pause ;;
            6) run_root journalctl -f ;;
            0) return ;;
        esac
    done
}

system_settings_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» System Settings${C_RESET}"; hr
        echo -e "  Hostname: ${C_WHITE}$(hostname)${C_RESET}"
        echo -e "  Timezone: ${C_WHITE}$(timedatectl 2>/dev/null | grep 'Time zone' | awk '{print $3}' || cat /etc/timezone 2>/dev/null)${C_RESET}"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} Change hostname"; echo -e "  ${C_CYAN}2)${C_RESET} Change timezone"
        echo -e "  ${C_CYAN}3)${C_RESET} Enable/disable swap"; echo -e "  ${C_CYAN}4)${C_RESET} Create swap file"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"; hr; read -rp "Choice: " c
        case "$c" in
            1) read -rp "New hostname: " hn; [[ -n "$hn" ]] && run_root hostnamectl set-hostname "$hn" && ok "Hostname set."; pause ;;
            2) read -rp "Timezone (e.g. Asia/Tehran): " tz; [[ -n "$tz" ]] && run_root timedatectl set-timezone "$tz" && ok "Timezone set."; pause ;;
            3) if [[ $(swapon --show | wc -l) -gt 0 ]]; then
                   confirm "Swap on. Turn off?" && run_root swapoff -a && ok "Swap off."
               else confirm "Swap off. Turn on?" && run_root swapon -a && ok "Swap on."; fi; pause ;;
            4) read -rp "Swap size (e.g. 2G): " sz
               if [[ -n "$sz" ]]; then
                   run_root fallocate -l "$sz" /swapfile && run_root chmod 600 /swapfile && \
                   run_root mkswap /swapfile && run_root swapon /swapfile && \
                   echo "/swapfile none swap sw 0 0" | run_root tee -a /etc/fstab >/dev/null && ok "Swap $sz created."; fi
               pause ;;
            0) return ;;
        esac
    done
}

security_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_MAGENTA}» Security${C_RESET}"; hr
        echo -e "  ${C_CYAN}1)${C_RESET} Install & configure Fail2ban"
        echo -e "  ${C_CYAN}2)${C_RESET} Show failed login attempts"
        echo -e "  ${C_CYAN}3)${C_RESET} Show last logins"
        echo -e "  ${C_CYAN}4)${C_RESET} Audit open ports + processes"
        echo -e "  ${C_CYAN}5)${C_RESET} Setup unattended-upgrades (Debian)"
        echo -e "  ${C_CYAN}6)${C_RESET} Disable SSH password auth (key-only)"
        echo -e "  ${C_CYAN}0)${C_RESET} Back"; hr; read -rp "Choice: " c
        case "$c" in
            1) run_root $PKG_INSTALL fail2ban && run_root systemctl enable --now fail2ban && ok "Fail2ban running."; pause ;;
            2) run_root journalctl _COMM=sshd | grep -i 'failed\|invalid' | tail -30 2>/dev/null || run_root grep -i 'failed\|invalid' /var/log/auth.log 2>/dev/null | tail -30; pause ;;
            3) last -n 20; pause ;;
            4) run_root ss -tulnp; pause ;;
            5) [[ "$DISTRO_FAMILY" == "debian" ]] && run_root $PKG_INSTALL unattended-upgrades && run_root dpkg-reconfigure --priority=low unattended-upgrades || warn "Debian only."; pause ;;
            6) confirm "Make SURE you have working SSH keys first!" || { pause; return; }
               run_root cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"
               run_root sed -i -E 's/^\s*#?\s*PasswordAuthentication\s+.*/PasswordAuthentication no/' /etc/ssh/sshd_config
               grep -qE '^\s*PasswordAuthentication' /etc/ssh/sshd_config || echo "PasswordAuthentication no" | run_root tee -a /etc/ssh/sshd_config >/dev/null
               run_root sshd -t && run_root systemctl restart "$(ssh_service)" && ok "Password auth disabled."; pause ;;
            0) return ;;
        esac
    done
}

backup_helper() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Quick Backup${C_RESET}"; hr
    read -rp "Directory to back up: " src
    [[ ! -d "$src" ]] && { err "Not a directory."; pause; return; }
    read -rp "Destination (default /root/backups): " dst; dst="${dst:-/root/backups}"
    run_root mkdir -p "$dst"
    local name="backup-$(basename "$src")-$(date +%Y%m%d-%H%M%S).tar.gz"
    run_root tar -czf "$dst/$name" -C "$(dirname "$src")" "$(basename "$src")"
    ok "Backup: $dst/$name"; pause
}

root_recovery_help() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Root Password Recovery${C_RESET}"; hr
    cat <<'INNER_EOF'
GRUB METHOD:
  1. Reboot, press 'e' in GRUB on default entry
  2. Find line starting with 'linux', append:  rw init=/bin/bash
  3. Ctrl-X to boot, then:  passwd root  then reboot

CLOUD VPS:
  Use provider's "VNC console" / "rescue mode" in their panel.
  Boot rescue image, mount root partition, chroot, run passwd.
INNER_EOF
    pause
}

self_install() {
    banner; echo -e "${C_BOLD}${C_BLUE}» Install black-tools-pro globally${C_RESET}"; hr
    local src="${BASH_SOURCE[0]}"
    [[ ! -f "$src" ]] && { err "Cannot find source."; pause; return; }
    run_root cp "$src" "$INSTALL_PATH"; run_root chmod +x "$INSTALL_PATH"
    ok "Installed to $INSTALL_PATH"; info "Run anywhere: ${C_BOLD}black-tools-pro${C_RESET}"; pause
}

show_about() {
    banner; echo -e "${C_BOLD}${C_BLUE}» About black-tools PRO${C_RESET}"; hr
    cat <<INNER_EOF
  Version:  $VERSION
  Log file: $LOG_FILE
  Distro:   $DISTRO ($DISTRO_FAMILY)
  PkgMgr:   $PKG_MGR

  black-tools PRO — Extended admin toolkit covering:
    • System info, monitoring, diagnostics, logs
    • SSH (port, root, keys, key generation, copy-id)
    • Users (create / delete / password / lock)
    • Firewall (UFW / firewalld / iptables / nftables)
      — open/close ports, block IPs, rate-limit, save rules
    • Advanced Network:
      — static IPv4/IPv6, DNS, IP forwarding, routing
    • Cron job manager (add/edit/remove/logs)
    • Temporary download link (Python HTTP server)
    • tmux (sessions, attach, kill, keybindings)
    • Docker (containers, images, volumes, compose)
    • Software Installer:
      — Nginx, MySQL, MariaDB, PostgreSQL, MongoDB, Redis
      — Python, Node.js, Docker
      — 3x-ui (paqctl), Madmail, StormDNS
    • Services (systemd start/stop/enable/logs)
    • Disk (usage, cleanup, large files)
    • Security (fail2ban, audits, hardening)
    • System settings (hostname, timezone, swap)
    • System update / upgrade + package management
    • Backups
INNER_EOF
    pause
}

# ============================================================================
#  MAIN MENU
# ============================================================================
main_menu() {
    while true; do
        banner; echo -e "${C_BOLD}${C_GREEN}» MAIN MENU — black-tools PRO${C_RESET}"; hr
        echo -e "  ${C_CYAN} 1)${C_RESET} System info"
        echo -e "  ${C_CYAN} 2)${C_RESET} Top processes"
        echo -e "  ${C_CYAN} 3)${C_RESET} Live monitor (htop/top)"
        echo -e "  ${C_CYAN} 4)${C_RESET} System diagnostics"
        echo -e "  ${C_CYAN} 5)${C_RESET} View logs"
        hr
        echo -e "  ${C_CYAN} 6)${C_RESET} SSH management ${C_DIM}(port/root/keys/keygen)${C_RESET}"
        echo -e "  ${C_CYAN} 7)${C_RESET} User management"
        echo -e "  ${C_CYAN} 8)${C_RESET} Root recovery guide"
        echo -e "  ${C_CYAN} 9)${C_RESET} Firewall ${C_DIM}(UFW/iptables/nftables/firewalld)${C_RESET}"
        echo -e "  ${C_CYAN}10)${C_RESET} Listening ports"
        echo -e "  ${C_CYAN}11)${C_RESET} Check port status"
        echo -e "  ${C_CYAN}12)${C_RESET} Kill process"
        echo -e "  ${C_CYAN}13)${C_RESET} Service management"
        hr
        echo -e "  ${C_CYAN}14)${C_RESET} Disk & files"
        echo -e "  ${C_CYAN}15)${C_RESET} Network info (basic)"
        echo -e "  ${C_CYAN}16)${C_RESET} Advanced network ${C_DIM}(static IP/IPv4/IPv6/DNS/forwarding)${C_RESET}"
        echo -e "  ${C_CYAN}17)${C_RESET} System settings ${C_DIM}(hostname/timezone/swap)${C_RESET}"
        echo -e "  ${C_CYAN}18)${C_RESET} Security"
        echo -e "  ${C_CYAN}19)${C_RESET} Backup helper"
        hr
        echo -e "  ${C_CYAN}20)${C_RESET} Cron job manager"
        echo -e "  ${C_CYAN}21)${C_RESET} tmux"
        echo -e "  ${C_CYAN}22)${C_RESET} Temporary download link"
        echo -e "  ${C_CYAN}23)${C_RESET} Docker management"
        hr
        echo -e "  ${C_CYAN}24)${C_RESET} System update & upgrade"
        echo -e "  ${C_CYAN}25)${C_RESET} Install package (manual)"
        echo -e "  ${C_CYAN}26)${C_RESET} Remove package"
        echo -e "  ${C_CYAN}27)${C_RESET} Search package"
        echo -e "  ${C_CYAN}28)${C_RESET} Software Installer ${C_DIM}(Nginx/DB/Python/Node/Docker/Custom)${C_RESET}"
        hr
        echo -e "  ${C_CYAN}88)${C_RESET} Install black-tools-pro globally"
        echo -e "  ${C_CYAN}99)${C_RESET} About"
        echo -e "  ${C_RED} 0)${C_RESET} Exit"
        hr
        read -rp "$(echo -e "${C_BOLD}black-tools-pro >${C_RESET} ")" c
        case "$c" in
            1)  show_system_info ;;    2)  show_top_processes ;;   3)  live_monitor ;;
            4)  diagnostics ;;         5)  view_logs ;;
            6)  ssh_menu ;;            7)  user_menu ;;            8)  root_recovery_help ;;
            9)  firewall_menu ;;       10) list_listening_ports ;; 11) port_status_check ;;
            12) kill_process_menu ;;   13) service_menu ;;
            14) disk_menu ;;           15) network_info ;;         16) network_advanced_menu ;;
            17) system_settings_menu ;; 18) security_menu ;;       19) backup_helper ;;
            20) cron_menu ;;           21) tmux_menu ;;            22) temp_download_link ;;
            23) docker_menu ;;
            24) system_update ;;       25) install_package ;;      26) remove_package ;;
            27) search_package ;;      28) software_installer_menu ;;
            88) self_install ;;        99) show_about ;;
            0)  echo -e "${C_GREEN}Bye.${C_RESET}"; exit 0 ;;
            *)  warn "Invalid option."; sleep 1 ;;
        esac
    done
}

# ----------------------------- Entrypoint -----------------------------------
trap 'echo; echo -e "${C_RED}Interrupted.${C_RESET}"; exit 130' INT

case "${1:-}" in
    --install)   detect_distro; self_install; exit 0 ;;
    --uninstall) detect_distro; run_root rm -f "$INSTALL_PATH" && ok "Removed."; exit 0 ;;
    --version|-v) echo "black-tools-pro v$VERSION"; exit 0 ;;
    --help|-h)
        cat <<HELP_EOF
black-tools PRO v$VERSION — Advanced Linux Server Admin Toolkit

Usage:
  black-tools-pro              Launch interactive menu (after install)
  bash install_pro.sh          Run directly without installing
  bash install_pro.sh --install    Install as /usr/local/bin/black-tools-pro
  bash install_pro.sh --uninstall  Remove installation

Quick install (one-liner):
  curl -fsSL https://raw.githubusercontent.com/saeederamy/black-tools/main/install_pro.sh | sudo bash -s -- --install

Or if you have the file:
  cat install_pro.sh | sudo bash -s -- --install
HELP_EOF
        exit 0 ;;
esac

detect_distro
[[ "$DISTRO_FAMILY" == "unknown" ]] && { warn "Unknown distro ($DISTRO). Some features may not work."; sleep 1; }
main_menu
EOF
sudo chmod +x /usr/local/bin/black-tools-pro
echo "✓ black-tools installed. Run with:  black-tools-pro"
