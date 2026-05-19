#!/usr/bin/env bash
set -euo pipefail

CERT_NAME="SMY Root Certification Authority ECC"
CERT_FILE_NAME="SMY-Root-CA.crt"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This installer only supports macOS." >&2
    exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
    echo "This script must be run as root. Re-run it with sudo." >&2
    exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
cert_path="${tmp_dir}/${CERT_FILE_NAME}"

cat > "$cert_path" <<'CERTIFICATE'
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

chmod 0644 "$cert_path"

echo "Installing $CERT_NAME..."
security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$cert_path"
echo "$CERT_NAME has been installed."
