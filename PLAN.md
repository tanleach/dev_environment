# Linux Workstation: Nix Environment Plan

## Status

Implementation started. The first source-only slice now includes the flake/Home
Manager foundation, safe lifecycle scripts, Brewfile, familiar shell/tmux config,
Neovim with `lazy.nvim`, Herdr keybindings, activation rollback, and CI checks.
Nix is installed, `flake.lock` is generated and reviewed, and the complete flake
check passes. The Brewfile and Home Manager generation are applied, command and
Neovim smoke checks pass, and the staged source still needs to be committed
before this is a reproducible baseline.

## Goals

- Keep Ubuntu/Linux and the current terminal workflow familiar.
- Make this repository the declarative source of truth.
- Use one Nix command to build, apply, check, update, and diagnose the setup.
- Use Homebrew for as many user-facing tools as is practical on Linux.
- Move from Vim to Neovim without changing every keybinding and habit at once.
- Support Go, Python, containers, GPU development, and several AI coding agents.
- Preserve the shared configuration in `~/Documents/github/coding_harnesses`.
- Keep credentials, sessions, caches, histories, and machine-local secrets out of Git.

## Scope and assumptions

- The first target is the current Ubuntu 24.04.4 LTS, `x86_64-linux`,
  systemd-based workstation.
- This is **not** a NixOS migration. Nix will coexist with the Linux distribution.
- Nix flakes and Home Manager will be the configuration/orchestration layer.
- Homebrew on Linux will remain at its supported prefix,
  `/home/linuxbrew/.linuxbrew`.
- A small privileged host layer is unavoidable on non-NixOS Linux. It will manage
  Docker Engine, the NVIDIA Container Toolkit, login shells, SSH, apt sources,
  user groups, and systemd services. It will be explicit and narrowly scoped.
- This is a managed workstation, so host work is adoption-first: detect healthy
  services and packages, leave them alone, and install or change only explicitly
  selected missing components. NVIDIA display drivers are always out of scope.

### Observed starting point (2026-07-07)

This snapshot informs migration logic; it is not automatically the desired final
inventory.

| Area | Current state |
| --- | --- |
| Nix | Not installed |
| Homebrew | Installed at `/home/linuxbrew/.linuxbrew` |
| Shell | `/usr/bin/zsh`; `.zshrc` still links into `server_setup` |
| Terminal session | Currently inside tmux; outer terminal still needs confirmation |
| Docker/GPU | Docker, NVIDIA tooling, and docker-group access already exist |
| AI CLIs | OpenCode and Codex from Brew; Claude and Hermes under `~/.local/bin`; Herdr absent |
| Git forges | `gh` from Ubuntu; `glab` from Brew |
| Languages | Go from Brew; Node from NVM; Bun and uv are user-local |
| Editor | Vim is installed and linked to `server_setup`; Neovim is absent |
| Other Brew leaves | Vault, OpenShift CLI, Signal CLI, pipx, GCC, and lazygit |

The first implementation must adopt this state without deleting auth data,
rewriting working Docker/NVIDIA configuration, or breaking the current shell.

## Reference design

The setup is inspired by
[`kunchenguid/dotfiles`](https://github.com/kunchenguid/dotfiles), which is the
repository demonstrated in the reference video. We will carry over these ideas:

- one repository and one normal apply command;
- a deliberately small first bootstrap;
- one canonical user/home setting threaded through the flake;
- a stable `~/.dev_environment` symlink to the active checkout;
- Home Manager out-of-store symlinks for configuration edited live in the repo;
- a persistent Zsh environment with an exported activation marker, a
  `dev-env-status` command, and a clean-environment fresh-shell regression
  check;
- an explicit repository-maintenance `nix develop` shell rather than evaluating
  or entering a flake during every interactive Zsh startup;
- a small Lua Neovim setup using `lazy.nvim`, not a full editor distribution;
- one reviewed agent-policy source linked into Claude, Codex, and OpenCode;
- an explicit build/check path that does not activate changes.

We will not copy its Mac-specific `nix-darwin` or `nix-homebrew` modules. We will
also not copy destructive Homebrew `zap` cleanup, hard-coded macOS paths, or
aliases that disable Claude/Codex safety checks. Linux Homebrew and privileged
Ubuntu services need their own explicit lifecycle and rollback boundaries.

## Proposed ownership model

| Owner | Responsibilities | Examples |
| --- | --- | --- |
| Nix flake | Pins inputs and exposes all supported commands | nixpkgs, Home Manager, checks, `apply`, `doctor` |
| Home Manager | User configuration and files | Zsh, environment variables, aliases, tmux config, Neovim config, Git config, harness symlinks |
| Homebrew + checked-in Brewfile | Most frequently updated user CLI programs | Go, uv, GitHub CLI, jq, bat, ripgrep, fzf, lazygit, OpenCode |
| Vendor-managed fallback, invoked explicitly | Recovery path when a current Brew package is unavailable or fails required features | Claude, Codex, Hermes, or OpenCode only after a documented Brew check fails |
| Ubuntu host module | Root-owned packages and services | Docker, NVIDIA runtime, SSH, `/etc/shells`, docker group |
| Project-local tooling | Per-project dependencies and versions | `uv.lock`, Go modules/toolchains, Node project lockfiles |

The phrase “Nix does everything” will mean that Nix is the front door: the user
runs a flake app such as `nix run .#apply`, and that app applies Home Manager and
the declared Brewfile in a deliberate order. Homebrew will not be hidden inside
a Home Manager activation hook. Keeping it as an explicit apply step prevents a
routine Home Manager switch from unexpectedly downloading or upgrading mutable
Homebrew packages, and makes the non-rollbackable Brew portion visible.

Avoid ad-hoc `nix profile install` and global npm/pip installs. Every persistent
tool must have one declared owner, while project dependencies stay in project
lock files.

## Proposed repository layout

Start compact, like the reference repository, and split modules only when the
top-level files become difficult to review. The initial layout should be:

```text
.
├── README.md
├── PLAN.md
├── AGENTS.md                     # instructions for working in this repo
├── flake.nix
├── flake.lock
├── bootstrap-linux.sh             # the only curl/shell bootstrap entrypoint
├── rebuild.sh                     # familiar daily apply wrapper
├── home.nix                       # Home Manager user config and links
├── .gitignore                     # result links, local overrides, caches, secrets
├── brew/
│   └── Brewfile                   # Brew packages/taps, readable without Nix
├── home/
│   ├── AGENTS.md                  # shared, reviewed agent policy
│   ├── .config/zsh/
│   ├── .config/tmux/
│   ├── .config/nvim/              # small Lua + lazy.nvim config
│   └── .config/herdr/
├── scripts/
│   ├── apply.sh                   # preflight/build, Brew, HM switch, smoke tests
│   ├── doctor.sh                  # read-only diagnostics
│   └── host-ubuntu.sh             # privileged Docker/NVIDIA/SSH system work
├── tests/
│   ├── flake-checks.nix
│   └── smoke.sh
└── .github/workflows/check.yml    # Linux flake, shell, and formatting checks
```

If `home.nix` grows beyond a comfortable review size, move coherent sections to
`nix/modules/{shell,tmux,neovim,ai-tools,links}.nix`. Do not create that module
tree before it is useful.

`brew/Brewfile` is the single authoritative Brew package list and must remain
hand-readable. Flake checks may validate it, but must not duplicate or generate a
second package list.

The flake should define the username, home directory, hostname label, and system
once, then pass them into Home Manager. Pin nixpkgs and Home Manager to matching
stable branches and lock exact revisions in `flake.lock`. Set
`home.stateVersion` once during implementation and do not bump it as an update
ritual.

## Initial setup script

The proposed `bootstrap-linux.sh` is the only imperative entrypoint needed on a
fresh Linux machine. It must be short, readable, idempotent, and safe to run a
second time.

### Responsibilities

1. Detect Linux distribution, architecture, current user, home directory,
   systemd availability, and whether the script is running through `sudo`.
2. Refuse root as the target workstation user and print the detected plan before
   changing anything.
3. Verify bootstrap-level Ubuntu prerequisites and install only missing ones with
   explicit sudo approval:
   `ca-certificates`, `curl`, `git`, `build-essential`, `procps`, and `file`.
4. Install Nix with a pinned, checksum-verified installer release. Enable flakes
   and the systemd Nix daemon. Do not silently replace an existing healthy Nix.
5. Source the Nix daemon environment for the remainder of the script.
6. Adopt the existing Homebrew at `/home/linuxbrew/.linuxbrew`; on a genuinely
   fresh host, install it only if absent. Pin or checksum the installer input and
   show any privileged directory creation step.
7. Clone this repo if it is missing, or use the current checkout if run from it.
   Never pull over a dirty working tree.
8. Symlink the active checkout to `~/.dev_environment` before the first build.
   Home Manager out-of-store links will resolve through this stable path, so the
   configuration does not depend on where the repository was cloned.
9. Compare the single configured username/home setting with the actual user and
   stop with a clear correction if they differ. Do not rewrite Nix files silently.
10. Run `nix flake check`, then `nix run .#apply`.
11. Offer the privileged Ubuntu host step separately and opt-in:
   `nix run .#host-ubuntu`. It starts with a read-only report and must show each
   proposed Docker/NVIDIA, SSH, group, apt-source, or service change before sudo.
   Healthy existing Docker/NVIDIA installations produce no changes.
12. Run `nix run .#doctor` and print manual authentication/setup tasks for the AI
    tools. Authentication is never scripted or stored in this repo.

### Required flags and safety behavior

- `--check`: report what is installed or missing without changing the machine.
- `--host`: opt into missing host-package/service work; the default is user-only.
- `--repo PATH`: apply an existing checkout from a non-default location.
- Brew upgrades must remain opt-in: either `nix run .#brew-update`, the separate
  interactive prompt during apply, or the explicit `--upgrade-brew` apply flag.
  Non-interactive apply must not upgrade Brew without `--upgrade-brew`.
- Back up pre-existing unmanaged dotfiles before Home Manager takes ownership.
- Write a backup manifest with original paths and restoration commands. Use Home
  Manager's backup behavior for collisions; never use blanket forced links.
- Never run `brew` as root.
- Never pipe an unpinned moving installer directly to a shell in the final form.
- Stop on the first failed stage and print the exact recovery command.
- Never replace an entire `~/.claude`, `~/.codex`, `~/.config/opencode`, or
  `~/.hermes` directory. Manage only reviewed durable files and preserve auth,
  sessions, databases, logs, caches, memories, and generated state.
- Warn when required flake files are untracked, because Git-backed flakes omit
  untracked files. Do not stage or commit them automatically.
- Respect existing proxy and certificate settings on the managed workstation;
  diagnose access to Nix, GitHub, Homebrew, and vendor endpoints without storing
  proxy credentials or private CA material in Git or the Nix store.

### Normal fresh-machine flow

```text
./bootstrap-linux.sh
  -> bootstrap apt prerequisites
  -> install/verify Nix
  -> install/verify Homebrew
  -> link checkout at ~/.dev_environment
  -> validate configured identity
  -> nix flake check
  -> nix run .#apply
  -> optional, explicit nix run .#host-ubuntu
  -> nix run .#doctor
```

## Things I want to install

This is the reviewable inventory. Add, remove, or move entries between owners
before implementation. “Brew preferred” means Brew is the default only when it
has a supported Linux package and does not break required functionality.

### Requested baseline

| Category | Tool | Proposed owner | Notes |
| --- | --- | --- | --- |
| Shell | zsh | Ubuntu host + Home Manager | Ubuntu provides the login-shell binary; Home Manager pins Oh My Zsh/plugins and preserves the current prompt |
| Multiplexer | tmux | Brew + Home Manager/Nix plugins | Preserve prefix, splits, pane movement, Catppuccin, TPM, and tmux-cpu behavior without a manual plugin-install step |
| Editor | neovim | Brew preferred | Home Manager owns config; `vim` becomes an alias to `nvim` after acceptance |
| Version control | git, gh, glab, lazygit | Brew | Required GitHub and GitLab CLIs; migrate `gh` from Ubuntu only after auth/config preservation checks |
| CLI utilities | bat, jq, ripgrep, fd, fzf, tree, unzip, wget | Brew | Add utilities deliberately; avoid duplicate apt/Nix installs |
| Go | go, gopls, goimports/gofumpt, delve, golangci-lint | Brew where packaged | Project dependencies stay in `go.mod`; every global Go tool is declared |
| Python | uv, ruff, basedpyright, debugpy | Brew or isolated uv tool | uv manages Python versions/environments; pytest stays project-local; avoid global pip installs |
| Node support | node | Brew | Primarily for AI tools and language servers; no NVM unless a project needs it |
| Per-project environments | direnv + nix-direnv | Home Manager/Nix | Preserve existing direnv use and make project flakes automatic after explicit allow |
| Containers | Docker Engine, Compose, Buildx | Ubuntu host | Docker daemon and plugins must integrate with systemd |
| GPU containers | NVIDIA Container Toolkit | Ubuntu host | Include repository/source normalization and an end-to-end GPU container check |
| AI harness | OpenCode | Brew tap | Keep `anomalyco/tap/opencode` and alias `o` |
| AI harness | Codex CLI | Brew cask; vendor fallback | Already Brew-managed; test version freshness and required features such as remote control |
| AI harness | Claude Code | Brew cask; vendor fallback | Migrate the existing native binary only after Brew passes; preserve all auth/state under `~/.claude` |
| AI harness | Hermes Agent | Brew `hermes-agent`; vendor fallback | Migrate the existing user-local binary only after Brew passes; preserve mutable `~/.hermes` state |
| Agent multiplexer | Herdr | Brew | Required; install the Linux-bottled `herdr` core formula and manage durable config under `~/.config/herdr` |
| Notes | Obsidian | AppImage/vendor | Keep outside Nix store if auto-updating is desired; config/vault remain unmanaged |
| Data tools | sqlite, PostgreSQL client, ClickHouse client | Brew where available | Confirm which clients are still used before migrating |
| Fonts | Meslo Nerd Font | Home Manager/Nix | Replaces the current release-zip download and refresh logic |
| Nix development | nil or nixd, nixfmt | Nix | Used to maintain this repository itself |
| Script/repo checks | shellcheck, shfmt, statix, deadnix | Nix | CI and local checks; not general runtime dependencies |

### Add my remaining tools here during review

| Category | Tool/application | CLI, GUI, or service? | Preferred installer | Required or optional? | Notes |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |

### Candidates imported from the old server setup that need confirmation

- `nvtop`
- `jira-cli`
- `xclip` and/or `wl-clipboard`
- PostgreSQL `libpq` tools
- ClickHouse client
- OpenSSH server and UFW rule
- Obsidian CLI/AppImage
- Bun
- OpenClaw completion support
- private NVIDIA Git/Go settings (`GOPRIVATE`)
- the `~/github` and `~/gitlab` compatibility symlinks
- the outer terminal emulator and its Nerd Font/key-protocol configuration
- existing Brew leaves: Vault, OpenShift CLI (`oc`), Signal CLI, pipx, and GCC

## Neovim migration plan

The first Neovim configuration should be intentionally small and recognizable,
not a large prebuilt distribution.

1. Install Neovim alongside Vim and leave the existing `.vimrc` untouched.
2. Translate the useful existing options and mappings into conventional Lua.
3. Preserve Gruvbox initially, or switch all terminal tools to Catppuccin only
   after the editor works. Avoid changing editor, theme, and key habits together.
4. Add only the baseline plugins: Treesitter, Telescope, Oil file browsing,
   WhichKey leader hints, Git signs, status line, completion, snippets, LSP, and
   formatting.
   Manage them with `lazy.nvim` and commit `lazy-lock.json` so plugin revisions
   are reviewable. The first Neovim launch will require network access.
   `lazy.nvim` owns editor plugins only; Brew/Nix/uv owns LSP servers, formatters,
   linters, and debuggers. Do not introduce Mason as a second binary owner.
5. Use Neovim's built-in tmux clipboard provider inside tmux, with OSC52 as the
   SSH-without-tmux fallback. This keeps remote copy/paste attached to the outer
   terminal and avoids PATH-shadowing desktop clipboard wrappers.
6. Configure language support:
   - Go: `gopls`, `goimports`/`gofumpt`, Delve, and test shortcuts.
   - Python: `basedpyright` or `pyright`, Ruff, uv-aware environments, and pytest.
   - Nix/Lua: `nil` or `nixd`, `nixfmt`, and `lua-language-server`.
7. Set `EDITOR` and `VISUAL` to `nvim`, add `vi`/`vim` compatibility aliases,
   and retain an explicit `oldvim` escape hatch for one migration phase.
8. Validate with `nvim --headless` startup, `:checkhealth`, a Go module, and a uv
   Python project before removing the old Vim setup and config.
9. Verify every LSP/formatter/debugger executable in a clean shell, including
   environment discovery inside tmux and Herdr.

## AI tool configuration

- Continue treating `coding_harnesses` as the durable shared asset repository.
- Keep a small `home/AGENTS.md` in this repo for workstation-wide defaults, and
  keep specialized reusable skills/tools in `coding_harnesses`. Do not duplicate
  large instruction sets between the two repositories.
- Use Home Manager out-of-store symlinks for mutable shared `agents`, `commands`,
  `skills`, and `tools` directories so edits do not require a Nix rebuild.
- Make `coding_harnesses` an explicit configurable dependency. Bootstrap/doctor
  should verify its expected path and provide a clone/setup instruction or a
  clear skip mode; a missing private repository must not cause a cryptic Nix
  evaluation failure.
- Preserve tool-specific top-level config rather than forcing all tools to use
  one schema.
- Add a repo-level `AGENTS.md` for shared project commands and expectations.
  Codex natively layers global and repository `AGENTS.md` instructions.
- Do not add shortcuts equivalent to `claude --dangerously-skip-permissions` or
  `codex --full-auto`; elevated autonomy should remain visible at invocation.
- Keep logins, API keys, OAuth tokens, session databases, histories, caches, and
  generated memory out of both the Nix store and Git.
- Preserve the current unmanaged secret file behavior through one documented,
  permission-checked local file, proposed as
  `~/.config/dev_environment/secrets.env` with mode `0600` (or a future secret
  manager). Migrate `~/.envStuff` deliberately. Home Manager may source the path
  but must never read secret values into a Nix derivation.
- Each AI CLI gets a smoke test (`--version` or `doctor`) but authentication and
  provider selection remain explicit post-install steps.
- Install both `gh` and `glab`, run version smoke tests, and leave `gh auth login`
  and `glab auth login` as explicit post-install steps. Their tokens and generated
  config must never enter the Nix store or repository.

## Herdr and tmux key alignment

Manage `~/.config/herdr/config.toml` from `home/.config/herdr/config.toml` with an
out-of-store Home Manager symlink. Start from `herdr --default-config`, then keep
this familiar mapping as the reviewed baseline:

| Action | tmux habit | Proposed Herdr binding |
| --- | --- | --- |
| Prefix | `Ctrl-Space` | `prefix = "ctrl+space"` |
| Side-by-side split | `prefix`, then `v` | `split_vertical = "prefix+v"` |
| Top/bottom split | `prefix`, then `h` | `split_horizontal = "prefix+h"` |
| Focus left/down/up/right | `Ctrl-h/j/k/l` | `focus_pane_* = "ctrl+h/j/k/l"` |
| New window/tab | `prefix`, then `n` | `new_tab = "prefix+n"` |
| Previous/next window/tab | `Alt-j` / `Alt-k` | `previous_tab = "alt+j"`, `next_tab = "alt+k"` |
| Rename window/tab | `prefix`, then `r` | `rename_tab = "prefix+r"` |
| Resize mode | `prefix`, then `Shift-e`; resize with `h/j/k/l` | `resize_mode = "prefix+shift+e"` |
| Copy mode | `prefix`, then `[` | `copy_mode = "prefix+["`; retain vi selection/copy habits |

Move Herdr's default resize-mode binding away from `prefix+r` so rename remains
familiar. Both configurations use `prefix+shift+e` for resize mode. Keep the
rest of Herdr's actions prefix-first unless there is an intentional tmux
equivalent; direct shortcuts can steal input from shells and Neovim.

Herdr and tmux should be parallel choices, not nested by default. An outer tmux
session would consume `Ctrl-Space` and the direct pane-focus chords before Herdr
sees them. If a nested remote workflow becomes necessary, document a deliberate
send-prefix/passthrough binding and test it in the actual terminal. Validate the
mapping with Herdr's key-help screen and reload changes with
`herdr server reload-config`.

## Migration phases

### Phase 0: inventory and decisions

- Complete the installation inventory above.
- Record Ubuntu version, CPU architecture, GPU/driver, display server, and shell.
- Capture current versions and `command -v` results to detect shadowed binaries.
- Diff the existing Zsh/tmux/Vim configuration into an explicit keep/change/drop
  inventory. Preserve familiar behavior intentionally rather than copying unsafe,
  private-host, or obsolete aliases blindly.
- Decide whether Brew cleanup is report-only or removes unlisted formulae.
- Confirm the outer terminal, display protocol (Wayland/X11), clipboard command,
  and which currently installed Brew leaves must remain.

### Phase 1: flake and read-only checks

- Add the pinned flake, Home Manager configuration, package inventory, and checks.
- Implement `nix run .#doctor` before any apply command.
- Make `nix flake check` build the Home Manager generation without activating it.
- Add Linux CI for `nix flake check`, formatting, ShellCheck, and static Nix checks.
- Keep CI pure and non-mutating: it must not require Homebrew, sudo, credentials,
  the private `coding_harnesses` checkout, or an existing `~/.dev_environment`
  link. Machine integration checks belong to `doctor`/smoke tests after apply.

### Phase 2: shell, links, and terminal

- Migrate Zsh, environment variables, aliases, tmux, fonts, and compatibility
  links to Home Manager.
- Preserve the current prompt and keybindings.
- Provision the existing tmux plugins declaratively (TPM, tmux-cpu, and
  Catppuccin) so a new machine does not require an undocumented `prefix+I` step.
- Copy the reviewed configs into `dev_environment`, then replace the current
  symlinks into `server_setup`; no live dotfile may depend on the old repo after
  this phase.
- Define and test PATH precedence for `~/.local/bin`, Linuxbrew, Nix/Home Manager,
  Go/Bun bins, and system paths. Every shadowed command must be intentional.
- Remove NVM only after Node from Brew is confirmed to cover existing work.

### Phase 3: Homebrew inventory

- Verify Homebrew through the reviewed bootstrap path; install it only on fresh
  hosts. On this machine, adopt and inventory the existing installation.
- Apply the Brewfile without cleanup on the first run.
- Detect and report duplicates across apt, Nix, and Brew.
- Enable cleanup only after the inventory is approved.

### Phase 4: Neovim

- Run Neovim beside Vim, translate configuration, and perform language checks.
- Switch `EDITOR`/`VISUAL`; retain rollback aliases.
- Remove Vim/Pathogen/CoC only after a normal-work validation period.

### Phase 5: AI and forge tools

- Adopt or install OpenCode, Codex, Claude Code, Hermes, and Herdr one at a time.
- Link durable shared assets and run tool-specific diagnostics.
- Authenticate interactively and confirm each tool in a disposable test repo.
- Verify `gh` and `glab` without replacing their existing auth/config directories.

### Phase 6: host services

- Implement Docker/NVIDIA behavior in the narrow Ubuntu host script.
- Treat existing Docker/NVIDIA as satisfied and never install or change the
  NVIDIA display driver. Host changes require an explicit component selection.
- Add regression tests for apt-source normalization,
  NVIDIA repository configuration, service state, and Docker group access.
- Treat SSH/UFW as opt-in rather than silently enabling network access.

### Phase 7: clean-machine validation

- Apply the complete setup twice to prove idempotence.
- Test on a clean Ubuntu VM.
- Remove the transitional Vim configuration only after rollback is no longer
  needed.

## Apply, update, check, and rollback workflow

| Task | Proposed command | Behavior |
| --- | --- | --- |
| Preview | `nix run .#doctor` | Read-only host, PATH, package, and config report |
| Build | `nix flake check` | Evaluate and build without activation |
| Apply user setup | `nix run .#apply` | Preflight/build, Brew install, optional prompted or `--upgrade-brew` upgrade, Home Manager switch, smoke checks |
| Apply host setup | `nix run .#host-ubuntu` | Explicit sudo-required Docker/NVIDIA/SSH work |
| Update pins | `nix flake update` | Review lock-file changes before applying |
| Update Brew tools | `nix run .#brew-update` | Explicit update/upgrade, never incidental to shell startup |
| Roll back HM | `home-manager generations` | Select a previous Home Manager generation |
| Diagnose | `nix run .#doctor` | Explain duplicates, missing tools, PATH order, and failed checks |

Home Manager generations can roll back files and Nix packages. Homebrew and the
Ubuntu host layer cannot roll back with a Nix generation, so the apply command
must report those changes separately. Initial Brew runs should avoid `brew bundle
cleanup`; initial host runs should preserve backups of changed files.

The apply order is intentional: finish all read-only checks and build the Home
Manager generation first; install missing Brew entries without upgrade/cleanup;
then, for interactive applies, offer a separate prompt to update and upgrade the
declared Brewfile entries. Activate Home Manager only after those steps pass,
then run smoke tests. This reduces partial activation when Brew fails. Brew
updates remain opt-in through either that prompt or the explicit update command.
Garbage collection and generation pruning must also be explicit maintenance,
never an automatic side effect of applying configuration.

## Acceptance criteria

- `nix flake check` succeeds on the target Linux architecture.
- A fresh Ubuntu VM reaches the same user environment using only the bootstrap
  script plus interactive credentials.
- Running `nix run .#apply` twice produces no unexpected changes.
- The default apply performs no privileged host changes on the current machine.
- `which -a` shows one intentional primary binary for each managed tool.
- `gh --version` and `glab --version` pass; authenticated API checks are reported
  separately because credentials are intentionally not provisioned.
- Zsh, aliases, tmux keybindings, clipboard behavior, and prompt remain familiar.
- A clean, inheritance-free interactive Zsh proves that the Home Manager
  environment activates automatically and `dev-env-status` reports its source.
- Neovim opens cleanly and Go/Python LSP, format, test, and debug workflows work.
- OpenCode, Codex, Claude, and Hermes start and pass their available diagnostics.
- `herdr --version` succeeds and Herdr can discover the installed agent CLIs.
- Herdr's split, pane navigation, tab navigation, rename, and copy-mode keys
  match the tmux mapping above without breaking Neovim input.
- Docker Compose works without sudo after relogin, and an NVIDIA container can
  see the GPU when the host has one.
- No credentials or mutable runtime state are copied into the Nix store or repo.
- Existing AI, GitHub, and GitLab authentication still works after migration.
- The local secrets file is mode `0600`, is ignored by Git, and its values never
  appear in a derivation, build log, or generated config.
- `~/.zshrc`, tmux, Vim/Neovim, and managed AI config no longer link into
  `server_setup` after their migration phase.
- tmux starts with TPM, tmux-cpu, and Catppuccin available without an interactive
  plugin bootstrap.
- CI runs the same flake, formatting, shell, and static checks used locally.
- A documented recovery path exists for user configuration, Brew changes, and
  privileged host changes.

## Decisions requested during review

1. **Neovim config:** approve the recommended small Lua configuration, or choose
   a distribution such as LazyVim.
2. **Brew cleanup:** start report-only (recommended), or remove unlisted formulae.
3. **Host services:** adopt the existing Docker/NVIDIA setup without changes and
   keep SSH/UFW as a separate opt-in (recommended).
4. **Theme:** preserve Gruvbox during migration (recommended), or standardize on
   Catppuccin immediately.
5. **Terminal/clipboard:** confirm the outer terminal and whether the desktop
   session needs `wl-clipboard`, `xclip`, or both.
6. **Existing tools:** confirm whether Vault, `oc`, Signal CLI, pipx, GCC,
   jira-cli, database clients, nvtop, Bun, and Obsidian remain managed.
7. Complete the “Things I want to install” table.

## Implementation risks to keep visible

- Homebrew is mutable and does not share Nix generation rollback semantics.
- Brew and Nix can silently shadow one another unless PATH and package ownership
  are checked automatically.
- Fast-moving AI CLIs may be stale or feature-incomplete in a package manager;
  their install method needs a per-tool health check, not a blanket rule.
- Enabling SSH or changing UFW is a security-relevant host action and must remain
  opt-in.
- Docker group membership is effectively root-equivalent.
- Nix cannot declaratively own every Ubuntu system service without either NixOS
  or another privileged host-management layer.
- Forced Home Manager links can destroy or hide mutable agent state; manage files,
  not whole state directories, and test backups/restoration.
- Managed-workstation policy may prohibit or revert apt/source/systemd changes;
  host diagnostics must distinguish policy from configuration drift.
- Git-backed flakes ignore untracked files, which can make new modules appear
  missing until the user intentionally stages them.

## Reference points

- [Reference dotfiles repository](https://github.com/kunchenguid/dotfiles)
- [lazy.nvim](https://github.com/folke/lazy.nvim)
- [Herdr Homebrew formula](https://formulae.brew.sh/formula/herdr)
- [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux)
- [Home Manager options](https://nix-community.github.io/home-manager/options.html)
- [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
- [OpenCode installation](https://dev.opencode.ai/docs)
- [Codex CLI](https://github.com/openai/codex)
- [Claude Code setup](https://docs.anthropic.com/en/docs/claude-code/getting-started)
- [Hermes Agent](https://github.com/NousResearch/hermes-agent)
- [Hermes Agent Homebrew formula](https://formulae.brew.sh/formula/hermes-agent)
- [Claude Code Homebrew cask](https://formulae.brew.sh/cask/claude-code)
