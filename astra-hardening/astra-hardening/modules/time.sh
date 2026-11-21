time_sync_read() {
    command -v timedatectl >/dev/null 2>&1 || return 1
    timedatectl show -p NTPSynchronized --value
}
time_ntp_enabled_read() {
    local out
    out=$(timedatectl show -p NTP --value 2>/dev/null) || return 1
    printf '%s\n' "$out"
}
time_ntp_enable() {
    timedatectl set-ntp true
}
module_time_run() {
    # The setting is safely applied, but synchronisation may take time or need connectivity.
    probe_apply TIME-NTP 'Включена сетевая синхронизация времени' yes time_ntp_enabled_read time_ntp_enable \
        'Проверьте активную службу NTP (chrony/systemd-timesyncd), её конфигурацию и разрешённые источники времени.' auto
    probe XLSX-260 'Часы синхронизированы с источником времени' yes time_sync_read \
        'Убедитесь в доступности утверждённого NTP-источника; синхронизация не гарантируется одной командой timedatectl set-ntp true. Учитывайте задержку после включения.'
}
