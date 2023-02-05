#!/usr/bin/bash

# TODO: Check on Ubuntu 20.04
# TODO: Check on Ubuntu 22.04
# TODO: Check on MacOS

# Script for setting up new Unix environment. Installing and configuring stuff.
# Supported distros:
# - Ubuntu 20.04
# - Ubuntu 22.04
# - MacOS
#
# To use call:
# wget -O - https://raw.githubusercontent.com/yisonPylkita/dotfiles/master/new.bash | bash

set -e 

get_system_type() {
    if command -v apt &>/dev/null; then
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
echo "System type: $SYSTEM_TYPE"

if [[ $SYSTEM_TYPE == "MacOS" ]]; then
    echo "Installing MacOS console developer tools"
    xcode-select --install
fi

install_homebrew() {
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ $SYSTEM_TYPE == U* ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ $SYSTEM_TYPE == "MacOS" ]]; then
        echo "TODO: check this one"
        exit
    fi

    brew update && brew upgrade
}

echo "Updating system and installing Homebrew"
if [[ $SYSTEM_TYPE == U* ]]; then
    sudo apt-get update &&
    sudo apt-get upgrade -y &&
    install_homebrew
    
elif [[ $SYSTEM_TYPE == "MacOS" ]]; then
    install_homebrew
fi

sai() {
    if [[ $SYSTEM_TYPE == U* ]]; then
        sudo apt-get install $1 -y
    elif [[ $SYSTEM_TYPE == "MacOS" ]]; then
        yes | brew install $1 
    fi  
}

if [[ $SYSTEM_TYPE == U* ]]; then
    echo "Installing usefull system packages"
    sai "zsh tmux cmake neovim build-essential pkg-config cmake openssl libssl-dev jq"
fi

echo "Install Rust toolchain"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# shellcheck source=/dev/null
source "$HOME/.cargo/env"

echo "Install usefull Rust command line tools"
cargo install starship --locked
cargo install cargo-update --locked
cargo install ripgrep --locked
cargo install lsd --locked
cargo install bat --locked

echo "Install fzf"
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
# shellcheck source=/dev/null
source ~/.fzf.zsh

echo "Setting up dot-files"
git clone https://github.com/yisonPylkita/dotfiles ~/dotfiles &> /dev/null
cp ~/dotfiles/.zshrc ~/.zshrc

echo "Change shell to ZSH"
sudo chsh -s /usr/bin/zsh

echo "For best expirience download patched Nerd Font"
echo "Good one is: Caskaydia Cove Nerd Font"

echo "All done. Now type zsh to login to your new expirience"
