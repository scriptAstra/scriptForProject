# Generic read/compare/apply pipeline. All readers must output one non-empty value.
probe_read() {
    local reader=$1 value
    value=$($reader) || return 1
    [[ -n $value ]] || return 1
    printf '%s\n' "$value"
}
probe() {
    local id=$1 label=$2 expected=$3 reader=$4 advice=$5
    probe_apply "$id" "$label" "$expected" "$reader" ':' "$advice" readonly
}
probe_apply() {
    local id=$1 label=$2 expected=$3 reader=$4 applier=$5 advice=$6 policy=${7:-auto}
    local actual after
    if ! actual=$(probe_read "$reader"); then
        result_add "$id" ERROR "$label" "$label" "$expected" 'не удалось считать' "$advice"
        return 1
    fi
    if [[ $actual == "$expected" ]]; then
        result_add "$id" PASS "$label" "$label" "$expected" "$actual" "$advice"
        return 0
    fi
    if [[ $MODE != apply ]]; then
        result_add "$id" FAIL "$label" "$label" "$expected" "$actual" "$advice"
        return 1
    fi
    if [[ $policy == readonly ]]; then
        # Report an actual discrepancy, not a false claim that this was fixed.
        result_add "$id" FAIL "$label" "$label" "$expected" "$actual" "$advice"
        return 1
    fi
    if [[ $policy == gated && ${ENABLE_RISKY:-no} != yes ]]; then
        result_add "$id" SKIP "$label (изменение требует ENABLE_RISKY=yes)" "$label" "$expected" "$actual" "$advice"
        return 1
    fi
    if ! $applier; then
        result_add "$id" ERROR "$label (применение не удалось)" "$label" "$expected" "$actual" "$advice"
        return 1
    fi
    if ! after=$(probe_read "$reader"); then
        result_add "$id" ERROR "$label (ошибка повторного чтения)" "$label" "$expected" 'не удалось считать' "$advice"
        return 1
    fi
    if [[ $after == "$expected" ]]; then
        result_add "$id" FIXED "$label" "$label" "$expected" "$after" "$advice"
    else
        # Some changes, e.g. NTP convergence, are asynchronous; do not assert FIXED.
        result_add "$id" FAIL "$label (после применения: $after)" "$label" "$expected" "$after" "$advice"
        return 1
    fi
}
