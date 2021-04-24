# Skip all this for non-interactive shells
[[ -z "$PS1" ]] && return

# Best way to keep your dotfiles in sync is to make them symlinks
[[ -L ~/.zshrc ]] || {
	local COLOR_GREEN=$(echo -en '\033[01;32m')
	local COLOR_RESTORE=$(echo -en '\033[0m')

	echo "Your ~/.zshrc file is not a symlink. Keep your dotfiles in sync."
	echo "Do: ${COLOR_GREEN}rm ~/.zshrc && ln -s ~/h_dev/dotfiles/.zshrc ~/.zshrc${COLOR_RESTORE}"
}

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

setopt prompt_subst # To be able to call functions inside of prompts
PS1='$(~/.zsh_tools/prompt-rs --error $?)'
RPS1='$(~/.zsh_tools/prompt-rs --rprompt)'

# ZSH history settings
HISTFILE=~/.zsh_history
HISTSIZE=20000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt incappendhistory

# fpath
fpath+=~/.zfunc

# Autocompletion
autoload -Uz compinit
compinit -D

## Edit command line with sane keybindings (Emacs)
## When you set EDITOR=vi then ZSH will set command like keybindings to vi as well
## And since this is totally retarded this magic option has to be set
#set -o emacs
## Also since we're at it I would like to traverse between words in terminal
## input with Ctrl+Arrow. Home and End keys would be nice too
#bindkey '^[[1;5C' forward-word
#bindkey '^[[1;5D' backward-word
#bindkey  '^[[H'   beginning-of-line
#bindkey  '^[[F'   end-of-line
TERM=xterm-color

# Don't pause terminal on Ctrl+S
[[ $- != *i* ]] && return

# Aliases
[[ -f /usr/bin/nvim ]] && alias vi='nvim' || alias vi='vim'
alias _='sudo '
alias la='lsd -la'
alias gss='git status'
alias gco='git checkout'
alias gcmsg='git commit -S -m'
alias grbi='git rebase -i'
alias gcl='git clean -fdx'
alias ghc='git clone https://github.com/' # TODO: how to append params here? Should be a function, right?
alias sau='sudo apt update && sudo apt upgrade --yes && cargo install-update -a'
alias sai='sudo apt install'
alias htop='htop -d10'
# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps --all'
#alias docker_kill_all='docker ps | awk {' print $1 '} | tail -n+2 > tmp.txt; for line in $(cat tmp.txt); do docker kill $line; done; rm tmp.txt'
#alias docker_remove_all='docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q)'
alias dc='docker-compose'

# Sway config
export BEMENU_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1
alias sway='export XKB_DEFAULT_LAYOUT=pl; export XKB_DEFAULT_MODEL=pc104; sway'

# exports
# export TERM=screen-256color # Should I even set this var?
export EDITOR=nvim
export XDG_CONFIG_HOME=~/.config

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
eval $(gpg-agent --daemon)
export GPG_TTY=$(tty)

# SSH agent setup
# Add `ssh-agent -s > ~/.ssh/active_agent.env` to your ~/.profile and after login execute `ssh-add`
#eval '$(cat ~/.ssh/active_agent.env)'

# WSL stuff
alias edge='/mnt/c/Program\ Files\ \(x86\)/Microsoft/Edge/Application/msedge.exe'

