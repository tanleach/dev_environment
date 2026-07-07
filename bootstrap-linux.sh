#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
EXPECTED_USER=tleach
EXPECTED_HOME=/home/tleach
NIX_INSTALLER_VERSION=v3.19.0
NIX_INSTALLER_URL="https://raw.githubusercontent.com/DeterminateSystems/nix-installer/${NIX_INSTALLER_VERSION}/nix-installer.sh"
NIX_INSTALLER_SHA256=cd5c4f80c7b20e0a4232b45c970de04d9b59484873cf933183bfa3547be2e64c
HOMEBREW_INSTALL_COMMIT=16be749c00897e40ecbf09e21f7f258706961b7b
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALL_COMMIT}/install.sh"
HOMEBREW_INSTALL_SHA256=99287f194a8b3c9e6b0203a11a5fa54518be57209343e6bb954dec4635796d9d

check_only=0
run_host_report=0
assume_yes=0

usage() {
	cat <<'EOF'
Usage: ./bootstrap-linux.sh [--check] [--host] [--repo PATH] [--no-brew-upgrade] [--yes]

  --check       Report prerequisites without changing the machine.
  --host        Run the read-only Ubuntu/Docker/NVIDIA report after setup.
  --repo PATH   Use another checked-out dev_environment repository.
  --no-brew-upgrade
                Compatibility flag; missing-only installs are already the default.
  --yes         Use non-interactive installers and skip the final apply prompt.
EOF
}

while (($#)); do
	case $1 in
	--check) check_only=1 ;;
	--host) run_host_report=1 ;;
	--repo)
		(($# >= 2)) || {
			printf '%s\n' '--repo requires a path' >&2
			exit 2
		}
		ROOT=$(readlink -f "$2")
		shift
		;;
	--no-brew-upgrade) : ;;
	--yes) assume_yes=1 ;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		printf 'Unknown argument: %s\n' "$1" >&2
		usage >&2
		exit 2
		;;
	esac
	shift
done

info() {
	printf '==> %s\n' "$*"
}

confirm() {
	local prompt=$1
	local answer
	if ((assume_yes)); then return 0; fi
	printf '%s [y/N] ' "$prompt" >&2
	read -r answer
	[[ $answer == y || $answer == Y || $answer == yes || $answer == YES ]]
}

download_verified() {
	local url=$1
	local expected=$2
	local destination=$3

	curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
		"$url" --output "$destination"
	printf '%s  %s\n' "$expected" "$destination" | sha256sum --check --status || {
		printf 'Checksum verification failed for %s\n' "$url" >&2
		return 1
	}
}

[[ $(id -u) -ne 0 ]] || {
	printf 'Run this script as the target user, not root. It will request sudo when needed.\n' >&2
	exit 1
}

[[ -f $ROOT/flake.nix && -f $ROOT/home.nix ]] || {
	printf 'Not a dev_environment checkout: %s\n' "$ROOT" >&2
	exit 1
}

[[ $(id -un) == "$EXPECTED_USER" ]] || {
	printf 'Configured user is %s, but current user is %s. Update flake.nix intentionally.\n' \
		"$EXPECTED_USER" "$(id -un)" >&2
	exit 1
}

[[ $HOME == "$EXPECTED_HOME" ]] || {
	printf 'Configured home is %s, but current HOME is %s. Update flake.nix intentionally.\n' \
		"$EXPECTED_HOME" "$HOME" >&2
	exit 1
}

architecture=$(uname -m)
[[ $architecture == x86_64 ]] || {
	printf 'Configured architecture is x86_64, but detected %s. Update flake.nix intentionally.\n' \
		"$architecture" >&2
	exit 1
}

command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]] || {
	printf 'This bootstrap expects an Ubuntu workstation running systemd.\n' >&2
	exit 1
}

if [[ -r /etc/os-release ]]; then
	# shellcheck disable=SC1091
	source /etc/os-release
	[[ ${ID:-} == ubuntu || ${ID_LIKE:-} == *ubuntu* || ${ID_LIKE:-} == *debian* ]] || {
		printf 'This bootstrap currently supports Ubuntu-compatible Linux only.\n' >&2
		exit 1
	}
fi

info "Detected workstation"
printf 'user:                %s\n' "$(id -un)"
printf 'home:                %s\n' "$HOME"
printf 'repository:          %s\n' "$ROOT"
printf 'architecture:        %s\n' "$architecture"
printf 'systemd:             yes\n'
if [[ -n ${SUDO_USER:-} ]]; then
	printf 'invoked via sudo by: %s (continuing as %s)\n' "$SUDO_USER" "$(id -un)"
else
	printf 'invoked via sudo:    no\n'
fi

untracked_flake_paths() {
	git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
	git -C "$ROOT" ls-files --others --exclude-standard -- \
		flake.nix flake.lock home.nix bootstrap-linux.sh rebuild.sh brew home scripts tests \
		2>/dev/null || true
}

info "Checking bootstrap prerequisites"
packages=(ca-certificates curl git build-essential procps file)
missing_packages=()
for package in "${packages[@]}"; do
	dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed' ||
		missing_packages+=("$package")
done

if ((${#missing_packages[@]})); then
	printf 'Missing apt packages: %s\n' "${missing_packages[*]}"
	if ((check_only)); then
		:
	elif confirm "Install the missing bootstrap packages with apt?"; then
		sudo apt-get update
		sudo apt-get install -y "${missing_packages[@]}"
	else
		printf 'Bootstrap prerequisites were declined.\n' >&2
		exit 1
	fi
else
	printf 'Bootstrap apt prerequisites are already installed.\n'
fi

if ((check_only)); then
	export DEV_ENV_LIVE_ROOT=$ROOT
	bash "$ROOT/scripts/doctor.sh"
	exit 0
fi

untracked=$(untracked_flake_paths)
if [[ -n $untracked ]]; then
	printf 'Git-backed Nix flakes omit these untracked source files:\n' >&2
	printf '%s\n' "$untracked" | sed 's/^/  /' >&2
	printf 'Review and git-add them, then rerun bootstrap. Nothing was staged automatically.\n' >&2
	exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

info "Checking Nix"
if ! command -v nix >/dev/null 2>&1; then
	download_verified "$NIX_INSTALLER_URL" "$NIX_INSTALLER_SHA256" "$tmp_dir/nix-installer.sh"
	installer_args=(install)
	if ((assume_yes)); then installer_args+=(--no-confirm); fi
	sh "$tmp_dir/nix-installer.sh" "${installer_args[@]}"
	# shellcheck disable=SC1091
	source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
	printf 'Nix already installed: %s\n' "$(nix --version)"
fi

info "Checking Homebrew"
if [[ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
	download_verified "$HOMEBREW_INSTALL_URL" "$HOMEBREW_INSTALL_SHA256" "$tmp_dir/homebrew-install.sh"
	if ((assume_yes)); then
		NONINTERACTIVE=1 bash "$tmp_dir/homebrew-install.sh"
	else
		bash "$tmp_dir/homebrew-install.sh"
	fi
else
	printf 'Homebrew already installed: %s\n' "$(/home/linuxbrew/.linuxbrew/bin/brew --version | head -1)"
fi

stable_link="$HOME/.dev_environment"
if [[ -e $stable_link && ! -L $stable_link ]]; then
	printf '%s exists and is not a symlink; move it before continuing.\n' "$stable_link" >&2
	exit 1
fi
if [[ -L $stable_link && $(readlink -f "$stable_link") != "$ROOT" ]]; then
	confirm "Repoint $stable_link to $ROOT?" || {
		printf 'Stable link update declined.\n' >&2
		exit 1
	}
fi
ln -sfn "$ROOT" "$stable_link"

if [[ ! -f $ROOT/flake.lock ]]; then
	info "Generating the initial flake.lock"
	nix flake lock "$ROOT"
	printf "Generated %s. Review it, run 'git add flake.lock', and rerun bootstrap.\n" \
		"$ROOT/flake.lock"
	printf 'No Homebrew packages or Home Manager files have been applied yet.\n'
	exit 3
fi

export DEV_ENV_LIVE_ROOT=$ROOT
apply_args=()
if ((assume_yes)); then apply_args+=(--yes); fi
bash "$ROOT/rebuild.sh" "${apply_args[@]}"

if ((run_host_report)); then
	nix run "$ROOT#host-ubuntu"
fi

nix run "$ROOT#doctor"

cat <<'EOF'

Manual sign-in checks (credentials remain outside this repository):
  gh auth status       # use `gh auth login` if needed
  glab auth status     # use `glab auth login` if needed
  opencode --version
  codex --version
  claude --version
  hermes --version
  herdr --version
EOF

info "Bootstrap complete"
