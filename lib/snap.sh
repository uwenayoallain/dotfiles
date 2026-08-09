#!/usr/bin/env bash

# Snap and Flatpak applications.

install_snaps() {
    print_step "Installing snap packages"

    if ! command_exists snap; then
        print_warning "snapd is not available, skipping snaps"
        return 0
    fi

    local files=()
    tier_manifests files snap
    [ ${#files[@]} -eq 0 ] && return 0

    local entries=()
    read_manifest entries "${files[@]}"

    local entry name
    for entry in "${entries[@]}"; do
        # Entries may carry flags, e.g. "slack-term --edge".
        read -ra parts <<< "$entry"
        name="${parts[0]}"
        if snap list "$name" &> /dev/null; then
            print_info "snap '$name' is already installed"
        else
            print_info "Installing snap '$name'..."
            run sudo snap install "${parts[@]}" || print_warning "snap install $name failed, continuing"
        fi
    done

    print_success "Snap packages installed"
}

install_flatpaks() {
    print_step "Installing flatpak applications"

    if ! command_exists flatpak; then
        print_warning "flatpak is not installed, skipping"
        return 0
    fi

    local files=()
    tier_manifests files flatpak
    [ ${#files[@]} -eq 0 ] && return 0

    run flatpak remote-add --if-not-exists --user \
        flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    local apps=()
    read_manifest apps "${files[@]}"

    local app
    for app in "${apps[@]}"; do
        if flatpak info --user "$app" &> /dev/null; then
            print_info "flatpak '$app' is already installed"
        else
            print_info "Installing flatpak '$app'..."
            run flatpak install --user -y flathub "$app" || print_warning "flatpak install $app failed, continuing"
        fi
    done

    print_success "Flatpak applications installed"
}
