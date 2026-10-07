#!/usr/bin/env bash

# Performance and resource tuning, sized from the machine it runs on.
#
# Every cap here is a fraction of this host's RAM, cores, or swap, never a
# fixed number, so the same repo gives a 8 GB laptop and a 64 GB workstation
# proportionate limits. Re-running recomputes them, so moving the disk to new
# hardware and re-running `./install.sh --only tuning` is enough.
#
# System part (needs sudo):
#   sysctl         swappiness / cache pressure / writeback ratios
#   zram           compressed swap sized from RAM
#   zfs            ARC ceiling as a share of RAM (only when ZFS is loaded)
#   journald       bounded journal
#   docker         log rotation, build-cache GC, and every container under one
#                  containers.slice whose memory/CPU ceilings are a share of
#                  the host — survives container recreation, no compose edits
#   power          keep power-profiles-daemon on `performance`
#   ollama         unload idle models, cap the service as a share of RAM
#   gpu            hybrid-graphics laptops: NVIDIA GPU on-demand + runtime D3
#   pl1            per-model Intel RAPL long-term power cap (thermal headroom)
#
# User part (no sudo):
#   background.slice CPU quota as a share of the cores; the slice itself and
#   its memory ceilings are stowed from systemd/ and already relative.

# --- Host measurements ------------------------------------------------------

host_mem_mb() { awk '/^MemTotal:/ {print int($2 / 1024)}' /proc/meminfo; }
host_cpus() { nproc; }

# pct_of_mem_bytes <percent>
pct_of_mem_bytes() {
    awk -v p="$1" '/^MemTotal:/ {printf "%d", $2 * 1024 * p / 100}' /proc/meminfo
}

# DMI model name. Lenovo keeps the marketing name in product_version and a
# part number in product_name; everyone else uses product_name.
host_model() {
    local version name
    version=$(cat /sys/class/dmi/id/product_version 2>/dev/null || true)
    name=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
    case "$version" in
        ThinkPad*|IdeaPad*|Legion*|Yoga*) echo "$version" ;;
        *) echo "$name" ;;
    esac
}

# Long-term package power limit (PL1), in watts, for models whose firmware
# default exceeds what the chassis can dissipate. Only listed models are
# capped; everywhere else the firmware value stands.
#   ThinkPad E14 Gen 2 (i7-1165G7): firmware 35 W > the chip's 28 W cTDP.
declare -A PL1_WATTS_BY_MODEL=(
    ["ThinkPad E14 Gen 2"]=28
)

# --- Writers ----------------------------------------------------------------

# Read a root-owned file; plain cat first so a dry run needs no password.
root_cat() { cat "$1" 2>/dev/null || sudo -n cat "$1" 2>/dev/null; }

# write_root_file <path> <mode>   (content on stdin)
# Writes only when the content differs. Returns 0 if it changed, 1 if not.
# A dry run prints a diff against the live file, or the whole file if new.
write_root_file() {
    local path=$1 mode=$2 tmp current
    tmp=$(mktemp)
    current=$(mktemp)
    cat > "$tmp"
    if [ -e "$path" ] && root_cat "$path" > "$current" && cmp -s "$tmp" "$current"; then
        TUNING_PRESENT=$(( ${TUNING_PRESENT:-0} + 1 ))
        rm -f "$tmp" "$current"
        return 1
    fi
    if [ "$DRY_RUN" = true ]; then
        if [ -e "$path" ]; then
            print_dry "update $path:"
            diff -u --label live --label new "$current" "$tmp" | tail -n +3 | sed 's/^/      /'
        else
            print_dry "create $path:"
            sed 's/^/      /' "$tmp"
        fi
        rm -f "$tmp" "$current"
        return 0
    fi
    sudo install -D -m "$mode" "$tmp" "$path"
    rm -f "$tmp" "$current"
    print_info "Wrote $path"
    TUNING_CHANGED=true
    return 0
}

# ensure_enabled <unit> [--now]: enable a system unit unless it already is.
ensure_enabled() {
    systemctl is-enabled "$1" &> /dev/null && return 0
    run sudo systemctl enable "$@" || print_warning "Could not enable $1"
}

# Reload systemd once per run, and only if a unit file actually changed.
reload_if_changed() {
    if [ "${TUNING_CHANGED:-false}" = true ] && [ "${TUNING_RELOADED:-false}" != true ]; then
        run sudo systemctl daemon-reload
        TUNING_RELOADED=true
    fi
    return 0
}

# --- System pieces ----------------------------------------------------------

tune_sysctl() {
    # swappiness 10: keep the desktop's working set in RAM and reclaim page
    # cache first. The writeback limits are ratios, so they scale with RAM.
    if write_root_file /etc/sysctl.d/99-desktop-perf.conf 0644 <<'EOF'
# Managed by dotfiles (lib/tuning.sh).
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
EOF
    then
        run sudo sysctl -q -p /etc/sysctl.d/99-desktop-perf.conf || true
    fi
}

tune_zram() {
    if [ ! -e /usr/lib/systemd/system-generators/zram-generator ]; then
        run sudo apt-get install -y systemd-zram-generator \
            || { print_warning "systemd-zram-generator unavailable, skipping zram"; return 0; }
    fi
    # Half of RAM, at most 8 GiB. zstd compresses desktop pages ~3x, so this
    # absorbs most swap traffic before anything reaches the disk.
    write_root_file /etc/systemd/zram-generator.conf 0644 <<'EOF' || true
# Managed by dotfiles (lib/tuning.sh).
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
EOF
    # Bring it up on a fresh machine. On a running one the device already
    # exists and resizing it would mean swapping everything back in first.
    if ! grep -q zram < <(swapon --show=NAME --noheadings 2>/dev/null); then
        reload_if_changed
        run sudo systemctl start systemd-zram-setup@zram0.service \
            || print_warning "Could not start zram now; it starts on next boot"
    fi
}

tune_zfs_arc() {
    [ -e /sys/module/zfs/parameters/zfs_arc_max ] || return 0

    # ARC max 20% of RAM, min 6%. Uncapped, ZFS takes ~half of RAM and fights
    # browsers and containers for it, which is what pushed this desktop into
    # swap in the first place.
    local max min
    max=$(pct_of_mem_bytes 20)
    min=$(pct_of_mem_bytes 6)

    # Applied through tmpfiles.d, NOT modprobe.d: on ZFS-root a modprobe.d
    # option only takes effect once baked into the initramfs, and regenerating
    # the initramfs is exactly what has broken booting on ZFS-root before.
    write_root_file /etc/tmpfiles.d/zfs-arc.conf 0644 <<EOF || true
# Managed by dotfiles (lib/tuning.sh): ARC = 6-20% of RAM.
# tmpfiles.d, not modprobe.d -- see the note in lib/tuning.sh.
w /sys/module/zfs/parameters/zfs_arc_max - - - - $max
w /sys/module/zfs/parameters/zfs_arc_min - - - - $min
EOF
    # Order matters when shrinking: max must never drop below min.
    if [ "$(cat /sys/module/zfs/parameters/zfs_arc_max)" != "$max" ] || [ "$(cat /sys/module/zfs/parameters/zfs_arc_min)" != "$min" ]; then
        run sudo sh -c "echo $max > /sys/module/zfs/parameters/zfs_arc_max; echo $min > /sys/module/zfs/parameters/zfs_arc_min" \
            || print_warning "Could not apply the ARC cap live; it applies on next boot"
    fi

    if command_exists zpool; then
        tune_zpool_capacity
    fi
}

tune_zpool_capacity() {
    write_root_file /usr/local/bin/zpool-capacity-check 0755 <<'EOF' || true
#!/bin/sh
# Managed by dotfiles (lib/tuning.sh).
# Warn when any pool passes 85%: ZFS allocation slows sharply past ~80%.
THRESHOLD=85
zpool list -Ho name,capacity,free | while read -r pool cap free; do
    cap=${cap%\%}
    [ "$cap" -lt "$THRESHOLD" ] && continue
    msg="$pool is ${cap}% full (${free} free). ZFS slows down past 80% - free some space."
    logger -t zpool-capacity "$msg"
    for uid in $(loginctl list-users --no-legend 2>/dev/null | awk '$1>=1000{print $1}'); do
        user=$(id -nu "$uid" 2>/dev/null) || continue
        runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
            notify-send -u critical -i drive-harddisk 'Disk filling up' "$msg" 2>/dev/null
    done
done
EOF
    write_root_file /etc/systemd/system/zpool-capacity.service 0644 <<'EOF' || true
[Unit]
Description=Warn when a ZFS pool exceeds 85% capacity

[Service]
Type=oneshot
ExecStart=/usr/local/bin/zpool-capacity-check
EOF
    write_root_file /etc/systemd/system/zpool-capacity.timer 0644 <<'EOF' || true
[Unit]
Description=Twice-daily ZFS pool capacity check

[Timer]
OnBootSec=10min
OnUnitActiveSec=12h
Persistent=true

[Install]
WantedBy=timers.target
EOF
    reload_if_changed
    ensure_enabled zpool-capacity.timer --now
}

tune_journald() {
    if write_root_file /etc/systemd/journald.conf.d/10-size.conf 0644 <<'EOF'
# Managed by dotfiles (lib/tuning.sh).
[Journal]
SystemMaxUse=200M
EOF
    then
        run sudo systemctl restart systemd-journald || true
    fi
}

tune_docker() {
    command_exists docker || return 0

    local cpus mem_high mem_max swap_max quota
    cpus=$(host_cpus)
    quota=$(( cpus * 75 ))
    swap_max=$(pct_of_mem_bytes 20)

    # One slice for every container. The ceilings are fractions of this host,
    # and because the slice is the cgroup parent rather than a per-container
    # flag, they survive `docker compose up --force-recreate` and need no
    # change to any project's compose file. Containers still compete among
    # themselves; they just cannot collectively starve the desktop.
    #   MemoryHigh 50%: reclaim pressure starts here, before the host swaps.
    #   MemoryMax  65%: hard ceiling for all containers together.
    #   CPUQuota   75% of the cores; CPUWeight 50 yields to the desktop (100).
    local slice_changed=false
    if write_root_file /etc/systemd/system/containers.slice 0644 <<EOF
# Managed by dotfiles (lib/tuning.sh). Sized for $cpus CPUs / $(host_mem_mb) MB.
[Unit]
Description=All Docker containers, capped as a share of the host

[Slice]
MemoryHigh=50%
MemoryMax=65%
MemorySwapMax=$swap_max
CPUWeight=50
CPUQuota=${quota}%
EOF
    then
        slice_changed=true
    fi

    # Merge into any existing daemon.json rather than overwrite it.
    local merged
    merged=$(root_cat /etc/docker/daemon.json | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
cfg = json.loads(raw) if raw else {}
cfg.setdefault("log-driver", "json-file")
cfg.setdefault("log-opts", {"max-size": "10m", "max-file": "3"})
cfg.setdefault("builder", {"gc": {"enabled": True, "defaultKeepStorage": "5GB",
                                  "policy": [{"keepStorage": "5GB", "all": True}]}})
cfg["cgroup-parent"] = "containers.slice"
print(json.dumps(cfg, indent=2))
')
    local daemon_changed=false
    if printf '%s\n' "$merged" | write_root_file /etc/docker/daemon.json 0644; then
        daemon_changed=true
    fi

    [ "$slice_changed" = true ] && reload_if_changed

    if [ "$daemon_changed" = true ]; then
        # The daemon must restart to pick up cgroup-parent; containers then land
        # in the slice as they start (verified: no recreate needed). Restarting
        # under running containers stops every one without a restart policy,
        # so do it only when nothing is running.
        if [ -z "$(docker ps -q 2>/dev/null)" ]; then
            run sudo systemctl restart docker || print_warning "docker restart failed"
        else
            print_warning "Docker limits take effect after 'sudo systemctl restart docker' (containers without a restart policy must be started again)"
        fi
    fi
}

tune_power() {
    command_exists powerprofilesctl || return 0
    # GNOME flips to power-saver on low battery and never flips back; on AC
    # that pins the CPU near its base clock. Re-assert performance at boot.
    write_root_file /etc/systemd/system/force-performance.service 0644 <<'EOF' || true
[Unit]
Description=Force power-profiles-daemon to performance
After=power-profiles-daemon.service
Wants=power-profiles-daemon.service

[Service]
Type=oneshot
RemainAfterExit=yes
# Retry: PPD may not own its D-Bus name yet at boot.
ExecStart=/bin/sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do /usr/bin/powerprofilesctl set performance && exit 0; sleep 2; done; exit 1'

[Install]
WantedBy=multi-user.target
EOF
    reload_if_changed
    ensure_enabled force-performance.service
}

tune_ollama() {
    systemctl cat ollama.service &> /dev/null || return 0
    # A loaded model can take most of RAM. Unload after 5 idle minutes, keep
    # one model resident at a time, and cap the service as a share of RAM so
    # a too-large model fails to load rather than push the desktop into swap.
    if write_root_file /etc/systemd/system/ollama.service.d/50-limits.conf 0644 <<'EOF'
# Managed by dotfiles (lib/tuning.sh).
[Service]
Environment=OLLAMA_KEEP_ALIVE=5m
Environment=OLLAMA_MAX_LOADED_MODELS=1
MemoryHigh=45%
MemoryMax=60%
CPUWeight=50
EOF
    then
        reload_if_changed
        run sudo systemctl try-restart ollama.service || true
    fi
}

is_laptop() {
    ls /sys/class/power_supply/BAT* &> /dev/null
}

# Hybrid-graphics laptops: let the NVIDIA GPU sleep until something asks for it.
#
# Ubuntu's "nvidia" PRIME profile keeps the discrete GPU powered at all times,
# a constant few watts of heat inside a laptop's power budget. "on-demand"
# renders the desktop on the integrated GPU and wakes the NVIDIA one only for
# work that requests it (CUDA, prime-run); runtime D3 powers it off between.
#
# This writes exactly the files `prime-select on-demand` writes, but skips its
# `update-initramfs`, which has broken booting on ZFS-root before. That is only
# safe when the nvidia modules are not inside the initramfs; otherwise warn.
tune_gpu() {
    command_exists prime-select || return 0
    is_laptop || return 0
    [ -f /run/nvidia_runtimepm_supported ] || return 0
    local mode
    mode=$(cat /etc/prime-discrete 2>/dev/null || echo unknown)
    if [ "$mode" = on-demand ] && [ -f /lib/modprobe.d/nvidia-runtimepm.conf ]; then
        mark_present "NVIDIA on-demand"
        return 0
    fi
    # Process substitution, not a pipe: under pipefail `cmd | grep -q` fails
    # with SIGPIPE whenever grep exits early, which would read as "not found"
    # and skip this safety check.
    if grep -qE '/nvidia(-drm|-modeset)?\.ko' < <(lsinitramfs "/boot/initrd.img-$(uname -r)" 2>/dev/null); then
        print_warning "NVIDIA GPU is always on; the driver is in the initramfs, so switch with 'sudo prime-select on-demand' yourself"
        return 0
    fi
    write_root_file /lib/modprobe.d/nvidia-runtimepm.conf 0644 <<'EOF' || true
options nvidia "NVreg_DynamicPowerManagement=0x02"
EOF
    run sudo rm -f /lib/modprobe.d/blacklist-nvidia.conf
    printf 'on-demand\n' | write_root_file /etc/prime-discrete 0644 || true
    print_warning "NVIDIA GPU switched to on-demand: it sleeps after the next reboot (CUDA/prime-run still wake it)"
}

tune_pl1() {
    local model watts rapl=/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
    model=$(host_model)
    watts="${PL1_WATTS_BY_MODEL[$model]:-}"
    [ -n "$watts" ] || return 0
    [ -e "$rapl" ] || { print_warning "$model: no intel-rapl, skipping PL1 cap"; return 0; }

    local uw=$(( watts * 1000000 ))
    # Deliberately NOT RemainAfterExit=yes: the unit has to go back to inactive
    # so the timer's OnUnitActiveSec can re-run it. ThinkPad DYTC firmware
    # resets PL1 on AC and profile changes, and thermald cannot run on DYTC
    # machines, so a periodic re-assert is the only thing that holds.
    write_root_file /etc/systemd/system/cap-pl1.service 0644 <<EOF || true
[Unit]
Description=Cap Intel RAPL long-term power limit (PL1) at ${watts}W for thermal headroom

[Service]
Type=oneshot
# Deliberately NOT RemainAfterExit=yes -- the unit must return to inactive so
# cap-pl1.timer (OnUnitActiveSec) can re-run it when firmware resets PL1.
# intel_rapl_msr is a loadable module and may appear late at boot.
ExecStart=/bin/sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do if [ -e $rapl ]; then echo $uw > $rapl && exit 0; fi; sleep 2; done; exit 1'
EOF
    write_root_file /etc/systemd/system/cap-pl1.timer 0644 <<EOF || true
[Unit]
Description=Re-assert the ${watts}W PL1 cap (firmware can override it)

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
AccuracySec=10s

[Install]
WantedBy=timers.target
EOF
    reload_if_changed
    ensure_enabled cap-pl1.timer --now
}

# --- User pieces ------------------------------------------------------------

tune_user() {
    local cpus quota swap_max dropin="$HOME/.config/systemd/user/background.slice.d"
    cpus=$(host_cpus)
    # Swap for all batch jobs together: 15% of RAM. They should fail inside
    # their own cgroup long before they fill the swap the desktop relies on.
    swap_max=$(pct_of_mem_bytes 15)
    # Background jobs together may use at most half of the cores. Per-job
    # CPUWeight=idle already lets the desktop preempt them; the quota bounds
    # heat, which on a thin laptop is what actually throttles the desktop.
    quota=$(( cpus * 50 ))

    local file="$dropin/50-host.conf" want changed=false
    want=$(printf '# Generated by dotfiles (lib/tuning.sh) for this host: %s CPUs, %s MB.\n[Slice]\nCPUQuota=%s%%\nMemorySwapMax=%s\n' \
        "$cpus" "$(host_mem_mb)" "$quota" "$swap_max")
    if [ "$(cat "$file" 2>/dev/null)" = "$want" ]; then
        mark_present "background.slice sized for $cpus CPUs"
    elif [ "$DRY_RUN" = true ]; then
        print_dry "write $file (CPUQuota=${quota}% MemorySwapMax=$swap_max)"
    else
        mkdir -p "$dropin"
        printf '%s\n' "$want" > "$file"
        print_info "Sized background.slice: CPUQuota=${quota}%, MemorySwapMax=$swap_max"
        changed=true
    fi

    if command_exists gsettings; then
        if [ "$(gsettings get org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery 2>/dev/null)" = false ]; then
            mark_present "no auto power-saver"
        else
            run gsettings set org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery false || true
        fi
    fi

    if command_exists systemctl; then
        [ "$changed" = true ] && run systemctl --user daemon-reload
        local unit
        for unit in pc-freeze-guard.timer pc-watch.service; do
            if systemctl --user is-enabled "$unit" &> /dev/null; then
                mark_present "$unit"
            else
                run systemctl --user enable --now "$unit" || print_warning "Could not enable $unit"
            fi
        done
    fi
    flush_present "user settings"
    return 0
}

install_tuning() {
    print_step "Tuning resources for $(host_cpus) CPUs / $(host_mem_mb) MB RAM ($(host_model))"
    tune_sysctl
    tune_zram
    tune_zfs_arc
    tune_journald
    tune_docker
    tune_power
    tune_ollama
    tune_gpu
    tune_pl1
    print_present "${TUNING_PRESENT:-0}" "tuning files"
    flush_present "settings"
    return 0
}

install_user_tuning() {
    print_step "Tuning user services"
    tune_user
}
