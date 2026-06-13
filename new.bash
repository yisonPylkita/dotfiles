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

	echo "${BLUE}Installing Pi AI coding assistant${RESTORE}"
	npm install -g --ignore-scripts @earendil-works/pi-coding-agent

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
	# Try SSH first; fall back to HTTPS if no key is registered with GitHub
	if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
		echo "${BLUE}  SSH key detected — cloning via SSH${RESTORE}"
		git clone git@github.com:yisonPylkita/dotfiles.git "$HOME/dotfiles"
		SSH_WAS_AVAILABLE=true
	else
		echo "${BLUE}  No SSH key for GitHub detected — cloning via HTTPS${RESTORE}"
		git clone https://github.com/yisonPylkita/dotfiles "$HOME/dotfiles"
		SSH_WAS_AVAILABLE=false
	fi
else
	# Already cloned, but check SSH availability for the key prompt later
	if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
		SSH_WAS_AVAILABLE=true
	else
		SSH_WAS_AVAILABLE=false
	fi
fi

# Top-level config files
cp "$HOME/dotfiles/.zshrc" "$HOME/.zshrc"
cp "$HOME/dotfiles/.tmux.conf" "$HOME/.tmux.conf"
cp "$HOME/dotfiles/.vimrc" "$HOME/.vimrc"

# Pi AI coding assistant config
mkdir -p "$HOME/.pi/agent/npm" "$HOME/.pi/agent/extensions/pi-rtk-optimizer"
cp "$HOME/dotfiles/.pi/agent/settings.json" "$HOME/.pi/agent/settings.json"
cp "$HOME/dotfiles/.pi/agent/trust.json" "$HOME/.pi/agent/trust.json"
cp "$HOME/dotfiles/.pi/agent/npm/package.json" "$HOME/.pi/agent/npm/package.json"
cp "$HOME/dotfiles/.pi/agent/extensions/eko24ive-pi-ask.json" "$HOME/.pi/agent/extensions/eko24ive-pi-ask.json"
cp "$HOME/dotfiles/.pi/agent/extensions/pi-rtk-optimizer/config.json" "$HOME/.pi/agent/extensions/pi-rtk-optimizer/config.json"
# Install pi extension dependencies silently
(cd "$HOME/.pi/agent" && npm install --ignore-scripts &>/dev/null) || true

# XDG configs
mkdir -p "$HOME/.config/fish" "$HOME/.config/alacritty" "$HOME/.config/zellij" "$HOME/.config/nvim"
cp "$HOME/dotfiles/.config/fish/config.fish" "$HOME/.config/fish/config.fish"
cp "$HOME/dotfiles/.config/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
cp "$HOME/dotfiles/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
cp "$HOME/dotfiles/nvim/init.vim" "$HOME/.config/nvim/init.vim"

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

echo "${BLUE}Installing CaskaydiaCove Nerd Font${RESTORE}"
install_nerd_font() {
	local FONT_NAME="CaskaydiaCove Nerd Font Mono"
	if [[ $SYSTEM_TYPE == "MacOS" ]]; then
		brew install --cask font-caskaydia-cove-nerd-font 2>/dev/null || echo "${BLUE}  Font already installed, skipping.${RESTORE}"
	elif [[ $SYSTEM_TYPE == U* ]]; then
		local FONT_DIR="$HOME/.local/share/fonts"
		mkdir -p "$FONT_DIR"
		echo "${BLUE}  Downloading CascadiaCode Nerd Font from GitHub...${RESTORE}"
		local TMP_ZIP="/tmp/CascadiaCode.zip"
		curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaCode.zip" -o "$TMP_ZIP"
		unzip -o -q "$TMP_ZIP" -d "$FONT_DIR"
		rm -f "$TMP_ZIP"
		fc-cache -fv
		echo "${BLUE}  Font cache updated.${RESTORE}"
	fi
}
install_nerd_font

# ============================================
# SSH key bootstrap — generate if not present
# ============================================
if [[ "$SSH_WAS_AVAILABLE" == "false" ]]; then
	echo "${BLUE}============================================${RESTORE}"
	echo "${BLUE}🔑  SSH Key Setup${RESTORE}"
	echo "${BLUE}============================================${RESTORE}"
	if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
		echo "${BLUE}  No SSH key found. Generating one for you...${RESTORE}"
		mkdir -p "$HOME/.ssh"
		ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "$(whoami)@$(hostname)-$(date +%Y-%m-%d)"
		echo ""
		echo "${BLUE}  ✅ New key generated: ~/.ssh/id_ed25519 (empty passphrase)${RESTORE}"
		echo "${BLUE}  📋 Your public key:${RESTORE}"
		echo ""
		cat "$HOME/.ssh/id_ed25519.pub"
	else
		echo "${BLUE}  SSH key exists (~/.ssh/id_ed25519) but isn't registered with GitHub.${RESTORE}"
		echo "${BLUE}  📋 Your public key:${RESTORE}"
		echo ""
		cat "$HOME/.ssh/id_ed25519.pub"
	fi
	echo ""
	echo "${BLUE}  ➡️  Add it to GitHub: https://github.com/settings/ssh/new${RESTORE}"
	echo "${BLUE}  🔗 Or manage all keys at:  https://github.com/settings/keys${RESTORE}"
	echo "${BLUE}============================================${RESTORE}"
fi

echo "${BLUE}All done. Type 'zsh' (or 'fish' to try fish) to launch your shell.${RESTORE}"
