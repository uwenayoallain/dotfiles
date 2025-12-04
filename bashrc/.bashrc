# Bash Configuration File with Oh My Bash

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ============================================
# Oh My Bash Configuration
# ============================================
export OSH="$HOME/.oh-my-bash"

# Theme - empty because we use starship prompt
OSH_THEME=""

# Case-insensitive completion
OMB_CASE_SENSITIVE="false"

# Hyphen-insensitive completion (- and _ are interchangeable)
OMB_HYPHEN_SENSITIVE="false"

# Enable command auto-correction
ENABLE_CORRECTION="true"

# Display red dots whilst waiting for completion
COMPLETION_WAITING_DOTS="true"

# History timestamp format
HIST_STAMPS='yyyy-mm-dd'

# Enable sudo plugin
OMB_USE_SUDO=true

# Completions to load
completions=(
    git
    ssh
    docker
    docker-compose
    makefile
    npm
    pip
    pip3
    tmux
    system
)

# Aliases to load
aliases=(
    general
)

# Plugins to load
plugins=(
    git
    bashmarks
    sudo
    npm
)

# Load Oh My Bash
if [ -f "$OSH/oh-my-bash.sh" ]; then
    source "$OSH/oh-my-bash.sh"
fi

# ============================================
# History Configuration (Enhanced)
# ============================================
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=50000
HISTFILESIZE=100000
HISTTIMEFORMAT="%F %T "
shopt -s histappend

# Save and reload history after each command (shared across terminals)
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# Check window size after each command
shopt -s checkwinsize

# ============================================
# Bash Completion (Additional)
# ============================================
# Enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Homebrew completions
if [ -d /home/linuxbrew/.linuxbrew/etc/bash_completion.d ]; then
    for f in /home/linuxbrew/.linuxbrew/etc/bash_completion.d/*; do
        [ -f "$f" ] && . "$f"
    done
fi

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================
# Environment Variables
# ============================================
export LANG=en_US.UTF-8
export EDITOR=nvim
export GOPATH="$HOME/go"
export XDG_CONFIG_HOME="$HOME/.config"
export SECURITY_TOOLS_DIR="$HOME/security"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'

# PATH
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.vimpkg/bin:${GOPATH}/bin:$HOME/.cargo/bin:/home/linuxbrew/.linuxbrew/bin:$PATH

# ============================================
# Aliases
# ============================================

# General Aliases
alias la='tree'
alias cat='bat'
alias cd='z'
alias py='python3'
alias cl='clear'

# VIM Alias
alias v="nvim"

# Git Aliases
alias gss='git status'
alias gc="git commit -m"
alias gca="git commit -a -m"
alias gp="git push origin HEAD"
alias gpu="git pull origin"
alias glog="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"
alias gdiff="git diff"
alias gco="git checkout"
alias gb='git branch'
alias gba='git branch -a'
alias gadd='git add'
alias ga='git add -p'
alias gm='git merge'
alias gcoall='git checkout -- .'
alias gr='git remote'
alias gre='git reset'

# Docker Aliases
alias dco="docker compose"
alias dps="docker ps"
alias dpa="docker ps -a"
alias dl="docker ps -l -q"
alias dx="docker exec -it"

# Directory Navigation Aliases
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

# Eza Aliases (modern ls replacement)
alias l="eza -l --icons --git -a"
alias ls="eza --icons --git"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2 --icons --git"

# HTTP Requests with xh
alias http="xh"

# Nmap Alias
alias nm="nmap -sC -sV -oN nmap"

# Security Tools Aliases
alias gobust="gobuster dir --wordlist \$SECURITY_TOOLS_DIR/wordlists/diccnoext.txt --wildcard --url"
alias dirsearch="python dirsearch.py -w \$SECURITY_TOOLS_DIR/db/dicc.txt -b -u"
alias server="python -m http.server 4445"
alias tunnel="ngrok http 4445"
alias fuzz="ffuf -w \$SECURITY_TOOLS_DIR/SecLists/content_discovery_all.txt -mc all -u"

# ============================================
# Functions
# ============================================

# Ranger: File manager integration that changes directory on exit
ranger() {
    local IFS=$'\t\n'
    local tempfile
    tempfile="$(mktemp -t tmp.XXXXXX)"
    local ranger_cmd=(
        command
        ranger
        --cmd="map Q chain shell echo %d > \"$tempfile\"; quitall"
    )

    "${ranger_cmd[@]}" "$@"
    if [[ -f "$tempfile" ]] && [[ "$(cat -- "$tempfile")" != "$(echo -n "$(pwd)")" ]]; then
        cd -- "$(cat "$tempfile")" || return
    fi
    command rm -f -- "$tempfile" 2>/dev/null
}
alias rr='ranger'

# Navigation Functions
cx() { cd "$@" && l; }
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)" && l; }
f() { echo "$(find . -type f -not -path '*/.*' | fzf)" | xclip -in -selection clipboard; }
fv() { nvim "$(find . -type f -not -path '*/.*' | fzf)"; }

# History search function
hg() { history | grep "$1"; }

# GitHub Copilot Suggest (ghcs)
ghcs() {
    local FUNCNAME="${FUNCNAME[0]}"
    local TARGET="shell"
    local GH_DEBUG="$GH_DEBUG"
    local GH_HOST="$GH_HOST"

    read -r -d '' __USAGE <<-'EOF'
Wrapper around `gh copilot suggest` to propose a command based on a natural language description.
Supports executing the suggested command if applicable.

USAGE:
    ghcs [flags] <prompt>

FLAGS:
    -d, --debug        Enable debugging.
    -h, --help         Display this help message.
        --hostname     The GitHub host to use for authentication.
    -t, --target       Target for suggestion; must be shell, gh, or git (default: "shell").

EXAMPLES:
    # Guided experience:
    $ ghcs

    # Git use cases:
    $ ghcs -t git "Undo the most recent local commits"
    $ ghcs -t git "Clean up local branches"
    $ ghcs -t git "Setup LFS for images"

    # GitHub CLI use cases:
    $ ghcs -t gh "Create pull request"
    $ ghcs -t gh "Summarize work I have done in issues and pull requests for promotion"

    # General use cases:
    $ ghcs "Kill processes holding onto deleted files"
    $ ghcs "Test for SSL/TLS issues with github.com"
    $ ghcs "Convert SVG to PNG and resize"
    $ ghcs "Convert MOV to animated PNG"
EOF

    local OPT OPTARG OPTIND
    while getopts "dht:-:" OPT; do
        if [ "$OPT" = "-" ]; then
            OPT="${OPTARG%%=*}"
            OPTARG="${OPTARG#"$OPT"}"
            OPTARG="${OPTARG#=}"
        fi

        case "$OPT" in
        debug | d)
            GH_DEBUG=api
            ;;
        help | h)
            echo "$__USAGE"
            return 0
            ;;
        hostname)
            GH_HOST="$OPTARG"
            ;;
        target | t)
            TARGET="$OPTARG"
            ;;
        esac
    done

    shift "$((OPTIND - 1))"

    local TMPFILE
    TMPFILE="$(mktemp -t gh-copilotXXXXXX)"
    trap 'rm -f "$TMPFILE"' EXIT
    if GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot suggest -t "$TARGET" "$@" --shell-out "$TMPFILE"; then
        if [ -s "$TMPFILE" ]; then
            local FIXED_CMD
            FIXED_CMD="$(cat "$TMPFILE")"
            history -s -- "$FIXED_CMD"
            echo
            eval -- "$FIXED_CMD"
        fi
    else
        return 1
    fi
}

# GitHub Copilot Explain (ghce)
ghce() {
    local FUNCNAME="${FUNCNAME[0]}"
    local GH_DEBUG="$GH_DEBUG"
    local GH_HOST="$GH_HOST"

    read -r -d '' __USAGE <<-'EOF'
Wrapper around `gh copilot explain` to provide a natural language explanation of a given command.

USAGE:
    ghce [flags] <command>

FLAGS:
    -d, --debug     Enable debugging.
    -h, --help      Display this help message.
        --hostname  The GitHub host to use for authentication.

EXAMPLES:
    $ ghce 'du -sh | sort -h'
    $ ghce 'git log --oneline --graph --decorate --all'
    $ ghce 'bfg --strip-blobs-bigger-than 50M'
EOF

    local OPT OPTARG OPTIND
    while getopts "dh-:" OPT; do
        if [ "$OPT" = "-" ]; then
            OPT="${OPTARG%%=*}"
            OPTARG="${OPTARG#"$OPT"}"
            OPTARG="${OPTARG#=}"
        fi

        case "$OPT" in
        debug | d)
            GH_DEBUG=api
            ;;
        help | h)
            echo "$__USAGE"
            return 0
            ;;
        hostname)
            GH_HOST="$OPTARG"
            ;;
        esac
    done

    shift "$((OPTIND - 1))"

    GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot explain "$@"
}

# ============================================
# Tool Initialization
# ============================================

# FZF keybindings and completion
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
[ -f /home/linuxbrew/.linuxbrew/opt/fzf/shell/completion.bash ] && source /home/linuxbrew/.linuxbrew/opt/fzf/shell/completion.bash
[ -f /home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.bash ] && source /home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.bash

# Initialize zoxide (smart cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# Initialize direnv
if command -v direnv &> /dev/null; then
    eval "$(direnv hook bash)"
fi

# Initialize starship prompt (should be at the end)
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi
