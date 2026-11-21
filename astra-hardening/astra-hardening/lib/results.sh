declare -A RESULT_COUNT

results_init() {
    RESULTS_FILE="$LOG_DIR/results_$RUN_ID.tsv"
    : >"$RESULTS_FILE"
}

result_add() {
    local id=$1 status=$2 desc=$3
    local field
    local -a fields=("$CURRENT_MODULE" "$id" "$status" "$desc" "${4:-$desc}" "${5:-—}" "${6:-—}" "${7:-Сверьте объект с указанным требованием и повторите проверку.}")
    for field in "${!fields[@]}"; do
        fields[field]=${fields[field]//$'\t'/ }
        fields[field]=${fields[field]//$'\n'/; }
        fields[field]=${fields[field]//$'\r'/ }
    done
    (IFS=$'\t'; printf '%s\n' "${fields[*]}") >>"$RESULTS_FILE" || exit 2
    RESULT_COUNT[$status]=$(( ${RESULT_COUNT[$status]:-0} + 1 ))
}

results_summary() {
    local s
    for s in PASS FIXED FAIL ERROR SKIP; do
        printf '%s=%s ' "$s" "${RESULT_COUNT[$s]:-0}"
    done
    printf '\nотчёт: %s\nжурнал: %s\nошибки: %s\n' "$REPORT_FILE" "$LOG_FILE" "$ERRORS_FILE"
}

results_ok() {
    (( ${RESULT_COUNT[FAIL]:-0} + ${RESULT_COUNT[ERROR]:-0} == 0 ))
}
