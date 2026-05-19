#!/usr/bin/env bash
set -euo pipefail

CERT_NAME="SMY Root Certification Authority ECC"
CERT_FILE_NAME="SMY-Root-CA.crt"

die() {
    echo "Error: $*" >&2
    exit 1
}

info() {
    echo "[ca-install] $*"
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

write_cert() {
    local target="$1"
    local target_dir
    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"

    cat > "$target" <<'CERTIFICATE'
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
CERTIFICATE

    chmod 0644 "$target"
}

install_with_update_ca_certificates() {
    has_command update-ca-certificates || die "update-ca-certificates was not found. Install ca-certificates first."

    local target="/usr/local/share/ca-certificates/$CERT_FILE_NAME"
    write_cert "$target"
    update-ca-certificates
    info "Installed certificate to $target"
}

install_with_update_ca_trust() {
    has_command update-ca-trust || die "update-ca-trust was not found. Install ca-certificates first."

    local target="/etc/pki/ca-trust/source/anchors/$CERT_FILE_NAME"
    write_cert "$target"
    update-ca-trust extract
    info "Installed certificate to $target"
}

install_openwrt() {
    local target="/etc/ssl/certs/$CERT_FILE_NAME"
    write_cert "$target"
    info "Installed certificate to $target"
}

to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

contains_os_word() {
    local needle="$1"
    local word

    for word in $OS_ID $OS_ID_LIKE; do
        if [[ "$word" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

if [[ "$(id -u)" -ne 0 ]]; then
    die "This script must be run as root. Re-run it with sudo."
fi

if [[ "$(uname -s)" != "Linux" ]]; then
    die "This installer only supports Linux."
fi

OS_ID=""
OS_ID_LIKE=""

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="$(to_lower "${ID:-}")"
    OS_ID_LIKE="$(to_lower "${ID_LIKE:-}")"
elif [[ -f /etc/openwrt_release ]]; then
    OS_ID="openwrt"
fi

info "Installing $CERT_NAME..."

if contains_os_word ubuntu || contains_os_word debian; then
    install_with_update_ca_certificates
elif contains_os_word centos || contains_os_word fedora || contains_os_word rhel; then
    install_with_update_ca_trust
elif contains_os_word alpine; then
    install_with_update_ca_certificates
elif contains_os_word openwrt; then
    install_openwrt
elif has_command update-ca-certificates; then
    install_with_update_ca_certificates
elif has_command update-ca-trust; then
    install_with_update_ca_trust
else
    die "Unsupported Linux distribution: ID=${OS_ID:-unknown}, ID_LIKE=${OS_ID_LIKE:-unknown}"
fi

info "$CERT_NAME has been installed."
