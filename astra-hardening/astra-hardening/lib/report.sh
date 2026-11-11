report_generate() {
    REPORT_FILE="$LOG_DIR/report_$RUN_ID.txt"
    ERRORS_FILE="$LOG_DIR/errors_$RUN_ID.txt"
    {
        echo "Отчёт о соответствии требованиям безопасной настройки"
        echo "Дата:  $(date '+%F %T')"
        echo "Узел:  $(hostname)"
        echo "ОС:    $(os_version)"
        echo "Режим: $MODE"
        echo
        awk -F'\t' '{c[$3]++} END {for (s in c) printf "%s=%d ", s, c[s]; print ""}' "$RESULTS_FILE"
        echo
        awk -F'\t' '{printf "%-10s %-14s %-6s %s\n", $1, $2, $3, $4}' "$RESULTS_FILE"
    } >"$REPORT_FILE"
    awk -F'\t' '$3=="FAIL" || $3=="ERROR"' "$RESULTS_FILE" >"$ERRORS_FILE"
}
