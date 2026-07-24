# dev_environment — Agent Instructions

Declarative Ubuntu workstation managed by Nix flakes + Home Manager + Homebrew.
Not a NixOS migration. Nix coexists with the Ubuntu distribution.

## Quick commands

| Task | Command |
| --- | --- |
| Preview (no changes) | `./rebuild.sh --check` or `nix run .#doctor` |
| Apply (interactive) | `./rebuild.sh` |
| Apply (non-interactive) | `./rebuild.sh --yes` |
| Brew update only | `nix run .#brew-update` |
| Host report (read-only) | `nix run .#host-ubuntu` |
| Rollback HM | `home-manager generations` |
| Restore from backup | `nix run .#restore -- ~/.local/state/dev_environment/backups/<ts>/manifest.tsv` |
| Verify activation | `dev-env-status` |

## Architecture

- **flake.nix** — pins nixpkgs (nixos-26.05) + Home Manager (release-26.05), defines workstation identity, exposes all flake apps.
- **home.nix** — Home Manager config; out-of-store symlinks from `home/` to `~/.config/*`.
- **brew/Brewfile** — single authoritative Brew package list; hand-readable, never auto-generated.
- **home/** — actual config files (`zsh/`, `tmux/`, `nvim/`, `herdr/`) linked live via `~/.dev_environment`.
- **scripts/** — `apply.sh`, `doctor.sh`, `brew-update.sh`, `host-ubuntu.sh`, `restore.sh`, `common.sh`.
- **tests/smoke.sh** — post-apply command + Neovim + zsh activation checks.
- **~/.dev_environment** — stable symlink → active checkout. Home Manager resolves out-of-store links through this.

## Workflow and order

1. Edit source files in the repo checkout.
2. **Stage/commit changes** — Git-backed flakes omit untracked files; `nix flake check` will fail silently on missing modules.
3. `./rebuild.sh --check` — builds the Home Manager generation without activating.
4. `./rebuild.sh` — applies: flake check → HM build → Brew reconcile/upgrade → HM switch → smoke tests.
5. `nix run .#doctor` — read-only diagnostics (PATH, tools, activation, state safety).

`rebuild.sh` is a thin wrapper around `nix run .#apply`. `--check`, `--skip-brew`, and `--yes` pass through.

## CI

GitHub Actions runs on push/PR to `main`:
- `nix flake check --print-build-logs`
- `statix check .` / `deadnix --fail .` / `nixfmt --check` (Nix style)
- `shfmt -d` on shell scripts, `stylua --check` on Neovim Lua

CI is pure: no Homebrew, sudo, credentials, or `~/.dev_environment` required.

## Formatting tools

| Language | Formatter | Check command |
| --- | --- | --- |
| Nix | nixfmt | `nixfmt --check flake.nix home.nix` |
| Shell | shfmt | `shfmt -d bootstrap-linux.sh rebuild.sh scripts tests` |
| Lua (nvim) | stylua | `stylua --check home/.config/nvim` |
| Nix lint | statix + deadnix | `statix check .` / `deadnix --fail .` |

All tools available via `nix develop`.

## Critical constraints

- **Never place credentials, tokens, session DBs, private keys, or agent state in the repo or Nix store.**
- **`manageAgentConfig = false`** in flake.nix — `~/.claude`, `~/.codex`, `~/.config/opencode`, `~/.hermes` are NOT managed by Home Manager. Preserve them intact.
- **`brew/Brewfile` is authoritative for workstation tools.** Normal rebuilds upgrade declared entries, and managed Zsh keeps their executables ahead of alternate user-local installers.
- **Homebrew is not rollbackable via Nix generations.** Brew changes are separate from HM activation.
- **`~/.zshrc` is managed** by Home Manager via out-of-store symlink. Every new Zsh loads the managed env automatically.
- **`home.stateVersion = "26.05"`** — set once, do not bump.
- **`nix develop`** is for repo-maintenance tools only; normal shell does NOT enter the flake dev shell on startup.
- **Secrets** live in `~/.config/dev_environment/secrets.env` (mode 0600), never in derivations or Git.
- **`PLAN.md`** is the architectural intent — update it when implementation decisions change materially.
- **`host-ubuntu`** is read-only; it does not mutate apt, Docker, NVIDIA, SSH, UFW, or user groups.
- **Backups** go to `~/.local/state/dev_environment/backups/` with a manifest and restore command.

## Ownership model

| Owner | What |
| --- | --- |
| Nix flake | Input pins, flake apps, checks, dev shell |
| Home Manager | Zsh, tmux, Neovim, Herdr config, env vars, fonts, direnv |
| Homebrew + Brewfile | Go, Python tooling, AI CLIs, git CLIs, CLI utilities |
| Ubuntu host | Docker, NVIDIA runtime, SSH, groups (explicit, opt-in) |
| Project-local | Per-project deps (`go.mod`, `uv.lock`, Node lockfiles) |
