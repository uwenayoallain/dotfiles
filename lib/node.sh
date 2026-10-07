#!/usr/bin/env bash

# NVM, Node LTS, and the global packages listed in packages/*/{npm,pnpm,bun}.txt.

NVM_VERSION=v0.40.3

install_node() {
    print_step "Installing Node toolchain"

    export NVM_DIR="$HOME/.config/nvm"

    if [ -s "$NVM_DIR/nvm.sh" ]; then
        mark_present "NVM"
    else
        print_info "Installing NVM..."
        run mkdir -p "$NVM_DIR"
        shielded bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | NVM_DIR='$NVM_DIR' bash"
        print_success "NVM installed"
    fi

    if [ "$DRY_RUN" = true ]; then
        # Load nvm read-only so the probes below see what is really installed.
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm use default > /dev/null 2>&1
        if command_exists node; then mark_present "node $(node --version)"; else print_dry "nvm install --lts && nvm alias default 'lts/*'"; fi
    else
        # shellcheck disable=SC1091
        . "$NVM_DIR/nvm.sh"
        if ! grep -q 'v[0-9]' < <(nvm ls --lts --no-colors 2>/dev/null); then
            nvm install --lts
        fi
        [ "$(nvm alias default 2>/dev/null | grep -c 'lts/\*')" -gt 0 ] || nvm alias default 'lts/*' > /dev/null
        nvm use default > /dev/null
        mark_present "node $(node --version)"
    fi

    if command_exists corepack && ! command_exists pnpm; then
        run corepack enable pnpm
    fi

    if command_exists bun; then
        mark_present "bun"
    else
        print_info "Installing bun..."
        shielded bash -c "curl -fsSL https://bun.sh/install | bash"
    fi
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"

    export PNPM_HOME="$HOME/.local/share/pnpm"
    [ -d "$PNPM_HOME" ] || run mkdir -p "$PNPM_HOME"
    export PATH="$PNPM_HOME:$PNPM_HOME/bin:$PATH"

    install_globals npm npm install -g
    install_globals pnpm pnpm add -g
    install_globals bun bun add -g

    flush_present "node tools"
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

    local pkg installed
    case $manager in
        # `|| true`: a failing lister must not abort the run under set -e.
        npm) installed=$(npm ls -g --depth=0 --parseable 2>/dev/null | sed 's#.*/node_modules/##' || true) ;;
        pnpm) installed=$(pnpm ls -g --depth=0 --parseable 2>/dev/null | sed 's#.*/node_modules/##' || true) ;;
        bun) installed=$(bun pm ls -g 2>/dev/null | sed -n 's/^[├└]── \(.*\)@[^@]*$/\1/p' || true) ;;
    esac
    local entry bin
    for entry in "${packages[@]}"; do
        # Manifest lines may name the command a package provides:
        # "@google/gemini-cli gemini". Present on PATH counts as installed,
        # whichever node or tool put it there.
        read -r pkg bin <<< "$entry"
        if grep -qxF -- "$pkg" <<< "$installed" || { [ -n "$bin" ] && command_exists "$bin"; }; then
            mark_present "$pkg"
            continue
        fi
        print_info "$manager: installing $pkg..."
        run "${install_cmd[@]}" "$pkg" || print_warning "$manager install $pkg failed, continuing"
    done
}
