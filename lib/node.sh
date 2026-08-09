#!/usr/bin/env bash

# NVM, Node LTS, and the global packages listed in packages/*/{npm,pnpm,bun}.txt.

NVM_VERSION=v0.40.3

install_node() {
    print_step "Installing Node toolchain"

    export NVM_DIR="$HOME/.config/nvm"

    if [ -s "$NVM_DIR/nvm.sh" ]; then
        print_info "NVM is already installed"
    else
        print_info "Installing NVM..."
        run mkdir -p "$NVM_DIR"
        shielded bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | NVM_DIR='$NVM_DIR' bash"
        print_success "NVM installed"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[dry-run]${NC} nvm install --lts && nvm alias default 'lts/*'"
    else
        # shellcheck disable=SC1091
        . "$NVM_DIR/nvm.sh"
        if ! nvm ls --lts --no-colors 2>/dev/null | grep -q 'v[0-9]'; then
            nvm install --lts
        fi
        nvm alias default 'lts/*'
        nvm use default
        print_success "Node active version: $(node --version)"
    fi

    if command_exists corepack; then
        run corepack enable pnpm
    fi

    if command_exists bun; then
        print_info "bun is already installed"
    else
        print_info "Installing bun..."
        shielded bash -c "curl -fsSL https://bun.sh/install | bash"
    fi
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"

    export PNPM_HOME="$HOME/.local/share/pnpm"
    run mkdir -p "$PNPM_HOME"
    export PATH="$PNPM_HOME:$PNPM_HOME/bin:$PATH"

    install_globals npm npm install -g
    install_globals pnpm pnpm add -g
    install_globals bun bun add -g

    print_success "Node toolchain ready"
}

# install_globals <manifest-name> <install command...>
install_globals() {
    local manager=$1
    shift
    local install_cmd=("$@")


    command_exists "$manager" || {
        print_warning "$manager not found, skipping its global packages"
        return 0
    }

    local files=()
    tier_manifests files "$manager"
    [ ${#files[@]} -eq 0 ] && return 0

    local packages=()
    read_manifest packages "${files[@]}"
    [ ${#packages[@]} -eq 0 ] && return 0

    local pkg
    for pkg in "${packages[@]}"; do
        print_info "$manager: installing $pkg..."
        run "${install_cmd[@]}" "$pkg" || print_warning "$manager install $pkg failed, continuing"
    done
}
