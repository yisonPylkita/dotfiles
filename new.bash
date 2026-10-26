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
			printf 'Usage: bash ./new.bash [--gui]\n'
			printf '  --gui          Include the Alacritty configuration and GUI setup.\n'
			exit 0
			;;
		*)
			printf 'Unknown option: %s\n' "$1" >&2
			exit 64
			;;
	esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOCAL_DOTFILES_DIR=''
if [[ -f "$SCRIPT_DIR/setup-config.sh" ]]; then
	LOCAL_DOTFILES_DIR="$SCRIPT_DIR"
fi

set +x
set -e

export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"
export CARGO_INSTALL_ROOT="$HOME/.cargo"
unset RUSTUP_TOOLCHAIN
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
cd "$HOME"

export DEBIAN_FRONTEND=noninteractive

RESTORE=$(echo -en '\033[0m')
BLUE=$(echo -en '\033[01;34m')

get_system_type() {
	if [[ $(uname) == "Darwin" ]]; then
		echo "MacOS"
	elif command -v apt-get &>/dev/null; then
		ID=''
		VERSION_ID=''
		if [[ -r /etc/os-release ]]; then
			# shellcheck source=/dev/null
			source /etc/os-release
		elif command -v lsb_release &>/dev/null; then
			ID="$(lsb_release -si | tr '[:upper:]' '[:lower:]')"
			VERSION_ID="$(lsb_release -sr)"
		fi
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

BREW_BIN=''

find_homebrew() {
	if command -v brew &>/dev/null; then
		BREW_BIN="$(command -v brew)"
		return 0
	fi
	for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
		if [[ -x "$brew_bin" ]]; then
			BREW_BIN="$brew_bin"
			return 0
		fi
	done
	return 1
}

ensure_homebrew() {
	if find_homebrew; then
		eval "$("$BREW_BIN" shellenv)"
		return
	fi
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	# Both Apple Silicon and Intel installations may be missing from PATH.
	for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
		if [[ -x "$brew_bin" ]]; then
			BREW_BIN="$brew_bin"
			break
		fi
	done
	if ! find_homebrew; then
		printf 'Error: Homebrew installation did not provide a brew command.\n' >&2
		return 1
	fi
	eval "$("$BREW_BIN" shellenv)"
}

brew_formula_installed() {
	"$BREW_BIN" list --formula "$1" >/dev/null 2>&1
}

brew_cask_installed() {
	"$BREW_BIN" list --cask "$1" >/dev/null 2>&1
}

ensure_brew_formulas() {
	local package
	local -a missing=()
	for package in "$@"; do
		if ! brew_formula_installed "$package"; then
			missing+=("$package")
		fi
	done
	if (( ${#missing[@]} > 0 )); then
		"$BREW_BIN" install "${missing[@]}"
	fi
}

ensure_brew_cask() {
	if ! brew_cask_installed "$1"; then
		"$BREW_BIN" install --cask "$1"
	fi
}

apt_package_installed() {
	dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^.i'
}

APT_INDEXES_REFRESHED=false

refresh_apt_indexes_if_needed() {
	if [[ "$APT_INDEXES_REFRESHED" == false ]]; then
		sudo apt-get update
		APT_INDEXES_REFRESHED=true
	fi
}

ensure_apt_packages() {
	local package
	local -a missing=()
	for package in "$@"; do
		if ! apt_package_installed "$package"; then
			missing+=("$package")
		fi
	done
	if (( ${#missing[@]} > 0 )); then
		refresh_apt_indexes_if_needed
		sudo apt-get install -y "${missing[@]}"
	fi
}

if [[ $SYSTEM_TYPE == U* ]]; then
	echo "${BLUE}Ensuring system packages (apt)${RESTORE}"
	ensure_apt_packages \
		zsh fish tmux cmake neovim build-essential pkg-config openssl libssl-dev \
		jq fzf curl git git-lfs htop ca-certificates unzip fontconfig \
		python3 python3-venv python3-pip pipx direnv nodejs npm

	if [[ "$GUI_SETUP" == true ]] && ! apt_package_installed alacritty; then
		echo "${BLUE}Ensuring GUI terminal (apt)${RESTORE}"
		refresh_apt_indexes_if_needed
		if ! sudo apt-get install -y alacritty; then
			echo "${BLUE}Alacritty is unavailable; skipping.${RESTORE}"
		fi
	fi
elif [[ $SYSTEM_TYPE == "MacOS" ]]; then
	ensure_homebrew
	echo "${BLUE}Ensuring CLI tools (brew)${RESTORE}"
	ensure_brew_formulas \
		zsh fish tmux neovim jq fzf podman git-lfs htop \
		python node fnm direnv uv cargo-binstall
	ensure_brew_cask codex

	if [[ "$GUI_SETUP" == true ]]; then
		echo "${BLUE}Ensuring GUI apps (brew --cask)${RESTORE}"
		if ! brew_cask_installed alacritty && [[ ! -d "/Applications/Alacritty.app" ]]; then
			if ! "$BREW_BIN" install --cask alacritty; then
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
			fi
		fi
		if [[ -d "/Applications/Alacritty.app" ]] && ! brew_cask_installed alacritty; then
			# Reproduce the cask's command and terminfo links.
			ln -sf /Applications/Alacritty.app/Contents/MacOS/alacritty "$("$BREW_BIN" --prefix)/bin/alacritty"
			mkdir -p "$HOME/.terminfo/61"
			ln -sf /Applications/Alacritty.app/Contents/Resources/61/alacritty "$HOME/.terminfo/61/alacritty"
			ln -sf /Applications/Alacritty.app/Contents/Resources/61/alacritty-direct "$HOME/.terminfo/61/alacritty-direct"
		fi
	fi
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
ensure_npm_global() {
	if ! npm list --global --depth=0 "$1" >/dev/null 2>&1; then
		npm install --global "$1"
	fi
}
ensure_npm_global @earendil-works/pi-coding-agent
if [[ $SYSTEM_TYPE == U* ]]; then
	ensure_npm_global @openai/codex
fi

if [[ $SYSTEM_TYPE == U* ]] && ! command -v uv >/dev/null 2>&1; then
	echo "${BLUE}Installing uv through pipx${RESTORE}"
	pipx install uv
fi

echo "${BLUE}Installing Rust toolchain${RESTORE}"
if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
fi
# shellcheck source=/dev/null
if [[ -r "$HOME/.cargo/env" ]]; then
	source "$HOME/.cargo/env"
fi

if ! "$HOME/.cargo/bin/rustup" toolchain list 2>/dev/null | grep -q ' (default)$'; then
	"$HOME/.cargo/bin/rustup" toolchain install stable
	"$HOME/.cargo/bin/rustup" default stable
fi
# Stable is the default; other installed toolchains are kept and reported.
"$HOME/.cargo/bin/rustup" default stable

if [[ $SYSTEM_TYPE == U* ]] && ! command -v cargo-binstall >/dev/null 2>&1; then
	echo "${BLUE}Installing cargo-binstall (prebuilt)${RESTORE}"
	curl -L --proto '=https' --tlsv1.2 -sSf \
		https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
fi

echo "${BLUE}Setting up dotfiles${RESTORE}"
DOTFILES_DIR="$LOCAL_DOTFILES_DIR"
SSH_BOOTSTRAP_NEEDED=false
SSH_WAS_AVAILABLE=true
if [[ -z "$DOTFILES_DIR" && ! -d "$HOME/dotfiles" ]]; then
	# Try SSH first; fall back to HTTPS if no key is registered with GitHub
	SSH_BOOTSTRAP_NEEDED=true
	if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
		echo "${BLUE}  SSH key detected — cloning via SSH${RESTORE}"
		git clone git@github.com:yisonPylkita/dotfiles.git "$HOME/dotfiles"
		DOTFILES_DIR="$HOME/dotfiles"
		SSH_WAS_AVAILABLE=true
	else
		echo "${BLUE}  No SSH key for GitHub detected — cloning via HTTPS${RESTORE}"
		git clone https://github.com/yisonPylkita/dotfiles "$HOME/dotfiles"
		DOTFILES_DIR="$HOME/dotfiles"
		SSH_WAS_AVAILABLE=false
	fi
else
	if [[ -z "$DOTFILES_DIR" ]]; then
		DOTFILES_DIR="$HOME/dotfiles"
	fi
	# Already cloned, but check SSH availability for the key prompt later
fi

if [[ ! -f "$DOTFILES_DIR/setup-config.sh" ]]; then
	printf 'Error: setup-config.sh is missing from %s\n' "$DOTFILES_DIR" >&2
	exit 1
fi

# Link Zsh files; reruns preserve the links and back up differing local files.
# Seed local overrides/secrets without overwriting an existing file.
# Install tracked helper commands.
# Other top-level config files
# Pi AI coding assistant config
# XDG configs
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ "$CONFIG_HOME" != /* ]]; then
	CONFIG_HOME="$HOME/.config"
fi
set +x
if [[ "$GUI_SETUP" == true ]]; then
	bash "$DOTFILES_DIR/setup-config.sh" --gui
else
	bash "$DOTFILES_DIR/setup-config.sh"
fi
if [[ -f "$HOME/dotfiles/bin/rustup-report" ]]; then
	mkdir -p "$HOME/.local/bin"
	install -m 755 "$HOME/dotfiles/bin/rustup-report" "$HOME/.local/bin/rustup-report"
fi

echo "${BLUE}Installing Rust CLI tools (prebuilt only)${RESTORE}"
ensure_rust_cli() {
	local crate="$1"
	local binary="$2"
	if ! command -v "$binary" >/dev/null 2>&1; then
		"$HOME/.local/bin/cargo-binstall-latest" "$crate"
	fi
}
ensure_rust_cli starship starship
ensure_rust_cli ripgrep rg
ensure_rust_cli lsd lsd
ensure_rust_cli bat bat
ensure_rust_cli gitui gitui
ensure_rust_cli zellij zellij

if [[ -x "$HOME/.local/bin/rustup-report" ]]; then
	echo "${BLUE}Rust toolchain disk usage${RESTORE}"
	"$HOME/.local/bin/rustup-report"
fi

# DeepSeek worker delegation is configured separately in ~/.codex (ds-worker);
# this bootstrap does not install a separate DeepSeek Codex home.

# Install pi extension dependencies silently (npm resolves through the
# system Node, or fnm when the system Node was too old)
if ! (cd "$HOME/.pi/agent/npm" && npm list --depth=0 >/dev/null 2>&1); then
	(cd "$HOME/.pi/agent/npm" && npm install --ignore-scripts >/dev/null)
fi

if [[ "$GUI_SETUP" == true ]]; then
	echo "${BLUE}Cloning Alacritty theme repo${RESTORE}"
	if [[ ! -d "$CONFIG_HOME/alacritty/themes" ]]; then
		git clone https://github.com/alacritty/alacritty-theme "$CONFIG_HOME/alacritty/themes"
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
LOGIN_USER="$(id -un)"
if [[ $SYSTEM_TYPE == "MacOS" ]]; then
	CONFIGURED_SHELL="$(dscl . -read "/Users/$LOGIN_USER" UserShell | sed 's/^UserShell: //')"
else
	CONFIGURED_SHELL="$(getent passwd "$LOGIN_USER" | awk -F: '{print $7}')"
fi
if [[ -z "$CONFIGURED_SHELL" ]]; then
	printf 'Error: could not determine the configured login shell for %s.\n' "$LOGIN_USER" >&2
	exit 1
fi
if [[ ! "$CONFIGURED_SHELL" -ef "$ZSH_BIN" ]]; then
	sudo chsh -s "$ZSH_BIN" "$LOGIN_USER"
fi

install_nerd_font() {
	if [[ $SYSTEM_TYPE == "MacOS" ]]; then
		ensure_brew_cask font-caskaydia-cove-nerd-font
	elif [[ $SYSTEM_TYPE == U* ]]; then
		local FONT_DIR="$HOME/.local/share/fonts"
		mkdir -p "$FONT_DIR"
		if ! find "$FONT_DIR" -type f -iname 'CaskaydiaCoveNerdFont*.ttf' -print -quit | grep -q .; then
			echo "${BLUE}  Downloading CascadiaCode Nerd Font from GitHub...${RESTORE}"
			local TMP_ZIP="/tmp/CascadiaCode.zip"
			curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaCode.zip" -o "$TMP_ZIP"
			unzip -o -q "$TMP_ZIP" -d "$FONT_DIR"
			rm -f "$TMP_ZIP"
			fc-cache -fv
			echo "${BLUE}  Font cache updated.${RESTORE}"
		fi
	fi
}

if [[ "$GUI_SETUP" == true ]]; then
	echo "${BLUE}Installing CaskaydiaCove Nerd Font${RESTORE}"
	install_nerd_font
fi

set +x
if [[ -f "$HOME/.config/dotfiles/setup.local.bash" ]]; then
	# shellcheck source=/dev/null
	source "$HOME/.config/dotfiles/setup.local.bash"
fi

# ============================================
# SSH key bootstrap — generate if not present
# ============================================
if [[ "$SSH_BOOTSTRAP_NEEDED" == "true" && "$SSH_WAS_AVAILABLE" == "false" ]]; then
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
