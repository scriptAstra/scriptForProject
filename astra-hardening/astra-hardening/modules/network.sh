network_ufw_read() {
    local out
    if ! command -v ufw >/dev/null 2>&1; then printf 'not-installed\n'; return; fi
    out=$(LC_ALL=C ufw status 2>/dev/null) || return 1
    awk '/^Status:/ {print $2; found=1; exit} END {if (!found) exit 1}' <<< "$out"
}
network_ufw_apply() {
    # Changing firewall rules may cut off remote administration.
    # Only permit activation with explicit consent and verified VM console.
    [[ ${ENABLE_FIREWALL_APPLY:-no} == yes ]] || {
        log_warn 'UFW: для применения требуется ENABLE_FIREWALL_APPLY=yes в root-owned reference.conf'
        return 1
    }
    [[ ${VM_CONSOLE_CONFIRMED:-no} == yes ]] || {
        log_warn 'UFW: не подтвержден доступ к консоли ВМ (VM_CONSOLE_CONFIRMED=yes)'
        return 1
    }
    command -v ufw >/dev/null 2>&1 || return 1
    backup_file /etc/ufw/user.rules || return 1
    backup_file /etc/ufw/user6.rules || return 1
    # Do not invent an allow rule for an unknown SSH port; operator must inspect rules.
    [[ ${FIREWALL_RULES_REVIEWED:-no} == yes ]] || return 1
    ufw --force enable >/dev/null
}
module_network_run() {
    local advice='Проверьте используемый межсетевой экран, согласуйте разрешённые соединения и доступ к консоли ВМ. Для включения UFW нужны ENABLE_FIREWALL_APPLY=yes, VM_CONSOLE_CONFIRMED=yes и FIREWALL_RULES_REVIEWED=yes; проверьте также сами правила.'
    # The reference specifically targets UFW. It is not a universal firewall compliance check.
    probe_apply XLSX-205 'Состояние UFW' active network_ufw_read network_ufw_apply "$advice" gated
}
