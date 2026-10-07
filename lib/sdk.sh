#!/usr/bin/env bash

# Toolchains that live outside any package manager. bashrc/.bashrc guards
# each one, so a machine without them still gets a clean shell.

install_vite_plus() {
    if [ -d "$HOME/.vite-plus" ]; then
        print_info "Vite+ is already installed"
        return 0
    fi

    print_info "Installing Vite+..."
    shielded bash -c "curl -fsSL https://viteplus.dev/install.sh | bash" \
        || print_warning "Vite+ install failed — the shell config tolerates its absence"
}

install_sdks() {
    print_step "Installing SDKs"
    install_vite_plus
    print_success "SDK step complete"
}
