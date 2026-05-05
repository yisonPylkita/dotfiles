#!/usr/bin/bash

# TODO: Check on Ubuntu 20.04
# TODO: Check on Ubuntu 22.04
# TODO: Check on MacOS

# Script for setting up a new Unix environment.
# Supported: Ubuntu 20.04, Ubuntu 22.04, MacOS
#
# Usage:
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/yisonPylkita/dotfiles/master/new.bash)"

set -ex

export DEBIAN_FRONTEND=noninteractive

RESTORE=$(echo -en '\033[0m')
BLUE=$(echo -en '\033[01;34m')


get_system_type() {
    if command -v apt-get &>/dev/null; then
        # shellcheck source=/dev/null
        source /etc/os-release
        if [[ $VERSION_ID == "20.04" ]]; then
            echo "U20.04"
        elif [[ $VERSION_ID == "22.04" ]]; then
            echo "U22.04"
        else
            echo "Unsupported Ubuntu distro: $VERSION_ID" && exit
        fi
    elif [[ $(uname) == "Darwin" ]]; then
        echo "MacOS"
    else
        echo "Unsupported system" && exit
    fi
}

SYSTEM_TYPE="$(get_system_type)"
echo "${BLUE}System type: $SYSTEM_TYPE${RESTORE}"

install_homebrew() {
    if ! command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    if [[ $SYSTEM_TYPE == U* ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ $SYSTEM_TYPE == "MacOS" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    brew update && brew upgrade
}

echo "${BLUE}Updating system and installing Homebrew${RESTORE}"
if [[ $SYSTEM_TYPE == U* ]]; then
    sudo apt-get update && NEEDRESTART_MODE=a sudo apt-get upgrade -y
elif [[ $SYSTEM_TYPE == "MacOS" ]]; then
    install_homebrew
fi

if [[ $SYSTEM_TYPE == U* ]]; then
    echo "${BLUE}Installing system packages (apt)${RESTORE}"
    sudo apt-get install -y \
        zsh fish tmux cmake neovim build-essential pkg-config openssl libssl-dev \
        jq fzf direnv
fi

if [[ $SYSTEM_TYPE == "MacOS" ]]; then
    echo "${BLUE}Installing CLI tools (brew)${RESTORE}"
    brew install \
        zsh fish tmux neovim jq fzf starship direnv fnm pyenv podman \
        lsd bat ripgrep gitui htop zellij

    echo "${BLUE}Installing GUI apps (brew --cask)${RESTORE}"
    brew install --cask alacritty
fi

echo "${BLUE}Installing Rust toolchain${RESTORE}"
if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# shellcheck source=/dev/null
source "$HOME/.cargo/env"

echo "${BLUE}Installing useful Rust command-line tools${RESTORE}"
cargo install cargo-quickinstall
cargo quickinstall cargo-update
if [[ $SYSTEM_TYPE == U* ]]; then
    # macOS gets these via brew above
    cargo quickinstall starship
    cargo quickinstall ripgrep
    cargo quickinstall lsd
    cargo quickinstall bat
fi

echo "${BLUE}Setting up dotfiles${RESTORE}"
if [[ ! -d "$HOME/dotfiles" ]]; then
    git clone https://github.com/yisonPylkita/dotfiles "$HOME/dotfiles"
fi

# Top-level config files
cp "$HOME/dotfiles/.zshrc"     "$HOME/.zshrc"
cp "$HOME/dotfiles/.tmux.conf" "$HOME/.tmux.conf"
cp "$HOME/dotfiles/.vimrc"     "$HOME/.vimrc"

# XDG configs
mkdir -p "$HOME/.config/fish" "$HOME/.config/alacritty" "$HOME/.config/zellij" "$HOME/.config/nvim"
cp "$HOME/dotfiles/.config/fish/config.fish"          "$HOME/.config/fish/config.fish"
cp "$HOME/dotfiles/.config/alacritty/alacritty.toml"  "$HOME/.config/alacritty/alacritty.toml"
cp "$HOME/dotfiles/.config/zellij/config.kdl"         "$HOME/.config/zellij/config.kdl"
cp "$HOME/dotfiles/nvim/init.vim"                     "$HOME/.config/nvim/init.vim"

echo "${BLUE}Cloning Alacritty theme repo${RESTORE}"
if [[ ! -d "$HOME/.config/alacritty/themes" ]]; then
    git clone https://github.com/alacritty/alacritty-theme "$HOME/.config/alacritty/themes"
fi

if [[ $SYSTEM_TYPE == U* ]]; then
    echo "${BLUE}Setting up fzf shell integration (Ubuntu)${RESTORE}"
    if [[ ! -d "$HOME/.fzf" ]]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --all --key-bindings --completion --no-update-rc
    fi
fi

echo "${BLUE}Default shell stays as zsh. To switch to fish later: chsh -s \$(which fish)${RESTORE}"
ZSH_BIN="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_BIN" ]]; then
    sudo chsh -s "$ZSH_BIN" "$USER"
fi

echo "${BLUE}For best experience download a patched Nerd Font (e.g., CaskaydiaCove Nerd Font)${RESTORE}"
echo "${BLUE}All done. Type 'zsh' (or 'fish' to try fish) to launch your shell.${RESTORE}"
