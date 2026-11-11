config_load() {
    local f=$CONFIG_FILE
    [[ -r $f ]] || { log_error "конфигурация недоступна: $f"; return 1; }
    if [[ $(stat -c %u "$f") != 0 ]] || (( 8#$(stat -c %a "$f") & 8#022 )); then
        log_error "конфигурация должна принадлежать root и быть недоступной на запись другим: $f"
        return 1
    fi
    # shellcheck source=/dev/null
    source "$f" || { log_error "ошибка чтения конфигурации: $f"; return 1; }
    [[ -n ${MODULES:-} ]] || { log_error "в конфигурации не задан MODULES"; return 1; }
    log_info "конфигурация загружена: $f"
}
