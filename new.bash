#!/usr/bin/env bash

# Script for setting up a new Unix environment.
# Supported: Ubuntu 22.04/24.04/26.04 LTS and macOS.
#
# By default this installs CLI/server tooling only. Pass --gui to also install
# GUI extras (Alacritty and the Nerd Font).
#
# mise is the developer-runtime owner: python, node, deno, uv, direnv and
# the pi coding agent are installed and pinned through mise (see the
# MISE_*_VERSION variables below). rustup is the documented exception.
# Homebrew stays available for CLI/GUI tools but no longer owns runtimes.
#
# Legacy-tool cleanup on EXISTING machines (nvm, fnm, pyenv, standalone uv,
# uv/npm caches) is NOT done here — see migrate-mise-cleanup.bash in this
# repo (dry-run by default; pass --apply to actually delete).
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

# Tool versions managed by mise — single source of truth; keep in sync with
# the live ~/.config/mise/config.toml on the reference machine
MISE_PYTHON_VERSION=3.14.6
MISE_NODE_VERSION=26.6.0
MISE_DENO_VERSION=2.9.4
MISE_UV_VERSION=0.9.26
MISE_DIRENV_VERSION=2.37.1
MISE_PI_VERSION=0.83.0
MISE_CODEX_VERSION=0.163.0 # Ubuntu; macOS uses the Homebrew cask

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
		jq fzf curl git git-lfs htop ca-certificates unzip fontconfig

	if [[ "$GUI_SETUP" == true ]]; then
		echo "${BLUE}Installing GUI terminal (apt)${RESTORE}"
		sudo apt-get install -y alacritty || echo "${BLUE}Alacritty is unavailable; skipping.${RESTORE}"
	fi
fi

if [[ $SYSTEM_TYPE == "MacOS" ]]; then
	echo "${BLUE}Installing CLI tools (brew)${RESTORE}"
	brew install \
		zsh fish tmux neovim jq fzf starship podman git-lfs \
		lsd bat ripgrep gitui htop zellij

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

echo "${BLUE}Installing mise (developer-runtime owner)${RESTORE}"
if ! command -v mise &>/dev/null; then
	if [[ $SYSTEM_TYPE == "MacOS" ]]; then
		brew install mise
	elif [[ $SYSTEM_TYPE == U* ]]; then
		# Official installer — same curl|sh pattern as rustup below
		curl -fsSL https://mise.run | sh
	fi
fi
# Resolve the mise binary (Linux installs to ~/.local/bin) and the tool
# shims for the remainder of this non-interactive script.
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/mise/shims:$PATH"

echo "${BLUE}Pinning developer runtimes via mise${RESTORE}"
mise use -g \
	"python@$MISE_PYTHON_VERSION" \
	"node@$MISE_NODE_VERSION" \
	"deno@$MISE_DENO_VERSION" \
	"uv@$MISE_UV_VERSION" \
	"direnv@$MISE_DIRENV_VERSION"
mise use -g "npm:@earendil-works/pi-coding-agent@$MISE_PI_VERSION"
mise install

if [[ $SYSTEM_TYPE == U* ]]; then
	echo "${BLUE}Installing Codex CLI through mise${RESTORE}"
	mise use -g "npm:@openai/codex@$MISE_CODEX_VERSION"
	mise install
fi

echo "${BLUE}Installing Rust toolchain${RESTORE}"
# rustup: documented exception — not managed by mise
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

# Link Zsh files; reruns preserve the links and back up differing local files.
bash "$HOME/dotfiles/setup-zsh.sh"

# Seed local overrides/secrets without overwriting an existing file.
if [[ ! -e "$HOME/.zsh_local" && -f "$HOME/dotfiles/.zsh_local.example" ]]; then
	install -m 600 "$HOME/dotfiles/.zsh_local.example" "$HOME/.zsh_local"
fi

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
# Install pi extension dependencies silently (npm resolves to the
# mise-managed node/npm via the shims PATH exported above)
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
