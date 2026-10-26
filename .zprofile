# macOS /etc/zprofile runs path_helper after .zshenv; restore local tool priority.
typeset -U path PATH
brew_prefix=""
for brew_bin in /opt/homebrew/bin /usr/local/bin /home/linuxbrew/.linuxbrew/bin; do
  if [[ -x "$brew_bin/brew" ]]; then
    brew_prefix="$brew_bin"
    eval "$("$brew_bin/brew" shellenv)"
    break
  fi
done
local_paths=("$HOME/.cargo/bin" "$HOME/.local/bin")
[[ -d "$HOME/.local/share/fnm" ]] && local_paths+=("$HOME/.local/share/fnm")
if [[ -n "$brew_prefix" ]]; then
  path=("${local_paths[@]}" "$brew_prefix" $path)
else
  path=("${local_paths[@]}" $path)
fi
unset brew_bin brew_prefix local_paths
export PATH
[[ -r "$HOME/.zshenv_local" ]] && source "$HOME/.zshenv_local"
