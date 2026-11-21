req_run() {
    local id=$1 desc=$2 chk=$3 app=$4
    local object=${5:-$desc} expected=${6:-—} reader=${7:-} advice=${8:-} actual=— rc=0
    if [[ -n $reader ]]; then
        actual=$($reader) || rc=$?
        if [[ $rc != 0 || -z $actual ]]; then
            result_add "$id" ERROR "$desc" "$object" "$expected" "не удалось считать" "Проверьте доступность источника значения: $object."
            return 1
        fi
    fi
    if $chk; then
        result_add "$id" PASS "$desc" "$object" "$expected" "$actual" "$advice"
        return 0
    fi
    if [[ $MODE != apply ]]; then
        log_warn "[$id] не соответствует: $desc"
        result_add "$id" FAIL "$desc" "$object" "$expected" "$actual" "$advice"
        return 1
    fi
    log_info "[$id] применение: $desc"
    if $app && $chk; then
        result_add "$id" FIXED "$desc" "$object" "$expected" "$actual" "$advice"
        return 0
    fi
    log_error "[$id] не удалось применить: $desc"
    result_add "$id" ERROR "$desc" "$object" "$expected" "$actual" "$advice"
    return 1
}

req_skip() {
    log_info "[$1] пропущено: $3"
    result_add "$1" SKIP "$2 ($3)"
}

req_gate() {
    local id=$1 desc=$2 flags=$3
    if [[ $flags == *x86* ]] && ! is_x86; then
        req_skip "$id" "$desc" "только для x86"
        return 1
    fi
    if [[ $flags == *risky* && ${ENABLE_RISKY:-no} != yes ]]; then
        req_skip "$id" "$desc" "рискованная настройка, нужен ENABLE_RISKY=yes"
        return 1
    fi
}
