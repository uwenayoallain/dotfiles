#!/usr/bin/env bash

# GNOME desktop settings stored as dconf dumps in dconf/.
# Each file is named after the dconf path it covers, with '/' written as ':'.

DCONF_DIR="$DOTFILES_DIR/dconf"

# dconf paths that are worth carrying to a new machine. Everything else is
# either machine-specific (monitors, window positions) or a default.
DCONF_PATHS=(
    /org/gnome/terminal/
    /org/gnome/shell/extensions/tiling-assistant/
    /org/gnome/desktop/interface/
    /org/gnome/desktop/wm/keybindings/
    /org/gnome/settings-daemon/plugins/media-keys/
)

dconf_file_for() {
    echo "$DCONF_DIR/$(echo "${1#/}" | tr '/' ':' | sed 's/:$//').ini"
}

dump_dconf() {
    command_exists dconf || { print_warning "dconf not available"; return 0; }
    mkdir -p "$DCONF_DIR"
    local path file
    for path in "${DCONF_PATHS[@]}"; do
        file=$(dconf_file_for "$path")
        if dconf dump "$path" > "$file" 2>/dev/null && [ -s "$file" ]; then
            print_info "Dumped $path"
        else
            rm -f "$file"
        fi
    done
}

load_dconf() {
    print_step "Restoring GNOME settings"

    if ! command_exists dconf; then
        print_warning "dconf not available, skipping GNOME settings"
        return 0
    fi

    local path file
    for path in "${DCONF_PATHS[@]}"; do
        file=$(dconf_file_for "$path")
        [ -f "$file" ] || continue
        print_info "Loading $path"
        if [ "$DRY_RUN" = true ]; then
            print_dry "dconf load $path < $file"
        else
            dconf load "$path" < "$file" || print_warning "Failed to load $path, continuing"
        fi
    done

    print_success "GNOME settings restored"
    print_warning "Terminal profiles are restored by UUID — pick the Catppuccin profile as default in Preferences"
}

install_vscode_extensions() {
    print_step "Installing VS Code extensions"

    if ! command_exists code; then
        print_warning "code command not found, skipping extensions"
        return 0
    fi

    local files=()
    tier_manifests files vscode
    [ ${#files[@]} -eq 0 ] && return 0

    local extensions=()
    read_manifest extensions "${files[@]}"

    local installed ext
    installed=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
    for ext in "${extensions[@]}"; do
        if grep -qx "$(tr '[:upper:]' '[:lower:]' <<< "$ext")" <<< "$installed"; then
            continue
        fi
        print_info "Installing extension $ext..."
        run code --install-extension "$ext" --force \
            || print_warning "Could not install $ext, continuing"
    done

    print_success "VS Code extensions installed"
}
