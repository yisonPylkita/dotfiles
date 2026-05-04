# To keep your dotfiles in sync remember to make them hardlinks to yisonPylita/dotfiles repo

# TODO: Make one-time setup script of environment

# Skip all this for non-interactive shells
[[ -z "$PS1" ]] && return

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
eval "$(starship init zsh)"

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
export PATH="$HOME/.local/bin:$PATH"

# fzf - commands history fuzzy finder. Also interactive files searcher
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Rust
source $HOME/.cargo/env

# Node version manager
# Disabled for now cuz its slow as fuck
#export NVM_DIR='$([ -z '${XDG_CONFIG_HOME-}' ] && printf %s '${HOME}/.nvm' || printf %s '${XDG_CONFIG_HOME}/nvm')'
#[ -s '$NVM_DIR/nvm.sh' ] && \. '$NVM_DIR/nvm.sh'

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

export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(direnv hook zsh)"

export PATH="$PATH:$HOME/.local/bin"

#export NVM_LAZY_LOAD=true
#source ~/.zsh-nvm/zsh-nvm.plugin.zsh

export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

export DOCKER_HOST='unix:///var/folders/pp/5474vyks5c3bnhy2qpkkqfkm0000gr/T/podman/podman-machine-default-api.sock'
alias docker="podman"
eval "$(fnm env --use-on-cd --shell zsh)"

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Added by Windsurf
export PATH="/Users/wojciech.bartnik/.codeium/windsurf/bin:$PATH"

alias code="windsurf"
alias buu="brew update && brew upgrade"

export BROWSER="open"

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
[ -f "$HOME/.zsh_local" ] && source "$HOME/.zsh_local"
