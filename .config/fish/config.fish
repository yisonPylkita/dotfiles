# ~/.config/fish/config.fish — generic shell config (lean port from .zshrc)
# Work-specific stuff lives in ~/.fish_local (untracked)

status is-interactive; or return

# Resolve installed tools before initializing their interactive integrations.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
    if test -x $brew_bin
        $brew_bin shellenv | source
        break
    end
end
test -f $HOME/.cargo/env.fish; and source $HOME/.cargo/env.fish
fish_add_path --prepend $HOME/.local/bin
fish_add_path --prepend $HOME/.local/share/mise/shims
type -q mise; and mise activate fish | source

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
if test (uname) = Darwin
    set -gx BROWSER open
else
    set -gx BROWSER xdg-open
end
set -gx GOPATH $HOME/go
# Machine-specific Podman socket settings belong in ~/.fish_local.

# PATH (fish_add_path is idempotent)
fish_add_path $HOME/.local/bin
fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fish_add_path $GOPATH/bin

# Linux Homebrew (no-op on macOS)
if test -f /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end

# Rust (rustup: documented exception — not managed by mise)
test -f $HOME/.cargo/env.fish; and source $HOME/.cargo/env.fish

# Integrations
if type -q fzf
    if fzf --fish >/dev/null 2>&1
        fzf --fish | source
    else if test -f $HOME/.fzf/shell/key-bindings.fish
        source $HOME/.fzf/shell/key-bindings.fish
    end
end
type -q direnv; and direnv hook fish | source # direnv via mise (resolves through mise shims)

# Reassert runtime priority after other PATH integrations.
fish_add_path --prepend --move $HOME/.local/share/mise/shims

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
