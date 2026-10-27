#!/usr/bin/env bash
set +x
set -euo pipefail
umask 077

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
gui_setup=false
while (( $# > 0 )); do
	case "$1" in
		--gui)
			gui_setup=true
			shift
			;;
		--help|-h)
			printf 'Usage: setup-config.sh [--gui]\n'
			exit 0
			;;
		*)
			printf 'Unknown option: %s\n' "$1" >&2
			exit 64
			;;
	esac
done

home_dir="$(cd -P "$HOME" && pwd -P)"
config_home="${XDG_CONFIG_HOME:-$home_dir/.config}"
state_home="${XDG_STATE_HOME:-$home_dir/.local/state}"
zsh_dir="${ZDOTDIR:-$home_dir}"

if [[ "$config_home" != /* ]]; then
	config_home="$home_dir/.config"
fi
if [[ "$state_home" != /* ]]; then
	state_home="$home_dir/.local/state"
fi
if [[ "$zsh_dir" != /* ]]; then
	zsh_dir="$(pwd -P)/$zsh_dir"
fi

reject_parent_components() {
	case "$1" in
		*"/../"*|*"/..")
			printf 'Error: paths containing .. are not supported: %s\n' "$1" >&2
			return 1
			;;
	esac
}

reject_parent_components "$config_home"
reject_parent_components "$state_home"
reject_parent_components "$zsh_dir"

link_sources=()
link_targets=()
seed_sources=()
seed_targets=()
empty_targets=()

add_link() {
	link_sources+=("$1")
	link_targets+=("$2")
}

add_seed() {
	seed_sources+=("$1")
	seed_targets+=("$2")
}

add_empty() {
	empty_targets+=("$1")
}

add_link "$repo_dir/.zshrc" "$zsh_dir/.zshrc"
add_link "$repo_dir/.zshenv" "$zsh_dir/.zshenv"
add_link "$repo_dir/.zprofile" "$zsh_dir/.zprofile"
add_link "$repo_dir/bin/cargo-binstall-latest" "$home_dir/.local/bin/cargo-binstall-latest"
add_link "$repo_dir/bin/dotfiles-rust-update" "$home_dir/.local/bin/dotfiles-rust-update"
add_link "$repo_dir/bin/dotfiles-ai-build" "$home_dir/.local/bin/dotfiles-ai-build"
add_link "$repo_dir/bin/rustup-report" "$home_dir/.local/bin/rustup-report"
add_link "$repo_dir/.config/zellij/config.kdl" "$config_home/zellij/config.kdl"
add_link "$repo_dir/nvim/init.vim" "$config_home/nvim/init.vim"
add_link "$repo_dir/nvim/init.vim" "$home_dir/.vimrc"
if [[ "$gui_setup" == true ]]; then
	add_link "$repo_dir/.config/alacritty/alacritty.toml" "$config_home/alacritty/alacritty.toml"
fi
add_seed "$repo_dir/.pi/agent/settings.json" "$home_dir/.pi/agent/settings.json"
add_seed "$repo_dir/.pi/agent/trust.json" "$home_dir/.pi/agent/trust.json"
add_seed "$repo_dir/.pi/agent/npm/package.json" "$home_dir/.pi/agent/npm/package.json"
add_seed "$repo_dir/.pi/agent/extensions/eko24ive-pi-ask.json" "$home_dir/.pi/agent/extensions/eko24ive-pi-ask.json"
add_seed "$repo_dir/.pi/agent/extensions/pi-rtk-optimizer/config.json" "$home_dir/.pi/agent/extensions/pi-rtk-optimizer/config.json"
add_empty "$home_dir/.zsh_local"
add_empty "$home_dir/.zshenv_local"
add_empty "$home_dir/.config/dotfiles/setup.local.bash"

canonicalize_target() {
	local target="$1"
	local parent="${target%/*}"
	local name="${target##*/}"
	local probe="$parent"
	local suffix=''
	local component
	local resolved_parent

	while [[ ! -d "$probe" ]]; do
		if [[ -e "$probe" || -L "$probe" ]]; then
			printf 'Error: destination parent is not a directory: %s\n' "$probe" >&2
			return 1
		fi
		if [[ "$probe" == "/" ]]; then
			printf 'Error: cannot resolve destination: %s\n' "$target" >&2
			return 1
		fi
		component="${probe##*/}"
		suffix="/$component$suffix"
		probe="${probe%/*}"
		[[ -n "$probe" ]] || probe="/"
	done

	resolved_parent="$(cd -P "$probe" && pwd -P)"
	if [[ "$resolved_parent" == "/" ]]; then
		resolved_parent="/${suffix#/}"
	else
		resolved_parent="$resolved_parent$suffix"
	fi
	[[ "$resolved_parent" == "/" ]] || resolved_parent="${resolved_parent%/}"
	case "$resolved_parent" in
		"$repo_dir"|"$repo_dir"/*)
			printf 'Error: destination directory resolves inside the checkout: %s\n' "$target" >&2
			return 1
			;;
	esac
	if [[ "$resolved_parent" == "/" ]]; then
		NORMALIZED_TARGET="/$name"
	else
		NORMALIZED_TARGET="$resolved_parent/$name"
	fi
}

canonicalize_target "$state_home/dotfiles/managed-links.tsv"
managed_manifest="$NORMALIZED_TARGET"
previous_links=()
if [[ -f "$managed_manifest" ]]; then
	while IFS= read -r previous_link; do
		[[ -n "$previous_link" ]] && previous_links+=("$previous_link")
	done < "$managed_manifest"
fi

ai_generated_file="$config_home/ai/AGENTS.md"
canonicalize_target "$ai_generated_file"
ai_generated_file="$NORMALIZED_TARGET"
if [[ ! -f "$repo_dir/ai/AGENTS.md" || ! -x "$repo_dir/bin/dotfiles-ai-build" ]]; then
	printf 'Error: AI instruction sources are missing from %s\n' "$repo_dir" >&2
	exit 1
fi
if [[ -d "$ai_generated_file" ]]; then
	printf 'Error: refusing to replace directory: %s\n' "$ai_generated_file" >&2
	exit 1
fi
add_link "$ai_generated_file" "$home_dir/.claude/CLAUDE.md"
add_link "$ai_generated_file" "$home_dir/.codex/AGENTS.md"

canonical_link_targets=()
canonical_seed_targets=()
canonical_empty_targets=()
all_targets=()

for ((i = 0; i < ${#link_sources[@]}; i++)); do
	source="${link_sources[$i]}"
	target="${link_targets[$i]}"
	if [[ "$source" != "$ai_generated_file" ]] && [[ ! -f "$source" || -L "$source" ]]; then
		printf 'Error: missing regular repository file: %s\n' "$source" >&2
		exit 1
	fi
	canonicalize_target "$target"
	canonical_target="$NORMALIZED_TARGET"
	if [[ "$canonical_target" == "$source" ]]; then
		printf 'Error: source and destination are the same path: %s\n' "$source" >&2
		exit 1
	fi
	if [[ -d "$canonical_target" ]]; then
		printf 'Error: refusing to replace directory: %s\n' "$canonical_target" >&2
		exit 1
	fi
	canonical_link_targets+=("$canonical_target")
	all_targets+=("$canonical_target")
done

for ((i = 0; i < ${#seed_sources[@]}; i++)); do
	source="${seed_sources[$i]}"
	target="${seed_targets[$i]}"
	if [[ ! -f "$source" || -L "$source" ]]; then
		printf 'Error: missing regular repository file: %s\n' "$source" >&2
		exit 1
	fi
	canonicalize_target "$target"
	canonical_target="$NORMALIZED_TARGET"
	if [[ "$canonical_target" == "$source" ]]; then
		printf 'Error: source and destination are the same path: %s\n' "$source" >&2
		exit 1
	fi
	if [[ -d "$canonical_target" ]]; then
		printf 'Error: refusing to replace directory: %s\n' "$canonical_target" >&2
		exit 1
	fi
	canonical_seed_targets+=("$canonical_target")
	all_targets+=("$canonical_target")
done

for ((i = 0; i < ${#empty_targets[@]}; i++)); do
	target="${empty_targets[$i]}"
	canonicalize_target "$target"
	canonical_target="$NORMALIZED_TARGET"
	if [[ -d "$canonical_target" ]]; then
		printf 'Error: refusing to replace directory: %s\n' "$canonical_target" >&2
		exit 1
	fi
	canonical_empty_targets+=("$canonical_target")
	all_targets+=("$canonical_target")
done

for ((i = 0; i < ${#all_targets[@]}; i++)); do
	if [[ -e "${all_targets[$i]}" && ! -f "${all_targets[$i]}" && ! -L "${all_targets[$i]}" ]]; then
		printf 'Error: refusing to replace non-file: %s\n' "${all_targets[$i]}" >&2
		exit 1
	fi
	for ((j = i + 1; j < ${#all_targets[@]}; j++)); do
		if [[ "${all_targets[$i]}" == "${all_targets[$j]}" ]]; then
			printf 'Error: multiple managed sources target the same path: %s\n' "${all_targets[$i]}" >&2
			exit 1
		fi
	done
done

backup_needed=false
for ((i = 0; i < ${#link_sources[@]}; i++)); do
	target="${canonical_link_targets[$i]}"
	source="${link_sources[$i]}"
	if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
		continue
	fi
	if [[ -e "$target" || -L "$target" ]]; then
		backup_needed=true
	fi
done

backup_root=''
if [[ "$backup_needed" == true ]]; then
	backup_probe="$state_home/dotfiles/.probe"
	canonicalize_target "$backup_probe"
	backup_root="${NORMALIZED_TARGET%/*}"
	case "$backup_root" in
		"$repo_dir"|"$repo_dir"/*)
			printf 'Error: backup directory resolves inside the checkout: %s\n' "$backup_root" >&2
			exit 1
			;;
	esac
fi

created_dirs=()
undo_targets=()
undo_sources=()
undo_backups=()
undo_modes=()
undo_seeds=()
backup_dir=''
ai_temp_file=''
committed=false
rolling_back=false

ensure_directory() {
	local directory="$1"
	local parent
	if [[ -d "$directory" ]]; then
		return 0
	fi
	if [[ -e "$directory" || -L "$directory" ]]; then
		printf 'Error: path is not a directory: %s\n' "$directory" >&2
		return 1
	fi
	parent="${directory%/*}"
	[[ -n "$parent" ]] || parent="/"
	if [[ "$parent" == "$directory" ]]; then
		printf 'Error: cannot create directory: %s\n' "$directory" >&2
		return 1
	fi
	ensure_directory "$parent"
	created_dirs+=("$directory")
	mkdir "$directory"
}

append_manifest() {
	printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$backup_dir/manifest.tsv"
}

read_mode() {
	local mode
	if mode="$(stat -f '%Lp' "$1" 2>/dev/null)" && [[ "$mode" =~ ^[0-7]+$ ]]; then
		printf '%s\n' "$mode"
	else
		stat -c '%a' "$1"
	fi
}

snapshot_private_entry() {
	local source="$1"
	local destination="$backup_dir/private/${source#/}"
	local mode=''
	if [[ ! -e "$source" && ! -L "$source" ]]; then
		return 0
	fi
	if [[ ! -f "$source" && ! -L "$source" ]]; then
		printf 'Error: private configuration is not a file: %s\n' "$source" >&2
		return 1
	fi
	if [[ ! -L "$source" ]]; then
		mode="$(read_mode "$source")"
	fi
	ensure_directory "${destination%/*}"
	cp -P "$source" "$destination"
	if [[ -f "$destination" && ! -L "$destination" ]]; then
		chmod 600 "$destination"
	fi
	append_manifest "$source" "$destination" "$mode"
}

prune_managed_links() {
	local old_target desired current
	local keep
	local failed=false
	if (( ${#previous_links[@]} > 0 )); then
		for old_target in "${previous_links[@]}"; do
			keep=false
			for desired in "${canonical_link_targets[@]}"; do
				if [[ "$old_target" == "$desired" ]]; then
					keep=true
					break
				fi
			done
			[[ "$keep" == true ]] && continue
			[[ -L "$old_target" ]] || continue
			current="$(readlink "$old_target" 2>/dev/null || true)"
			case "$current" in
				"$repo_dir"|"$repo_dir"/*)
					if [[ ! -e "$current" ]]; then
						rm -f "$old_target" || failed=true
					fi
					;;
			esac
		done
	fi
	[[ "$failed" == false ]]
}

write_managed_links() {
	local temp_file
	ensure_directory "${managed_manifest%/*}"
	temp_file="$(mktemp "${managed_manifest}.XXXXXX")"
	printf '%s\n' "${canonical_link_targets[@]}" > "$temp_file"
	chmod 600 "$temp_file"
	mv -f "$temp_file" "$managed_manifest"
}

rollback() {
	local status=$?
	local index target source backup seed mode
	local restore_failed=false
	if [[ "$committed" == true || "$rolling_back" == true ]]; then
		return
	fi
	rolling_back=true
	trap - EXIT HUP INT TERM
	set +e
	if [[ -n "$ai_temp_file" && ( -e "$ai_temp_file" || -L "$ai_temp_file" ) ]]; then
		rm -f "$ai_temp_file" || restore_failed=true
	fi
	for ((index = ${#undo_seeds[@]} - 1; index >= 0; index--)); do
		seed="${undo_seeds[$index]}"
		rm -f "$seed" || restore_failed=true
	done
	for ((index = ${#undo_targets[@]} - 1; index >= 0; index--)); do
		target="${undo_targets[$index]}"
		source="${undo_sources[$index]}"
		backup="${undo_backups[$index]}"
		mode="${undo_modes[$index]}"
		if [[ -L "$target" ]] && [[ "$(readlink "$target" 2>/dev/null)" == "$source" ]]; then
			rm -f "$target" || restore_failed=true
		fi
		if [[ -n "$backup" && ( -e "$backup" || -L "$backup" ) ]]; then
			if [[ ! -e "$target" && ! -L "$target" ]]; then
				if mv "$backup" "$target"; then
					if [[ -n "$mode" ]]; then
						chmod "$mode" "$target" || restore_failed=true
					fi
				else
					restore_failed=true
				fi
			else
				restore_failed=true
			fi
		fi
	done
	if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
		if [[ "$restore_failed" == true ]]; then
			printf 'Automatic restoration was incomplete; backups retained at %s\n' "$backup_dir" >&2
		else
			rm -rf "$backup_dir"
		fi
	fi
	for ((index = ${#created_dirs[@]} - 1; index >= 0; index--)); do
		rmdir "${created_dirs[$index]}" 2>/dev/null
	done
	exit "$status"
}

trap rollback EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$backup_needed" == true ]]; then
	ensure_directory "$backup_root"
	backup_stamp="$(date '+%Y%m%d-%H%M%S')"
	backup_dir="$(mktemp -d "$backup_root/dotfiles-setup-$backup_stamp.XXXXXXXX")"
	chmod 700 "$backup_dir"
	for private_path in \
		"$home_dir/.zsh_local" \
		"$home_dir/.zshenv_local" \
		"$home_dir/.config/dotfiles/setup.local.bash"; do
		snapshot_private_entry "$private_path"
	done
fi

ensure_directory "${ai_generated_file%/*}"
ai_temp_file="$(mktemp "${ai_generated_file%/*}/.AGENTS.md.XXXXXX")"
XDG_CONFIG_HOME="$config_home" DOTFILES_DIR="$repo_dir" \
	"$repo_dir/bin/dotfiles-ai-build" --output "$ai_temp_file"

for ((i = 0; i < ${#link_sources[@]}; i++)); do
	source="${link_sources[$i]}"
	target="${canonical_link_targets[$i]}"
	if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
		continue
	fi
	backup=''
	mode=''
	if [[ -e "$target" || -L "$target" ]]; then
		backup="$backup_dir/originals/${target#/}"
		if [[ -f "$target" && ! -L "$target" ]]; then
			mode="$(read_mode "$target")"
		fi
	fi
	undo_targets+=("$target")
	undo_sources+=("$source")
	undo_backups+=("$backup")
	undo_modes+=("$mode")
	if [[ -n "$backup" ]]; then
		ensure_directory "${backup%/*}"
		mv "$target" "$backup"
		if [[ -f "$backup" && ! -L "$backup" ]]; then
			chmod 600 "$backup"
		fi
		append_manifest "$target" "$backup" "$mode"
	fi
	ensure_directory "${target%/*}"
	ln -s "$source" "$target"
done

for ((i = 0; i < ${#seed_sources[@]}; i++)); do
	source="${seed_sources[$i]}"
	target="${canonical_seed_targets[$i]}"
	if [[ -e "$target" || -L "$target" ]]; then
		continue
	fi
	ensure_directory "${target%/*}"
	undo_seeds+=("$target")
	cp -P "$source" "$target"
	chmod 600 "$target"
done

for ((i = 0; i < ${#empty_targets[@]}; i++)); do
	target="${canonical_empty_targets[$i]}"
	if [[ -e "$target" || -L "$target" ]]; then
		continue
	fi
	ensure_directory "${target%/*}"
	undo_seeds+=("$target")
	: > "$target"
	chmod 600 "$target"
done

mv -f "$ai_temp_file" "$ai_generated_file"
ai_temp_file=''

committed=true
trap - EXIT HUP INT TERM
if ! prune_managed_links; then
	printf 'Warning: some stale managed links could not be removed.\n' >&2
fi
write_managed_links
printf 'Configuration links point to %s\n' "$repo_dir"
if [[ -n "$backup_dir" ]]; then
	printf 'Backups stored under %s\n' "$backup_dir"
fi
