#!/usr/bin/env bash

# Linuxbrew and the formulae listed in packages/*/brew.txt.

BREW_PREFIX=/home/linuxbrew/.linuxbrew

load_brew() {
    if [ -x "$BREW_PREFIX/bin/brew" ]; then
        eval "$("$BREW_PREFIX/bin/brew" shellenv)"
        return 0
    fi
    command_exists brew
}

install_brew() {
    print_step "Installing Homebrew"

    if ! load_brew; then
        shielded /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        load_brew
        print_success "Homebrew installed"
    fi

    local files=()
    tier_manifests files brew
    [ ${#files[@]} -eq 0 ] && return 0

    local packages=()
    read_manifest packages "${files[@]}"

    # `brew install` is happy to take the whole list, but doing them one at a
    # time means a single broken formula does not lose the rest of the run.
    local installed pkg present=0
    installed=$(brew list --formula -1 2>/dev/null || true)
    for pkg in "${packages[@]}"; do
        if grep -qx "$pkg" <<< "$installed"; then
            present=$((present + 1))
        else
            print_info "Installing $pkg..."
            run brew install "$pkg" || print_warning "brew install $pkg failed, continuing"
        fi
    done
    print_present "$present" "Homebrew formulae"
    return 0
}

setup_fzf() {
    [ -f "$BREW_PREFIX/opt/fzf/install" ] || return 0
    # Once per fzf version: a stamp records which one was set up.
    local stamp="$HOME/.local/state/dotfiles/fzf-setup" version
    version=$(readlink -f "$BREW_PREFIX/opt/fzf")
    [ "$(cat "$stamp" 2>/dev/null)" = "$version" ] && return 0
    print_info "Setting up fzf key bindings..."
    run "$BREW_PREFIX/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-zsh \
        && run mkdir -p "$(dirname "$stamp")" && { [ "$DRY_RUN" = true ] || echo "$version" > "$stamp"; }
    return 0
}
