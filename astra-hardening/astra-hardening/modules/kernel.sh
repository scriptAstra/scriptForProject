GRUB_DIRTY=0

kernel_sysctl_check() {
    local key=$1 want=$2 cur
    cur=$(sysctl -n "$key" 2>/dev/null) || return 1
    if [[ $want == '>='* ]]; then
        (( cur >= ${want#>=} ))
    else
        [[ $cur == "$want" ]]
    fi
}

kernel_sysctl_apply() {
    local key=$1 val=${2#>=}
    backup_file "$SYSCTL_FILE"
    touch "$SYSCTL_FILE" || return 1
    sed -i "/^${key//./\\.}[[:space:]]*=/d" "$SYSCTL_FILE"
    printf '%s = %s\n' "$key" "$val" >>"$SYSCTL_FILE"
    sysctl -w "$key=$val" >/dev/null
}

grub_cmdline_get() {
    [[ -r $GRUB_FILE ]] || return 1
    sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"[[:space:]]*$/\1/p' "$GRUB_FILE"
}

grub_param_present() {
    [[ " $(grub_cmdline_get) " == *" $1 "* ]]
}

grub_param_set() {
    local param=$1 key=${1%%=*} cur new
    [[ -w $GRUB_FILE ]] || return 1
    cur=$(grub_cmdline_get)
    new=$(tr ' ' '\n' <<<"$cur" | grep -vE "^${key//./\\.}(=|$)" | xargs)
    new="${new:+$new }$param"
    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE"; then
        sed -i -E "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new\"|" "$GRUB_FILE"
    else
        printf 'GRUB_CMDLINE_LINUX_DEFAULT="%s"\n' "$new" >>"$GRUB_FILE"
    fi
}

kernel_boot_check() {
    grub_param_present "$1"
}

kernel_boot_apply() {
    backup_file "$GRUB_FILE"
    grub_param_set "$1" && GRUB_DIRTY=1
}

kernel_finalize() {
    (( GRUB_DIRTY )) || return 0
    if update-grub >>"$LOG_FILE" 2>&1; then
        log_warn "конфигурация GRUB обновлена, требуется перезагрузка"
    else
        log_error "update-grub завершился с ошибкой"
        return 1
    fi
}

module_kernel_run() {
    local line id key val flags
    for line in "${SYSCTL_REQS[@]}"; do
        IFS='|' read -r id key val flags <<<"$line"
        req_gate "$id" "sysctl $key" "$flags" || continue
        if [[ ! -e /proc/sys/${key//.//} ]]; then
            req_skip "$id" "sysctl $key" "параметр отсутствует в ядре"
            continue
        fi
        req_run "$id" "sysctl $key $val" \
            "kernel_sysctl_check $key $val" "kernel_sysctl_apply $key $val"
    done

    for line in "${BOOT_REQS[@]}"; do
        IFS='|' read -r id key flags <<<"$line"
        req_gate "$id" "boot $key" "$flags" || continue
        req_run "$id" "параметр загрузки $key" \
            "kernel_boot_check $key" "kernel_boot_apply $key"
    done

    [[ $MODE == apply ]] && kernel_finalize
}
