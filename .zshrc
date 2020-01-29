# ZSh history settings
HISTFILE=~/.zsh_history
HISTSIZE=20000
SAVEHIST=10000
setopt appendhistory

# fpath
fpath+=~/.zfunc

# Autocompletion
autoload -Uz compinit promptinit up-line-or-beginning-search down-line-or-beginning-search #rustup
compinit
promptinit
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
setopt COMPLETE_ALIASES
zstyle ':completion:*' menu select
zstyle ':completion::complete:*' gain-privileges 1

# sync history netween terminals
setopt inc_append_history
setopt share_history

[[ -n "$key[Up]" ]] && bindkey -- "$key[Up]" up-line-or-beginning-search
[[ -n "$key[Down]" ]] && bindkey -- "$key[Down]" down-line-or-beginning-search

# Aliases
alias vi="nvim"
alias gco="git checkout"
alias _='sudo '
alias la='lsd -la'
alias gss='git status'
alias gcmsg='git commit -m'
alias grbi='git rebase -i'
alias gco='git checkout'
# GitHub aliases
alias ghc='git clone https://github.com/' # how to append params here? Should be a function, right?

# exports
export TERM=tmux-256color
export EDITOR=vi
export XDG_CONFIG_HOME=~/.config

# promprt
PROMPT='%(?.%F{green}√.%F{red}?%?)%f %B%F{240}%2~%f%b %# '

# standard PATH adjustments
export PATH="$HOME/.local/bin:$PATH"

# fzf - commands history fuzzy finder. Also interactive files searcher
source ~/.fzf.zsh

# Node version manager
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

