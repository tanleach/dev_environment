#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=scripts/common.sh
source "${DEV_ENV_COMMON:-$SCRIPT_DIR/common.sh}"

if (($#)); then
	die "Host mutation is intentionally not implemented yet; this command is read-only."
fi

info "Ubuntu host report (read-only)"

if [[ -r /etc/os-release ]]; then
	# shellcheck disable=SC1091
	source /etc/os-release
	printf 'OS:                  %s\n' "${PRETTY_NAME:-unknown}"
fi
printf 'Architecture:        %s\n' "$(uname -m)"
printf 'systemd:             %s\n' "$(systemctl is-system-running 2>/dev/null || true)"
printf 'login shell:         %s\n' "$(getent passwd "$(id -un)" | cut -d: -f7)"
printf 'docker group member: '
if id -nG | tr ' ' '\n' | grep -qx docker; then printf 'yes\n'; else printf 'no\n'; fi

if command -v docker >/dev/null 2>&1; then
	docker --version
	timeout 8 docker info --format 'Docker server: {{.ServerVersion}}' 2>/dev/null || warn "Docker daemon unavailable"
else
	printf 'Docker:              missing\n'
fi

if command -v nvidia-smi >/dev/null 2>&1; then
	nvidia-smi -L || warn "nvidia-smi failed"
else
	printf 'NVIDIA:              unavailable\n'
fi

if command -v nvidia-ctk >/dev/null 2>&1; then
	nvidia-ctk --version
else
	printf 'NVIDIA toolkit:      missing\n'
fi

printf '\nNo apt sources, drivers, services, groups, SSH, or firewall settings were changed.\n'
