#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
export DEV_ENV_LIVE_ROOT=$ROOT

if ! command -v nix >/dev/null 2>&1 && [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
	# shellcheck disable=SC1091
	source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

command -v nix >/dev/null 2>&1 || {
	printf 'Nix is not installed. Run ./bootstrap-linux.sh first.\n' >&2
	exit 1
}

exec nix run "$ROOT#apply" -- "$@"
