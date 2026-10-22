#!/usr/bin/env bash
# Link shared Zsh files, keeping original files in a private local backup.
set +x
set -euo pipefail
umask 077

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
zsh_dir="${ZDOTDIR:-$HOME}"
if [[ ! -d "$zsh_dir" || -L "$zsh_dir" ]]; then
  printf 'Error: Zsh configuration directory must be an existing real directory.\n' >&2
  exit 1
fi
zsh_dir="$(cd -- "$zsh_dir" && pwd -P)"
if [[ "$zsh_dir" == "$repo_dir" ]]; then
  printf 'Error: refusing to replace repository source files with links.\n' >&2
  exit 1
fi

names=(.zshrc .zshenv .zprofile)
for name in "${names[@]}"; do
  if [[ ! -f "$repo_dir/$name" || -L "$repo_dir/$name" ]]; then
    printf 'Error: missing regular repository file: %s\n' "$name" >&2
    exit 1
  fi
  if [[ -e "$zsh_dir/$name" && ! -f "$zsh_dir/$name" && ! -L "$zsh_dir/$name" ]]; then
    printf 'Error: refusing to replace non-file: %s\n' "$zsh_dir/$name" >&2
    exit 1
  fi
done

backup_dir=''
changed=()
rollback() {
  local rc=$? name
  trap - ERR HUP INT TERM
  for name in "${changed[@]}"; do
    if [[ -L "$zsh_dir/$name" && "$(readlink "$zsh_dir/$name")" == "$repo_dir/$name" ]]; then
      unlink "$zsh_dir/$name"
    fi
    if [[ -n "$backup_dir" && ( -e "$backup_dir/$name" || -L "$backup_dir/$name" ) ]]; then
      mv "$backup_dir/$name" "$zsh_dir/$name"
    fi
  done
  [[ $rc -ne 0 ]] || rc=1
  exit "$rc"
}
trap rollback ERR HUP INT TERM

for name in "${names[@]}"; do
  if [[ -L "$zsh_dir/$name" && "$(readlink "$zsh_dir/$name")" == "$repo_dir/$name" ]]; then
    continue
  fi
  if [[ -e "$zsh_dir/$name" || -L "$zsh_dir/$name" ]]; then
    if [[ -z "$backup_dir" ]]; then
      for directory in "$HOME/.local" "$HOME/.local/state" "$HOME/.local/state/dotfiles"; do
        [[ ! -L "$directory" ]] || { printf 'Error: symlink backup directory refused.\n' >&2; false; }
      done
      mkdir -p "$HOME/.local/state/dotfiles"
      backup_dir="$(mktemp -d "$HOME/.local/state/dotfiles/zsh-backup.XXXXXXXX")"
    fi
    mv "$zsh_dir/$name" "$backup_dir/$name"
    if [[ -f "$backup_dir/$name" && ! -L "$backup_dir/$name" ]]; then
      chmod 600 "$backup_dir/$name"
    fi
  fi
  changed+=("$name")
  ln -s "$repo_dir/$name" "$zsh_dir/$name"
done
trap - ERR HUP INT TERM
printf 'Zsh files are linked to %s\n' "$repo_dir"
if [[ -n "$backup_dir" ]]; then
  printf 'Original files were backed up privately under %s\n' "$backup_dir"
fi
