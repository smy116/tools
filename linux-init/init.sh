#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]:-$0}")"
SCRIPT_DIR=""
TMP_DIR=""

OS_ID="other"
OS_FAMILY="other"
OS_VERSION_CODENAME=""
PACKAGE_MANAGER=""
PACKAGE_CACHE_UPDATED=0

DEFAULT_SSH_PORT="54422"
SSH_PORT="${SMY_SSH_PORT:-$DEFAULT_SSH_PORT}"
PUBLIC_KEY="${SMY_PUBLIC_KEY:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETbOuKJEi5BUJXkCopshD/dfAKTOphKM9fqffCH5v+Y SMY}"
NEZHA_SERVER="${SMY_NEZHA_SERVER:-status.smy.me:443}"
ASSUME_YES="${SMY_ASSUME_YES:-0}"
DEFAULT_DOMAIN="${SMY_DOMAIN:-}"

FAKE_PAGE_URL="https://cdn.jsdelivr.net/gh/smy116/tools@main/linux-init/nginx/fake-page.tar.gz"
NGINX_CONF_URL="https://cdn.jsdelivr.net/gh/smy116/tools@main/linux-init/nginx/nginx.conf"
NEZHA_INSTALL_URL="https://cdn.jsdelivr.net/gh/nezhahq/scripts@main/agent/install.sh"

read -r -d '' SMY_ROOT_CA <<'EOF' || true
-----BEGIN CERTIFICATE-----
MIICSDCCAc6gAwIBAgIUM4jeRFYbyv7wkCJ9C+j8hHpGECEwCgYIKoZIzj0EAwMw
WjELMAkGA1UEBhMCQ04xDjAMBgNVBAgMBUh1bmFuMQwwCgYDVQQKDANTTVkxLTAr
BgNVBAMMJFNNWSBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IEVDQzAgFw0y
MzEyMjEwNzUyNDVaGA8yMTIyMTEyNzA3NTI0NVowWjELMAkGA1UEBhMCQ04xDjAM
BgNVBAgMBUh1bmFuMQwwCgYDVQQKDANTTVkxLTArBgNVBAMMJFNNWSBSb290IENl
cnRpZmljYXRpb24gQXV0aG9yaXR5IEVDQzB2MBAGByqGSM49AgEGBSuBBAAiA2IA
BBvH4Xa36MTKrnhBIyyUg/IxykVOwZhzVXzYPswPGOYYE9enmuqmdaN6lhXzduBT
5arxSCULpsrZ8lb/wxO6cEkJCa5E1acfgVRdno6JfdBxZd7WEw8J94mrbqw5mxPr
Q6NTMFEwHQYDVR0OBBYEFD5c06VwJKNCtzLpVCcd6HS8RtrKMB8GA1UdIwQYMBaA
FD5c06VwJKNCtzLpVCcd6HS8RtrKMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0E
AwMDaAAwZQIwWOC+QllECy76guWZNdQSDXO5sSUlo1JBwQVTbwDrtF2ABB7ptjgh
9/ILrkbq7rM5AjEA7pXuwkLz/hZUQM/RtNAsMkzbxqBUOwrxV9LJ0sWF4uQjxMu8
aSsoBsICQmAdfnx+
-----END CERTIFICATE-----
EOF

cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

supports_color() {
    [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]
}

if supports_color; then
    COLOR_RED="$(tput setaf 1)"
    COLOR_GREEN="$(tput setaf 2)"
    COLOR_YELLOW="$(tput setaf 3)"
    COLOR_BLUE="$(tput setaf 4)"
    COLOR_RESET="$(tput sgr0)"
else
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_RESET=""
fi

log() {
    printf '%s\n' "$*"
}

info() {
    printf '%s[INFO]%s %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$*"
}

success() {
    printf '%s[OK]%s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$*"
}

warn() {
    printf '%s[WARN]%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*" >&2
}

error() {
    printf '%s[ERROR]%s %s\n' "$COLOR_RED" "$COLOR_RESET" "$*" >&2
}

fail() {
    error "$*"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_yes() {
    case "${1:-}" in
        1|y|Y|yes|YES|true|TRUE|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

confirm() {
    local prompt="${1:-Continue?}"
    local default_answer="${2:-Y}"
    local answer=""

    if is_yes "$ASSUME_YES"; then
        return 0
    fi

    if [[ ! -t 0 ]]; then
        [[ "$default_answer" =~ ^[Yy]$ ]]
        return
    fi

    if [[ "$default_answer" =~ ^[Yy]$ ]]; then
        read -r -p "$prompt [Y/n]: " answer || answer=""
        answer="${answer:-Y}"
    else
        read -r -p "$prompt [y/N]: " answer || answer=""
        answer="${answer:-N}"
    fi

    [[ "$answer" =~ ^[Yy]$ ]]
}

need_root() {
    if [[ "$(id -u)" != "0" ]]; then
        fail "This script must be run as root."
    fi
}

set_script_dir() {
    local source_path="${BASH_SOURCE[0]:-$0}"

    case "$source_path" in
        /dev/fd/*|/proc/*/fd/*)
            SCRIPT_DIR=""
            return
            ;;
    esac

    if [[ -f "$source_path" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "$source_path")" && pwd -P)"
    else
        SCRIPT_DIR=""
    fi
}

ensure_tmp_dir() {
    if [[ -z "${TMP_DIR:-}" ]]; then
        TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/smy-init.XXXXXX")"
    fi
}

detect_os() {
    OS_ID="other"
    OS_FAMILY="other"
    OS_VERSION_CODENAME=""
    PACKAGE_MANAGER=""

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-other}"
        OS_VERSION_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
    elif command_exists opkg; then
        OS_ID="openwrt"
    elif [[ -f /etc/alpine-release ]]; then
        OS_ID="alpine"
    elif [[ -f /etc/redhat-release ]]; then
        OS_ID="rhel"
    fi

    case "$OS_ID" in
        ubuntu)
            OS_FAMILY="debian"
            PACKAGE_MANAGER="apt-get"
            ;;
        debian|raspbian)
            OS_ID="debian"
            OS_FAMILY="debian"
            PACKAGE_MANAGER="apt-get"
            ;;
        alpine)
            OS_FAMILY="alpine"
            PACKAGE_MANAGER="apk"
            ;;
        openwrt)
            OS_FAMILY="openwrt"
            PACKAGE_MANAGER="opkg"
            ;;
        centos|rhel|rocky|almalinux|fedora|ol)
            OS_FAMILY="rhel"
            if command_exists dnf; then
                PACKAGE_MANAGER="dnf"
            else
                PACKAGE_MANAGER="yum"
            fi
            ;;
        *)
            if command_exists opkg; then
                OS_ID="openwrt"
                OS_FAMILY="openwrt"
                PACKAGE_MANAGER="opkg"
            elif command_exists apk; then
                OS_ID="alpine"
                OS_FAMILY="alpine"
                PACKAGE_MANAGER="apk"
            elif command_exists apt-get; then
                OS_FAMILY="debian"
                PACKAGE_MANAGER="apt-get"
            elif command_exists dnf; then
                OS_FAMILY="rhel"
                PACKAGE_MANAGER="dnf"
            elif command_exists yum; then
                OS_FAMILY="rhel"
                PACKAGE_MANAGER="yum"
            else
                OS_FAMILY="other"
                PACKAGE_MANAGER=""
            fi
            ;;
    esac
}

require_supported_package_manager() {
    if [[ -z "$PACKAGE_MANAGER" ]]; then
        fail "No supported package manager was found on this system."
    fi
}

pkg_update() {
    require_supported_package_manager

    case "$PACKAGE_MANAGER" in
        apt-get)
            apt-get update
            ;;
        dnf)
            dnf makecache -y
            ;;
        yum)
            yum makecache -y
            ;;
        apk)
            apk update
            ;;
        opkg)
            opkg update
            ;;
        *)
            fail "Unsupported package manager: $PACKAGE_MANAGER"
            ;;
    esac
}

pkg_update_once() {
    if [[ "$PACKAGE_CACHE_UPDATED" -eq 0 ]]; then
        info "Refreshing package metadata..."
        if pkg_update; then
            PACKAGE_CACHE_UPDATED=1
        else
            warn "Package metadata refresh failed. Continuing where possible."
        fi
    fi
}

pkg_update_force() {
    info "Refreshing package metadata..."
    if pkg_update; then
        PACKAGE_CACHE_UPDATED=1
    else
        fail "Package metadata refresh failed."
    fi
}

pkg_install() {
    require_supported_package_manager

    if [[ "$#" -eq 0 ]]; then
        return 0
    fi

    case "$PACKAGE_MANAGER" in
        apt-get)
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
            ;;
        dnf)
            dnf install -y "$@"
            ;;
        yum)
            yum install -y "$@"
            ;;
        apk)
            apk add --no-cache "$@"
            ;;
        opkg)
            opkg install "$@"
            ;;
        *)
            fail "Unsupported package manager: $PACKAGE_MANAGER"
            ;;
    esac
}

try_install_packages() {
    if [[ "$#" -eq 0 ]]; then
        return 0
    fi

    pkg_update_once
    if pkg_install "$@"; then
        return 0
    fi

    return 1
}

ensure_command_with_package() {
    local command_name="$1"
    shift

    if command_exists "$command_name"; then
        return 0
    fi

    if [[ "$#" -gt 0 ]]; then
        info "Installing dependency for command: $command_name"
        if ! try_install_packages "$@"; then
            fail "Failed to install dependency for command: $command_name"
        fi
    fi

    command_exists "$command_name" || fail "Required command is not available: $command_name"
}

ensure_download_tool() {
    if command_exists curl || command_exists wget; then
        return 0
    fi

    info "Installing a download tool..."
    if ! try_install_packages curl; then
        warn "Failed to install curl. Trying wget..."
        try_install_packages wget || true
    fi

    command_exists curl || command_exists wget || fail "Neither curl nor wget is available."
}

download_file() {
    local url="$1"
    local output="$2"

    ensure_download_tool

    if command_exists curl; then
        curl -fsSL --retry 3 --connect-timeout 15 -o "$output" "$url"
        return
    fi

    wget -q -O "$output" "$url"
}

install_common_dependencies() {
    local packages=()

    if ! command_exists tar; then
        packages+=("tar")
    fi
    if ! command_exists openssl; then
        if [[ "$OS_FAMILY" == "openwrt" ]]; then
            packages+=("openssl-util")
        else
            packages+=("openssl")
        fi
    fi
    if ! command_exists curl && ! command_exists wget; then
        packages+=("curl")
    fi

    if [[ "${#packages[@]}" -gt 0 ]]; then
        info "Installing common dependencies..."
        if ! try_install_packages "${packages[@]}"; then
            warn "Some common dependencies could not be installed. Commands that need them may fail."
        fi
    fi
}

backup_file() {
    local file_path="$1"
    local backup_path=""

    if [[ ! -e "$file_path" ]]; then
        return 0
    fi

    backup_path="${file_path}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "$file_path" "$backup_path"
    printf '%s\n' "$backup_path"
}

append_line_once() {
    local file_path="$1"
    local line="$2"

    touch "$file_path"
    if ! grep -qxF "$line" "$file_path"; then
        printf '%s\n' "$line" >> "$file_path"
    fi
}

set_shell_variable() {
    local file_path="$1"
    local key="$2"
    local value="$3"

    touch "$file_path"
    if grep -q "^${key}=" "$file_path"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file_path"
    else
        printf '\n%s=%s\n' "$key" "$value" >> "$file_path"
    fi
}

set_sshd_option() {
    local file_path="$1"
    local key="$2"
    local value="$3"

    if grep -q "^[#[:space:]]*${key}[[:space:]]" "$file_path"; then
        sed -i "s|^[#[:space:]]*${key}[[:space:]].*|${key} ${value}|" "$file_path"
    else
        printf '\n%s %s\n' "$key" "$value" >> "$file_path"
    fi
}

find_sshd_binary() {
    if command_exists sshd; then
        command -v sshd
        return
    fi

    if [[ -x /usr/sbin/sshd ]]; then
        printf '%s\n' "/usr/sbin/sshd"
        return
    fi

    if [[ -x /usr/local/sbin/sshd ]]; then
        printf '%s\n' "/usr/local/sbin/sshd"
        return
    fi

    return 1
}

validate_sshd_config() {
    local config_path="$1"
    local sshd_binary=""

    if ! sshd_binary="$(find_sshd_binary)"; then
        warn "OpenSSH server binary was not found. Skipping sshd config validation."
        return 0
    fi

    mkdir -p /run/sshd 2>/dev/null || true
    "$sshd_binary" -t -f "$config_path"
}

service_action() {
    local service_name="$1"
    local action="$2"

    if command_exists systemctl && [[ -d /run/systemd/system ]]; then
        systemctl "$action" "$service_name"
        return
    fi

    if command_exists rc-service; then
        rc-service "$service_name" "$action"
        return
    fi

    if command_exists service; then
        service "$service_name" "$action"
        return
    fi

    if [[ -x "/etc/init.d/$service_name" ]]; then
        "/etc/init.d/$service_name" "$action"
        return
    fi

    return 1
}

service_enable() {
    local service_name="$1"

    if command_exists systemctl && [[ -d /run/systemd/system ]]; then
        systemctl enable "$service_name"
        return
    fi

    if command_exists rc-update; then
        rc-update add "$service_name" default
        return
    fi

    if [[ -x "/etc/init.d/$service_name" ]]; then
        "/etc/init.d/$service_name" enable
        return
    fi

    return 1
}

restart_first_available_service() {
    local service_name=""

    for service_name in "$@"; do
        if service_action "$service_name" restart >/dev/null 2>&1; then
            success "Restarted service: $service_name"
            return 0
        fi
    done

    warn "No matching service could be restarted: $*"
    return 1
}

start_and_enable_service() {
    local service_name="$1"

    if service_enable "$service_name" >/dev/null 2>&1; then
        success "Enabled service: $service_name"
    else
        warn "Could not enable service automatically: $service_name"
    fi

    if service_action "$service_name" start >/dev/null 2>&1; then
        success "Started service: $service_name"
    else
        warn "Could not start service automatically: $service_name"
    fi
}

get_debian_codename() {
    if [[ -n "$OS_VERSION_CODENAME" ]]; then
        printf '%s\n' "$OS_VERSION_CODENAME"
        return
    fi

    if command_exists lsb_release; then
        lsb_release -cs
        return
    fi

    fail "Could not detect Debian/Ubuntu codename."
}

install_ca_certificates_package() {
    case "$OS_FAMILY" in
        debian|rhel|alpine)
            try_install_packages ca-certificates || fail "Failed to install ca-certificates."
            ;;
        openwrt)
            try_install_packages ca-certificates || warn "Could not install ca-certificates on OpenWrt."
            ;;
        *)
            warn "Skipping ca-certificates package install for unsupported OS family: $OS_FAMILY"
            ;;
    esac
}

set_timezone() {
    local zone_name="Asia/Shanghai"
    local zone_file="/usr/share/zoneinfo/$zone_name"
    local current_zone=""

    current_zone="$(date +%z 2>/dev/null || true)"
    if [[ "$current_zone" == "+0800" ]]; then
        success "The current time zone is already UTC+8: $(date -R)"
        return 0
    fi

    if command_exists timedatectl && [[ -d /run/systemd/system ]]; then
        timedatectl set-timezone "$zone_name"
        success "Time zone has been set to $zone_name."
        return 0
    fi

    if [[ ! -f "$zone_file" && "$OS_FAMILY" != "openwrt" ]]; then
        warn "Zoneinfo file is missing. Trying to install tzdata..."
        try_install_packages tzdata || true
    fi

    if [[ -f "$zone_file" ]]; then
        if [[ -e /etc/localtime ]]; then
            backup_file /etc/localtime >/dev/null || true
        fi
        cp "$zone_file" /etc/localtime
        printf '%s\n' "$zone_name" > /etc/timezone 2>/dev/null || true
        success "Time zone has been set to $zone_name: $(date -R)"
        return 0
    fi

    if [[ "$OS_FAMILY" == "openwrt" && -f /etc/config/system ]] && command_exists uci; then
        uci set system.@system[0].zonename="$zone_name"
        uci set system.@system[0].timezone="CST-8"
        uci commit system
        service_action system reload >/dev/null 2>&1 || true
        success "OpenWrt time zone has been set to $zone_name."
        return 0
    fi

    fail "Could not set time zone because $zone_file is not available."
}

install_public_key_for_openssh() {
    local ssh_dir="/root/.ssh"
    local keys_file="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    append_line_once "$keys_file" "$PUBLIC_KEY"
    chmod 600 "$keys_file"
    success "SSH public key has been installed for OpenSSH."
}

install_public_key_for_dropbear() {
    local dropbear_dir="/etc/dropbear"
    local keys_file="$dropbear_dir/authorized_keys"

    mkdir -p "$dropbear_dir"
    chmod 700 "$dropbear_dir"
    append_line_once "$keys_file" "$PUBLIC_KEY"
    chmod 600 "$keys_file"
    success "SSH public key has been installed for Dropbear."
}

install_public_key() {
    local installed=0

    if [[ -f /etc/ssh/sshd_config || -d /etc/ssh ]]; then
        install_public_key_for_openssh
        installed=1
    fi

    if [[ -d /etc/dropbear || -f /etc/config/dropbear || -f /etc/default/dropbear ]] || command_exists dropbear; then
        install_public_key_for_dropbear
        installed=1
    fi

    if [[ "$installed" -eq 0 ]]; then
        install_public_key_for_openssh
    fi
}

configure_openssh_authentication() {
    local config_path="/etc/ssh/sshd_config"
    local backup_path=""

    if [[ ! -f "$config_path" ]]; then
        warn "OpenSSH config was not found. Skipping OpenSSH authentication hardening."
        return 0
    fi

    backup_path="$(backup_file "$config_path" || true)"

    set_sshd_option "$config_path" "PermitRootLogin" "yes"
    set_sshd_option "$config_path" "PubkeyAuthentication" "yes"
    set_sshd_option "$config_path" "PasswordAuthentication" "no"
    set_sshd_option "$config_path" "KbdInteractiveAuthentication" "no"
    set_sshd_option "$config_path" "ChallengeResponseAuthentication" "no"

    if validate_sshd_config "$config_path"; then
        success "OpenSSH authentication settings have been updated."
    else
        if [[ -n "$backup_path" && -f "$backup_path" ]]; then
            cp "$backup_path" "$config_path"
        fi
        fail "OpenSSH config validation failed. The previous config was restored."
    fi
}

configure_openwrt_dropbear_authentication() {
    if [[ -f /etc/config/dropbear ]] && command_exists uci; then
        backup_file /etc/config/dropbear >/dev/null || true
        uci set dropbear.@dropbear[0].PasswordAuth='off' || true
        uci set dropbear.@dropbear[0].RootPasswordAuth='off' || true
        uci commit dropbear || true
        success "OpenWrt Dropbear password authentication has been disabled."
    fi
}

set_root_password() {
    local root_password="${1:-}"

    if [[ -n "$root_password" ]]; then
        if ! command_exists chpasswd; then
            case "$OS_FAMILY" in
                alpine)
                    ensure_command_with_package chpasswd shadow
                    ;;
                openwrt)
                    if ! try_install_packages shadow-chpasswd; then
                        fail "Failed to install chpasswd for OpenWrt."
                    fi
                    command_exists chpasswd || fail "Required command is not available: chpasswd"
                    ;;
                *)
                    ensure_command_with_package chpasswd passwd
                    ;;
            esac
        fi
        printf 'root:%s\n' "$root_password" | chpasswd
        success "Root password has been updated."
        return 0
    fi

    if [[ ! -t 0 ]]; then
        fail "Root password is required in non-interactive mode."
    fi

    passwd root
    success "Root password has been updated."
}

configure_root_login() {
    local root_password="${1:-}"

    set_root_password "$root_password"
    install_public_key
    configure_openssh_authentication
    configure_openwrt_dropbear_authentication
    restart_first_available_service sshd ssh dropbear >/dev/null 2>&1 || warn "Please restart SSH manually."
    success "Root SSH access has been configured."
}

change_ssh_port() {
    local should_restart="${1:-1}"
    local changed=0
    local config_path=""
    local backup_path=""

    if [[ -f /etc/config/dropbear ]] && command_exists uci; then
        backup_file /etc/config/dropbear >/dev/null || true
        uci set dropbear.@dropbear[0].Port="$SSH_PORT"
        uci commit dropbear
        changed=1
        success "OpenWrt Dropbear SSH port has been set to $SSH_PORT."
        if [[ "$should_restart" == "1" ]]; then
            restart_first_available_service dropbear >/dev/null 2>&1 || warn "Please restart Dropbear manually."
        fi
    elif [[ -f /etc/default/dropbear ]]; then
        config_path="/etc/default/dropbear"
        backup_file "$config_path" >/dev/null || true
        set_shell_variable "$config_path" "DROPBEAR_PORT" "$SSH_PORT"
        changed=1
        success "Dropbear SSH port has been set to $SSH_PORT."
        if [[ "$should_restart" == "1" ]]; then
            restart_first_available_service dropbear >/dev/null 2>&1 || warn "Please restart Dropbear manually."
        fi
    elif [[ -f /etc/ssh/sshd_config ]]; then
        config_path="/etc/ssh/sshd_config"
        backup_path="$(backup_file "$config_path" || true)"
        set_sshd_option "$config_path" "Port" "$SSH_PORT"

        if validate_sshd_config "$config_path"; then
            changed=1
            success "OpenSSH port has been set to $SSH_PORT."
            if [[ "$should_restart" == "1" ]]; then
                restart_first_available_service sshd ssh >/dev/null 2>&1 || warn "Please restart OpenSSH manually."
            fi
        else
            if [[ -n "$backup_path" && -f "$backup_path" ]]; then
                cp "$backup_path" "$config_path"
            fi
            fail "OpenSSH config validation failed. The previous config was restored."
        fi
    fi

    if [[ "$changed" -eq 0 ]]; then
        fail "No supported SSH server configuration was found."
    fi
}

install_ca() {
    local target_path=""

    install_ca_certificates_package

    case "$OS_FAMILY" in
        debian|alpine)
            target_path="/usr/local/share/ca-certificates/SMY-Root-CA.crt"
            mkdir -p "$(dirname "$target_path")"
            printf '%s\n' "$SMY_ROOT_CA" > "$target_path"
            update-ca-certificates
            ;;
        rhel)
            target_path="/etc/pki/ca-trust/source/anchors/SMY-Root-CA.crt"
            mkdir -p "$(dirname "$target_path")"
            printf '%s\n' "$SMY_ROOT_CA" > "$target_path"
            update-ca-trust enable >/dev/null 2>&1 || true
            update-ca-trust extract
            ;;
        openwrt)
            target_path="/etc/ssl/certs/SMY-Root-CA.crt"
            mkdir -p "$(dirname "$target_path")"
            printf '%s\n' "$SMY_ROOT_CA" > "$target_path"
            if command_exists update-ca-certificates; then
                update-ca-certificates || warn "OpenWrt certificate refresh failed."
            fi
            ;;
        *)
            fail "Unsupported OS family for CA installation: $OS_FAMILY"
            ;;
    esac

    success "SMY Root CA has been installed."
}

install_nezha() {
    local client_secret="${1:-}"
    local installer_path=""

    if [[ -z "$client_secret" ]]; then
        if [[ -n "${SMY_NEZHA_CLIENT_SECRET:-}" ]]; then
            client_secret="$SMY_NEZHA_CLIENT_SECRET"
        elif [[ -t 0 ]]; then
            read -r -p "Enter the Nezha client secret: " client_secret || client_secret=""
        fi
    fi

    if [[ -z "$client_secret" ]]; then
        fail "Nezha client secret is required."
    fi

    ensure_tmp_dir
    installer_path="$TMP_DIR/nezha-agent-install.sh"
    info "Downloading Nezha agent installer..."
    download_file "$NEZHA_INSTALL_URL" "$installer_path"
    chmod +x "$installer_path"

    info "Installing Nezha agent..."
    env \
        NZ_SERVER="$NEZHA_SERVER" \
        NZ_TLS="true" \
        NZ_CLIENT_SECRET="$client_secret" \
        NZ_DISABLE_COMMAND_EXECUTE="true" \
        "$installer_path"

    success "Nezha agent installer finished."
}

install_fake_page() {
    local web_root="$1"
    local archive_path=""
    local local_archive=""

    mkdir -p "$web_root"
    ensure_command_with_package tar tar
    ensure_tmp_dir

    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/nginx/fake-page.tar.gz" ]]; then
        local_archive="$SCRIPT_DIR/nginx/fake-page.tar.gz"
        archive_path="$local_archive"
    else
        archive_path="$TMP_DIR/fake-page.tar.gz"
        if ! download_file "$FAKE_PAGE_URL" "$archive_path"; then
            warn "Failed to download the default web page package. Skipping it."
            return 0
        fi
    fi

    if tar -zxf "$archive_path" -C "$web_root"; then
        success "Default web page has been installed to $web_root."
    else
        warn "Failed to extract the default web page package."
    fi
}

ensure_dhparam() {
    local dhparam_path="/etc/ssl/certs/dhparam.pem"

    if [[ -s "$dhparam_path" ]]; then
        success "Existing DH parameters found: $dhparam_path"
        return 0
    fi

    if ! command_exists openssl; then
        if [[ "$OS_FAMILY" == "openwrt" ]]; then
            ensure_command_with_package openssl openssl-util
        else
            ensure_command_with_package openssl openssl
        fi
    fi
    mkdir -p "$(dirname "$dhparam_path")"
    info "Generating DH parameters. This may take a while..."
    openssl dhparam -out "$dhparam_path" 2048
    success "DH parameters have been generated."
}

install_nginx_config() {
    local target_path="/etc/nginx/nginx.conf"
    local local_config=""

    mkdir -p /etc/nginx

    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/nginx/nginx.conf" ]]; then
        local_config="$SCRIPT_DIR/nginx/nginx.conf"
        cp "$local_config" "$target_path"
        success "Nginx config has been installed from local bundle."
        return 0
    fi

    info "Downloading Nginx config..."
    if download_file "$NGINX_CONF_URL" "$target_path"; then
        success "Nginx config has been downloaded."
    else
        warn "Failed to download Nginx config."
    fi
}

install_nginx_debian_repo() {
    local codename=""
    local key_file=""
    local keyring_tmp=""
    local distro_path="$OS_ID"
    local keyring_package="debian-archive-keyring"

    if [[ "$distro_path" == "ubuntu" ]]; then
        keyring_package="ubuntu-keyring"
    else
        distro_path="debian"
    fi

    try_install_packages curl gnupg ca-certificates lsb-release "$keyring_package" || true
    ensure_command_with_package gpg gnupg
    ensure_tmp_dir
    mkdir -p /usr/share/keyrings /etc/apt/sources.list.d

    codename="$(get_debian_codename)"
    key_file="$TMP_DIR/nginx_signing.key"
    keyring_tmp="$TMP_DIR/nginx-archive-keyring.gpg"

    download_file "https://nginx.org/keys/nginx_signing.key" "$key_file"
    gpg --dearmor -o "$keyring_tmp" "$key_file"
    install -m 0644 "$keyring_tmp" /usr/share/keyrings/nginx-archive-keyring.gpg

    printf 'deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/%s/ %s nginx\n' \
        "$distro_path" "$codename" > /etc/apt/sources.list.d/nginx.list

    pkg_update_force
    pkg_install nginx
}

install_nginx_rhel_repo() {
    mkdir -p /etc/yum.repos.d
    cat > /etc/yum.repos.d/nginx.repo <<'EOF'
[nginx-stable]
name=nginx stable repository
baseurl=https://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
    pkg_update_force
    pkg_install nginx
}

install_nginx_alpine_repo() {
    local alpine_version=""
    local repo_line=""
    local key_path="/etc/apk/keys/nginx_signing.rsa.pub"

    try_install_packages ca-certificates curl openssl || true
    mkdir -p /etc/apk/keys
    alpine_version="$(cut -d '.' -f 1-2 /etc/alpine-release)"
    repo_line="http://nginx.org/packages/alpine/v${alpine_version}/main"

    if ! grep -qxF "$repo_line" /etc/apk/repositories; then
        printf '%s\n' "$repo_line" >> /etc/apk/repositories
    fi

    download_file "https://nginx.org/keys/nginx_signing.rsa.pub" "$key_path"
    pkg_update_force
    pkg_install nginx
}

install_nginx_openwrt_package() {
    pkg_update_once
    if ! pkg_install nginx; then
        warn "Package nginx was not available. Trying nginx-ssl..."
        pkg_install nginx-ssl
    fi
}

install_nginx_package() {
    case "$OS_FAMILY" in
        debian)
            install_nginx_debian_repo
            ;;
        rhel)
            install_nginx_rhel_repo
            ;;
        alpine)
            install_nginx_alpine_repo
            ;;
        openwrt)
            install_nginx_openwrt_package
            ;;
        *)
            fail "Unsupported OS family for Nginx installation: $OS_FAMILY"
            ;;
    esac
}

install_nginx() {
    info "Installing Nginx..."
    install_nginx_package
    mkdir -p /usr/share/nginx/acme-challenge /usr/share/nginx/html
    install_fake_page /usr/share/nginx/html
    ensure_dhparam
    install_nginx_config
    start_and_enable_service nginx
    success "Nginx installation finished."
}

install_caddy_debian_repo() {
    local key_file=""
    local keyring_tmp=""
    local source_file=""

    try_install_packages curl gnupg debian-keyring debian-archive-keyring apt-transport-https ca-certificates || true
    ensure_command_with_package gpg gnupg
    ensure_tmp_dir
    mkdir -p /usr/share/keyrings /etc/apt/sources.list.d

    key_file="$TMP_DIR/caddy-stable-gpg.key"
    keyring_tmp="$TMP_DIR/caddy-stable-archive-keyring.gpg"
    source_file="$TMP_DIR/caddy-stable.list"

    download_file "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" "$key_file"
    gpg --dearmor -o "$keyring_tmp" "$key_file"
    install -m 0644 "$keyring_tmp" /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    download_file "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" "$source_file"
    install -m 0644 "$source_file" /etc/apt/sources.list.d/caddy-stable.list

    pkg_update_force
    pkg_install caddy
}

install_caddy_rhel_repo() {
    if [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        try_install_packages 'dnf-command(copr)' || true
        dnf copr enable -y @caddy/caddy
        pkg_update_force
        pkg_install caddy
        return
    fi

    try_install_packages yum-plugin-copr || true
    yum copr enable -y @caddy/caddy
    pkg_update_force
    pkg_install caddy
}

install_caddy_package() {
    case "$OS_FAMILY" in
        debian)
            install_caddy_debian_repo
            ;;
        rhel)
            install_caddy_rhel_repo
            ;;
        alpine|openwrt)
            pkg_update_once
            pkg_install caddy
            ;;
        *)
            fail "Unsupported OS family for Caddy installation: $OS_FAMILY"
            ;;
    esac
}

validate_domain() {
    local domain_name="$1"

    if [[ -z "$domain_name" ]]; then
        fail "Domain name cannot be empty."
    fi

    case "$domain_name" in
        *[!A-Za-z0-9.-]*|.*|*-|*..*|*.)
            fail "Domain name contains unsupported characters: $domain_name"
            ;;
    esac
}

create_caddy_config() {
    local domain_name="${1:-}"

    if [[ -z "$domain_name" ]]; then
        domain_name="$DEFAULT_DOMAIN"
    fi

    if [[ -z "$domain_name" && -t 0 ]]; then
        read -r -p "Enter the domain name for Caddy: " domain_name || domain_name=""
    fi

    validate_domain "$domain_name"

    mkdir -p /etc/caddy /usr/share/nginx/html
    install_fake_page /usr/share/nginx/html

    cat > /etc/caddy/Caddyfile <<EOF
{
    admin off
}

http://$domain_name {
    redir https://{host}{uri}
}

$domain_name {
    root * /usr/share/nginx/html
    file_server
    encode gzip
    header {
        -Server
    }
}
EOF

    success "Caddy config has been written for $domain_name."
}

install_caddy() {
    local domain_name="${1:-}"

    info "Installing Caddy..."
    install_caddy_package
    create_caddy_config "$domain_name"
    start_and_enable_service caddy
    success "Caddy installation finished."
}

show_help() {
    cat <<EOF
SMY Linux initialization script

Usage:
  $SCRIPT_NAME
  $SCRIPT_NAME help
  $SCRIPT_NAME timezone
  $SCRIPT_NAME ca
  $SCRIPT_NAME sshport
  $SCRIPT_NAME root <root-password>
  $SCRIPT_NAME nezha <nezha-client-secret>
  $SCRIPT_NAME nginx
  $SCRIPT_NAME caddy [domain]

Environment overrides:
  SMY_SSH_PORT       SSH port to configure. Default: $DEFAULT_SSH_PORT
  SMY_PUBLIC_KEY     SSH public key to install for root.
  SMY_NEZHA_SERVER   Nezha server address. Default: status.smy.me:443
  SMY_DOMAIN         Default domain for Caddy.
  SMY_ASSUME_YES     Set to 1 to answer yes to confirmation prompts.

Supported systems:
  Debian, Ubuntu, Alpine, OpenWrt, CentOS, RHEL, Rocky Linux, AlmaLinux, Fedora
EOF
}

pause_after_action() {
    local answer=""

    if [[ ! -t 0 ]]; then
        return 0
    fi

    read -r -p "Press Enter to return to the menu, or type q to quit: " answer || answer=""
    case "$answer" in
        q|Q)
            exit 0
            ;;
    esac
}

show_menu_header() {
    clear || true
    log "================================================================="
    log "SMY one-click deployment script"
    log "Supported: Debian / Ubuntu / OpenWrt / Alpine / RHEL family"
    log "Detected system: $OS_ID ($OS_FAMILY)"
    log "================================================================="
    log ""
}

start_menu() {
    local menu_choice=""

    while true; do
        show_menu_header
        log " 1. Set the time zone to UTC+8"
        log " 2. Configure SSH public key and root account"
        log " 3. Set SSH port to $SSH_PORT"
        log " 4. Install SMY Root Certification Authority"
        log " 5. Install Nezha agent"
        log " 6. Install Nginx"
        log " 7. Install Caddy"
        log " 8. Reboot system"
        log " 0. Exit"
        log ""

        read -r -p "Please input number: " menu_choice || menu_choice=""

        case "$menu_choice" in
            1)
                set_timezone
                pause_after_action
                ;;
            2)
                configure_root_login ""
                pause_after_action
                ;;
            3)
                change_ssh_port 1
                pause_after_action
                ;;
            4)
                install_ca
                warn "A reboot may be required for all applications to trust the new CA."
                pause_after_action
                ;;
            5)
                install_nezha ""
                pause_after_action
                ;;
            6)
                install_nginx
                pause_after_action
                ;;
            7)
                install_caddy ""
                pause_after_action
                ;;
            8)
                if confirm "Reboot the system now?" "N"; then
                    reboot
                fi
                pause_after_action
                ;;
            0)
                exit 0
                ;;
            *)
                warn "Please enter a valid option."
                sleep 1
                ;;
        esac
    done
}

prepare_runtime() {
    need_root
    detect_os
    install_common_dependencies
}

main() {
    local subcommand="${1:-menu}"

    set_script_dir

    case "$subcommand" in
        help|-h|--help)
            show_help
            exit 0
            ;;
    esac

    prepare_runtime

    case "$subcommand" in
        menu|"")
            start_menu
            ;;
        timezone)
            set_timezone
            ;;
        ca)
            install_ca
            ;;
        sshport)
            change_ssh_port 1
            ;;
        root)
            if [[ -z "${2:-}" ]]; then
                fail "Usage: $SCRIPT_NAME root <root-password>"
            fi
            configure_root_login "$2"
            ;;
        nezha)
            if [[ -z "${2:-}" ]]; then
                fail "Usage: $SCRIPT_NAME nezha <nezha-client-secret>"
            fi
            install_nezha "$2"
            ;;
        nginx)
            install_nginx
            ;;
        caddy)
            install_caddy "${2:-}"
            ;;
        *)
            show_help
            fail "Unknown command: $subcommand"
            ;;
    esac
}

main "$@"
