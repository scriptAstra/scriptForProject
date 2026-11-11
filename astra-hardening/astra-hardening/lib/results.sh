declare -A RESULT_COUNT

results_init() {
    RESULTS_FILE="$LOG_DIR/results_$RUN_ID.tsv"
    : >"$RESULTS_FILE"
}

result_add() {
    local id=$1 status=$2 desc=$3
    printf '%s\t%s\t%s\t%s\n' "$CURRENT_MODULE" "$id" "$status" "$desc" >>"$RESULTS_FILE"
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
