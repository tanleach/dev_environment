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

brew_upgrade_declared() {
	local brew=$1
	local brewfile=$2

	"$brew" update
	"$brew" bundle install --file "$brewfile" --upgrade
	"$brew" bundle check --file "$brewfile"
	info "Homebrew update complete; cleanup was not run"
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

check_fresh_zsh_activation() {
	local root=$1
	local actual_zshrc
	local expected_zshrc
	local output
	local probe_dir
	local zsh_bin

	root=$(readlink -f "$root") || {
		warn "Unable to resolve the dev_environment repository: $1"
		return 1
	}
	expected_zshrc="$root/home/.config/zsh/.zshrc"
	actual_zshrc=$(readlink -f "$HOME/.zshrc" 2>/dev/null || true)
	if [[ $actual_zshrc != "$expected_zshrc" ]]; then
		warn "$HOME/.zshrc does not resolve to $expected_zshrc"
		return 1
	fi

	if [[ -x /usr/bin/zsh ]]; then
		zsh_bin=/usr/bin/zsh
	else
		zsh_bin=$(command -v zsh 2>/dev/null || true)
	fi
	if [[ -z $zsh_bin ]]; then
		warn "zsh is unavailable"
		return 1
	fi

	probe_dir=$(mktemp -d "${TMPDIR:-/tmp}/dev-environment-zsh.XXXXXX") || {
		warn "Unable to create a temporary directory for the zsh activation check"
		return 1
	}
	mkdir -p "$probe_dir/cache/oh-my-zsh"

	# The single-quoted program is evaluated by the isolated child zsh.
	# shellcheck disable=SC2016
	if ! output=$(
		env -i \
			HOME="$HOME" \
			USER="$(id -un)" \
			LOGNAME="$(id -un)" \
			SHELL="$zsh_bin" \
			TERM=dumb \
			PATH=/usr/bin:/bin \
			HISTFILE="$probe_dir/history" \
			XDG_CACHE_HOME="$probe_dir/cache" \
			ZSH_CACHE_DIR="$probe_dir/cache/oh-my-zsh" \
			ZSH_COMPDUMP="$probe_dir/zcompdump" \
			"$zsh_bin" -ic '
fail() {
  print -ru2 -- "$1"
  exit 1
}

expected_root=$1
[[ ${DEV_ENVIRONMENT_ACTIVE:-0} == 1 ]] || fail "DEV_ENVIRONMENT_ACTIVE is not set"
[[ -n ${DEV_ENVIRONMENT_ROOT:-} ]] || fail "DEV_ENVIRONMENT_ROOT is not set"
[[ ${DEV_ENVIRONMENT_ROOT:A} == ${expected_root:A} ]] || fail "DEV_ENVIRONMENT_ROOT points elsewhere"
[[ ${__HM_SESS_VARS_SOURCED:-0} == 1 ]] || fail "Home Manager session variables were not loaded"
[[ $EDITOR == nvim && $VISUAL == nvim ]] || fail "editor variables were not loaded"
[[ $ZSH == "$HOME/.local/share/oh-my-zsh" ]] || fail "the managed Oh My Zsh path was not loaded"
active_zshrc=$HOME/.zshrc
expected_zshrc=${expected_root:A}/home/.config/zsh/.zshrc
[[ ${active_zshrc:A} == ${expected_zshrc:A} ]] || fail "zsh loaded an unexpected startup file"
command -v nix >/dev/null 2>&1 || fail "nix is not on PATH"
command -v brew >/dev/null 2>&1 || fail "brew is not on PATH"
' dev-environment-zsh-check "$root" 2>&1
	); then
		warn "A fresh zsh did not activate the managed environment"
		[[ -z $output ]] || printf '%s\n' "$output" >&2
		rm -rf -- "$probe_dir"
		return 1
	fi

	# A shell started from a pre-apply parent can inherit Home Manager's guard and
	# skip re-sourcing its generated variables. The managed .zshrc must still set
	# the activation contract itself.
	# shellcheck disable=SC2016
	if ! output=$(
		env -i \
			HOME="$HOME" \
			USER="$(id -un)" \
			LOGNAME="$(id -un)" \
			SHELL="$zsh_bin" \
			TERM=dumb \
			PATH=/usr/bin:/bin \
			__HM_SESS_VARS_SOURCED=1 \
			HISTFILE="$probe_dir/history" \
			XDG_CACHE_HOME="$probe_dir/cache" \
			ZSH_CACHE_DIR="$probe_dir/cache/oh-my-zsh" \
			ZSH_COMPDUMP="$probe_dir/zcompdump" \
			"$zsh_bin" -ic '
expected_root=$1
[[ ${DEV_ENVIRONMENT_ACTIVE:-0} == 1 ]] || {
  print -ru2 -- "nested zsh did not set DEV_ENVIRONMENT_ACTIVE"
  exit 1
}
[[ -n ${DEV_ENVIRONMENT_ROOT:-} && ${DEV_ENVIRONMENT_ROOT:A} == ${expected_root:A} ]] || {
  print -ru2 -- "nested zsh did not set DEV_ENVIRONMENT_ROOT"
  exit 1
}
dev-env-status >/dev/null 2>&1 || {
  print -ru2 -- "dev-env-status did not confirm the nested zsh"
  exit 1
}
' dev-environment-nested-zsh-check "$root" 2>&1
	); then
		warn "A nested zsh did not refresh the managed activation contract"
		[[ -z $output ]] || printf '%s\n' "$output" >&2
		rm -rf -- "$probe_dir"
		return 1
	fi

	rm -rf -- "$probe_dir"
	printf 'fresh zsh: active (%s)\n' "$root"
}
