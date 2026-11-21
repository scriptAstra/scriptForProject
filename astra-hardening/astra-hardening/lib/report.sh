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
        printf '\nПодтверждённые несоответствия:\n'
        awk -F'\t' '$3=="FAIL" {printf "[%s / %s] %s\n  Факт: %s; эталон: %s\n  Рекомендация: %s\n",$1,$2,$5,$7,$6,$8; n++} END {if(!n) print "Нет"}' "$RESULTS_FILE"
        printf '\nОшибки и пропуски итоговой проверки:\n'
        awk -F'\t' '$3=="ERROR" || $3=="SKIP" {print $1, $2, $3, $4, $8}' "$RESULTS_FILE"
        if [[ $MODE == apply ]]; then
            printf '\nСравнение до и после: comparison_%s.tsv\n' "$RUN_ID"
            printf '\nОшибки этапа применения:\n'
            awk -F'\t' '$3=="ERROR" {print $1, $2, $4, $8}' "$LOG_DIR/apply_$RUN_ID.tsv"
        fi
    } >"$REPORT_FILE" || return 1
    awk -F'\t' '$3=="FAIL" || $3=="ERROR"' "$RESULTS_FILE" >"$ERRORS_FILE"
}

comparison_generate() {
    local output="$LOG_DIR/comparison_$RUN_ID.tsv"
    awk -F'\t' 'BEGIN {OFS=FS; print "Модуль","ID","Объект","Эталон","До","После","Статус до","Статус после"}
        FILENAME==ARGV[1] {k=$1 SUBSEP $2 SUBSEP $5; old[k]=$7; state[k]=$3; row[k]=$0; next}
        {k=$1 SUBSEP $2 SUBSEP $5; print $1,$2,$5,$6,(k in old?old[k]:"—"),$7,(k in state?state[k]:"—"),$3; delete row[k]}
        END {for(k in row) {split(row[k],a,FS); print a[1],a[2],a[5],a[6],a[7],"—",a[3],"нет результата"}}' \
        "$LOG_DIR/before_$RUN_ID.tsv" "$RESULTS_FILE" >"$output" || return 1
    printf 'сравнение: %s\n' "$output"
}
