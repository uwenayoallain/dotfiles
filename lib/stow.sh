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

    # Real directories, never stow-folded symlinks: the private overlay stows
    # into the same unit directory, and install.sh generates drop-ins there
    # (background.slice.d) that must not land inside this repo.
    run mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.local/bin" \
        "$HOME/.config/systemd/user"

    # Ask stow what it would do first, so an already-linked tree is one line.
    local pending
    pending=$( { stow -n -v -t "$HOME" "${STOW_HOME_PACKAGES[@]}"
                 stow -n -v -t "$HOME/.config" "${STOW_CONFIG_PACKAGES[@]}"
                 stow -n -v -t "$HOME/.local/share" "${STOW_SHARE_PACKAGES[@]}"; } 2>&1 | grep -c '^LINK' || true)
    if [ "$pending" -eq 0 ]; then
        print_success "All dotfiles already linked"
        return 0
    fi
    print_info "Linking $pending new file(s)"
    run stow -t "$HOME" "${STOW_HOME_PACKAGES[@]}"
    run stow -t "$HOME/.config" "${STOW_CONFIG_PACKAGES[@]}"
    run stow -t "$HOME/.local/share" "${STOW_SHARE_PACKAGES[@]}"
    print_success "Dotfiles stowed"
}

enable_user_services() {
    print_step "Enabling systemd user services"

    if ! command_exists systemctl; then
        print_warning "systemd not available, skipping user services"
        return 0
    fi

    [ "$DRY_RUN" = true ] || systemctl --user daemon-reload

    # Only this repo's own units: the unit directory also holds the overlay's,
    # project-shipped ones, and vendor ones, which their owners enable. Units
    # whose backing binary is missing stay stowed but inert.
    local unit name exec_bin present=0
    for unit in "$DOTFILES_DIR"/systemd/systemd/user/*.service "$DOTFILES_DIR"/systemd/systemd/user/*.timer; do
        [ -e "$unit" ] || continue
        name=$(basename "$unit")
        exec_bin=$(grep -m1 '^ExecStart=' "$unit" | sed 's/^ExecStart=//' | awk '{print $1}' | tr -d '"' || true)
        exec_bin=${exec_bin//%h/$HOME}
        if [ -n "$exec_bin" ] && [ ! -x "$exec_bin" ]; then
            print_warning "$name: $exec_bin is missing, leaving it disabled"
            continue
        fi
        grep -q '^\[Install\]' "$unit" || continue
        if systemctl --user is-enabled "$name" &> /dev/null; then
            present=$((present + 1))
            continue
        fi
        run systemctl --user enable --now "$name" \
            || print_warning "Could not enable $name, continuing"
    done
    print_present "$present" "user services enabled"
    return 0
}
