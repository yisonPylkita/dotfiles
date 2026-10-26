#!/usr/bin/env bash
# Link shared Zsh files, keeping original files in a private local backup.
set +x
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec bash "$repo_dir/setup-config.sh" --zsh-only
