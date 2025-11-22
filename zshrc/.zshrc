# Zsh Configuration File

# Autosuggestions
export ZSH="$HOME/.oh-my-zsh"
plugins=(
	git
	zsh-autosuggestions
)
source $ZSH/oh-my-zsh.sh
source ~/.config/zsh-syntax-highlighting/themes/catppuccin_latte-zsh-syntax-highlighting.zsh
source /home/rcaa/.config/zshrc/mongodb.zsh
bindkey '^w' autosuggest-execute
bindkey '^e' autosuggest-accept
bindkey '^u' autosuggest-toggle
bindkey '^L' vi-forward-word
bindkey '^k' up-line-or-search
bindkey '^j' down-line-or-search


# Language Environment
export LANG=en_US.UTF-8

# Editor
export EDITOR=/usr/bin/nvim # CHECK PATH: Verify nvim path.

# Aliases
alias la='tree'
alias cat='bat'
alias cd='z'
alias py='python3'

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

# GO Environment
export GOPATH='/home/rcaa/go' # ADJUST PATH: Verify Go workspace path.

# VIM Alias
alias v="/usr/bin/nvim" # ADJUST PATH: Verify nvim path.

# Nmap Alias
alias nm="nmap -sC -sV -oN nmap"

# PATH
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/home/rcaa/.vimpkg/bin:${GOPATH}/bin:/home/rcaa/.cargo/bin:/home/linuxbrew/.linuxbrew/bin

alias cl='clear'

# Kubernetes (K8S) Settings
export KUBECONFIG=~/.kube/config # CHECK PATH: Verify kubeconfig path.
alias k="kubectl"
alias ka="kubectl apply -f"
alias kg="kubectl get"
alias kd="kubectl describe"
alias kdel="kubectl delete"
alias kl="kubectl logs"
alias kgpo="kubectl get pod"
alias kgd="kubectl get deployments"
alias kc="kubectx"
alias kns="kubens"
alias ke="kubectl exec -it"
alias kcns='kubectl config set-context --current --namespace'

# HTTP Requests with xh
alias http="xh"

# Vi Mode
bindkey jj vi-cmd-mode

# Eza Aliases
alias l="eza -l --icons --git -a"
alias ls="eza --icons --git"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2 --icons --git"

# Security Tools
export SECURITY_TOOLS_DIR="$HOME/security" # ADJUST PATH: Verify security tools path.
alias gobust="gobuster dir --wordlist $SECURITY_TOOLS_DIR/wordlists/diccnoext.txt --wildcard --url"
alias dirsearch="python dirsearch.py -w $SECURITY_TOOLS_DIR/db/dicc.txt -b -u"
alias massdns="~/hacking/tools/massdns/bin/massdns -r ~/hacking/tools/massdns/lists/resolvers.txt -t A -o S bf-targets.txt -w livehosts.txt -s 4000"
alias server="python -m http.server 4445"
alias tunnel="ngrok http 4445" # ENSURE PATH: Ensure ngrok is in PATH.
alias fuzz="ffuf -w $SECURITY_TOOLS_DIR/SecLists/content_discovery_all.txt -mc all -u"
alias gf="~/go/src/github.com/tomnomnom/gf/gf" # Renamed from 'gr' to avoid conflict with git alias.

# FZF Configuration
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Functions

# Ranger: File manager integration that changes directory on exit.
function ranger {
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

# GitHub Copilot Suggest (ghcs)
ghcs() {
	FUNCNAME="$funcstack[1]"
	TARGET="shell"
	local GH_DEBUG="$GH_DEBUG"
	local GH_HOST="$GH_HOST"

	read -r -d '' __USAGE <<-'EOF'
		    Wrapper around `gh copilot suggest` to propose a command based on a natural language description.
		    Supports executing the suggested command if applicable.

		    USAGE:
		        $FUNCNAME [flags] <prompt>

		    FLAGS:
		        -d, --debug        Enable debugging.
		        -h, --help         Display this help message.
		            --hostname     The GitHub host to use for authentication.
		        -t, --target       Target for suggestion; must be shell, gh, or git (default: "shell").

		    EXAMPLES:
		        # Guided experience:
		        $ $FUNCNAME

		        # Git use cases:
		        $ $FUNCNAME -t git "Undo the most recent local commits"
		        $ $FUNCNAME -t git "Clean up local branches"
		        $ $FUNCNAME -t git "Setup LFS for images"

		        # GitHub CLI use cases:
		        $ $FUNCNAME -t gh "Create pull request"
		        $ $FUNCNAME -t gh "Summarize work I have done in issues and pull requests for promotion"

		        # General use cases:
		        $ $FUNCNAME "Kill processes holding onto deleted files"
		        $ $FUNCNAME "Test for SSL/TLS issues with github.com"
		        $ $FUNCNAME "Convert SVG to PNG and resize"
		        $ $FUNCNAME "Convert MOV to animated PNG"
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

	TMPFILE="$(mktemp -t gh-copilotXXXXXX)"
	trap 'rm -f "$TMPFILE"' EXIT
	if GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot suggest -t "$TARGET" "$@" --shell-out "$TMPFILE"; then
		if [ -s "$TMPFILE" ]; then
			FIXED_CMD="$(cat "$TMPFILE")"
			print -s -- "$FIXED_CMD"
			echo
			eval -- "$FIXED_CMD"
		fi
	else
		return 1
	fi
}

# GitHub Copilot Explain (ghce)
ghce() {
	FUNCNAME="$funcstack[1]"
	local GH_DEBUG="$GH_DEBUG"
	local GH_HOST="$GH_HOST"

	read -r -d '' __USAGE <<-'EOF'
		    Wrapper around `gh copilot explain` to provide a natural language explanation of a given command.

		    USAGE:
		        $FUNCNAME [flags] <command>

		    FLAGS:
		        -d, --debug     Enable debugging.
		        -h, --help      Display this help message.
		            --hostname  The GitHub host to use for authentication.

		    EXAMPLES:
		        $ $FUNCNAME 'du -sh | sort -h'
		        $ $FUNCNAME 'git log --oneline --graph --decorate --all'
		        $ $FUNCNAME 'bfg --strip-blobs-bigger-than 50M'
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

export XDG_CONFIG_HOME="/home/rcaa/.config"

# Zoxide and Direnv
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)" 
eval "$(starship init zsh)"
