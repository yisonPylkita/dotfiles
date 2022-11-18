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

# Don't pause terminal on Ctrl+S
[[ $- != *i* ]] && return

# Aliases
get_prefered_editor() {
    [[ $(nvim --version >/dev/null 2>&1 && echo $?) ]] && echo 'nvim' && return
    [[ $(vim --version >/dev/null 2>&1 && echo $?) ]] && return 'vim' && return
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

alias vi="$(get_prefered_editor)"
alias _='sudo '
alias la='lsd -la'
alias gss='git status'
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
