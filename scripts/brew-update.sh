#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=scripts/common.sh
source "${DEV_ENV_COMMON:-$SCRIPT_DIR/common.sh}"

if [[ ${1:-} == --yes ]]; then
	export DEV_ENV_ASSUME_YES=1
elif (($#)); then
	die "Usage: dev-env-brew-update [--yes]"
fi

ROOT=$(resolve_live_root)
brew=$(brew_bin) || die "Homebrew is not installed"

confirm "Run explicit Homebrew update and upgrade for declared entries?" || die "Update cancelled"

"$brew" update
"$brew" bundle install --file "$ROOT/brew/Brewfile" --upgrade
"$brew" bundle check --file "$ROOT/brew/Brewfile"

info "Homebrew update complete; cleanup was not run"
