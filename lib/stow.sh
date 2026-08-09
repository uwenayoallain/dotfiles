#!/usr/bin/env bash

# Symlink the dotfiles with GNU Stow.
#
# Package -> target mapping. Each package directory mirrors the tree below its
# target, so `bashrc/.bashrc` lands at `$HOME/.bashrc`.

STOW_HOME_PACKAGES=(agents bashrc gitconfig localbin skills ssh)
STOW_CONFIG_PACKAGES=(nvim opencode starship systemd tmux vscode wezterm)
STOW_SHARE_PACKAGES=(applications)

BACKUP_DIR=""

# Move any real file that stow would collide with into a timestamped backup,
# preserving its path so it can be restored by hand. Targets are derived from
# the package contents, so a new tracked file never needs a list update here.
#
# backup_package_conflicts <target-dir> <package>...
backup_package_conflicts() {
    local target=$1
    shift
    local pkg rel live

    for pkg in "$@"; do
        [ -d "$DOTFILES_DIR/$pkg" ] || continue
        while IFS= read -r rel; do
            live="$target/$rel"
            # -e follows symlinks, so a link to a deleted file needs -L too.
            [ -e "$live" ] || [ -L "$live" ] || continue

            # Anything already resolving inside this repo is stow's own work,
            # not a conflict. The path need not be a symlink itself — it is
            # enough for a parent directory to be the stow link, as with
            # ~/.config/tmux -> dotfiles/tmux/tmux. Moving those would gut
            # the repo.
            case "$(readlink -f "$live")" in
                "$DOTFILES_DIR"/*) continue ;;
            esac

            # Everything else conflicts, including symlinks pointing outside
            # the repo: stow refuses to adopt a link it does not own (an
            # AppImageLauncher unit linked from /opt, for instance).

            if [ -z "$BACKUP_DIR" ]; then
                BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
                print_info "Backing up conflicting files to $BACKUP_DIR..."
            fi
            run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            run mv "$live" "$BACKUP_DIR/$rel"
            print_info "Backed up ${live#"$HOME"/}"
        done < <(cd "$DOTFILES_DIR/$pkg" && find . -type f -printf '%P\n')
    done
}

backup_conflicts() {
    BACKUP_DIR=""
    backup_package_conflicts "$HOME" "${STOW_HOME_PACKAGES[@]}"
    backup_package_conflicts "$HOME/.config" "${STOW_CONFIG_PACKAGES[@]}"
    backup_package_conflicts "$HOME/.local/share" "${STOW_SHARE_PACKAGES[@]}"
    [ -n "$BACKUP_DIR" ] && print_success "Backup complete"
    return 0
}

stow_dotfiles() {
    print_step "Stowing dotfiles"

    cd "$DOTFILES_DIR" || return 1
    backup_conflicts

    run mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.local/bin"

    print_info "Stowing to \$HOME: ${STOW_HOME_PACKAGES[*]}"
    run stow -t "$HOME" "${STOW_HOME_PACKAGES[@]}"

    print_info "Stowing to ~/.config: ${STOW_CONFIG_PACKAGES[*]}"
    run stow -t "$HOME/.config" "${STOW_CONFIG_PACKAGES[@]}"

    print_info "Stowing to ~/.local/share: ${STOW_SHARE_PACKAGES[*]}"
    run stow -t "$HOME/.local/share" "${STOW_SHARE_PACKAGES[@]}"

    print_success "Dotfiles stowed"
}

enable_user_services() {
    print_step "Enabling systemd user services"

    if ! command_exists systemctl; then
        print_warning "systemd not available, skipping user services"
        return 0
    fi

    run systemctl --user daemon-reload

    # Only services whose backing binary is present get enabled; the rest stay
    # stowed but inert until their app is installed.
    local service unit_dir="$HOME/.config/systemd/user"
    for service in "$unit_dir"/*.service; do
        [ -e "$service" ] || continue
        local name
        name=$(basename "$service")
        local exec_bin
        exec_bin=$(grep -m1 '^ExecStart=' "$service" | sed 's/^ExecStart=//' | awk '{print $1}' | tr -d '"')
        if [ -n "$exec_bin" ] && [ ! -x "$exec_bin" ]; then
            print_warning "$name: $exec_bin is missing, leaving it disabled"
            continue
        fi
        if grep -q '^\[Install\]' "$service"; then
            run systemctl --user enable "$name" \
                || print_warning "Could not enable $name, continuing"
        else
            print_info "$name has no [Install] section, start it manually"
        fi
    done

    print_success "User services processed"
}
