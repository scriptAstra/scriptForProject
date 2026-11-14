#!/usr/bin/env bash
set -o pipefail

BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RUN_ID=$(date +%Y%m%d_%H%M%S)
MODE=check
FORCE_OS=0
VERBOSE=0
SELECTED_MODULES=""
CONFIG_FILE="$BASE_DIR/config/reference.conf"
LOG_DIR=${LOG_DIR:-/var/log/astra-hardening}
BACKUP_ROOT=${BACKUP_ROOT:-/var/backups/astra-hardening}
CURRENT_MODULE=main

for lib in logger common config results checker report; do
    # shellcheck source=/dev/null
    source "$BASE_DIR/lib/$lib.sh" || { echo "не удалось загрузить lib/$lib.sh" >&2; exit 2; }
done

usage() {
    cat <<USAGE
Использование: $0 [-a] [-c файл] [-m модули] [-f] [-v] [-l] [-h]
  -a        применять изменения (по умолчанию только проверка)
  -c файл   файл эталонной конфигурации
  -m список модули через запятую
  -f        не проверять тип ОС
  -v        подробный вывод
  -l        список модулей
  -h        справка
USAGE
}

list_modules() {
    local f
    for f in "$BASE_DIR"/modules/*.sh; do basename "$f" .sh; done
}

parse_args() {
    local opt
    while getopts ":c:m:afvlh" opt; do
        case $opt in
            c) CONFIG_FILE=$OPTARG ;;
            m) SELECTED_MODULES=$OPTARG ;;
            a) MODE=apply ;;
            f) FORCE_OS=1 ;;
            v) VERBOSE=1 ;;
            l) list_modules; exit 0 ;;
            h) usage; exit 0 ;;
            *) usage >&2; exit 2 ;;
        esac
    done
}

run_module() {
    local m=$1 file="$BASE_DIR/modules/$1.sh"
    CURRENT_MODULE=$m
    if [[ ! -r $file ]]; then
        log_error "модуль не найден: $m"
        result_add "$m" ERROR "модуль не найден"
        return 1
    fi
    # shellcheck source=/dev/null
    source "$file"
    if ! declare -F "module_${m}_run" >/dev/null; then
        log_error "в модуле $m нет module_${m}_run"
        result_add "$m" ERROR "нет точки входа"
        return 1
    fi
    log_info "модуль: $m (режим: $MODE)"
    "module_${m}_run"
}

main() {
    local modules m
    parse_args "$@"
    require_root || exit 2
    log_init || exit 2
    check_os || { log_error "ОС не определена как Astra Linux (-f для обхода)"; exit 2; }
    config_load || exit 2
    results_init || exit 2

    modules=${SELECTED_MODULES:-$MODULES}
    for m in ${modules//,/ }; do
        run_module "$m"
    done

    report_generate
    results_summary
    results_ok
}

main "$@"
