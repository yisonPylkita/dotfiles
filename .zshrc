# Autocompletion
autoload -Uz compinit promptinit up-line-or-beginning-search down-line-or-beginning-search
compinit
promptinit
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
setopt COMPLETE_ALIASES
zstyle ':completion:*' menu select
zstyle ':completion::complete:*' gain-privileges 1

[[ -n "$key[Up]" ]] && bindkey -- "$key[Up]" up-line-or-beginning-search
[[ -n "$key[Down]" ]] && bindkey -- "$key[Down]" down-line-or-beginning-search

# Search in history by Ctrl-R
bindkey -v
bindkey '^R' history-incremental-search-backward

# Aliases
alias _='sudo '
alias la='ls -la'
alias vi=nvim
alias gss='git status'
alias gcmsg='git commit -m'
alias grbi='git rebase -i'
alias gco='git checkout'

# Variables
export EDITOR=vi

# XDG
export XDG_CONFIG_HOME=~/.config

# Fish-like syntax highlight
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# HiDPI hacks
#xrandr --output eDP-1 --auto --scale 0.75x0.75

# Node Version Manager
source /usr/share/nvm/init-nvm.sh
