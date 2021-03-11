# Skip all this for non-interactive shells
[[ -z "$PS1" ]] && return

# Set promprt
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
#PROMPT='%(?.%F{green}√.%F{red}?%?)%f %B%F{240}%2~%f%b %# '
PS1=$'%(?..%B%K{red}[%?]%K{def}%b )%(1j.%b%K{yel}%F{bla}%jJ%F{def}%K{def} .)%F{white}%B%*%b %F{mag}%m:%F{white}%~ %(!.#.>) %F{def}'

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
#bindkey "^[[1;5C" forward-word
#bindkey "^[[1;5D" backward-word
#bindkey  "^[[H"   beginning-of-line
#bindkey  "^[[F"   end-of-line
TERM=xterm-color

# Aliases
[[ -f /usr/bin/nvim ]] && alias vi="nvim" || alias vi="vim"
alias _='sudo '
alias la='lsd -la'
alias gss='git status'
alias gco="git checkout"
alias gcmsg='git commit -S -m'
alias grbi='git rebase -i'
alias gcl='git clean -fdx'
alias ghc='git clone https://github.com/' # TODO: how to append params here? Should be a function, right?
alias sau='sudo apt update && sudo apt upgrade --yes'
alias sai='sudo apt install'
alias htop='htop -d10'
# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps --all'
alias docker_kill_all='docker ps | awk {' print $1 '} | tail -n+2 > tmp.txt; for line in $(cat tmp.txt); do docker kill $line; done; rm tmp.txt'

# Sway config
export BEMENU_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1
alias sway='export XKB_DEFAULT_LAYOUT=pl; export XKB_DEFAULT_MODEL=pc104; sway'

# exports
# export TERM=screen-256color # Should I even set this var?
export EDITOR=vi
export XDG_CONFIG_HOME=~/.config

# standard PATH adjustments
export PATH="$HOME/.local/bin:$PATH"

# fzf - commands history fuzzy finder. Also interactive files searcher
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Rust
source $HOME/.cargo/env

# Node version manager
# Disabled for now cuz its slow as fuck
#export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Sign my commits with a GPG key
# TODO: check if this works
export GPG_TTY=$(tty)


