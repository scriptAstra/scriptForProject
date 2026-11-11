ssh_effective() {
    sshd -T 2>/dev/null | awk -v k="$1" 'tolower($1)==k {print tolower($2); exit}'
}

ssh_alt_admin_exists() {
    local g u
    for g in sudo wheel astra-admin; do
        for u in $(getent group "$g" | cut -d: -f4 | tr ',' ' '); do
            [[ $u != root ]] && return 0
        done
    done
    return 1
}

ssh_root_login_check() {
    [[ $(ssh_effective permitrootlogin) == no ]]
}

ssh_root_login_apply() {
    local cfg=/etc/ssh/sshd_config
    if ! ssh_alt_admin_exists; then
        log_error "нет альтернативного административного пользователя, изменение отменено"
        return 1
    fi
    backup_file "$cfg"
    conf_set_first "$cfg" PermitRootLogin no || return 1
    if ! sshd -t; then
        log_error "sshd -t: ошибка конфигурации, восстановите из $BACKUP_ROOT/$RUN_ID"
        return 1
    fi
    systemctl restart ssh 2>/dev/null || systemctl restart sshd
}

ssh_installed() {
    [[ -f /etc/ssh/sshd_config ]] && { command -v sshd || [[ -x /usr/sbin/sshd ]]; } >/dev/null
}

module_ssh_run() {
    if ! ssh_installed; then
        req_skip "2.1.2" "Запрещён вход root по SSH (PermitRootLogin no)" "sshd не установлен"
        return 0
    fi
    req_run "2.1.2" "Запрещён вход root по SSH (PermitRootLogin no)" \
        ssh_root_login_check ssh_root_login_apply
}
