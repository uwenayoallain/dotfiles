#!/usr/bin/env bash

# Standalone binaries and desktop apps that ship their own installer.

install_duckdb() {
    if command_exists duckdb; then
        print_info "DuckDB is already installed"
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
        print_info "Claude Code is already installed"
        return 0
    fi
    print_info "Installing Claude Code..."
    shielded bash -c "curl -fsSL https://claude.ai/install.sh | bash" \
        || print_warning "Claude Code install failed, continuing"
}

install_coderabbit() {
    if command_exists coderabbit; then
        print_info "CodeRabbit CLI is already installed"
        return 0
    fi
    print_info "Installing CodeRabbit CLI..."
    shielded bash -c "curl -fsSL https://cli.coderabbit.ai/install.sh | bash" \
        || print_warning "CodeRabbit install failed, continuing"
}

install_cursor_agent() {
    if command_exists cursor-agent || [ -x "$HOME/.local/bin/agent" ]; then
        print_info "Cursor Agent is already installed"
        return 0
    fi
    print_info "Installing Cursor Agent..."
    shielded bash -c "curl -fsSL https://cursor.com/install | bash" \
        || print_warning "Cursor Agent install failed, continuing"
}

install_miniserve() {
    # miniserve backs the `serve` / `serve-media` scripts in localbin/.
    if [ -x "$HOME/.local/bin/miniserve" ]; then
        print_info "miniserve is already installed"
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
        print_info "AppImageLauncher is already installed"
        return 0
    fi

    print_info "Installing AppImageLauncher..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[dry-run]${NC} download and dpkg -i the latest AppImageLauncher release"
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
    install_coderabbit
    install_cursor_agent
    install_miniserve
    install_appimagelauncher
    print_success "Standalone applications installed"
}
