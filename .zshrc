# Shared interactive settings. setup-zsh.sh links this file into your home.
# Credentials and machine-specific overrides belong in ~/.zsh_local (ignored).

# Skip all this for non-interactive shells
[[ -o interactive ]] || return
typeset -U path PATH

# mise — developer-runtime owner (python, node, deno, uv, direnv, pi)
# Non-interactive shells get mise shims via the linked ~/.zshenv.
if command -v mise >/dev/null 2>&1; then
	eval "$(mise activate zsh)"
fi

# Set prompt
#
# Ok, this is quite serious actually
# I need my prompt to provide me these features:
#  - Is this a SSH connection or not?
#  - Show me parent and current directory
#  - Show me status of last command
#  - Show me date of the time when prompt was created (so for every Return
#    key I'll get new date) up to seconds precision
#  - [Optional] Show me time of last command execution
#  - [Optional] Show me if I'm in a git repo
#

#setopt prompt_subst # To be able to call functions inside of prompts
#PS1='$(~/.zsh_tools/prompt-rs --error $?)'
#RPS1='$(~/.zsh_tools/prompt-rs --rprompt)'
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

# Don't pause terminal on Ctrl+S
[[ $- != *i* ]] && return

# Aliases
get_prefered_editor() {
	[[ $(nvim --version >/dev/null 2>&1 && echo $?) ]] && echo 'nvim' && return
	[[ $(vim --version >/dev/null 2>&1 && echo $?) ]] && echo 'vim' && return
	echo 'vi'
}

get_update_system_command() {
	if command -v apt &>/dev/null; then
		command="sudo apt update && sudo apt upgrade --yes"
	elif [[ $(uname) == "Darwin" ]]; then
		command="brew update && brew upgrade"
	else
		command='echo "Unknown OS!, Cannot update automatically"'
	fi

	echo "$command && rustup update && cargo install-update -a"
}

alias git='LANG=en_US.UTF-8 git'

alias vi="$(get_prefered_editor)"
alias _='sudo '
alias la='lsd -la'
alias gss='git status'
alias gpl='git pull'
alias gco='git checkout'
alias gcmsg='git commit -S -m'
alias grbi='git rebase -i'
alias gcl='git clean -fdx'
alias sau="$(get_update_system_command)"
alias sai='sudo apt install'
alias htop='htop -d10'
# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps --all'
#alias docker_kill_all='docker ps | awk {' print $1 '} | tail -n+2 > tmp.txt; for line in $(cat tmp.txt); do docker kill $line; done; rm tmp.txt'
#alias docker_remove_all='docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q)'
alias dc='docker-compose'

# Sway config
#export BEMENU_BACKEND=wayland
#export MOZ_ENABLE_WAYLAND=1
#alias sway='export XKB_DEFAULT_LAYOUT=pl; export XKB_DEFAULT_MODEL=pc104; sway'

# exports
# export XDG_CONFIG_HOME=~/.config

# standard PATH adjustments
path=("$HOME/.local/share/mise/shims" "$HOME/.local/bin" $path)

# fzf - commands history fuzzy finder. Also interactive files searcher
# Prefer the cloned fzf (with shell integration) over an older system package.
if [[ -d "$HOME/.fzf/bin" ]]; then
	path=("$HOME/.fzf/bin" $path)
fi
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Rust
# rustup: documented exception — not managed by mise
if [[ -r "$HOME/.cargo/env" ]]; then
	source "$HOME/.cargo/env"
fi

# Sign my commits with a GPG key
#eval $(gpg-agent --daemon)
#export GPG_TTY=$(tty)

# SSH agent setup
# Add `ssh-agent -s > ~/.ssh/active_agent.env` to your ~/.profile and after login execute `ssh-add`
#eval '$(cat ~/.ssh/active_agent.env)'

# WSL stuff
#alias edge='/mnt/c/Program\ Files\ \(x86\)/Microsoft/Edge/Application/msedge.exe'

# MacOS stuff
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# Homebrew on Linux
# Run this one time
#/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#echo '# Set PATH, MANPATH, etc., for Homebrew.' >> "$HOME/.zprofile"
#echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.zprofile"

[[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

alias gcm="git checkout main"

alias cr='git rev-parse --is-inside-work-tree >/dev/null 2>&1 && cd "$(git rev-parse --show-toplevel)"'

# direnv via mise (mise-managed direnv resolves through the mise shims PATH)
if command -v direnv >/dev/null 2>&1; then
	eval "$(direnv hook zsh)"
fi

export PATH="$PATH:$HOME/.local/bin"

export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# A per-machine Podman socket, when needed, belongs in ~/.zsh_local.
alias docker="podman"

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# code resolves to VS Code via PATH (/Applications/Visual Studio Code.app/.../bin/code)
alias buu="brew update && brew upgrade"

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
path=("$HOME/.local/share/mise/shims" "$HOME/.local/bin" $path)
if [[ -r "$HOME/.zsh_local" ]]; then
	source "$HOME/.zsh_local"
fi
