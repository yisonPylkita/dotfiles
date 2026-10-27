# ~/.config/fish/config.fish — generic shell config (lean port from .zshrc)
# Work-specific stuff lives in ~/.fish_local (untracked)

fish_add_path --path --prepend $HOME/.cargo/bin
status is-interactive; or return

# Resolve installed tools before initializing their interactive integrations.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew
    if test -x $brew_bin
        $brew_bin shellenv | source
        break
    end
end
# Linux Homebrew (no-op on macOS)
if test -f /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end
# Rust (rustup lives outside the system package manager)
test -f $HOME/.cargo/env.fish; and source $HOME/.cargo/env.fish
fish_add_path --path --prepend $HOME/.local/bin
test -d $HOME/.local/share/fnm; and fish_add_path --path --prepend $HOME/.local/share/fnm
type -q fnm; and fnm env --use-on-cd --shell fish | source

# Prompt
type -q starship; and starship init fish | source

# Editor
if not set -q EDITOR
    if type -q nvim
        set -gx EDITOR nvim
    else if type -q vim
        set -gx EDITOR vim
    else
        set -gx EDITOR vi
    end
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
fish_add_path --path $HOME/.local/bin
test -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"; and fish_add_path --path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fish_add_path --path $GOPATH/bin

# Integrations
# Prefer the cloned fzf (with shell integration) over an older system package.
if test -d $HOME/.fzf/bin
    fish_add_path --path --prepend $HOME/.fzf/bin
end
if type -q fzf
    if fzf --fish >/dev/null 2>&1
        fzf --fish | source
    else if test -f $HOME/.fzf/shell/key-bindings.fish
        source $HOME/.fzf/shell/key-bindings.fish
    end
end
type -q direnv; and direnv hook fish | source

# Reassert local tool priority after other PATH integrations.
fish_add_path --path --prepend --move $HOME/.cargo/bin $HOME/.local/bin

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
type -q podman; and alias docker podman

function update_system --description 'update the operating system packages'
    if test (uname) = Darwin
        brew update; and brew upgrade
    else if type -q apt
        sudo apt update; and sudo apt upgrade --yes
    else if type -q dnf
        sudo dnf upgrade --refresh -y
    else if type -q yum
        sudo yum update -y
    else if type -q pacman
        sudo pacman -Syu --noconfirm
    else if type -q zypper
        sudo zypper refresh; and sudo zypper update -y
    else if type -q apk
        sudo apk update; and sudo apk upgrade
    else if type -q brew
        brew update; and brew upgrade
    else
        echo "Unknown OS; cannot update automatically" >&2
        return 1
    end
end

function update_rust --description 'update stable Rust and its CLIs, then report toolchain disk usage'
    dotfiles-rust-update
    set -l update_status $status
    type -q rustup-report; and env -u RUSTUP_TOOLCHAIN CARGO_HOME="$HOME/.cargo" RUSTUP_HOME="$HOME/.rustup" rustup-report
    return $update_status
end

function update_rust_tools --description 'update Rust CLIs from prebuilt binaries'
    dotfiles-rust-update tools
end

function sau --description 'update OS packages, stable Rust, and prebuilt Rust CLIs'
    update_system; or return
    update_rust
end

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
