#!/system/bin/sh

MODDIR=${0%/*}
CERT_FILE="7c45bb5f.0"
MOD_CERT="$MODDIR/system/etc/security/cacerts/$CERT_FILE"
SYS_CERT_DIR="/system/etc/security/cacerts"
APEX_CERT_DIR="/apex/com.android.conscrypt/cacerts"
TMP_CERT_DIR="$MODDIR/runtime-cacerts"
LOG_FILE="$MODDIR/service.log"
NSENTER_AVAILABLE=0

log_msg() {
    echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG_FILE" 2>/dev/null
}

copy_regular_files() {
    src="$1"
    dst="$2"

    [ -d "$src" ] || return 0
    mkdir -p "$dst" 2>/dev/null || return 1

    for file in "$src"/*; do
        [ -f "$file" ] || continue
        cp -f "$file" "$dst/" 2>/dev/null || log_msg "Failed to copy $file to $dst"
    done
}

apply_cert_permissions() {
    dir="$1"

    [ -d "$dir" ] || return 1
    chown 0:0 "$dir" "$dir"/* 2>/dev/null || true
    chmod 0755 "$dir" 2>/dev/null || true
    chmod 0644 "$dir"/* 2>/dev/null || true

    if command -v chcon >/dev/null 2>&1; then
        chcon u:object_r:system_security_cacerts_file:s0 "$dir" "$dir"/* 2>/dev/null ||
            chcon u:object_r:system_file:s0 "$dir" "$dir"/* 2>/dev/null ||
            true
    fi
}

wait_for_boot_completed() {
    until [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ]; do
        sleep 2
    done
}

prepare_runtime_store() {
    [ -d "$APEX_CERT_DIR" ] || return 1
    [ -d "$SYS_CERT_DIR" ] || return 1
    [ -f "$MOD_CERT" ] || {
        log_msg "Missing module certificate: $MOD_CERT"
        return 1
    }

    mkdir -p "$TMP_CERT_DIR" 2>/dev/null || return 1
    rm -f "$TMP_CERT_DIR"/* 2>/dev/null || true

    log_msg "Collecting APEX certificates"
    copy_regular_files "$APEX_CERT_DIR" "$TMP_CERT_DIR"

    log_msg "Collecting system certificates"
    copy_regular_files "$SYS_CERT_DIR" "$TMP_CERT_DIR"

    cp -f "$MOD_CERT" "$TMP_CERT_DIR/$CERT_FILE" 2>/dev/null || {
        log_msg "Failed to stage $CERT_FILE"
        return 1
    }

    if ! mount -t tmpfs tmpfs "$SYS_CERT_DIR" >/dev/null 2>&1; then
        log_msg "tmpfs mount skipped or failed for $SYS_CERT_DIR"
    fi

    copy_regular_files "$TMP_CERT_DIR" "$SYS_CERT_DIR"
    apply_cert_permissions "$SYS_CERT_DIR"

    if [ ! -f "$SYS_CERT_DIR/$CERT_FILE" ]; then
        log_msg "$CERT_FILE is not visible in $SYS_CERT_DIR"
        return 1
    fi

    return 0
}

detect_nsenter() {
    if command -v nsenter >/dev/null 2>&1; then
        NSENTER_AVAILABLE=1
    elif [ -x /system/bin/nsenter ] || [ -x /bin/nsenter ]; then
        NSENTER_AVAILABLE=1
    else
        NSENTER_AVAILABLE=0
    fi
}

nsenter_run() {
    pid="$1"
    shift

    [ "$NSENTER_AVAILABLE" = "1" ] || return 1
    [ -r "/proc/$pid/ns/mnt" ] || return 1

    nsenter --mount="/proc/$pid/ns/mnt" -- "$@" >/dev/null 2>&1 ||
        nsenter -t "$pid" -m -- "$@" >/dev/null 2>&1 ||
        /system/bin/nsenter --mount="/proc/$pid/ns/mnt" -- "$@" >/dev/null 2>&1 ||
        /system/bin/nsenter -t "$pid" -m -- "$@" >/dev/null 2>&1 ||
        /bin/nsenter --mount="/proc/$pid/ns/mnt" -- "$@" >/dev/null 2>&1 ||
        /bin/nsenter -t "$pid" -m -- "$@" >/dev/null 2>&1
}

cert_visible_in_namespace() {
    pid="$1"
    nsenter_run "$pid" ls "$APEX_CERT_DIR/$CERT_FILE"
}

bind_mount_in_namespace() {
    pid="$1"

    nsenter_run "$pid" mount -o bind "$SYS_CERT_DIR" "$APEX_CERT_DIR" ||
        nsenter_run "$pid" mount --bind "$SYS_CERT_DIR" "$APEX_CERT_DIR" ||
        nsenter_run "$pid" /system/bin/mount -o bind "$SYS_CERT_DIR" "$APEX_CERT_DIR" ||
        nsenter_run "$pid" /system/bin/mount --bind "$SYS_CERT_DIR" "$APEX_CERT_DIR" ||
        nsenter_run "$pid" /bin/mount -o bind "$SYS_CERT_DIR" "$APEX_CERT_DIR" ||
        nsenter_run "$pid" /bin/mount --bind "$SYS_CERT_DIR" "$APEX_CERT_DIR"
}

zygote_pids() {
    pidof zygote 2>/dev/null
    pidof zygote64 2>/dev/null
}

child_pids_of() {
    parent="$1"

    ps -o PID -P "$parent" 2>/dev/null | awk 'NR > 1 { print $1 }'
    ps 2>/dev/null | awk -v parent="$parent" 'NR > 1 && $3 == parent { print $2 }'
}

inject_process() {
    pid="$1"

    [ -n "$pid" ] || return 0
    [ -d "/proc/$pid" ] || return 0

    if cert_visible_in_namespace "$pid"; then
        return 0
    fi

    if bind_mount_in_namespace "$pid"; then
        log_msg "Injected APEX cert mount into pid $pid"
    else
        log_msg "Failed to inject APEX cert mount into pid $pid"
    fi
}

inject_zygote_and_apps() {
    zygotes="$(zygote_pids | tr '\n' ' ')"

    for pid in $zygotes; do
        inject_process "$pid"
    done

    for zpid in $zygotes; do
        for pid in $(child_pids_of "$zpid"); do
            inject_process "$pid"
        done
    done
}

monitor_zygote() {
    while true; do
        inject_zygote_and_apps
        sleep 10
    done
}

main() {
    echo "" > "$LOG_FILE" 2>/dev/null || true
    log_msg "SMY Root CA service starting"

    wait_for_boot_completed

    if [ ! -d "$APEX_CERT_DIR" ]; then
        log_msg "Conscrypt APEX cert directory not found; system mount is sufficient"
        return 0
    fi

    if ! prepare_runtime_store; then
        log_msg "Failed to prepare runtime certificate store"
        return 0
    fi

    detect_nsenter
    if [ "$NSENTER_AVAILABLE" != "1" ]; then
        log_msg "nsenter not available; APEX namespace injection skipped"
        return 0
    fi

    inject_zygote_and_apps
    monitor_zygote &
    log_msg "SMY Root CA service finished initial injection"
}

main
