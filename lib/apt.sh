#!/usr/bin/env bash

# Third-party apt repositories and apt package installation.

KEYRINGS_DIR=/etc/apt/keyrings
SOURCES_DIR=/etc/apt/sources.list.d

apt_codename() {
    . /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}"
}

# True when some source file already points apt at <url>, whatever it is
# named (.list or deb822 .sources, written by us, the vendor, or by hand).
# A second entry for the same repo with a different Signed-By makes every
# `apt update` fail, so presence is decided by URL, not by file name.
repo_configured() {
    local url=${1%/}
    grep -rqsF -- "$url" /etc/apt/sources.list /etc/apt/sources.list.d/
}

# add_repo <name> <key-url> <source-line>
# Downloads and dearmors the signing key, then writes the source list.
# Skips entirely when the source file already exists.
add_repo() {
    local name=$1 key_url=$2 source_line=$3
    local keyring="$KEYRINGS_DIR/$name.gpg"
    local list="$SOURCES_DIR/$name.list"

    local url
    url=$(grep -oE 'https?://[^ ]+' <<< "$source_line" | head -1)
    if [ -f "$list" ] || repo_configured "$url"; then
        print_success "apt repo '$name' is configured"
        return 0
    fi

    print_info "Adding apt repo '$name'..."
    run sudo install -m 0755 -d "$KEYRINGS_DIR"
    if [ "$DRY_RUN" = true ]; then
        print_dry "curl $key_url | gpg --dearmor > $keyring"
        print_dry "echo '$source_line' > $list"
        return 0
    fi

    if ! curl -fsSL "$key_url" | sudo gpg --dearmor --yes -o "$keyring"; then
        print_warning "Could not fetch the signing key for '$name', skipping this repo"
        sudo rm -f "$keyring"
        return 0
    fi
    sudo chmod a+r "$keyring"
    echo "$source_line" | sudo tee "$list" > /dev/null
    APT_NEEDS_UPDATE=true
}

# add_vendor_repo <name> <key> <keyring-path> <sources-file> <sources-content>
# For vendors whose own package (re)writes its repo file on install: Chrome,
# ChatGPT, Helium. The keyring and deb822 file are written at exactly the
# paths and with the same Signed-By the vendor uses, so the package updates
# them in place. A second copy elsewhere with a different Signed-By would make
# every `apt update` fail.
# <key> is a URL, or a file name under packages/keyrings/ for vendors that
# publish no fetchable key.
add_vendor_repo() {
    local name=$1 key=$2 keyring=$3 sources=$4 content=$5
    local url
    url=$(grep -oE 'https?://[^ ]+' <<< "$content" | head -1)
    if [ -f "$sources" ] || repo_configured "$url"; then
        print_success "apt repo '$name' is configured"
        return 0
    fi

    print_info "Adding apt repo '$name'..."
    if [ "$DRY_RUN" = true ]; then
        print_dry "install key $key -> $keyring; write $sources"
        return 0
    fi
    case "$key" in
        http*) curl -fsSL "$key" ;;
        *) cat "$PACKAGES_DIR/keyrings/$key" ;;
    esac | sudo gpg --dearmor --yes -o "$keyring" \
        || { print_warning "Could not install the key for '$name', skipping"; sudo rm -f "$keyring"; return 0; }
    sudo chmod a+r "$keyring"
    printf '%s\n' "$content" | sudo tee "$sources" > /dev/null
    APT_NEEDS_UPDATE=true
}

# deb822 body for a single-suite amd64 repo.
deb822() {
    printf 'X-Repolib-Name: %s\nTypes: deb\nURIs: %s\nSuites: %s\nComponents: main\nArchitectures: amd64\nSigned-By: %s' "$1" "$2" "$3" "$4"
}

install_apt_repos() {
    print_step "Configuring apt repositories"
    local codename
    codename=$(apt_codename)
    local arch
    arch=$(dpkg --print-architecture)

    run sudo apt-get install -y ca-certificates curl gnupg apt-transport-https

    add_repo docker \
        "https://download.docker.com/linux/ubuntu/gpg" \
        "deb [arch=$arch signed-by=$KEYRINGS_DIR/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable"

    add_vendor_repo google-chrome "https://dl.google.com/linux/linux_signing_key.pub" \
        /usr/share/keyrings/google-chrome.gpg "$SOURCES_DIR/google-chrome.sources" \
        "$(deb822 "Google Chrome" https://dl.google.com/linux/chrome-stable/deb/ stable /usr/share/keyrings/google-chrome.gpg)"

    add_vendor_repo google-chrome-beta "https://dl.google.com/linux/linux_signing_key.pub" \
        /usr/share/keyrings/google-chrome-beta.gpg "$SOURCES_DIR/google-chrome-beta.sources" \
        "$(deb822 "Google Chrome (beta)" https://dl.google.com/linux/chrome-beta/deb/ stable /usr/share/keyrings/google-chrome-beta.gpg)"

    add_repo vscode \
        "https://packages.microsoft.com/keys/microsoft.asc" \
        "deb [arch=$arch signed-by=$KEYRINGS_DIR/vscode.gpg] https://packages.microsoft.com/repos/code stable main"

    add_repo ngrok \
        "https://ngrok-agent.s3.amazonaws.com/ngrok.asc" \
        "deb [signed-by=$KEYRINGS_DIR/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com buster main"

    add_repo tailscale \
        "https://pkgs.tailscale.com/stable/ubuntu/$codename.noarmor.gpg" \
        "deb [signed-by=$KEYRINGS_DIR/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu $codename main"

    add_repo tableplus \
        "https://deb.tableplus.com/apt.tableplus.com.gpg.key" \
        "deb [arch=amd64 signed-by=$KEYRINGS_DIR/tableplus.gpg] https://deb.tableplus.com/debian/24 tableplus main"

    add_repo claude-desktop \
        "https://downloads.claude.ai/claude-desktop/apt/stable/claude-desktop-archive-keyring.asc" \
        "deb [arch=amd64,arm64 signed-by=$KEYRINGS_DIR/claude-desktop.gpg] https://downloads.claude.ai/claude-desktop/apt/stable stable main"

    add_repo windsurf \
        "https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt/public.gpg" \
        "deb [arch=amd64 signed-by=$KEYRINGS_DIR/windsurf.gpg] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main"

    add_repo antigravity \
        "https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg" \
        "deb [signed-by=$KEYRINGS_DIR/antigravity.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main"

    add_repo anydesk \
        "https://keys.anydesk.com/repos/DEB-GPG-KEY" \
        "deb [arch=amd64 signed-by=$KEYRINGS_DIR/anydesk.gpg] http://deb.anydesk.com/ all main"


    add_repo cloudflared \
        "https://pkg.cloudflare.com/cloudflare-main.gpg" \
        "deb [signed-by=$KEYRINGS_DIR/cloudflared.gpg] https://pkg.cloudflare.com/cloudflared any main"

    add_vendor_repo helium helium.asc /usr/share/keyrings/helium.gpg "$SOURCES_DIR/helium.list" \
        "deb [signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main"

    add_vendor_repo chatgpt chatgpt-archive-keyring.asc \
        /usr/share/keyrings/chatgpt-archive-keyring.gpg "$SOURCES_DIR/chatgpt.sources" \
        "$(deb822 ChatGPT https://persistent.oaistatic.com/codex-app-prod/linux/deb stable /usr/share/keyrings/chatgpt-archive-keyring.gpg)"

    if [ "${APT_NEEDS_UPDATE:-false}" = true ]; then
        run sudo apt-get update
    fi
    print_success "apt repositories configured"
}

install_apt_packages() {
    print_step "Installing apt packages"

    local files=()
    tier_manifests files apt
    if [ ${#files[@]} -eq 0 ]; then
        print_warning "No apt manifests for the active tiers, skipping"
        return 0
    fi

    local packages=()
    read_manifest packages "${files[@]}"

    # Split the list so one unavailable package cannot abort the whole install.
    local available=() missing=() pkg
    for pkg in "${packages[@]}"; do
        if [ "$DRY_RUN" = true ] || apt-cache show "$pkg" &> /dev/null; then
            available+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    if [ ${#available[@]} -gt 0 ]; then
        print_info "Installing ${#available[@]} apt packages..."
        run sudo apt-get install -y "${available[@]}"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_warning "Not available from any configured repository: ${missing[*]}"
        print_warning "See packages/desktop/manual.md for the ones that need a hand-download"
    fi

    # Ubuntu ships bat as batcat; the shell config aliases `cat` to `bat`.
    if command_exists batcat && ! command_exists bat; then
        run sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
    fi

    if command_exists docker && ! id -nG "$USER" | grep -qw docker; then
        run sudo usermod -aG docker "$USER"
        print_warning "Log out and back in for docker group membership to take effect"
    fi

    print_success "apt packages installed"
}
