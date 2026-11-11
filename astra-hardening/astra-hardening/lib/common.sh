require_root() {
    (( EUID == 0 )) || { echo "требуются права root" >&2; return 1; }
}

check_os() {
    [[ $FORCE_OS == 1 ]] && return 0
    [[ -f /etc/astra_version ]] && return 0
    grep -qiE '^(ID|NAME)=.*astra' /etc/os-release 2>/dev/null
}

os_version() {
    cat /etc/astra_version 2>/dev/null || sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"'
}

is_x86() { [[ $(uname -m) == x86_64 ]]; }

backup_file() {
    [[ -e $1 ]] || return 0
    BACKUP_DIR="$BACKUP_ROOT/$RUN_ID"
    mkdir -p "$BACKUP_DIR" && (cd / && cp -a --parents -- "${1#/}" "$BACKUP_DIR/")
}

conf_set_first() {
    local file=$1 key=$2 value=$3
    sed -i -E "/^[[:space:]]*$key[[:space:]]+/Id" "$file" && sed -i "1i $key $value" "$file"
}

list_homes() {
    getent passwd | awk -F: '($3==0 || ($3>=1000 && $3<65534)) && $7 !~ /(nologin|false)$/ && $6!="" {print $6}' | sort -u
}

wheel_has_members() {
    getent group wheel | cut -d: -f4 | tr ',' '\n' | grep -vx root | grep -q .
}

perm_check() {
    local mask=$1 lister=$2 f rc=0
    while IFS= read -r f; do
        f=$(readlink -f -- "$f") || continue
        [[ -e $f ]] || continue
        [[ -d $f && -k $f ]] && continue
        if (( 8#$(stat -c %a -- "$f") & 8#$mask )); then
            log_warn "права $(stat -c %a -- "$f"): $f"
            rc=1
        fi
    done < <("$lister")
    return $rc
}

perm_apply() {
    local mask=$1 lister=$2 f cur new rc=0
    while IFS= read -r f; do
        f=$(readlink -f -- "$f") || continue
        [[ -e $f ]] || continue
        [[ -d $f && -k $f ]] && continue
        cur=$(stat -c %a -- "$f")
        (( 8#$cur & 8#$mask )) || continue
        new=$(printf '%o' $(( 8#$cur & ~8#$mask )))
        if chmod "$new" -- "$f"; then
            log_info "chmod $new (было $cur): $f"
        else
            log_error "chmod не выполнен: $f"
            rc=1
        fi
    done < <("$lister")
    return $rc
}

owner_check() {
    local lister=$1 f rc=0
    while IFS= read -r f; do
        f=$(readlink -f -- "$f") || continue
        [[ -f $f ]] || continue
        if (( $(stat -c %u -- "$f") >= 1000 )); then
            log_warn "владелец $(stat -c %U -- "$f"): $f"
            rc=1
        fi
    done < <("$lister")
    return $rc
}

owner_apply() {
    local lister=$1 f rc=0
    while IFS= read -r f; do
        f=$(readlink -f -- "$f") || continue
        [[ -f $f ]] || continue
        (( $(stat -c %u -- "$f") >= 1000 )) || continue
        if chown root -- "$f"; then
            log_info "chown root: $f"
        else
            log_error "chown не выполнен: $f"
            rc=1
        fi
    done < <("$lister")
    return $rc
}
