#!/usr/bin/env bash

# Script for setting up a new Unix environment.
# Supported: Ubuntu 22.04/24.04/26.04 LTS and macOS.
#
# By default this installs CLI/server tooling only. Pass --gui to also install
# GUI extras (Alacritty and the Nerd Font).
#
# Developer runtimes come from the operating system:
#   macOS: Homebrew
#   Ubuntu: apt
# Node uses the system LTS unless it is too old for the current tools; in
# that case fnm installs a newer LTS. Rust tools are installed as prebuilt
# binaries through cargo-binstall, never compiled locally.
#
# Usage:
#   bash new.bash
#   bash new.bash --gui
#   bash <(curl -fsSL https://yisonpylkita.github.io/new.bash)
#   bash <(curl -fsSL https://yisonpylkita.github.io/new.bash) --gui

GUI_SETUP=false
while (( $# > 0 )); do
	case "$1" in
		--gui)
			GUI_SETUP=true
			shift
			;;
		--help|-h)
			printf 'Usage: new.bash [--gui]\n'
			exit 0
			;;
		*)
			printf 'Unknown option: %s\n' "$1" >&2
			exit 64
			;;
	esac
done

set -ex

export DEBIAN_FRONTEND=noninteractive

RESTORE=$(echo -en '\033[0m')
BLUE=$(echo -en '\033[01;34m')

get_system_type() {
	if [[ $(uname) == "Darwin" ]]; then
		echo "MacOS"
	elif command -v apt-get &>/dev/null; then
		# shellcheck source=/dev/null
		source /etc/os-release
		case "$ID:$VERSION_ID" in
			ubuntu:22.04|ubuntu:24.04|ubuntu:26.04)
				echo "U${VERSION_ID}"
				;;
			*)
				printf 'Unsupported distribution: %s %s\n' "$ID" "$VERSION_ID" >&2
				return 1
				;;
		esac
	else
		printf 'Unsupported system\n' >&2
		return 1
	fi
}

SYSTEM_TYPE="$(get_system_type)"
echo "${BLUE}System type: $SYSTEM_TYPE${RESTORE}"

install_homebrew() {
	if ! command -v brew &>/dev/null; then
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
	# Both Apple Silicon and Intel installations may be missing from PATH.
	for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
		if [[ -x "$brew_bin" ]]; then
			eval "$("$brew_bin" shellenv)"
			break
		fi
	done

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
		jq fzf curl git git-lfs htop ca-certificates unzip fontconfig \
		python3 python3-venv python3-pip pipx direnv nodejs npm

	if [[ "$GUI_SETUP" == true ]]; then
		echo "${BLUE}Installing GUI terminal (apt)${RESTORE}"
		sudo apt-get install -y alacritty || echo "${BLUE}Alacritty is unavailable; skipping.${RESTORE}"
	fi
fi

if [[ $SYSTEM_TYPE == "MacOS" ]]; then
	echo "${BLUE}Installing CLI tools (brew)${RESTORE}"
	brew install \
		zsh fish tmux neovim jq fzf podman git-lfs htop \
		python node fnm direnv uv cargo-binstall

	if [[ "$GUI_SETUP" == true ]]; then
		echo "${BLUE}Installing GUI apps (brew --cask)${RESTORE}"
		if ! brew install --cask alacritty; then
			# Homebrew disabled the Alacritty cask on 2026-09-01. Fall back to
			# the official GitHub release, which passes Gatekeeper on macOS 26.
			echo "${BLUE}Homebrew cask unavailable; installing Alacritty from GitHub...${RESTORE}"
			if [[ ! -d "/Applications/Alacritty.app" ]]; then
				alacritty_version=0.17.0
				alacritty_tmp="$(mktemp -d)"
				mkdir -p "$alacritty_tmp/mnt"
				curl -fL "https://github.com/alacritty/alacritty/releases/download/v${alacritty_version}/Alacritty-v${alacritty_version}.dmg" -o "$alacritty_tmp/Alacritty.dmg"
				hdiutil attach -nobrowse -quiet -mountpoint "$alacritty_tmp/mnt" "$alacritty_tmp/Alacritty.dmg"
				sudo cp -R "$alacritty_tmp/mnt/Alacritty.app" /Applications/
				hdiutil detach "$alacritty_tmp/mnt" -quiet
				rm -rf "$alacritty_tmp"
			fi

			# Reproduce the cask's command and terminfo links.
			ln -sf /Applications/Alacritty.app/Contents/MacOS/alacritty "$(brew --prefix)/bin/alacritty"
			mkdir -p "$HOME/.terminfo/61"
			ln -sf /Applications/Alacritty.app/Contents/Resources/61/alacritty "$HOME/.terminfo/61/alacritty"
			ln -sf /Applications/Alacritty.app/Contents/Resources/61/alacritty-direct "$HOME/.terminfo/61/alacritty-direct"
		fi
	fi
	brew list --cask codex >/dev/null 2>&1 || brew install --cask codex
fi

if ! git config --global --get init.defaultBranch >/dev/null 2>&1; then
	git config --global init.defaultBranch main
fi
if command -v git-lfs >/dev/null 2>&1; then
	git lfs install
fi

echo "${BLUE}Configuring Node.js and fnm${RESTORE}"
export PATH="$HOME/.local/bin:$PATH"
if [[ $SYSTEM_TYPE == U* ]]; then
	if ! command -v fnm >/dev/null 2>&1; then
		# Prebuilt binary; --skip-shell because this repo owns shell config.
		curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
	fi
	export PATH="$HOME/.local/share/fnm:$HOME/.local/bin:$PATH"
fi

if ! command -v fnm >/dev/null 2>&1; then
	echo "fnm is not installed" >&2
	exit 1
fi

eval "$(fnm env --shell bash)"
if ! command -v node >/dev/null 2>&1 || ! node -e '
	const [major, minor] = process.versions.node.split(".").map(Number);
	process.exit(major > 22 || (major === 22 && minor >= 19) ? 0 : 1);
'; then
	echo "${BLUE}System Node is too old; installing Node 22 LTS with fnm${RESTORE}"
	fnm install 22
	fnm default 22
	fnm use 22
fi

echo "${BLUE}Installing npm tools${RESTORE}"
npm config set prefix "$HOME/.local"
npm install -g @earendil-works/pi-coding-agent
if [[ $SYSTEM_TYPE == U* ]]; then
	npm install -g @openai/codex
fi

if [[ $SYSTEM_TYPE == U* ]] && ! command -v uv >/dev/null 2>&1; then
	echo "${BLUE}Installing uv through pipx${RESTORE}"
	pipx install uv
fi

echo "${BLUE}Installing Rust toolchain${RESTORE}"
if ! command -v cargo &>/dev/null; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# shellcheck source=/dev/null
source "$HOME/.cargo/env"

if [[ $SYSTEM_TYPE == U* ]] && ! command -v cargo-binstall >/dev/null 2>&1; then
	echo "${BLUE}Installing cargo-binstall (prebuilt)${RESTORE}"
	curl -L --proto '=https' --tlsv1.2 -sSf \
		https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
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

# Link Zsh files; reruns preserve the links and back up differing local files.
bash "$HOME/dotfiles/setup-zsh.sh"

# Seed local overrides/secrets without overwriting an existing file.
if [[ ! -e "$HOME/.zsh_local" && -f "$HOME/dotfiles/.zsh_local.example" ]]; then
	install -m 600 "$HOME/dotfiles/.zsh_local.example" "$HOME/.zsh_local"
fi

# Install tracked helper commands.
if [[ -f "$HOME/dotfiles/bin/cargo-binstall-latest" ]]; then
	mkdir -p "$HOME/.local/bin"
	install -m 755 "$HOME/dotfiles/bin/cargo-binstall-latest" "$HOME/.local/bin/cargo-binstall-latest"
fi

echo "${BLUE}Installing Rust CLI tools (prebuilt only)${RESTORE}"
for crate in starship ripgrep lsd bat gitui zellij; do
	"$HOME/.local/bin/cargo-binstall-latest" "$crate"
done

# Other top-level config files
cp "$HOME/dotfiles/.tmux.conf" "$HOME/.tmux.conf"
cp "$HOME/dotfiles/.vimrc" "$HOME/.vimrc"

# DeepSeek worker delegation is configured separately in ~/.codex (ds-worker);
# this bootstrap does not install a separate DeepSeek Codex home.

# Pi AI coding assistant config
mkdir -p "$HOME/.pi/agent/npm" "$HOME/.pi/agent/extensions/pi-rtk-optimizer"
cp "$HOME/dotfiles/.pi/agent/settings.json" "$HOME/.pi/agent/settings.json"
if [[ ! -e "$HOME/.pi/agent/trust.json" ]]; then
	cp "$HOME/dotfiles/.pi/agent/trust.json" "$HOME/.pi/agent/trust.json"
fi
cp "$HOME/dotfiles/.pi/agent/npm/package.json" "$HOME/.pi/agent/npm/package.json"
cp "$HOME/dotfiles/.pi/agent/extensions/eko24ive-pi-ask.json" "$HOME/.pi/agent/extensions/eko24ive-pi-ask.json"
cp "$HOME/dotfiles/.pi/agent/extensions/pi-rtk-optimizer/config.json" "$HOME/.pi/agent/extensions/pi-rtk-optimizer/config.json"
# Install pi extension dependencies silently (npm resolves through the
# system Node, or fnm when the system Node was too old)
(cd "$HOME/.pi/agent" && npm install --ignore-scripts &>/dev/null) || true

# XDG configs
mkdir -p "$HOME/.config/fish" "$HOME/.config/zellij" "$HOME/.config/nvim"
cp "$HOME/dotfiles/.config/fish/config.fish" "$HOME/.config/fish/config.fish"
cp "$HOME/dotfiles/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
cp "$HOME/dotfiles/nvim/init.vim" "$HOME/.config/nvim/init.vim"

if [[ "$GUI_SETUP" == true ]]; then
	mkdir -p "$HOME/.config/alacritty"
	cp "$HOME/dotfiles/.config/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"

	echo "${BLUE}Cloning Alacritty theme repo${RESTORE}"
	if [[ ! -d "$HOME/.config/alacritty/themes" ]]; then
		git clone https://github.com/alacritty/alacritty-theme "$HOME/.config/alacritty/themes"
	fi
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

install_nerd_font() {
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

if [[ "$GUI_SETUP" == true ]]; then
	echo "${BLUE}Installing CaskaydiaCove Nerd Font${RESTORE}"
	install_nerd_font
fi

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
