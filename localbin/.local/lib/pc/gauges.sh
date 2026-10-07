#!/usr/bin/env bash
# Shared readings for pc-status and pc-watch. Sourced, never executed.
#
# Everything comes straight from /proc and /sys (no subprocess per gauge), so
# reading the full set costs well under a millisecond and is safe to do every
# few seconds even while the machine is struggling.

CPUS=$(nproc)

# gauge_read: fills the GAUGE_* variables.
#   GAUGE_MEM_TOTAL_MB GAUGE_MEM_AVAIL_MB GAUGE_MEM_USED_PCT
#   GAUGE_SWAP_TOTAL_MB GAUGE_SWAP_USED_MB GAUGE_SWAP_PCT
#   GAUGE_PSI_MEM GAUGE_PSI_MEM_FULL GAUGE_PSI_CPU GAUGE_PSI_IO   (% stalled, avg10)
#   GAUGE_LOAD1 GAUGE_TEMP_C (CPU package, empty if unknown)
gauge_read() {
    local k v _
    while read -r k v _; do
        case $k in
            MemTotal:) GAUGE_MEM_TOTAL_MB=$((v / 1024)) ;;
            MemAvailable:) GAUGE_MEM_AVAIL_MB=$((v / 1024)) ;;
            SwapTotal:) GAUGE_SWAP_TOTAL_MB=$((v / 1024)) ;;
            SwapFree:) GAUGE_SWAP_FREE_MB=$((v / 1024)) ;;
        esac
    done < /proc/meminfo
    GAUGE_MEM_USED_PCT=$(( 100 - GAUGE_MEM_AVAIL_MB * 100 / GAUGE_MEM_TOTAL_MB ))
    GAUGE_SWAP_USED_MB=$(( GAUGE_SWAP_TOTAL_MB - GAUGE_SWAP_FREE_MB ))
    GAUGE_SWAP_PCT=0
    [ "$GAUGE_SWAP_TOTAL_MB" -gt 0 ] && GAUGE_SWAP_PCT=$(( GAUGE_SWAP_USED_MB * 100 / GAUGE_SWAP_TOTAL_MB ))

    GAUGE_PSI_MEM=$(psi_avg10 memory some)
    GAUGE_PSI_MEM_FULL=$(psi_avg10 memory full)
    GAUGE_PSI_CPU=$(psi_avg10 cpu some)
    GAUGE_PSI_IO=$(psi_avg10 io full)

    read -r GAUGE_LOAD1 _ < /proc/loadavg
    GAUGE_TEMP_C=$(package_temp)
}

# psi_avg10 <memory|cpu|io> <some|full>: integer percent of the last 10 s
# that tasks were stalled on that resource.
psi_avg10() {
    local line field
    [ -r "/proc/pressure/$1" ] || { echo 0; return; }
    while read -r line; do
        case $line in
            "$2 "*)
                for field in $line; do
                    case $field in avg10=*) field=${field#avg10=}; echo "${field%.*}"; return ;; esac
                done
                ;;
        esac
    done < "/proc/pressure/$1"
    echo 0
}

# CPU package temperature in °C, from the first thermal zone that reports it.
package_temp() {
    local zone type
    for zone in /sys/class/thermal/thermal_zone*; do
        read -r type < "$zone/type" 2>/dev/null || continue
        case $type in
            x86_pkg_temp|k10temp|cpu_thermal|acpitz)
                local t
                read -r t < "$zone/temp" 2>/dev/null || continue
                echo $((t / 1000))
                return
                ;;
        esac
    done
}

# Fold the helper processes of multi-process apps into one readable name.
AWK_APP_NAME='
function app_name(n) {
    if (n ~ /^(Isolated Web Co|Web Content|WebExtensions|Privileged Cont|RDD Process|Socket Process|Utility Process|GeckoMain)/) return "firefox/zen tabs"
    if (n ~ /^(chrome|chrome_crashpad|chrome-sandbox)/) return "chrome"
    if (n ~ /^(code|code-insiders)$/) return "vscode"
    return n
}'

# top_memory [n]: "<MB> <app>" for the n biggest apps, summing every process
# of an app (a browser is dozens of processes) and counting shared pages once
# per process (RSS) - an over-estimate, but the ranking is what matters.
top_memory() {
    ps -eo rss=,comm= | awk '
        { rss = $1; sub(/^ *[0-9]+ +/, ""); m[app_name($0)] += rss }
        END { for (k in m) printf "%d %s\n", m[k] / 1024, k }
        '"$AWK_APP_NAME" \
        | sort -rn | head -n "${1:-3}"
}

# top_cpu [n]: "<percent> <app>" over the last half second.
top_cpu() {
    top -b -n 2 -d 0.5 -w 200 2>/dev/null \
        | awk '/^top -/ {pass++}
               pass == 2 && $1 ~ /^[0-9]+$/ {cpu = $9; for (i = 1; i < 12; i++) $i = ""; sub(/^ +/, ""); c[app_name($0)] += cpu}
               END {for (k in c) if (c[k] >= 1) printf "%d %s\n", c[k], k}
               '"$AWK_APP_NAME" \
        | sort -rn | head -n "${1:-3}"
}

# slice_usage <unit> [--user]: "<current MB> <max MB|∞>" for a systemd slice.
slice_usage() {
    local unit=$1 scope=${2:-} cur max
    cur=$(systemctl $scope show "$unit" -p MemoryCurrent --value 2>/dev/null)
    max=$(systemctl $scope show "$unit" -p MemoryMax --value 2>/dev/null)
    case $cur in ''|'[not set]'|infinity) cur=0 ;; esac
    if [ -z "$max" ] || [ "$max" = infinity ]; then max="∞"; else max=$((max / 1048576)); fi
    echo "$((cur / 1048576)) $max"
}

# gauge_verdict: after gauge_read, sets GAUGE_LEVEL (ok|warn|crit) and
# GAUGE_REASONS (human-readable, "; "-separated).
#
# Pressure-stall (PSI) is the primary signal: it measures time tasks actually
# spent waiting, which is what lag *is*. Fill levels are secondary, and high
# swap alone is not lag (stale pages from a long uptime sit there harmlessly),
# so swap only counts while RAM is also tight. All thresholds are percentages,
# so they mean the same on any machine. Override with PC_WATCH_* variables.
gauge_verdict() {
    local warn=() crit=()
    local mem_w=${PC_WATCH_MEM_WARN:-88} mem_c=${PC_WATCH_MEM_CRIT:-95}
    local psi_w=${PC_WATCH_PSI_WARN:-10} psi_c=${PC_WATCH_PSI_CRIT:-25}
    local io_w=${PC_WATCH_IO_WARN:-25} io_c=${PC_WATCH_IO_CRIT:-50}
    local cpu_w=${PC_WATCH_CPU_WARN:-60}
    local temp_w=${PC_WATCH_TEMP_WARN:-93} temp_c=${PC_WATCH_TEMP_CRIT:-98}

    [ "$GAUGE_MEM_USED_PCT" -ge "$mem_c" ] && crit+=("memory ${GAUGE_MEM_USED_PCT}% full")
    [ "$GAUGE_MEM_USED_PCT" -ge "$mem_w" ] && [ "$GAUGE_MEM_USED_PCT" -lt "$mem_c" ] && warn+=("memory ${GAUGE_MEM_USED_PCT}% full")
    [ "$GAUGE_SWAP_PCT" -ge 90 ] && [ "$GAUGE_MEM_USED_PCT" -ge 80 ] && crit+=("swap ${GAUGE_SWAP_PCT}% full")
    [ "$GAUGE_SWAP_PCT" -ge 75 ] && [ "$GAUGE_SWAP_PCT" -lt 90 ] && [ "$GAUGE_MEM_USED_PCT" -ge 80 ] && warn+=("swap ${GAUGE_SWAP_PCT}% full")
    [ "$GAUGE_PSI_MEM" -ge "$psi_c" ] || [ "$GAUGE_PSI_MEM_FULL" -ge 10 ] && crit+=("waiting on memory ${GAUGE_PSI_MEM}% of the time")
    [ "$GAUGE_PSI_MEM" -ge "$psi_w" ] && [ "$GAUGE_PSI_MEM" -lt "$psi_c" ] && [ "$GAUGE_PSI_MEM_FULL" -lt 10 ] && warn+=("waiting on memory ${GAUGE_PSI_MEM}% of the time")
    [ "$GAUGE_PSI_IO" -ge "$io_c" ] && crit+=("disk stalls ${GAUGE_PSI_IO}% of the time")
    [ "$GAUGE_PSI_IO" -ge "$io_w" ] && [ "$GAUGE_PSI_IO" -lt "$io_c" ] && warn+=("disk stalls ${GAUGE_PSI_IO}% of the time")
    [ "$GAUGE_PSI_CPU" -ge "$cpu_w" ] && warn+=("CPU queue: tasks waiting ${GAUGE_PSI_CPU}% of the time")
    if [ -n "$GAUGE_TEMP_C" ]; then
        [ "$GAUGE_TEMP_C" -ge "$temp_c" ] && crit+=("CPU at ${GAUGE_TEMP_C}°C, throttling")
        [ "$GAUGE_TEMP_C" -ge "$temp_w" ] && [ "$GAUGE_TEMP_C" -lt "$temp_c" ] && warn+=("CPU at ${GAUGE_TEMP_C}°C")
    fi

    if [ ${#crit[@]} -gt 0 ]; then
        GAUGE_LEVEL=crit
    elif [ ${#warn[@]} -gt 0 ]; then
        GAUGE_LEVEL=warn
    else
        GAUGE_LEVEL=ok
    fi
    local all=("${crit[@]}" "${warn[@]}")
    GAUGE_REASONS=$(IFS=';'; echo "${all[*]}" | sed 's/;/; /g')
    return 0
}
