# ~/.config/fish/config.fish — generic shell config (lean port from .zshrc)
# Work-specific stuff lives in ~/.fish_local (untracked)

status is-interactive; or exit 0

# Prompt
type -q starship; and starship init fish | source

# Editor
if type -q nvim
    set -gx EDITOR nvim
else if type -q vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end
alias vi=$EDITOR

# Locale
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

# Misc env
set -gx BROWSER open
set -gx GOPATH $HOME/go
set -gx DOCKER_HOST 'unix:///var/folders/pp/5474vyks5c3bnhy2qpkkqfkm0000gr/T/podman/podman-machine-default-api.sock'

# PATH (fish_add_path is idempotent)
fish_add_path $HOME/.local/bin
fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fish_add_path $HOME/.pyenv/bin
fish_add_path $GOPATH/bin
fish_add_path $HOME/.codeium/windsurf/bin

# Linux Homebrew (no-op on macOS)
if test -f /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end

# Rust
test -f $HOME/.cargo/env.fish; and source $HOME/.cargo/env.fish

# Integrations
type -q fzf;    and fzf --fish | source
type -q direnv; and direnv hook fish | source
type -q fnm;    and fnm env --use-on-cd --shell fish | source

# Git aliases
alias gss 'git status'
alias gpl 'git pull'
alias gco 'git checkout'
alias gcmsg 'git commit -S -m'
alias grbi 'git rebase -i'
alias gcl 'git clean -fdx'
alias gcm 'git checkout main'

function cr --description 'cd to git repo root'
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        cd (git rev-parse --show-toplevel)
    end
end

# Misc aliases
alias la 'lsd -la'
alias htop 'htop -d10'
alias dps 'docker ps'
alias dpsa 'docker ps --all'
alias dc docker-compose
alias docker podman
alias buu 'brew update && brew upgrade'

function loop --description 'run a command repeatedly while it succeeds'
    set -l count 0
    while eval $argv
        set count (math $count + 1)
        echo -e "\n✓ Pass $count succeeded, running again..."
    end
    echo -e "\n✗ Failed after $count successful pass(es)."
    return 1
end

# Local / machine-specific overrides (not tracked)
test -f $HOME/.fish_local; and source $HOME/.fish_local
