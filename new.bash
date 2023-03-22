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

export DEBIAN_FRONTEND=noninteractive

RESTORE=$(echo -en '\033[0m')
RED=$(echo -en '\033[01;31m')
GREEN=$(echo -en '\033[01;32m')
BLUE=$(echo -en '\033[01;34m')


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
echo ${BLUE}"System type: $SYSTEM_TYPE"${RESTORE}

if [[ $SYSTEM_TYPE == "MacOS" ]]; then
    echo ${BLUE}"Installing MacOS console developer tools"${RESTORE}
    xcode-select --install
fi

install_homebrew() {
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ $SYSTEM_TYPE == U* ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ $SYSTEM_TYPE == "MacOS" ]]; then
        echo ${BLUE}"TODO: check this one"${RESTORE}
        exit
    fi

    brew update && brew upgrade
}

echo ${BLUE}"Updating system and installing Homebrew"${RESTORE}
if [[ $SYSTEM_TYPE == U* ]]; then
    sudo apt-get update && sudo apt-get upgrade -y
    # TODO: decide if installing Homebrew by default is worth it
    # install_homebrew    
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
    echo ${BLUE}"Installing usefull system packages"${RESTORE}
    sai "zsh tmux cmake neovim build-essential pkg-config cmake openssl libssl-dev jq"
fi

echo ${BLUE}"Install Rust toolchain"${RESTORE}
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# shellcheck source=/dev/null
source "$HOME/.cargo/env"

echo ${BLUE}"Install usefull Rust command line tools"${RESTORE}
cargo install cargo-quickinstall
cargo quickinstall starship
cargo quickinstall cargo-update
cargo quickinstall ripgrep
cargo quickinstall lsd
cargo quickinstall bat

echo ${BLUE}"Install fzf - this will require additional steps later "${RESTORE}
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all --key-bindings --completion --no-update-rc

echo ${BLUE}"Setting up dot-files"${RESTORE}
git clone https://github.com/yisonPylkita/dotfiles ~/dotfiles
cp ~/dotfiles/.zshrc ~/.zshrc

echo ${BLUE}"Change shell to ZSH"${RESTORE}
sudo chsh -s /usr/bin/zsh

echo ${BLUE}"For best expirience download patched Nerd Font"${RESTORE}
echo ${BLUE}"Good one is: Caskaydia Cove Nerd Font"${RESTORE}

echo ${BLUE}"All done. Now type zsh to login to your new expirience"${RESTORE}
