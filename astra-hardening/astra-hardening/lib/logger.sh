log_init() {
    mkdir -p "$LOG_DIR" || return 1
    LOG_FILE="$LOG_DIR/hardening_$RUN_ID.log"
    : >>"$LOG_FILE" || return 1
    chmod 600 "$LOG_FILE"
}

_log() {
    local level=$1 line
    shift
    line="$(date '+%F %T') [$level] [$CURRENT_MODULE] $*"
    [[ -n ${LOG_FILE:-} ]] && printf '%s\n' "$line" >>"$LOG_FILE"
    [[ $level == DEBUG && $VERBOSE != 1 ]] || printf '%s\n' "$line" >&2
}

log_debug() { _log DEBUG "$@"; }
log_info()  { _log INFO "$@"; }
log_warn()  { _log WARN "$@"; }
log_error() { _log ERROR "$@"; }
