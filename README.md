# dev_environment

Declarative Ubuntu development environment managed through Nix, Home Manager,
and Linuxbrew.

The implementation is being built from [PLAN.md](PLAN.md). It is adoption-first:
existing Docker/NVIDIA services, credentials, agent sessions, and mutable state
are not replaced by the default workflow.

## Current status

The first implementation slice now contains:

- a pinned Nix/Home Manager flake for `tleach@tleach-workstation`;
- a reviewed Homebrew inventory for Go, Python, GitHub/GitLab, Neovim, and AI CLIs;
- read-only diagnostics and host reporting;
- familiar Zsh and tmux configuration with pinned plugins;
- Neovim 0.12 configuration using `lazy.nvim` and a checked-in plugin lockfile;
- Go/Python LSP, formatting, linting, and Delve/debugpy adapters;
- Herdr configuration aligned with the tmux keymap;
- build, shell, Brewfile, and CI checks.

Nix is installed, `flake.lock` has been generated and reviewed, and the complete
flake/Home Manager build passes. The Brewfile and Home Manager generation are
applied, all declared CLIs pass smoke checks, and Neovim starts with its locked
plugin set. Commit the staged source and lockfile before treating this setup as a
reproducible baseline.

## Safe preview

Before installing or activating anything:

```bash
./bootstrap-linux.sh --check
```

After Nix is installed and `flake.lock` exists:

```bash
nix run .#doctor
nix flake check
./rebuild.sh --check
```

These commands do not activate Home Manager. `doctor` and `host-ubuntu` are
read-only.

## First setup

Review `PLAN.md`, `brew/Brewfile`, `home.nix`, and the files under `home/`.
Git-backed flakes omit untracked files, so stage or commit the reviewed source
before bootstrap; the scripts never do this for you.

```bash
git add .github .gitignore AGENTS.md README.md PLAN.md \
  flake.nix home.nix bootstrap-linux.sh rebuild.sh brew home scripts tests
./bootstrap-linux.sh
```

On the first run, bootstrap installs or adopts Nix and Homebrew, generates
`flake.lock`, and pauses before package installation or activation. Review and
stage the lock, then rerun:

```bash
git diff -- flake.lock
git add flake.lock
./bootstrap-linux.sh
```

The bootstrap verifies checksummed, version-pinned Nix and Homebrew installers.
It reuses existing installations, creates `~/.dev_environment`, builds before
activation, installs missing Brew entries without cleanup or broad upgrades,
and asks before Home Manager takes ownership of dotfiles.

Existing managed paths are moved to timestamped backups under:

```text
~/.local/state/dev_environment/backups/
```

Every backup contains a manifest and exact restore command. It can also be run
directly with:

```bash
nix run .#restore -- ~/.local/state/dev_environment/backups/<timestamp>/manifest.tsv
```

If Home Manager activation fails, the apply command invokes this restoration
automatically and preserves any partially activated entries beside the manifest.

Agent configuration management is disabled initially so existing authentication,
sessions, histories, and memories remain untouched.

## Daily workflow

```bash
./rebuild.sh --check     # build/preview
./rebuild.sh             # confirm and apply
nix run .#doctor         # diagnose PATH, missing tools, and state ownership
nix run .#brew-update    # explicit update; never performs cleanup
```

Host services are deliberately separate:

```bash
nix run .#host-ubuntu
```

That command currently reports Ubuntu, Docker, and NVIDIA state without changing
apt, drivers, services, groups, SSH, or firewall settings.
