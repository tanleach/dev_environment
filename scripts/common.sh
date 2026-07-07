#!/usr/bin/env bash

set -euo pipefail

info() {
	printf '==> %s\n' "$*"
}

warn() {
	printf 'WARN: %s\n' "$*" >&2
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

confirm() {
	local prompt=$1
	local answer

	if [[ ${DEV_ENV_ASSUME_YES:-0} == 1 ]]; then
		return 0
	fi

	printf '%s [y/N] ' "$prompt" >&2
	read -r answer
	[[ $answer == y || $answer == Y || $answer == yes || $answer == YES ]]
}

resolve_live_root() {
	local script_root
	script_root=$(cd "$(dirname "${BASH_SOURCE[1]}")/.." 2>/dev/null && pwd -P || true)

	if [[ -n ${DEV_ENV_LIVE_ROOT:-} && -f ${DEV_ENV_LIVE_ROOT}/flake.nix ]]; then
		printf '%s\n' "$DEV_ENV_LIVE_ROOT"
	elif [[ -f "$HOME/.dev_environment/flake.nix" ]]; then
		readlink -f "$HOME/.dev_environment"
	elif [[ -n $script_root && -f $script_root/flake.nix ]]; then
		printf '%s\n' "$script_root"
	elif [[ -n ${DEV_ENV_SOURCE:-} && -f ${DEV_ENV_SOURCE}/flake.nix ]]; then
		printf '%s\n' "$DEV_ENV_SOURCE"
	else
		die "Unable to find the dev_environment repository. Set DEV_ENV_LIVE_ROOT."
	fi
}

brew_bin() {
	if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
		printf '%s\n' /home/linuxbrew/.linuxbrew/bin/brew
	elif command -v brew >/dev/null 2>&1; then
		command -v brew
	else
		return 1
	fi
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

untracked_flake_paths() {
	local root=$1

	git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
	git -C "$root" ls-files --others --exclude-standard -- \
		flake.nix flake.lock home.nix bootstrap-linux.sh rebuild.sh brew home scripts tests \
		2>/dev/null || true
}

require_tracked_flake_source() {
	local root=$1
	local untracked

	untracked=$(untracked_flake_paths "$root")
	if [[ -n $untracked ]]; then
		warn "Git-backed Nix flakes omit untracked source files:"
		printf '%s\n' "$untracked" | sed 's/^/  /' >&2
		die "Review and git-add these files before building; nothing was staged automatically."
	fi
}

source_nix_daemon() {
	if command -v nix >/dev/null 2>&1; then
		return 0
	fi

	if [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
		# shellcheck disable=SC1091
		source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
	fi
}
