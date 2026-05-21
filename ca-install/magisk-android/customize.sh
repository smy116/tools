#!/system/bin/sh

CERT_FILE="7c45bb5f.0"
CERT_NAME="SMY Root Certification Authority ECC"

print_line() {
    if command -v ui_print >/dev/null 2>&1; then
        ui_print "$1"
    else
        echo "$1"
    fi
}

print_line "- Installing ${CERT_NAME}"
print_line "- Android certificate file: ${CERT_FILE}"

if [ -n "$MODPATH" ] && [ -d "$MODPATH/system/etc/security/cacerts" ]; then
    if command -v set_perm_recursive >/dev/null 2>&1; then
        set_perm_recursive "$MODPATH/system/etc/security" 0 0 0755 0644 2>/dev/null || true
        set_perm_recursive "$MODPATH/system/etc/security/cacerts" 0 0 0755 0644 2>/dev/null || true
    else
        chmod 0755 "$MODPATH/system" "$MODPATH/system/etc" "$MODPATH/system/etc/security" "$MODPATH/system/etc/security/cacerts" 2>/dev/null || true
        chmod 0644 "$MODPATH/system/etc/security/cacerts/$CERT_FILE" 2>/dev/null || true
    fi

    if command -v set_perm >/dev/null 2>&1; then
        set_perm "$MODPATH/system/etc/security/cacerts/$CERT_FILE" 0 0 0644 2>/dev/null || true
    fi
fi

if [ -n "$MODPATH" ] && [ -f "$MODPATH/service.sh" ]; then
    if command -v set_perm >/dev/null 2>&1; then
        set_perm "$MODPATH/service.sh" 0 0 0755 2>/dev/null || true
    else
        chmod 0755 "$MODPATH/service.sh" 2>/dev/null || true
    fi
fi

print_line "- Reboot to activate the system CA"
