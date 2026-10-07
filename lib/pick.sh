#!/usr/bin/env bash

# Interactive selection for `install.sh --pick`.
#
# Walks through tiers, then modules, then (optionally) the individual apps in
# each manifest, using whiptail checklists. Everything starts pre-selected the
# way a plain `./install.sh` would run, so pressing Enter through every screen
# gives the default install. Deselected packages land in EXCLUDED_PACKAGES,
# which read_manifest (lib/common.sh) skips.

# checklist <title> <text> <result-array> <tag> <label> <on|off> ...
# Shows a whiptail checklist and stores the selected tags in <result-array>.
# Returns 1 if the user cancelled.
checklist() {
    local title=$1 text=$2
    # gum's picker when cli-kit is loaded and there is a terminal.
    if [ "${CLI_KIT:-false}" = true ] && ck_interactive; then
        ui_step "$title"
        ui_pick "$text" "$3" "${@:4}"
        return
    fi
    local -n _picked=$3
    shift 3
    local items=$(( $# / 3 ))
    local height=$(( items + 9 ))
    [ "$height" -gt 24 ] && height=24
    local out
    out=$(whiptail --title "$title" --separate-output --checklist "$text" \
        "$height" 78 $(( height - 8 )) "$@" 3>&1 1>&2 2>&3) || return 1
    _picked=()
    local tag
    while IFS= read -r tag; do
        [ -n "$tag" ] && _picked+=("$tag")
    done <<< "$out"
    return 0
}

pick_tiers() {
    local args=() tier on
    local -A desc=(
        [core]="Shell, build tools, CLI utilities (safe on a server)"
        [dev]="Docker, SDKs, AI CLIs, VS Code, agent skills"
        [desktop]="Browsers, GUI apps, fonts, GNOME settings"
        [optional]="NVIDIA driver, ZFS, NTFS/exFAT (check hardware)"
    )
    for tier in "${ALL_TIERS[@]}"; do
        on=off
        tier_active "$tier" && on=on
        args+=("$tier" "${desc[$tier]}" "$on")
    done
    local picked=()
    checklist "Tiers" "What kind of machine is this?" picked "${args[@]}" || return 1
    ACTIVE_TIERS=("${picked[@]}")
}

pick_modules() {
    local args=() entry name
    for entry in "${MODULES[@]}"; do
        name=${entry%%:*}
        # Offer only modules the chosen tiers would run.
        module_enabled "$name" || continue
        args+=("$name" "${entry#*:}" on)
    done
    local picked=()
    checklist "Modules" "Which install steps should run?" picked "${args[@]}" || return 1
    ONLY_MODULES=("${picked[@]}")
    # An empty ONLY_MODULES means "everything" to module_enabled.
    [ ${#ONLY_MODULES[@]} -eq 0 ] && ONLY_MODULES=(none)
    return 0
}

# One checklist per manifest of the active tiers, for the modules that will run.
pick_packages() {
    if [ "${CLI_KIT:-false}" = true ] && ck_interactive; then
        ui_confirm "Review the individual apps in each list? (No installs everything listed)" no || return 0
    else
        whiptail --title "Apps" --yesno \
            "Review the individual apps and packages in each list?\n\nChoose No to install every listed package." \
            10 70 || return 0
    fi

    local -A manager_module=(
        [apt]=apt [brew]=brew [snap]=snap [flatpak]=flatpak
        [npm]=node [pnpm]=node [bun]=node [vscode]=vscode
    )
    local tier manifest manager entries entry args picked pkg
    for tier in "${ACTIVE_TIERS[@]}"; do
        for manifest in "$PACKAGES_DIR/$tier"/*.txt; do
            [ -e "$manifest" ] || continue
            manager=$(basename "$manifest" .txt)
            [ -n "${manager_module[$manager]:-}" ] || continue
            module_enabled "${manager_module[$manager]}" || continue

            entries=()
            read_manifest entries "$manifest"
            [ ${#entries[@]} -gt 0 ] || continue
            args=()
            for entry in "${entries[@]}"; do
                pkg=${entry%% *}
                args+=("$pkg" "" on)
            done
            picked=()
            checklist "$tier / $manager" "Untick anything you do not want on this machine." \
                picked "${args[@]}" || continue
            for entry in "${entries[@]}"; do
                pkg=${entry%% *}
                printf '%s\n' "${picked[@]}" | grep -qxF -- "$pkg" || EXCLUDED_PACKAGES+=("$pkg")
            done
        done
    done
    return 0
}

run_picker() {
    # Prefer gum: fetch it without root if cli-kit is here but gum is not.
    if [ "${CLI_KIT:-false}" = true ] && ! ck_has_gum && [ -x "$CK_DIR/install-gum" ]; then
        print_info "Fetching gum for the pickers..."
        "$CK_DIR/install-gum" && export PATH="$HOME/.local/bin:$PATH"
    fi
    if [ "${CLI_KIT:-false}" = true ] && ck_interactive; then
        :
    elif ! command_exists whiptail; then
        print_warning "whiptail is not installed; installing it for --pick"
        sudo apt-get install -y whiptail || { print_error "Cannot run --pick without whiptail"; exit 1; }
    fi
    pick_tiers || { print_warning "Cancelled"; exit 0; }
    pick_modules || { print_warning "Cancelled"; exit 0; }
    pick_packages
    return 0
}
