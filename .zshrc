# Shared interactive settings. setup-config.sh links this file into your home.
# Credentials and machine-specific overrides belong in ~/.zsh_local (ignored).

# Skip all this for non-interactive shells
[[ -o interactive ]] || return
typeset -U path PATH

# Node version manager; the system Node remains the default.
if command -v fnm >/dev/null 2>&1; then
	eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Prompt
if command -v starship >/dev/null 2>&1; then
	eval "$(starship init zsh)"
fi

# ZSH history settings - Never expire history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=999999999            # Practically unlimited history in memory
SAVEHIST=$HISTSIZE            # Match SAVEHIST to HISTSIZE
setopt BANG_HIST              # Treat the '!' character specially during expansion
setopt EXTENDED_HISTORY       # Write the ":start:elapsed;command" format
setopt INC_APPEND_HISTORY     # Write to history file immediately, not when shell exits
setopt SHARE_HISTORY          # Share history between all sessions
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history
setopt HIST_IGNORE_DUPS       # Don't record an entry that was just recorded again
setopt HIST_IGNORE_ALL_DUPS   # Delete old recorded entry if new entry is a duplicate
setopt HIST_FIND_NO_DUPS      # Do not display a line previously found
setopt HIST_IGNORE_SPACE      # Don't record an entry starting with a space
setopt HIST_SAVE_NO_DUPS      # Don't write duplicate entries in the history file
setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks before recording entry
setopt HIST_VERIFY            # Don't execute immediately upon history expansion

# fpath
fpath+=~/.zfunc

# Homebrew autocompletion
if type brew &>/dev/null; then
	FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Autocompletion
autoload -Uz compinit
compinit

# Aliases
get_preferred_editor() {
	command -v nvim >/dev/null 2>&1 && echo 'nvim' && return
	command -v vim >/dev/null 2>&1 && echo 'vim' && return
	echo 'vi'
}

update_rust() {
	dotfiles-rust-update
	local update_status=$?
	command -v rustup-report >/dev/null 2>&1 && env -u RUSTUP_TOOLCHAIN CARGO_HOME="$HOME/.cargo" RUSTUP_HOME="$HOME/.rustup" rustup-report
	return $update_status
}

if [[ -z "${EDITOR:-}" ]]; then
	export EDITOR="$(get_preferred_editor)"
fi

update_rust_tools() {
	dotfiles-rust-update tools
}

update_system() {
	if [[ $(uname) == "Darwin" ]]; then
		brew update && brew upgrade
	elif command -v apt >/dev/null 2>&1; then
		sudo apt update && sudo apt upgrade --yes
	else
		echo "Unsupported OS; cannot update automatically" >&2
		return 1
	fi
}

alias git='LANG=en_US.UTF-8 git'

alias vi="$EDITOR"
alias _='sudo '
alias la='lsd -la'
alias gss='git status'
alias gpl='git pull'
alias gco='git checkout'
alias gcmsg='git commit -S -m'
alias grbi='git rebase -i'
alias gcl='git clean -fdx'
sau() {
	update_system || return
	update_rust
}
alias sai='sudo apt install'
alias htop='htop -d10'
# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps --all'
alias dc='docker-compose'

# fzf - commands history fuzzy finder. Also interactive files searcher
# Prefer the cloned fzf (with shell integration) over an older system package.
if [[ -d "$HOME/.fzf/bin" ]]; then
	path=("$HOME/.fzf/bin" $path)
fi
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Rust
if [[ -r "$HOME/.cargo/env" ]]; then
	source "$HOME/.cargo/env"
fi

# MacOS stuff
if [[ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]]; then
	export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

# Homebrew on Linux
[[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

alias gcm="git checkout main"

alias cr='git rev-parse --is-inside-work-tree >/dev/null 2>&1 && cd "$(git rev-parse --show-toplevel)"'

# direnv
if command -v direnv >/dev/null 2>&1; then
	eval "$(direnv hook zsh)"
fi

export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

# A per-machine Podman socket, when needed, belongs in ~/.zsh_local.
command -v podman >/dev/null 2>&1 && alias docker="podman"

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# code resolves to VS Code via PATH (/Applications/Visual Studio Code.app/.../bin/code)
if [[ $OSTYPE == darwin* ]]; then
	export BROWSER="open"
else
	export BROWSER="xdg-open"
fi

loop() {
  local count=0
  while eval "$@"; do
    ((count++))
    echo "\n✓ Pass $count succeeded, running again..."
  done
  echo "\n✗ Failed after $count successful pass(es)."
  return 1
}

# Local / machine-specific overrides (not tracked)
path=("$HOME/.cargo/bin" "$HOME/.local/bin" $path)
if [[ -r "$HOME/.zsh_local" ]]; then
	source "$HOME/.zsh_local"
fi
