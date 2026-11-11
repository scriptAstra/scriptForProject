password_empty_users() {
    awk -F: '$2=="" {print $1}' /etc/shadow
}

password_empty_check() {
    local u rc=0
    while IFS= read -r u; do
        log_warn "пустой пароль: $u"
        rc=1
    done < <(password_empty_users)
    return $rc
}

password_empty_apply() {
    local u rc=0
    backup_file /etc/shadow
    while IFS= read -r u; do
        if passwd -l "$u" >/dev/null; then
            log_info "учётная запись заблокирована: $u"
        else
            log_error "не удалось заблокировать: $u"
            rc=1
        fi
    done < <(password_empty_users)
    return $rc
}

module_password_run() {
    req_run "2.1.1(а,б)" "Нет учётных записей с пустым паролем (пустые блокируются)" \
        password_empty_check password_empty_apply
    req_skip "PWD-1" "Парольная политика: PAM, сроки, блокировки" "требований в методическом документе нет"
}
