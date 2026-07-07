#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=scripts/common.sh
source "${DEV_ENV_COMMON:-$SCRIPT_DIR/common.sh}"

usage() {
	cat <<'EOF'
Usage: dev-env-restore [--yes] MANIFEST

Restore paths recorded by a dev_environment apply backup manifest. Any current
entries at those paths are preserved beside the manifest before restoration.
EOF
}

if [[ ${1:-} == --yes ]]; then
	export DEV_ENV_ASSUME_YES=1
	shift
fi

[[ $# == 1 ]] || {
	usage >&2
	exit 2
}
manifest_input=$1
[[ -f $manifest_input ]] || die "Backup manifest not found: $manifest_input"
manifest=$(readlink -f "$manifest_input")

backup_root=$(dirname "$manifest")
entries=0
while IFS=$'\t' read -r original backup; do
	[[ -z $original || $original == \#* ]] && continue
	case $original in
	"$HOME"/*) ;;
	*) die "Manifest contains a path outside HOME: $original" ;;
	esac
	case $backup in
	"$backup_root"/*) ;;
	*) die "Manifest contains a backup outside its backup directory: $backup" ;;
	esac
	entries=$((entries + 1))
done <"$manifest"

((entries > 0)) || die "Manifest has no restorable entries: $manifest"
confirm "Restore $entries path(s) from $manifest?" || die "Restore cancelled"

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
displaced_root="$backup_root/displaced-$timestamp"
restored=0
failures=0

while IFS=$'\t' read -r original backup; do
	[[ -z $original || $original == \#* ]] && continue

	if [[ ! -e $backup && ! -L $backup ]]; then
		warn "Backup entry is missing: $backup"
		failures=$((failures + 1))
		continue
	fi

	if [[ -e $original || -L $original ]]; then
		relative=${original#"$HOME"/}
		displaced="$displaced_root/$relative"
		mkdir -p "$(dirname "$displaced")"
		mv "$original" "$displaced"
		printf 'preserved current: %s -> %s\n' "$original" "$displaced"
	fi

	mkdir -p "$(dirname "$original")"
	mv "$backup" "$original"
	printf 'restored:          %s\n' "$original"
	restored=$((restored + 1))
done <"$manifest"

printf 'Restored %d path(s).\n' "$restored"
if ((failures > 0)); then
	die "$failures backup entry or entries could not be restored"
fi
