#!/bin/bash

set -u
set -o pipefail

#===============================================================================
# 描述: 使用 rclone 将数据同步，并发送 NotifyMux 通知。
# 作者: SMY
#===============================================================================

# --- 配置变量 ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# 任务名称，用于日志和通知
JOB_NAME="Sync-Minio-To-E5"

# rclone 可执行文件路径
# 默认使用脚本所在目录下的 rclone
RCLONE_PATH="${SCRIPT_DIR}/rclone"
# rclone 配置文件路径
CONFIG_FILE="${SCRIPT_DIR}/rclone.conf"

# 源目录 (rclone 远程或本地路径)
# 示例: "minio_remote:bucket_name/path/" 或 "/local/data/"
SOURCE_DIR="minio:"
# 目标目录 (rclone 远程或本地路径)
DEST_DIR="E5-MinioBackup-Crypt:"

# 排除列表，使用逗号分隔的模式。
# 例如: "Public/**,*.tmp,cache/"
# 如果为空，则不排除任何文件。
EXCLUDE_LIST=""
# EXCLUDE_LIST="Public/**,*.log,temp_files/"

# 日志文件目录
LOG_DIR="${SCRIPT_DIR}/logs"
NOTIFYMUX_API_KEY="<YOUR NOTIFYMUX API KEY HERE>"
NOTIFYMUX_ENDPOINT="https://push.smy.me/send"

# --- 全局变量 ---
# 每月一个日志文件
TIMESTAMP=$(date +%Y%m)
LOG_FILE="${LOG_DIR}/${JOB_NAME}_${TIMESTAMP}.log"
RCLONE_OPTS=()

# --- 函数定义 ---

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_message() {
    local level="$1"
    local message="$2"

    printf "[%s] [%s] %s\n" "$(timestamp)" "${level}" "${message}" >> "${LOG_FILE}"
}

critical_stderr() {
    local message="$1"

    >&2 printf "[%s] [CRITICAL] %s\n" "$(timestamp)" "${message}"
}

ensure_log_dir() {
    if [[ -d "${LOG_DIR}" ]]; then
        return 0
    fi

    if ! mkdir -p "${LOG_DIR}"; then
        critical_stderr "无法创建日志目录: ${LOG_DIR}. 请检查权限。"
        return 1
    fi

    log_message "INFO" "日志目录 ${LOG_DIR} 已创建。"
}

preflight_check() {
    local status=0

    if [[ ! -x "${RCLONE_PATH}" ]]; then
        log_message "ERROR" "rclone 不存在或不可执行: ${RCLONE_PATH}"
        status=1
    fi

    if [[ ! -r "${CONFIG_FILE}" ]]; then
        log_message "ERROR" "rclone 配置文件不存在或不可读: ${CONFIG_FILE}"
        status=1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_message "WARNING" "未找到 curl；如果任务失败，将无法发送 NotifyMux 通知。"
    fi

    if [[ -z "${NOTIFYMUX_API_KEY}" || "${NOTIFYMUX_API_KEY}" == *"<YOUR NOTIFYMUX API KEY HERE>"* ]]; then
        log_message "WARNING" "NotifyMux API Key 未配置或仍为占位符；失败通知将被跳过。"
    fi

    return "${status}"
}

notifymux_configured() {
    [[ -n "${NOTIFYMUX_API_KEY}" && "${NOTIFYMUX_API_KEY}" != *"<YOUR NOTIFYMUX API KEY HERE>"* ]]
}

trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf "%s" "${value}"
}

build_rclone_opts() {
    local dry_run="${1:-false}"
    local exclude_array=()
    local item
    local trimmed_item

    RCLONE_OPTS=(
        "--config" "${CONFIG_FILE}"
        "sync"
        "${SOURCE_DIR}"
        "${DEST_DIR}"
        "--no-check-certificate" # 如果你的 SSL 证书是自签名的或有其他问题，可能需要此选项。生产环境请谨慎使用。
        "--timeout" "60m"         # 单个文件传输超时时间
        "--retries" "3"           # 失败重试次数
        "--retries-sleep" "5s"    # 重试间隔时间
        "--delete-excluded"       # 删除目标端被排除规则匹配到的文件
        "--stats" "1m"            # 每分钟输出一次传输状态
        "--fast-list"             # 对于支持的后端 (如 Minio, S3, Onedrive)，可以显著加快大目录的列表速度
        "--log-level" "INFO"      # rclone 自身的日志级别
        "--log-file" "${LOG_FILE}" # rclone 将其日志也输出到我们的主日志文件
        # 性能调优参数 (根据实际情况调整)
        # "--checkers=8"          # 并发检查文件数量 (默认为 8)
        # "--transfers=4"         # 并发传输文件数量 (默认为 4)
        # "--buffer-size=16M"     # 内存缓冲区大小 (默认为 16M)
        # "--bwlimit" "2M"        # 限速2M
    )

    if [[ -n "${EXCLUDE_LIST}" ]]; then
        IFS=',' read -r -a exclude_array <<< "${EXCLUDE_LIST}"
        for item in "${exclude_array[@]}"; do
            trimmed_item="$(trim_whitespace "${item}")"
            if [[ -n "${trimmed_item}" ]]; then
                RCLONE_OPTS+=("--exclude" "${trimmed_item}")
            fi
        done
    fi

    if [[ "${dry_run}" == "true" ]]; then
        RCLONE_OPTS+=("--dry-run")
    fi
}

format_rclone_command() {
    local quoted_command

    printf -v quoted_command "%q " "${RCLONE_PATH}" "${RCLONE_OPTS[@]}"
    printf "%s" "${quoted_command% }"
}

json_escape() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf "%s" "${value}"
}

build_notifymux_payload() {
    local message="$1"
    local title
    local body
    local job

    title="$(json_escape "Rclone Sync: ${JOB_NAME}")"
    body="$(json_escape "${message}")"
    job="$(json_escape "${JOB_NAME}")"

    printf '{"title":"%s","body":"%s","channelIds":[],"metadata":{"service":"rclone-sync","job":"%s"}}' \
        "${title}" \
        "${body}" \
        "${job}"
}

send_notifymux() {
    local message="$1"
    local curl_response
    local curl_exit_code
    local http_status
    local response_body
    local payload

    if ! notifymux_configured; then
        log_message "WARNING" "NotifyMux API Key 未配置，跳过失败通知。"
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_message "ERROR" "curl 不可用，无法发送 NotifyMux 通知。"
        return 1
    fi

    payload="$(build_notifymux_payload "${message}")"

    log_message "INFO" "正在发送 NotifyMux 通知..."
    curl_response=$(
        curl -sS -w $'\nHTTP_STATUS:%{http_code}' -X POST \
            -H "content-type: application/json" \
            -H "X-API-Key: ${NOTIFYMUX_API_KEY}" \
            --data "${payload}" \
            "${NOTIFYMUX_ENDPOINT}" 2>&1
    )
    curl_exit_code=$?

    if [[ ${curl_exit_code} -ne 0 ]]; then
        log_message "ERROR" "NotifyMux 通知发送失败 (curl 退出码: ${curl_exit_code}): ${curl_response}"
        return "${curl_exit_code}"
    fi

    http_status="${curl_response##*HTTP_STATUS:}"
    response_body="${curl_response%$'\n'HTTP_STATUS:*}"

    if [[ "${http_status}" == "200" ]]; then
        log_message "INFO" "NotifyMux 通知发送成功。"
        return 0
    fi

    log_message "ERROR" "NotifyMux 通知发送失败。HTTP 状态码: ${http_status}. 响应: ${response_body}"
    return 1
}

run_sync() {
    local dry_run="${1:-false}"

    build_rclone_opts "${dry_run}"
    log_message "INFO" "执行 rclone 命令: $(format_rclone_command)"

    "${RCLONE_PATH}" "${RCLONE_OPTS[@]}"
}

run_sync_command() {
    local dry_run="${1:-false}"
    local exit_code=0
    local message
    local mode_label="同步"

    if [[ "${dry_run}" == "true" ]]; then
        mode_label="dry-run"
    fi

    log_message "INFO" "==================== 任务 '${JOB_NAME}' ${mode_label} 开始于 $(timestamp) ===================="

    if preflight_check; then
        run_sync "${dry_run}"
        exit_code=$?
    else
        exit_code=2
        message="任务 '${JOB_NAME}' 预检失败，未执行${mode_label}。源: '${SOURCE_DIR}' -> 目标: '${DEST_DIR}'."
        log_message "ERROR" "${message}"
        if [[ "${dry_run}" != "true" ]]; then
            send_notifymux "${message}" || true
        fi
    fi

    if [[ ${exit_code} -eq 0 ]]; then
        message="任务 '${JOB_NAME}' ${mode_label}成功！源: '${SOURCE_DIR}' -> 目标: '${DEST_DIR}'."
        log_message "INFO" "${message}"
    elif [[ ${exit_code} -ne 2 ]]; then
        message="任务 '${JOB_NAME}' ${mode_label}失败！源: '${SOURCE_DIR}' -> 目标: '${DEST_DIR}'. rclone 退出码: ${exit_code}."
        log_message "ERROR" "${message}"
        if [[ "${dry_run}" != "true" ]]; then
            send_notifymux "${message}" || true
        fi
    fi

    log_message "INFO" "==================== 任务 '${JOB_NAME}' ${mode_label} 结束于 $(timestamp) (退出码: ${exit_code}) ================"
    printf "\n" >> "${LOG_FILE}"

    exit "${exit_code}"
}

run_push_test() {
    local message

    if ! notifymux_configured; then
        log_message "ERROR" "NotifyMux API Key 未配置，无法发送 push-test 通知。"
        printf "NotifyMux API Key 未配置，请先填写 NOTIFYMUX_API_KEY。\n" >&2
        exit 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_message "ERROR" "curl 不可用，无法发送 push-test 通知。"
        printf "curl 不可用，无法发送 push-test 通知。\n" >&2
        exit 1
    fi

    message="rclone-sync push-test 测试消息。任务 '${JOB_NAME}' 已成功连接 NotifyMux。"
    log_message "INFO" "正在执行 push-test。"
    if send_notifymux "${message}"; then
        log_message "INFO" "push-test 成功。"
        printf "push-test succeeded.\n"
        exit 0
    fi

    log_message "ERROR" "push-test 失败。"
    printf "push-test failed. See log: %s\n" "${LOG_FILE}" >&2
    exit 1
}

show_help() {
    cat <<EOF
rclone-sync

Usage:
  bash rclone-sync.sh [sync|dry-run|push-test|help]

Commands:
  sync       Run rclone sync. This is the default when no command is provided.
  dry-run    Run rclone sync with --dry-run. No NotifyMux failure notification is sent.
  push-test  Send one NotifyMux test notification. rclone and config are not checked.
  help       Show this help message.

Examples:
  bash rclone-sync.sh
  bash rclone-sync.sh sync
  bash rclone-sync.sh dry-run
  bash rclone-sync.sh push-test

Configuration:
  JOB_NAME, RCLONE_PATH, CONFIG_FILE, SOURCE_DIR, DEST_DIR, EXCLUDE_LIST, LOG_DIR,
  NOTIFYMUX_API_KEY, NOTIFYMUX_ENDPOINT
EOF
}

main() {
    local command="${1:-sync}"

    case "${command}" in
        sync|dry-run|push-test)
            ;;
        help|-h|--help)
            show_help
            exit 0
            ;;
        *)
            show_help >&2
            exit 64
            ;;
    esac

    if [[ $# -gt 1 ]]; then
        show_help >&2
        exit 64
    fi

    if ! ensure_log_dir; then
        exit 1
    fi

    case "${command}" in
        sync)
            run_sync_command "false"
            ;;
        dry-run)
            run_sync_command "true"
            ;;
        push-test)
            run_push_test
            ;;
    esac
}

# --- 脚本执行入口 ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
