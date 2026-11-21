password_empty_users() { awk -F: '$2=="" {print $1}' /etc/shadow; }
password_empty_read() {
    local users
    users=$(password_empty_users) || return 1
    if [[ -z $users ]]; then printf 'none\n'; else paste -sd, <<< "$users"; fi
}
password_empty_apply() {
    local u rc=0
    backup_file /etc/shadow || return 1
    while IFS= read -r u; do
        [[ -n $u ]] || continue
        # Never disable an arbitrary account with no recovery; only when explicitly authorised.
        [[ ${LOCK_EMPTY_PASSWORD_ACCOUNTS:-no} == yes ]] || return 1
        passwd -l "$u" >/dev/null || rc=1
    done < <(password_empty_users)
    return "$rc"
}
password_policy_read() {
    local key=$1 val
    [[ -r /etc/login.defs ]] || return 1
    val=$(awk -v k="$key" '$1 == k {value=$2} END {if (value!="") print value}' /etc/login.defs)
    [[ -n $val ]] || return 1
    printf '%s\n' "$val"
}
# Prepare a complete replacement in the same directory; never edit login.defs in place.
# The file argument makes it possible to exercise the writer using a disposable fixture.
password_login_defs_set_file() {
    local file=$1 key=$2 value=$3 tmp='' candidate='' rc=1
    local dir
    case $key in PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE) ;; *) return 1 ;; esac
    [[ $value =~ ^[0-9]+$ ]] || return 1
    [[ -f $file && ! -L $file && -r $file && -w $file ]] || return 1
    dir=$(dirname -- "$file") || return 1
    [[ -d $dir ]] || return 1
    tmp=$(mktemp "$dir/.login.defs.astra.XXXXXXXX") || return 1
    candidate=$(mktemp "$dir/.login.defs.content.XXXXXXXX") || { rm -f -- "$tmp"; return 1; }

    # Preserve DAC permissions, owner/group and other attributes where supported.
    # Editing only the temporary copy also leaves the original intact on failure.
    if cp -a -- "$file" "$tmp" &&
       awk -v k="$key" -v v="$value" '
           $1 == k && $0 !~ /^[[:space:]]*#/ {
               if (!replaced) { print k "\t" v; replaced=1 }
               next
           }
           {print}
           END {if (!replaced) print k "\t" v}
       ' "$file" >"$candidate" &&
       cat -- "$candidate" >"$tmp" &&
       [[ $(awk -v k="$key" '$1==k && $0 !~ /^[[:space:]]*#/ {n++; if ($2 !~ /^[0-9]+$/) bad=1} END {if (n==1 && !bad) print "ok"}' "$tmp") == ok ]] &&
       cmp -s -- "$candidate" "$tmp" &&
       mv -f -- "$tmp" "$file"; then
        rc=0
    fi
    rm -f -- "$tmp" "$candidate"
    return "$rc"
}
password_login_defs_apply() {
    local key=$1 value=$2 file=/etc/login.defs
    [[ -f $file && ! -L $file ]] || return 1
    backup_file "$file" || return 1
    # Only future account defaults are affected; existing user aging is unchanged.
    password_login_defs_set_file "$file" "$key" "$value"
}
password_pam_feature_read() {
    local feature=$1
    local conf
    case $feature in
        quality) conf=/etc/pam.d/common-password; pattern='pam_pwquality[.]so|pam_cracklib[.]so' ;;
        history) conf=/etc/pam.d/common-password; pattern='pam_pwhistory[.]so|remember=' ;;
        lockout) conf=/etc/pam.d/common-auth; pattern='pam_faillock[.]so|pam_tally2[.]so' ;;
        *) return 1 ;;
    esac
    [[ -r $conf ]] || return 1
    if grep -Ev '^[[:space:]]*(#|$)' "$conf" | grep -Eq "$pattern"; then printf 'configured\n'; else printf 'not-configured\n'; fi
}
module_password_run() {
    probe_apply '2.1.1(а,б)' 'Учётные записи с пустым паролем' none password_empty_read password_empty_apply \
        'Проверьте список УЗ и их назначение; автоматическая блокировка требует LOCK_EMPTY_PASSWORD_ACCOUNTS=yes и предварительной проверки альтернативного доступа.' gated

    # Baseline values below are project defaults, not universal FSTEC requirements.
    # An operator must reconcile them with the comparison table and approved policy.
    local key target
    for key in PASS_MAX_DAYS PASS_MIN_DAYS PASS_WARN_AGE; do
        case $key in
            PASS_MAX_DAYS) target=${POLICY_PASS_MAX_DAYS:-90} ;;
            PASS_MIN_DAYS) target=${POLICY_PASS_MIN_DAYS:-1} ;;
            PASS_WARN_AGE) target=${POLICY_PASS_WARN_AGE:-7} ;;
        esac
        probe_apply "PWD-$key" "Парольная политика по умолчанию: $key" "$target" \
            "password_policy_read $key" "password_login_defs_apply $key $target" \
            'Проверьте /etc/login.defs и политику организации. Изменение влияет на значения по умолчанию для новых учётных записей, но не меняет сроки существующих паролей.' auto
    done
    probe 'PWD-PAM-QUALITY' 'PAM: проверка сложности новых паролей' configured \
        'password_pam_feature_read quality' 'Согласуйте политику сложности и настройте PAM через штатный механизм Astra Linux; не переписывайте common-password автоматически.'
    probe 'PWD-PAM-HISTORY' 'PAM: история паролей' configured \
        'password_pam_feature_read history' 'Проверьте pam_pwhistory и допустимую глубину истории по принятому эталону.'
    probe 'PWD-PAM-LOCKOUT' 'PAM: ограничение неудачных попыток' configured \
        'password_pam_feature_read lockout' 'Проверьте PAM common-auth, пороги блокировки и совместимость с Astra Linux; ручная настройка с резервной копией и консольным доступом.'
}
