#!/usr/bin/env bash

# migrate-mise-cleanup.bash — legacy tool cleanup for EXISTING machines
# ---------------------------------------------------------------------
# Part of the mise migration (pkg3). mise is now the developer-runtime
# owner (python, node, deno, uv, direnv, pi). This script removes legacy
# nvm / npm cache / uv cache / standalone uv / fnm artifacts on machines
# that predate the migration. New machines get no legacy cruft at all
# (see new.bash, which bootstraps mise only).
#
# SAFETY RULES (hard-coded):
#   * NEVER deletes: ~/.npmrc, project node_modules, virtualenvs,
#     uv-managed Python/data (~/.local/share/uv), rustup, brew node,
#     brew-global pi, or anything outside the explicit path list below.
#   * Refuses to run unless mise is installed AND fresh-shell `pi` and
#     `uv` already resolve to mise shims (proof the cutover is done).
#   * Default mode is DRY-RUN: prints the plan, deletes nothing.
#     Pass --apply to actually delete.
#   * Every deletion is path-bounded and idempotent; already-absent
#     targets are skipped.
#
# Usage:
#   bash migrate-mise-cleanup.bash           # dry-run (default)
#   bash migrate-mise-cleanup.bash --apply   # delete
#
# Checked paths:
#   ~/.nvm                          (nvm install dir; only if nvm-managed)
#   ~/.npm/_cacache _logs _npx      (npm cache/logs; other ~/.npm content NEVER)
#   ~/.cache/uv                     (uv download/build cache; NOT ~/.local/share/uv)
#   ~/.local/bin/uv ~/.local/bin/uvx (standalone astral binaries)
#   ~/.local/share/fnm              (fnm store; only if empty)
#   ~/.local/state/fnm_multishells  (stale fnm session symlinks)

set -eu

RESTORE=$(echo -en '\033[0m')
BLUE=$(echo -en '\033[01;34m')

fail() {
	echo "ERROR: $*" >&2
	echo "Aborting — nothing was deleted." >&2
	exit 1
}

info() {
	echo "${BLUE}$*${RESTORE}"
}

APPLY=false
MODE=''
for arg in "$@"; do
	if [[ "$arg" == "--apply" ]]; then
		[[ "$MODE" != dry-run ]] || fail "--apply and --dry-run cannot be combined"
		MODE=apply
		APPLY=true
	elif [[ "$arg" == "--dry-run" ]]; then
		[[ "$MODE" != apply ]] || fail "--apply and --dry-run cannot be combined"
		MODE=dry-run
		APPLY=false
	elif [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
		printf 'Usage: bash migrate-mise-cleanup.bash [--dry-run | --apply]\n'
		exit 0
	else
		fail "unknown argument: $arg (expected --apply or --dry-run)"
	fi
done

if [[ "$APPLY" == true ]]; then
	info "Mode: APPLY — deletions will be executed."
else
	info "Mode: DRY-RUN — plan only, nothing will be deleted (use --apply to delete)."
fi

# --- Precondition gate: mise cutover must already be in place ---------
command -v mise >/dev/null 2>&1 || fail "mise is not installed — nothing to clean up."

PI_RESOLUTION="$(zsh -c 'command -v pi' 2>/dev/null || true)"
UV_RESOLUTION="$(zsh -c 'command -v uv' 2>/dev/null || true)"
[[ "$PI_RESOLUTION" == *"/mise/shims/pi" ]] || fail "fresh-shell 'pi' does not resolve to a mise shim (got: '${PI_RESOLUTION:-unresolved}') — cutover not verified yet."
[[ "$UV_RESOLUTION" == *"/mise/shims/uv" ]] || fail "fresh-shell 'uv' does not resolve to a mise shim (got: '${UV_RESOLUTION:-unresolved}') — cutover not verified yet."
info "Preconditions OK: mise installed; fresh-shell pi -> $PI_RESOLUTION; uv -> $UV_RESOLUTION"

# --- Helpers ----------------------------------------------------------
remove() {
	# remove <path> <description>: dry-run prints; --apply deletes.
	local path="$1"
	local desc="$2"
	# Never follow a redirected cache/state parent outside the intended home.
	local parent
	parent="$(dirname "$path")"
	while [[ "$parent" != "$HOME" && "$parent" != / ]]; do
		[[ ! -L "$parent" ]] || fail "symlink parent refused: $parent"
		parent="$(dirname "$parent")"
	done
	if [[ ! -e "$path" && ! -L "$path" ]]; then
		echo "  - skip: $desc ($path already absent)"
		return 0
	fi
	if [[ "$APPLY" == true ]]; then
		rm -rf "$path"
		echo "  - removed: $desc ($path)"
	else
		echo "  - would remove: $desc ($path)"
	fi
}

# --- ~/.nvm ------------------------------------------------------------
NVM_DIR="$HOME/.nvm"
if [[ -d "$NVM_DIR" ]]; then
	if [[ -d "$NVM_DIR/versions/node" || -f "$NVM_DIR/nvm.sh" ]]; then
		remove "$NVM_DIR" "legacy nvm install dir (nvm-managed node versions)"
	else
		echo "  - skip: ~/.nvm exists but does not look nvm-managed — leaving it alone"
	fi
else
	echo "  - skip: legacy nvm (~/.nvm already absent)"
fi

# --- npm cache/log artifacts ------------------------------------------
# NEVER touch ~/.npmrc or anything that is not a known cache/log path.
NPM_CACHE_ARTIFACTS=(_cacache _logs _npx _update-notifier-last-checked)
if [[ -d "$HOME/.npm" ]]; then
	UNKNOWN=()
	for entry in "$HOME"/.npm/*; do
		base="$(basename "$entry")"
		known=false
		for known_name in "${NPM_CACHE_ARTIFACTS[@]}"; do
			[[ "$base" == "$known_name" ]] && known=true
		done
		[[ "$known" == true ]] || UNKNOWN+=("$base")
	done
	if [[ ${#UNKNOWN[@]} -gt 0 ]]; then
		echo "  - skip: ~/.npm contains non-cache entries — refusing to touch: ${UNKNOWN[*]}"
	else
		for artifact in "${NPM_CACHE_ARTIFACTS[@]}"; do
			remove "$HOME/.npm/$artifact" "npm cache/log artifact"
		done
	fi
else
	echo "  - skip: ~/.npm already absent"
fi

# --- uv cache (NOT uv-managed Python/data) -----------------------------
remove "$HOME/.cache/uv" "uv download/build cache"

# --- standalone uv binaries --------------------------------------------
remove "$HOME/.local/bin/uv" "standalone uv binary (mise shim verified)"
remove "$HOME/.local/bin/uvx" "standalone uvx binary (mise shim verified)"

# --- fnm store ---------------------------------------------------------
FNM_STORE="$HOME/.local/share/fnm"
if [[ -d "$FNM_STORE" ]]; then
	if [[ -z "$(ls -A "$FNM_STORE")" ]]; then # shellcheck disable=SC2012
		remove "$FNM_STORE" "empty fnm store"
	else
		echo "  - skip: ~/.local/share/fnm is not empty — leaving it alone"
	fi
else
	echo "  - skip: fnm store (~/.local/share/fnm already absent)"
fi

# --- stale fnm multishell session symlinks -----------------------------
FNM_MULTISHELLS="$HOME/.local/state/fnm_multishells"
if [[ -d "$FNM_MULTISHELLS" ]]; then
	if [[ -z "$(ls -A "$FNM_MULTISHELLS")" ]]; then # shellcheck disable=SC2012
		remove "$FNM_MULTISHELLS" "empty fnm multishells dir"
	else
		STALE=true
		for entry in "$FNM_MULTISHELLS"/*; do
			if [[ ! -L "$entry" ]]; then
				STALE=false
				echo "  - skip: $entry is not a symlink — leaving fnm_multishells alone"
				break
			fi
		done
		if [[ "$STALE" == true ]]; then
			remove "$FNM_MULTISHELLS" "stale fnm multishell session symlinks"
		fi
	fi
else
	echo "  - skip: fnm multishells (~/.local/state/fnm_multishells already absent)"
fi

echo ""
if [[ "$APPLY" == true ]]; then
	info "Done. Remember: ~/.npmrc, node_modules, virtualenvs, uv-managed data and rustup were never touched."
else
	info "Dry-run complete — nothing was deleted. Re-run with --apply to execute."
fi
