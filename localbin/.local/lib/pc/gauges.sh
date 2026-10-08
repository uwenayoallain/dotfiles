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
    if (n ~ /^(zen|firefox|Isolated Web Co|Web Content|WebExtensions|Privileged Cont|RDD Process|Socket Process|Utility Process|GeckoMain|forkserver)/) return "zen/firefox"
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
        | sort -rn 2>/dev/null | head -n "${1:-3}"
}

# top_cpu [n]: "<percent> <app>" over the last half second.
top_cpu() {
    top -b -n 2 -d 0.5 -w 200 2>/dev/null \
        | awk '/^top -/ {pass++}
               pass == 2 && $1 ~ /^[0-9]+$/ {cpu = $9; for (i = 1; i < 12; i++) $i = ""; sub(/^ +/, ""); c[app_name($0)] += cpu}
               END {for (k in c) if (c[k] >= 1) printf "%d %s\n", c[k], k}
               '"$AWK_APP_NAME" \
        | sort -rn 2>/dev/null | head -n "${1:-3}"
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

# gauge_lag: after gauge_read, sets LAG_LEVEL (ok|warn|crit) and LAG_REASONS,
# counting only what a person at the keyboard actually feels: time tasks spent
# *waiting* (pressure stalls), a CPU so saturated that tasks queue, memory about
# to run out, and the CPU hot enough to throttle. Fill levels on their own
# (RAM 90% full of cache, stale swap) are not lag and never alert.
gauge_lag() {
    local warn=() crit=()
    [ "$GAUGE_PSI_MEM_FULL" -ge 10 ] && crit+=("everything is waiting on memory")
    [ "$GAUGE_PSI_MEM" -ge 30 ] && crit+=("apps wait on memory ${GAUGE_PSI_MEM}% of the time")
    [ "$GAUGE_PSI_MEM" -ge 15 ] && [ "$GAUGE_PSI_MEM" -lt 30 ] && warn+=("apps wait on memory ${GAUGE_PSI_MEM}% of the time")
    [ "$GAUGE_MEM_USED_PCT" -ge 97 ] && crit+=("memory almost exhausted (${GAUGE_MEM_USED_PCT}%)")
    [ "$GAUGE_PSI_IO" -ge 40 ] && crit+=("disk stalls ${GAUGE_PSI_IO}% of the time")
    [ "$GAUGE_PSI_IO" -ge 25 ] && [ "$GAUGE_PSI_IO" -lt 40 ] && warn+=("disk stalls ${GAUGE_PSI_IO}% of the time")
    [ "$GAUGE_PSI_CPU" -ge 80 ] && warn+=("CPU saturated: tasks queue ${GAUGE_PSI_CPU}% of the time")
    [ -n "$GAUGE_TEMP_C" ] && [ "$GAUGE_TEMP_C" -ge 97 ] && warn+=("CPU throttling at ${GAUGE_TEMP_C}°C")
    if [ ${#crit[@]} -gt 0 ]; then LAG_LEVEL=crit
    elif [ ${#warn[@]} -gt 0 ]; then LAG_LEVEL=warn
    else LAG_LEVEL=ok; fi
    local all=("${crit[@]}" "${warn[@]}")
    LAG_REASONS=$(IFS=';'; echo "${all[*]}" | sed 's/;/; /g')
    return 0
}

# Processes pc-fix never offers to stop: the desktop session, audio, input,
# terminals and shells (stopping those would take pc-fix itself down).
PROTECTED_RE='^(gnome-shell|gnome-session|Xwayland|Xorg|systemd|dbus|pipewire|wireplumber|gdm|gsd-|ibus|at-spi|xdg-|gvfs|evolution-|tracker-|goa-|gjs|mutter|gnome-keyring|dconf|gnome-terminal|kgx|ptyxis|wezterm|bash|sh|zsh|fish|tmux|sudo|ssh|gpg-agent|pc-fix|gum|top|ps|sort|awk|sleep|notify-send|snapd-desktop|xdg-desktop|evolution-alarm|nautilus)'

# Session services that are never stopped, even when an app runs inside them
# (D-Bus activates some apps inside dbus.service; stopping that would end the
# desktop session). Apps found inside them are offered per process instead.
CORE_UNIT_RE='^(dbus|dbus-broker|pipewire|pipewire-pulse|wireplumber|filter-chain|gnome-|org\.gnome\.|xdg-|at-spi|evolution-|tracker-|gvfs|ibus|dconf|gcr-|snapd|snap\.snapd|init|session|appimagelauncherd|pc-watch|pc-freeze-guard)'

# heavy_apps [n]: the n heaviest things this user runs, grouped the way
# systemd already groups them, one per line:
#   <MB>\t<cpu%>\t<processes>\t<kind>\t<target>\t<name>
#   kind=unit  target=<unit,unit,...>     (a launched app's scopes, or a service)
#   kind=pids  target=<pid,pid,...>       (commands in a terminal, or apps
#                                          living inside a core session unit)
# Memory is summed RSS; CPU is measured over the last half second.
heavy_apps() {
    local cpu_file
    cpu_file=$(mktemp)
    top -b -n 2 -d 0.5 -w 200 -u "$UID" 2>/dev/null \
        | awk '/^top -/ {pass++} pass == 2 && $1 ~ /^[0-9]+$/ {print $1, $9}' > "$cpu_file"
    ps -u "$UID" -o pid=,rss=,comm= | awk -v cpuf="$cpu_file" -v protect="$PROTECTED_RE" -v core="$CORE_UNIT_RE" '
        BEGIN { while ((getline line < cpuf) > 0) { split(line, a, " "); cpu[a[1]] = a[2] } }
        {
            pid = $1; rss = $2
            sub(/^ *[0-9]+ +[0-9]+ +/, ""); comm = $0
            if (comm ~ protect || rss == 0) next
            cg = ""; f = "/proc/" pid "/cgroup"
            if ((getline cg < f) > 0) close(f); else next
            n = split(cg, parts, "/"); unit = parts[n]
            if (unit ~ /^docker-/) next     # containers are listed via docker itself
            if (unit ~ /^vte-spawn-|^tmux-spawn-/ || unit !~ /\.(scope|service)$/ || unit ~ core) {
                # A terminal tab or a core unit: one row per command, per tab.
                name = app_name(comm); key = "pids:" unit ":" name; kind = "pids"; tgt = pid
            } else if (unit ~ /^app-/) {
                # app-gnome-org.gnome.Nautilus-1234.scope -> Nautilus; an app
                # spread over several scopes becomes one row stopping them all.
                name = unit; sub(/^app-(gnome|flatpak|snap)?-?/, "", name); sub(/-[0-9]+\.scope$/, "", name)
                sub(/\.(scope|service)$/, "", name); gsub(/\\x2d/, "-", name); sub(/@.*$/, "", name); sub(/^.*\./, "", name)
                key = "app:" name; kind = "unit"; tgt = unit
            } else {
                name = unit; sub(/\.service$/, "", name); sub(/^snap\./, "", name); sub(/\..*$/, "", name)
                name = name " (service)"; key = "svc:" unit; kind = "unit"; tgt = unit
            }
            m[key] += rss; c[key] += cpu[pid]; k[key]++; K[key] = kind; N[key] = name
            if (index("," t[key] ",", "," tgt ",") == 0) t[key] = t[key] (t[key] == "" ? "" : ",") tgt
        }
        END { for (x in m) printf "%d\t%d\t%d\t%s\t%s\t%s\n", m[x] / 1024, c[x], k[x], K[x], t[x], N[x] }
        '"$AWK_APP_NAME" | sort -t$'\t' -k1,1nr 2>/dev/null | head -n "${1:-10}"
    rm -f "$cpu_file"
}
