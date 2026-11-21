audit_service_state() {
    local svc=$1 prop=$2
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl show "${svc}.service" -p "$prop" --value
}
audit_active() { audit_service_state auditd ActiveState; }
audit_enabled() { audit_service_state auditd UnitFileState; }
syslog_active() { audit_service_state syslog-ng ActiveState; }
audit_installed() { systemctl list-unit-files 'auditd.service' --no-legend 2>/dev/null | grep -q '^auditd.service'; }
syslog_installed() { systemctl list-unit-files 'syslog-ng.service' --no-legend 2>/dev/null | grep -q '^syslog-ng.service'; }
audit_enable_boot() { audit_installed && systemctl enable auditd.service; }
audit_start() {
    audit_installed || return 1
    if command -v auditd >/dev/null 2>&1; then auditd -t >/dev/null 2>&1 || return 1; fi
    systemctl start auditd.service
}
syslog_start() {
    syslog_installed || return 1
    if command -v syslog-ng >/dev/null 2>&1; then syslog-ng -s >/dev/null 2>&1 || return 1; fi
    systemctl start syslog-ng.service
}
audit_rule_count() {
    command -v auditctl >/dev/null 2>&1 || { printf 'not-installed\n'; return; }
    local rules
    rules=$(auditctl -l 2>/dev/null) || return 1
    if [[ -z $rules || $rules == 'No rules' ]]; then printf 'none\n'; else printf 'configured\n'; fi
}
module_audit_run() {
    probe_apply AUD-BOOT 'Автозапуск auditd' enabled audit_enabled audit_enable_boot \
        'Проверьте unit auditd и разрешите его запуск при загрузке.' auto
    probe_apply AUD-SVC 'Состояние службы auditd' active audit_active audit_start \
        'Проверьте конфигурацию auditd, доступность журналов и сообщения службы.' auto
    probe_apply AUD-LOG 'Состояние syslog-ng' active syslog_active syslog_start \
        'Проверьте установленный механизм системного логирования и корректность конфигурации syslog-ng.' auto
    probe AUD-RULES 'Правила аудита загружены' configured audit_rule_count \
        'Сверьте правила auditctl -l и /etc/audit/rules.d с утверждённой политикой. Автоматическая генерация правил без перечня контролируемых событий запрещена.'
}
