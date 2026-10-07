#!/usr/bin/env bash

# Personal overlay: a separate private repository applied on top of this one.
#
# This repo is public and stays generic. Anything personal — service units for
# specific projects, scripts that act on personal data, the list of project
# repos to clone — lives in the overlay, which has its own install.sh. Data is
# never synced by either repo; projects come back from their git remotes.
#
#   DOTFILES_PRIVATE_DIR   where the overlay lives    (~/dotfiles-private)
#   DOTFILES_PRIVATE_REPO  where to clone it from     (git@github.com:<you>/dotfiles-private.git)

DOTFILES_PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-$HOME/dotfiles-private}"

private_repo_url() {
    if [ -n "${DOTFILES_PRIVATE_REPO:-}" ]; then
        echo "$DOTFILES_PRIVATE_REPO"
        return 0
    fi
    # Same owner as this repo's origin.
    local origin owner
    origin=$(git -C "$DOTFILES_DIR" remote get-url origin 2>/dev/null || true)
    owner=$(sed -E 's#^(git@github\.com:|https://github\.com/)([^/]+)/.*#\2#' <<< "$origin")
    [ -n "$owner" ] && [ "$owner" != "$origin" ] && echo "git@github.com:$owner/dotfiles-private.git"
    return 0
}

install_private_overlay() {
    print_step "Personal overlay"

    if [ ! -d "$DOTFILES_PRIVATE_DIR/.git" ]; then
        local url
        url=$(private_repo_url)
        if [ -z "$url" ]; then
            print_warning "No overlay repo known; set DOTFILES_PRIVATE_REPO to use one"
            return 0
        fi
        print_info "Cloning $url..."
        # A fresh machine usually has no SSH key on GitHub yet; gh's HTTPS
        # credentials work as soon as `gh auth login` has run.
        if ! run git clone "$url" "$DOTFILES_PRIVATE_DIR" 2>/dev/null; then
            if command_exists gh && gh auth status &> /dev/null; then
                run gh repo clone "${url#git@github.com:}" "$DOTFILES_PRIVATE_DIR" \
                    || { print_warning "Could not clone the overlay, skipping"; return 0; }
            else
                print_warning "Could not clone the overlay. Run 'gh auth login', then:"
                print_warning "  ./install.sh --only private"
                return 0
            fi
        fi
    fi

    if [ ! -x "$DOTFILES_PRIVATE_DIR/install.sh" ]; then
        print_warning "$DOTFILES_PRIVATE_DIR has no install.sh, skipping"
        return 0
    fi

    local args=()
    [ "$DRY_RUN" = true ] && args+=(--dry-run)
    [ "${PICK:-false}" = true ] && args+=(--pick)
    DOTFILES_DIR="$DOTFILES_DIR" DOTFILES_NESTED=1 "$DOTFILES_PRIVATE_DIR/install.sh" "${args[@]}" \
        || print_warning "Personal overlay finished with warnings (see above)"
}
