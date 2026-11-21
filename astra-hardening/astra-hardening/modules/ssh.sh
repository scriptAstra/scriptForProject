ssh_bin() {
    if command -v sshd >/dev/null 2>&1; then command -v sshd
    elif [[ -x /usr/sbin/sshd ]]; then printf '/usr/sbin/sshd\n'
    else return 1; fi
}
ssh_effective() {
    local bin out
    bin=$(ssh_bin) || return 1
    out=$($bin -T 2>/dev/null) || return 1
    awk -v k="$1" 'tolower($1)==k {print tolower($2); found=1; exit} END {if (!found) exit 1}' <<< "$out"
}
ssh_alt_admin_exists() {
    # Group membership alone is not proof of a working alternative login.
    [[ ${SSH_ALT_ADMIN_CONFIRMED:-no} == yes ]]
}
ssh_root_login_check() { [[ $(ssh_effective permitrootlogin) == no ]]; }
ssh_root_login_apply() {
    local cfg=/etc/ssh/sshd_config bin
    [[ ${VM_CONSOLE_CONFIRMED:-no} == yes ]] || return 1
    ssh_alt_admin_exists || { log_warn 'SSH: альтернативный административный доступ не подтверждён'; return 1; }
    bin=$(ssh_bin) || return 1
    backup_file "$cfg" || return 1
    conf_set_first "$cfg" PermitRootLogin no || return 1
    if ! "$bin" -t; then
        log_error "ошибка конфигурации SSH — восстановите $cfg из $BACKUP_ROOT/$RUN_ID"
        return 1
    fi
    # Do not restart SSH and disconnect existing sessions. Reload if running.
    if systemctl is-active --quiet ssh.service; then systemctl reload ssh.service
    elif systemctl is-active --quiet sshd.service; then systemctl reload sshd.service
    else return 0; fi
}
ssh_installed() { [[ -f /etc/ssh/sshd_config ]] && ssh_bin >/dev/null; }
module_ssh_run() {
    if ! ssh_installed; then
        req_skip '2.1.2' 'Запрещён вход root по SSH (PermitRootLogin no)' 'sshd не установлен'
        return 0
    fi
    # Unlike the old implementation, never treat an empty output as a valid reading.
    probe_apply '2.1.2' 'Запрещён вход root по SSH (PermitRootLogin no)' no \
        'ssh_effective permitrootlogin' ssh_root_login_apply \
        'Проверьте sshd -T, Include/Match. Изменение допускается только с VM_CONSOLE_CONFIRMED=yes и SSH_ALT_ADMIN_CONFIRMED=yes; проверьте работающий административный вход.' gated
}
