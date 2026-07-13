#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=scripts/common.sh
source "${DEV_ENV_COMMON:-$SCRIPT_DIR/common.sh}"

source_nix_daemon

ROOT=$(resolve_live_root)
BREWFILE="$ROOT/brew/Brewfile"
warnings=0

section() {
	printf '\n-- %s --\n' "$1"
}

warning() {
	warn "$*"
	warnings=$((warnings + 1))
}

section "Host"
printf 'repository: %s\n' "$ROOT"
printf 'user:       %s\n' "$(id -un)"
printf 'home:       %s\n' "$HOME"
printf 'hostname:   %s\n' "$(hostname)"
printf 'kernel:     %s\n' "$(uname -srmo)"
if [[ -r /etc/os-release ]]; then
	# shellcheck disable=SC1091
	source /etc/os-release
	printf 'os:         %s\n' "${PRETTY_NAME:-unknown}"
fi

section "Core managers"
for command_name in nix brew zsh git; do
	if command -v "$command_name" >/dev/null 2>&1; then
		printf '%-12s %s\n' "$command_name" "$(command -v "$command_name")"
	else
		printf '%-12s MISSING\n' "$command_name"
		warning "$command_name is not installed or not on PATH"
	fi
done

section "Requested tools"
tools=(
	nvim tmux go gopls goimports gofumpt dlv golangci-lint
	uv ruff basedpyright debugpy tree-sitter node gh glab lazygit
	opencode codex claude hermes herdr
)
for command_name in "${tools[@]}"; do
	if command -v "$command_name" >/dev/null 2>&1; then
		printf '%-16s %s\n' "$command_name" "$(command -v "$command_name")"
	else
		printf '%-16s MISSING\n' "$command_name"
	fi
done

section "Shadowed commands"
for command_name in git go node python3 uv gh glab opencode codex claude hermes; do
	paths=$(
		type -a -p "$command_name" 2>/dev/null |
			while IFS= read -r command_path; do readlink -f "$command_path"; done |
			awk '!seen[$0]++' ||
			true
	)
	count=$(printf '%s\n' "$paths" | sed '/^$/d' | wc -l)
	if ((count > 1)); then
		printf '%s:\n%s\n' "$command_name" "$paths" | sed '2,$s/^/  /'
	fi
done

section "Managed links"
for path in "$HOME/.zshrc" "$HOME/.tmux.conf" "$HOME/.config/nvim" "$HOME/.config/herdr/config.toml"; do
	if [[ -L $path ]]; then
		printf '%s -> %s\n' "$path" "$(readlink -f "$path")"
	elif [[ -e $path ]]; then
		printf '%s (existing, unmanaged)\n' "$path"
	else
		printf '%s (missing)\n' "$path"
	fi
done

section "Shell activation"
if ! check_fresh_zsh_activation "$ROOT"; then
	warning "Automatic dev_environment activation is not healthy; run $ROOT/rebuild.sh and start a new zsh"
fi

section "State safety"
for path in "$HOME/.claude" "$HOME/.codex" "$HOME/.config/opencode" "$HOME/.hermes"; do
	if [[ -d $path ]]; then
		printf 'preserve: %s\n' "$path"
	fi
done

secret_file="$HOME/.config/dev_environment/secrets.env"
if [[ -e $secret_file ]]; then
	mode=$(stat -c '%a' "$secret_file")
	printf 'secrets:    %s (mode %s)\n' "$secret_file" "$mode"
	[[ $mode == 600 ]] || warning "$secret_file should have mode 0600"
elif [[ -e $HOME/.envStuff ]]; then
	warning "Legacy ~/.envStuff exists; migrate it to $secret_file before retiring the old setup"
else
	printf 'secrets:    not configured\n'
fi

harness_repo="$HOME/Documents/github/coding_harnesses"
if [[ -d $harness_repo ]]; then
	printf 'harness:    %s\n' "$harness_repo"
else
	warning "Optional coding_harnesses repo is missing at $harness_repo"
fi

section "Homebrew inventory"
if brew=$(brew_bin); then
	if HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_BUNDLE_NO_UPGRADE=1 \
		"$brew" bundle check --file "$BREWFILE"; then
		printf 'Brewfile:   satisfied\n'
	else
		HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_BUNDLE_NO_UPGRADE=1 \
			"$brew" bundle check --verbose --file "$BREWFILE" || true
		warning "Brewfile has missing entries; apply will install without cleanup or broad upgrades"
	fi
else
	warning "Homebrew is unavailable"
fi

section "Host services (read-only)"
if command -v docker >/dev/null 2>&1; then
	if timeout 8 docker info --format 'docker:     server {{.ServerVersion}}' 2>/dev/null; then
		:
	else
		warning "Docker CLI exists but daemon access failed"
	fi
else
	printf 'docker:     missing\n'
fi

if command -v nvidia-smi >/dev/null 2>&1; then
	nvidia-smi -L 2>/dev/null | sed 's/^/nvidia:     /' || warning "nvidia-smi failed"
else
	printf 'nvidia:     unavailable\n'
fi

section "Repository"
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	git -C "$ROOT" status --short
	untracked=$(untracked_flake_paths "$ROOT")
	if [[ -n $untracked ]]; then
		warning "Required flake source files are untracked and will be omitted by Git-backed Nix flakes"
	fi
fi

printf '\nDoctor completed with %d warning(s). No changes were made.\n' "$warnings"
