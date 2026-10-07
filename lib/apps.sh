#!/usr/bin/env bash

# Standalone binaries and desktop apps that ship their own installer.

install_duckdb() {
    if command_exists duckdb; then
        mark_present "DuckDB"
        return 0
    fi
    print_info "Installing DuckDB..."
    run mkdir -p "$HOME/.local/bin"
    if [ "$DRY_RUN" != true ]; then
        local tmp_dir
        tmp_dir=$(mktemp -d)
        curl -fsSL -o "$tmp_dir/duckdb.zip" \
            "https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-amd64.zip"
        unzip -qo "$tmp_dir/duckdb.zip" -d "$HOME/.local/bin"
        chmod +x "$HOME/.local/bin/duckdb"
        rm -rf "$tmp_dir"
    fi
    print_success "DuckDB installed"
}

install_claude_code() {
    if command_exists claude; then
        mark_present "Claude Code"
        return 0
    fi
    print_info "Installing Claude Code..."
    shielded bash -c "curl -fsSL https://claude.ai/install.sh | bash" \
        || print_warning "Claude Code install failed, continuing"
}

install_antigravity_cli() {
    if command_exists agy; then
        mark_present "Antigravity CLI"
        return 0
    fi
    print_info "Installing Antigravity CLI (agy)..."
    shielded bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash" \
        || print_warning "Antigravity CLI install failed, continuing"
}

install_coderabbit() {
    if command_exists coderabbit; then
        mark_present "CodeRabbit CLI"
        return 0
    fi
    print_info "Installing CodeRabbit CLI..."
    shielded bash -c "curl -fsSL https://cli.coderabbit.ai/install.sh | bash" \
        || print_warning "CodeRabbit install failed, continuing"
}

install_ollama() {
    if command_exists ollama; then
        mark_present "Ollama"
        return 0
    fi
    print_info "Installing Ollama..."
    run bash -c "curl -fsSL https://ollama.com/install.sh | sh" \
        || print_warning "Ollama install failed, continuing"
}

install_balena_etcher() {
    if command_exists balena-etcher || dpkg -s balena-etcher &> /dev/null; then
        mark_present "balenaEtcher"
        return 0
    fi
    print_info "Installing balenaEtcher..."
    if [ "$DRY_RUN" = true ]; then
        print_dry "download and apt install the latest balenaEtcher .deb"
        return 0
    fi
    local url tmp
    url=$(curl -fsSL https://api.github.com/repos/balena-io/etcher/releases/latest \
        | grep -oE '"browser_download_url": *"[^"]+amd64\.deb"' | head -1 | cut -d'"' -f4)
    [ -n "$url" ] || { print_warning "Could not find a balenaEtcher .deb, continuing"; return 0; }
    tmp=$(mktemp --suffix=.deb)
    curl -fsSL -o "$tmp" "$url" && sudo apt-get install -y "$tmp" \
        || print_warning "balenaEtcher install failed, continuing"
    rm -f "$tmp"
}

install_miniserve() {
    # miniserve: a single-binary static file server (`miniserve <dir>`).
    if [ -x "$HOME/.local/bin/miniserve" ]; then
        mark_present "miniserve"
        return 0
    fi
    print_info "Installing miniserve..."
    run mkdir -p "$HOME/.local/bin"
    run bash -c "curl -fsSL 'https://github.com/svenstaro/miniserve/releases/latest/download/miniserve-linux-x86_64' -o '$HOME/.local/bin/miniserve'" \
        || { print_warning "miniserve download failed, continuing"; return 0; }
    run chmod +x "$HOME/.local/bin/miniserve"
}

install_appimagelauncher() {
    if command_exists appimagelauncherd; then
        mark_present "AppImageLauncher"
        return 0
    fi

    print_info "Installing AppImageLauncher..."
    if [ "$DRY_RUN" = true ]; then
        print_dry "download and dpkg -i the latest AppImageLauncher release"
        return 0
    fi

    local url
    url=$(curl -fsSL https://api.github.com/repos/TheAssassin/AppImageLauncher/releases/latest \
        | grep -oP '"browser_download_url"\s*:\s*"\K[^"]*bionic_amd64\.deb' | head -1)
    if [ -z "$url" ]; then
        print_warning "Could not resolve an AppImageLauncher release asset, skipping"
        return 0
    fi

    local tmp_deb
    tmp_deb=$(mktemp --suffix=.deb)
    curl -fsSL -o "$tmp_deb" "$url"
    sudo apt-get install -y "$tmp_deb" || print_warning "AppImageLauncher install failed, continuing"
    rm -f "$tmp_deb"
}

install_apps() {
    print_step "Installing standalone applications"
    install_duckdb
    install_claude_code
    install_antigravity_cli
    install_coderabbit
    install_miniserve
    install_appimagelauncher
    install_ollama
    if tier_active desktop; then install_balena_etcher; fi
    flush_present "apps"
}
