#!/usr/bin/env bash

# Agent skills and Claude Code plugins.
#
# Skills are stored once in ~/.agents/skills (stowed from the skills/ package)
# and symlinked into each agent's own skills directory, so editing a skill in
# one place updates it everywhere.

SKILL_STORE="$HOME/.agents/skills"

link_skills() {
    print_step "Linking agent skills"

    if [ ! -d "$SKILL_STORE" ] && [ "$DRY_RUN" != true ]; then
        print_warning "$SKILL_STORE is missing — run the stow module first"
        return 0
    fi

    local map="" tier
    for tier in "${ACTIVE_TIERS[@]}"; do
        [ -f "$PACKAGES_DIR/$tier/skills.map" ] && map="$PACKAGES_DIR/$tier/skills.map"
    done
    if [ -z "$map" ]; then
        print_warning "No skills.map in the active tiers, skipping"
        return 0
    fi

    local line target_dir skill_list
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        [ -z "$line" ] && continue

        target_dir="$HOME/${line%%:*}"
        skill_list="${line#*:}"

        if [ "${skill_list// /}" = "all" ]; then
            skill_list=""
            local entry
            for entry in "$SKILL_STORE"/*/; do
                [ -d "$entry" ] || continue
                skill_list+=" $(basename "$entry")"
            done
        fi

        run mkdir -p "$target_dir"
        local skill
        for skill in $skill_list; do
            if [ ! -d "$SKILL_STORE/$skill" ] && [ "$DRY_RUN" != true ]; then
                print_warning "Skill '$skill' is not in the store, skipping"
                continue
            fi
            run ln -sfn "$SKILL_STORE/$skill" "$target_dir/$skill"
        done
        print_info "Linked ${target_dir#"$HOME"/} ->$skill_list"
    done < "$map"

    print_success "Agent skills linked"
}

install_claude_plugins() {
    print_step "Installing Claude Code plugins"

    if ! command_exists claude; then
        print_warning "claude not found, skipping plugins"
        return 0
    fi

    local files=()
    tier_manifests files claude-plugins
    if [ ${#files[@]} -eq 0 ]; then
        return 0
    fi

    local entries=()
    read_manifest entries "${files[@]}"

    local entry
    for entry in "${entries[@]}"; do
        read -ra parts <<< "$entry"
        if [ "${parts[0]}" = "marketplace" ]; then
            print_info "Adding marketplace ${parts[1]}..."
            run claude plugin marketplace add "${parts[2]}" \
                || print_warning "Could not add marketplace ${parts[1]}, continuing"
        fi
    done

    for entry in "${entries[@]}"; do
        read -ra parts <<< "$entry"
        [ "${parts[0]}" = "marketplace" ] && continue
        print_info "Installing plugin ${parts[0]}..."
        run claude plugin install "${parts[0]}" \
            || print_warning "Could not install ${parts[0]}, continuing"
    done

    print_success "Claude Code plugins installed"
}

install_agent_skills() {
    link_skills
    install_claude_plugins
}
