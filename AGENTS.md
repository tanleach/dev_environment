# Repository working agreements

- Treat `PLAN.md` as the architectural intent and update it when an implementation
  decision changes materially.
- Never place credentials, OAuth tokens, session databases, private keys, secret
  environment values, or generated agent state in this repository or the Nix store.
- Keep Homebrew cleanup disabled unless the user explicitly approves a reviewed
  inventory change.
- Default commands must not mutate apt sources, systemd services, Docker, NVIDIA,
  SSH, UFW, or user groups.
- Preserve existing authentication and mutable state under `~/.claude`,
  `~/.codex`, `~/.config/opencode`, `~/.hermes`, `~/.config/gh`, and GitLab config.
- Run `bash -n`/ShellCheck for shell changes, `nix flake check` when Nix is
  available, and `tests/smoke.sh` only after an intentional apply.
- Keep flake inputs tracked before running Nix; never stage or commit files on
  the user's behalf from bootstrap or apply scripts.
- Use `apply_patch` for hand-authored file changes and keep unrelated user changes.
