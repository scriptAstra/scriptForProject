SUDO_DROPIN=/etc/sudoers.d/90-astra-hardening

access_su_check() {
    grep -Eq '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_wheel\.so[[:space:]]+use_uid' /etc/pam.d/su
}

access_su_apply() {
    if ! wheel_has_members; then
        log_error "в группе wheel нет пользователей кроме root, изменение отменено"
        return 1
    fi
    backup_file /etc/pam.d/su
    echo 'auth required pam_wheel.so use_uid' >>/etc/pam.d/su
}

access_sudo_render() {
    printf '%s\n' "${SUDO_RULES[@]}"
}

access_sudo_check() {
    [[ -f $SUDO_DROPIN ]] && diff -q <(access_sudo_render) "$SUDO_DROPIN" >/dev/null
}

access_sudo_apply() {
    local tmp
    tmp=$(mktemp) || return 1
    access_sudo_render >"$tmp"
    if ! visudo -cf "$tmp" >/dev/null; then
        log_error "visudo: некорректные SUDO_RULES"
        rm -f "$tmp"
        return 1
    fi
    backup_file "$SUDO_DROPIN"
    install -m 0440 -o root -g root "$tmp" "$SUDO_DROPIN"
    rm -f "$tmp"
}

list_sudo_binaries() {
    { cat /etc/sudoers /etc/sudoers.d/* 2>/dev/null; } \
        | grep -vE '^[[:space:]]*(#|$)' \
        | grep -Eo '/[A-Za-z0-9._/+-]+' | sort -u \
        | while IFS= read -r p; do [[ -f $p ]] && printf '%s\n' "$p"; done
}

list_suid() {
    find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null
}

suid_whitelist_entries() {
    grep -vE '^[[:space:]]*(#|$)' "$SUID_WHITELIST" 2>/dev/null
}

list_suid_extra() {
    list_suid | grep -vxFf <(suid_whitelist_entries)
}

access_suid_extra_check() {
    local f rc=0
    while IFS= read -r f; do
        log_warn "лишний SUID/SGID: $f"
        rc=1
    done < <(list_suid_extra)
    return $rc
}

access_suid_extra_apply() {
    local f rc=0
    while IFS= read -r f; do
        if chmod ug-s -- "$f"; then
            log_info "сняты SUID/SGID: $f"
        else
            log_error "не удалось снять SUID/SGID: $f"
            rc=1
        fi
    done < <(list_suid_extra)
    return $rc
}

module_access_run() {
    req_run "2.2.1(а)" "su ограничен группой wheel (pam_wheel use_uid)" \
        access_su_check access_su_apply

    if (( ${#SUDO_RULES[@]} )); then
        req_run "2.2.2" "Правила sudo соответствуют эталону" access_sudo_check access_sudo_apply
    else
        req_skip "2.2.2" "Ограничение sudo" "SUDO_RULES не задан"
    fi

    req_run "2.3.4(а)" "Файлы, запускаемые через sudo: владелец не обычный пользователь" \
        "owner_check list_sudo_binaries" "owner_apply list_sudo_binaries"
    req_run "2.3.4(б)" "Файлы, запускаемые через sudo: go-w" \
        "perm_check 022 list_sudo_binaries" "perm_apply 022 list_sudo_binaries"
    req_run "2.3.9(а)" "SUID/SGID-программы: go-w" \
        "perm_check 022 list_suid" "perm_apply 022 list_suid"

    if [[ -n $(suid_whitelist_entries) ]]; then
        req_run "2.3.9(б)" "Нет SUID/SGID-программ вне белого списка" \
            access_suid_extra_check access_suid_extra_apply
    else
        req_skip "2.3.9(б)" "Лишние SUID/SGID" "белый список пуст"
    fi

    req_skip "ACC-1" "DAC, PARSEC, привилегии" "модуль не реализован"
}
