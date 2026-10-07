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

    local entry name present=0 installed
    installed=$(snap list 2>/dev/null | awk 'NR > 1 {print $1}')
    for entry in "${entries[@]}"; do
        # Entries may carry flags, e.g. "slack-term --edge".
        read -ra parts <<< "$entry"
        name="${parts[0]}"
        if grep -qx "$name" <<< "$installed"; then
            present=$((present + 1))
        else
            print_info "Installing snap '$name'..."
            run sudo snap install "${parts[@]}" || print_warning "snap install $name failed, continuing"
        fi
    done

    print_present "$present" "snaps"
    return 0
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

    flatpak remotes --user 2>/dev/null | grep -q '^flathub' \
        || run flatpak remote-add --if-not-exists --user \
            flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    local apps=()
    read_manifest apps "${files[@]}"

    local app present=0
    for app in "${apps[@]}"; do
        if flatpak info --user "$app" &> /dev/null || flatpak info "$app" &> /dev/null; then
            present=$((present + 1))
        else
            print_info "Installing flatpak '$app'..."
            run flatpak install --user -y flathub "$app" || print_warning "flatpak install $app failed, continuing"
        fi
    done

    print_present "$present" "flatpaks"
    return 0
}
