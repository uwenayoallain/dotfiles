#!/usr/bin/env bash

# Language SDKs and toolchains that live outside any package manager.
# All of these are on PATH in bashrc/.bashrc, so a machine without them
# gets a shell whose PATH points at directories that do not exist.

install_flutter() {
    if [ -d "$HOME/flutter" ]; then
        print_info "Flutter SDK is already present at ~/flutter"
        return 0
    fi

    print_info "Installing Flutter SDK to ~/flutter..."
    run sudo apt-get install -y git curl unzip xz-utils zip libglu1-mesa
    run git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
    if [ "$DRY_RUN" != true ]; then
        "$HOME/flutter/bin/flutter" --version || true
    fi
    print_success "Flutter installed — run 'flutter doctor' to finish setup"
}

install_android_studio() {
    if [ -d /opt/android-studio ]; then
        print_info "Android Studio is already present at /opt/android-studio"
        return 0
    fi

    print_warning "Android Studio is not installed."
    print_warning "Download the Linux tarball from https://developer.android.com/studio"
    print_warning "and extract it to /opt/android-studio (the PATH entry is already set)."
}

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
    install_flutter
    install_android_studio
    install_vite_plus
    print_success "SDK step complete"
}
