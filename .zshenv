# Shared setup for every Zsh session, including noninteractive commands.
typeset -U path PATH

# rustup remains separate from mise; guard partially initialized machines.
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

# Keep managed runtimes ahead of legacy standalone tools in ~/.local/bin.
path=("$HOME/.local/share/mise/shims" "$HOME/.local/bin" $path)
export PATH
