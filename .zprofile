# macOS /etc/zprofile runs path_helper after .zshenv; restore mise priority.
typeset -U path PATH
path=("$HOME/.local/share/mise/shims" "$HOME/.local/bin" $path)
export PATH
