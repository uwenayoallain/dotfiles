#!/usr/bin/env bash

# Vite+ (Node versions), and the global packages listed in packages/*/{npm,pnpm,bun}.txt.


install_node() {
    print_step "Installing Node toolchain"

    # Vite+ manages Node: versions, the global default, and the node/npm/npx
    # shims in ~/.vite-plus/bin. One manager, so there is never a second Node
    # whose global packages shadow or hide the first one's.
    if [ -d "$HOME/.vite-plus" ]; then
        mark_present "Vite+"
    else
        print_info "Installing Vite+..."
        shielded bash -c "curl -fsSL https://viteplus.dev/install.sh | bash" \
            || { print_warning "Vite+ install failed, skipping the Node toolchain"; return 0; }
    fi
    export VP_HOME="$HOME/.vite-plus"
    export PATH="$VP_HOME/bin:$PATH"

    if command_exists node; then
        mark_present "node $(node --version)"
    else
        run vp env default lts || print_warning "Could not set up Node LTS with Vite+"
    fi

    install_corepack_wrappers

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

# pnpm, pnpx, yarn and yarnpkg as tiny wrappers around `corepack`, found on
# PATH through Vite+'s shims. `corepack enable` would instead symlink into one
# specific Node version's directory, which breaks the day that version is
# upgraded or cleaned away.
install_corepack_wrappers() {
    local tool dir="$HOME/.local/bin" added=()
    for tool in pnpm pnpx yarn yarnpkg; do
        if [ -f "$dir/$tool" ] && grep -q 'exec corepack' "$dir/$tool" 2>/dev/null; then
            continue
        fi
        if [ "$DRY_RUN" = true ]; then
            print_dry "write $dir/$tool (corepack wrapper)"
            continue
        fi
        mkdir -p "$dir"
        rm -f "$dir/$tool"
        printf '#!/bin/sh\n# corepack wrapper (dotfiles lib/node.sh): follows whichever Node is current.\nexec corepack %s "$@"\n' "$tool" > "$dir/$tool"
        chmod +x "$dir/$tool"
        added+=("$tool")
    done
    [ ${#added[@]} -gt 0 ] && print_info "corepack wrappers: ${added[*]}"
    mark_present "pnpm/yarn via corepack"
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
        # "@openai/codex codex". Present on PATH counts as installed,
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
