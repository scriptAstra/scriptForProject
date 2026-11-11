users_wheel_check() {
    local u
    getent group wheel >/dev/null || return 1
    for u in root "${WHEEL_USERS[@]}"; do
        id -nG "$u" 2>/dev/null | tr ' ' '\n' | grep -qx wheel || return 1
    done
}

users_wheel_apply() {
    local u
    getent group wheel >/dev/null || groupadd wheel || return 1
    backup_file /etc/group
    for u in root "${WHEEL_USERS[@]}"; do
        usermod -aG wheel "$u" || return 1
    done
}

list_home_dotfiles() {
    local h n
    while IFS= read -r h; do
        for n in .bash_history .history .sh_history .bash_profile .bashrc .profile .bash_logout .rhosts; do
            [[ -e $h/$n ]] && printf '%s\n' "$h/$n"
        done
    done < <(list_homes)
}

module_users_run() {
    req_run "2.2.1(б)" "Группа wheel: root и разрешённые для su пользователи" \
        users_wheel_check users_wheel_apply
    req_run "2.3.10" "Файлы истории и настроек оболочки, .rhosts: go-rwx" \
        "perm_check 077 list_home_dotfiles" "perm_apply 077 list_home_dotfiles"
    req_run "2.3.11" "Домашние каталоги: 700" \
        "perm_check 077 list_homes" "perm_apply 077 list_homes"
}
