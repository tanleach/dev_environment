#!/usr/bin/env bash

set -euo pipefail

failures=0

check_command() {
	local command_name=$1
	if command -v "$command_name" >/dev/null 2>&1; then
		printf 'ok      %-18s %s\n' "$command_name" "$(command -v "$command_name")"
	else
		printf 'MISSING %-18s\n' "$command_name" >&2
		failures=$((failures + 1))
	fi
}

for command_name in \
	zsh git tmux nvim go gopls goimports gofumpt dlv golangci-lint \
	uv ruff basedpyright node gh glab lazygit opencode codex claude hermes herdr; do
	check_command "$command_name"
done

if command -v nvim >/dev/null 2>&1; then
	nvim --headless '+lua vim.print("nvim startup ok")' +qa
fi

if ((failures)); then
	printf '%d smoke check(s) failed.\n' "$failures" >&2
	exit 1
fi

printf 'All smoke checks passed.\n'
