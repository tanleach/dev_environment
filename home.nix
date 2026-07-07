{
  config,
  lib,
  pkgs,
  inputs,
  workstation,
  liveConfigRoot,
  ...
}:
let
  outOfStore = config.lib.file.mkOutOfStoreSymlink;

  managedFiles = {
    ".zshrc".source = outOfStore "${liveConfigRoot}/home/.config/zsh/.zshrc";
    ".tmux.conf".source = outOfStore "${liveConfigRoot}/home/.config/tmux/tmux.conf";
    ".config/nvim".source = outOfStore "${liveConfigRoot}/home/.config/nvim";
    ".config/herdr/config.toml".source = outOfStore "${liveConfigRoot}/home/.config/herdr/config.toml";

    # Pin shell and tmux assets through the flake while keeping the familiar
    # system zsh and Homebrew Neovim/tmux binaries.
    ".local/share/oh-my-zsh".source = inputs.oh-my-zsh;
    ".local/share/oh-my-zsh-custom/plugins/zsh-syntax-highlighting".source =
      inputs.zsh-syntax-highlighting;
    ".tmux/plugins/tpm".source = inputs.tpm;
    ".tmux/plugins/tmux-cpu".source = inputs.tmux-cpu;
    ".config/tmux/plugins/catppuccin/tmux".source = inputs.catppuccin-tmux;
  };

  agentFiles = {
    ".codex/AGENTS.md".source = outOfStore "${liveConfigRoot}/home/AGENTS.md";
    ".config/opencode/AGENTS.md".source = outOfStore "${liveConfigRoot}/home/AGENTS.md";
    ".claude/CLAUDE.md".source = outOfStore "${liveConfigRoot}/home/AGENTS.md";
  };
in
{
  assertions = [
    {
      assertion = workstation.system == pkgs.stdenv.hostPlatform.system;
      message = "Configured system does not match the evaluated Nix platform.";
    }
  ];

  home = {
    inherit (workstation) homeDirectory;

    username = workstation.user;
    stateVersion = "26.05";

    packages = with pkgs; [
      deadnix
      lua-language-server
      nerd-fonts.meslo-lg
      nixd
      nixfmt
      shellcheck
      shfmt
      statix
      stylua
    ];

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/bin"
      "$HOME/go/bin"
      "$HOME/.bun/bin"
    ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "cat";
      GOBIN = "$HOME/go/bin";
    };

    file = managedFiles // lib.optionalAttrs workstation.manageAgentConfig agentFiles;
  };

  xdg.enable = true;
  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
  programs.direnv = {
    enable = true;
    enableZshIntegration = false;
    nix-direnv.enable = true;
  };
}
