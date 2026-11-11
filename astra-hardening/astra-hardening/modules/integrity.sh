list_passwd()  { printf '%s\n' /etc/passwd; }
list_group()   { printf '%s\n' /etc/group; }
list_shadow()  { printf '%s\n' /etc/shadow; }

list_running_bins() {
    {
        local p
        for p in /proc/[0-9]*/exe; do readlink -f -- "$p" 2>/dev/null; done
        awk '$6 ~ /^\// {print $6}' /proc/[0-9]*/maps 2>/dev/null
    } | sort -u | while IFS= read -r f; do [[ -f $f ]] && printf '%s\n' "$f"; done
}

list_running_parents() {
    local f d
    while IFS= read -r f; do
        d=$f
        while d=$(dirname "$d"); [[ $d != / && $d != . ]]; do
            printf '%s\n' "$d"
        done
    done < <(list_running_bins) | sort -u
}

list_running_all() {
    list_running_bins
    list_running_parents
}

list_cron_sources() {
    printf '%s\n' /etc/crontab
    find /etc/cron.d /var/spool/cron -type f 2>/dev/null
}

list_cron_targets() {
    list_cron_sources \
        | xargs -r cat 2>/dev/null \
        | grep -vE '^[[:space:]]*(#|$|[A-Za-z_]+=)' \
        | grep -Eo '(^|[[:space:]=;|&(])/[A-Za-z0-9._/+-]+' \
        | sed -E 's/^[^/]*//' | sort -u \
        | while IFS= read -r p; do [[ -f $p ]] && printf '%s\n' "$p"; done
}

list_cron_periodic_scripts() {
    find /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly -type f 2>/dev/null
}

list_cron_system() {
    local p
    for p in /etc/crontab /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
        [[ -e $p ]] && printf '%s\n' "$p"
    done
    find /etc/cron.d -type f 2>/dev/null
}

list_cron_user() {
    find /var/spool/cron -type f 2>/dev/null
}

list_static_scripts() {
    find -L /etc/rc*.d -type f 2>/dev/null
    find /etc/systemd /lib/systemd /usr/lib/systemd /run/systemd -type f -name '*.service' 2>/dev/null
}

list_system_bins() {
    local dirs=("${SYS_BIN_DIRS[@]}" "/lib/modules/$(uname -r)")
    find -H "${dirs[@]}" -xdev -type f -perm /022 2>/dev/null
}

module_integrity_run() {
    req_run "2.3.1(а)" "/etc/passwd: 644" "perm_check 133 list_passwd" "perm_apply 133 list_passwd"
    req_run "2.3.1(б)" "/etc/group: 644" "perm_check 133 list_group" "perm_apply 133 list_group"
    req_run "2.3.1(в)" "/etc/shadow: go-rwx" "perm_check 077 list_shadow" "perm_apply 077 list_shadow"
    req_run "2.3.2" "Исполняемые файлы запущенных процессов, библиотеки и их каталоги: go-w" \
        "perm_check 022 list_running_all" "perm_apply 022 list_running_all"
    req_run "2.3.3" "Файлы, вызываемые из заданий cron: go-w" \
        "perm_check 022 list_cron_targets" "perm_apply 022 list_cron_targets"
    req_run "2.3.5" "Скрипты /etc/rc*.d и файлы .service: o-w" \
        "perm_check 002 list_static_scripts" "perm_apply 002 list_static_scripts"
    req_run "2.3.6(а)" "Скрипты /etc/cron.{hourly,daily,weekly,monthly}: go-wx" \
        "perm_check 033 list_cron_periodic_scripts" "perm_apply 033 list_cron_periodic_scripts"
    req_run "2.3.6(б)" "Системные файлы-расписания cron: go-wx" \
        "perm_check 033 list_cron_system" "perm_apply 033 list_cron_system"
    req_run "2.3.7" "Пользовательские файлы заданий cron: go-w" \
        "perm_check 022 list_cron_user" "perm_apply 022 list_cron_user"
    req_run "2.3.8" "Системные исполняемые файлы, библиотеки, модули ядра: go-w" \
        "perm_check 022 list_system_bins" "perm_apply 022 list_system_bins"
}
