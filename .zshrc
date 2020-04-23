# Skip all this for non-interactive shells
[[ -z "$PS1" ]] && return

# Set promprt
#PROMPT='%(?.%F{green}√.%F{red}?%?)%f %B%F{240}%2~%f%b %# '
PS1=$'%(?..%B%K{red}[%?]%K{def}%b )%(1j.%b%K{yel}%F{bla}%jJ%F{def}%K{def} .)%F{white}%B%*%b %F{mag}%m:%F{white}%~ %(!.#.>) %F{def}'

# ZSH history settings
HISTFILE=~/.zsh_history
HISTSIZE=20000
SAVEHIST=10000
setopt appendhistory

# fpath
fpath+=~/.zfunc

# Autocompletion
autoload -Uz compinit
compinit

setopt COMPLETE_ALIASES
zstyle ':completion:*' menu select
zstyle ':completion::complete:*' gain-privileges 1

# sync history netween terminals
setopt inc_append_history
setopt share_history

# Edit command line with sane keybindings (Emacs)
# When you set EDITOR=vi then ZSH will set command like keybindings to vi as well
# And since this is totally retarded this magic option has to be set
set -o emacs
# Also since we're at it I would like to traverse between words in terminal
# input with Ctrl+Arrow. Home and End keys would be nice too
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey  "^[[H"   beginning-of-line
bindkey  "^[[F"   end-of-line

# Aliases
alias vi="nvim"
alias gco="git checkout"
alias _='sudo '
alias la='lsd -la'
alias gss='git status'
alias gcmsg='git commit -m'
alias grbi='git rebase -i'
alias gco='git checkout'
alias ghc='git clone https://github.com/' # how to append params here? Should be a function, right?

# Sway config
alias sway='export XKB_DEFAULT_LAYOUT=pl; export XKB_DEFAULT_MODEL=pc104; sway'
export BEMENU_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1

# exports
# export TERM=screen-256color # Should I even set this var?
export EDITOR=vi
export XDG_CONFIG_HOME=~/.config

# standard PATH adjustments
export PATH="$HOME/.local/bin:$PATH"

# fzf - commands history fuzzy finder. Also interactive files searcher
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# Node version manager
# Disabled for now cuz its slow as fuck
#export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

