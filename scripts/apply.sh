#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=scripts/common.sh
source "${DEV_ENV_COMMON:-$SCRIPT_DIR/common.sh}"

check_only=0
skip_brew=0

usage() {
	cat <<'EOF'
Usage: dev-env-apply [--check] [--skip-brew] [--yes]

  --check       Build and report without activating Home Manager or installing Brew entries.
  --skip-brew   Do not check or install Brewfile entries.
  --yes         Skip the final interactive activation confirmation.
EOF
}

while (($#)); do
	case $1 in
	--check) check_only=1 ;;
	--skip-brew) skip_brew=1 ;;
	--yes) export DEV_ENV_ASSUME_YES=1 ;;
	-h | --help)
		usage
		exit 0
		;;
	*) die "Unknown argument: $1" ;;
	esac
	shift
done

source_nix_daemon
require_command nix

ROOT=$(resolve_live_root)
TARGET=${DEV_ENV_HOME_TARGET:-tleach@tleach-workstation}
BREWFILE="$ROOT/brew/Brewfile"

require_tracked_flake_source "$ROOT"

info "Preflight: $ROOT#$TARGET"
nix flake check "$ROOT"
generation=$(nix build "$ROOT#default" --no-link --print-out-paths)
printf 'Home Manager generation: %s\n' "$generation"

if ((skip_brew == 0)); then
	brew=$(brew_bin) || die "Homebrew is required at /home/linuxbrew/.linuxbrew"
	if HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_BUNDLE_NO_UPGRADE=1 \
		"$brew" bundle check --file "$BREWFILE"; then
		info "Brewfile already satisfied"
	elif ((check_only == 1)); then
		warn "Brewfile has missing entries"
	else
		HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_BUNDLE_NO_UPGRADE=1 \
			"$brew" bundle check --verbose --file "$BREWFILE" || true
		confirm "Install the missing Brewfile entries without upgrading or cleaning up?" ||
			die "Homebrew installation cancelled"
		info "Installing missing Brewfile entries (no cleanup, no broad upgrade)"
		HOMEBREW_NO_AUTO_UPDATE=1 \
			HOMEBREW_BUNDLE_NO_UPGRADE=1 \
			"$brew" bundle install --file "$BREWFILE" --no-upgrade
	fi
fi

if ((check_only == 1)); then
	info "Check complete; no Home Manager activation was performed"
	exit 0
fi

if ((skip_brew == 0)); then
	if [[ ${DEV_ENV_ASSUME_YES:-0} == 1 ]]; then
		info "Skipping optional Homebrew upgrade during non-interactive apply; run nix run .#brew-update -- --yes to upgrade declared entries."
	elif confirm "Run Homebrew update and upgrade declared Brewfile entries now?"; then
		brew_upgrade_declared "$brew" "$BREWFILE"
	else
		info "Skipping optional Homebrew upgrade"
	fi
fi

cat <<EOF

Home Manager will now take ownership of these reviewed paths:
  ~/.zshrc
  ~/.tmux.conf
  ~/.config/nvim
  ~/.config/herdr/config.toml
  pinned shell/tmux plugin paths

Existing entries will be moved into a timestamped backup under:
  ~/.local/state/dev_environment/backups/

Agent state/auth directories are not managed in this phase.
EOF

confirm "Activate this generation?" || die "Activation cancelled"

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
backup_dir="$HOME/.local/state/dev_environment/backups/$timestamp"
if [[ -e $backup_dir ]]; then
	backup_dir="${backup_dir}-$$"
fi
manifest="$backup_dir/manifest.tsv"

managed_paths=(
	"$HOME/.zshrc"
	"$HOME/.tmux.conf"
	"$HOME/.config/nvim"
	"$HOME/.config/herdr/config.toml"
	"$HOME/.local/share/oh-my-zsh"
	"$HOME/.local/share/oh-my-zsh-custom/plugins/zsh-syntax-highlighting"
	"$HOME/.tmux/plugins/tpm"
	"$HOME/.tmux/plugins/tmux-cpu"
	"$HOME/.config/tmux/plugins/catppuccin/tmux"
)

expected_targets=(
	"$ROOT/home/.config/zsh/.zshrc"
	"$ROOT/home/.config/tmux/tmux.conf"
	"$ROOT/home/.config/nvim"
	"$ROOT/home/.config/herdr/config.toml"
	""
	""
	""
	""
	""
)

backup_count=0
rollback_needed=0

rollback_on_exit() {
	local status=$?
	trap - EXIT

	if ((status != 0 && rollback_needed == 1)); then
		warn "Apply did not complete; restoring the pre-activation files."
		DEV_ENV_ASSUME_YES=1 bash "$ROOT/scripts/restore.sh" "$manifest" ||
			warn "Automatic restoration was incomplete; run: bash $ROOT/scripts/restore.sh $manifest"
	fi
	exit "$status"
}

for index in "${!managed_paths[@]}"; do
	path=${managed_paths[$index]}
	expected=${expected_targets[$index]}

	if [[ -e $path || -L $path ]]; then
		if [[ -L $path ]]; then
			raw_target=$(readlink "$path")
			resolved_target=$(readlink -f "$path" 2>/dev/null || true)
			if [[ -n $expected && $resolved_target == "$expected" ]] ||
				[[ $raw_target == *home-manager-files* ]]; then
				continue
			fi
		fi

		if ((backup_count == 0)); then
			mkdir -p "$backup_dir"
			{
				printf '# dev_environment backup manifest v1\n'
				printf '# created: %s\n' "$timestamp"
				printf '# restore: bash %q %q\n' "$ROOT/scripts/restore.sh" "$manifest"
			} >"$manifest"
		fi

		relative=${path#"$HOME"/}
		destination="$backup_dir/$relative"
		mkdir -p "$(dirname "$destination")"
		printf '%s\t%s\n' "$path" "$destination" >>"$manifest"
		rollback_needed=1
		trap rollback_on_exit EXIT
		mv "$path" "$destination"
		backup_count=$((backup_count + 1))
	fi
done

info "Activating Home Manager generation"
if ! "$generation/activate"; then
	warn "Home Manager activation failed."
	exit 1
fi
rollback_needed=0
trap - EXIT

info "Activation complete"
if ((backup_count > 0)); then
	printf 'Backup manifest: %s\n' "$manifest"
fi

bash "$ROOT/tests/smoke.sh"
