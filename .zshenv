# Shared setup for every Zsh session, including noninteractive commands.
typeset -U path PATH

# rustup lives outside the system package manager.
if [[ -r "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

# Discover the standard Homebrew prefixes without starting brew on every shell.
for brew_bin in /opt/homebrew/bin /usr/local/bin /home/linuxbrew/.linuxbrew/bin; do
  if [[ -x "$brew_bin/brew" ]]; then
    path=("$brew_bin" $path)
    break
  fi
done
unset brew_bin

# Prefer cargo-installed Rust tools over Homebrew duplicates.
path=("$HOME/.cargo/bin" $path)

# Keep user-local tools ahead of system tools.
[[ -d "$HOME/.local/share/fnm" ]] && path=("$HOME/.local/share/fnm" $path)
path=("$HOME/.local/bin" $path)
export PATH
