{
  description = "Tleach's Linux development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oh-my-zsh = {
      url = "github:ohmyzsh/ohmyzsh";
      flake = false;
    };

    zsh-syntax-highlighting = {
      url = "github:zsh-users/zsh-syntax-highlighting";
      flake = false;
    };

    tpm = {
      url = "github:tmux-plugins/tpm";
      flake = false;
    };

    tmux-cpu = {
      url = "github:tmux-plugins/tmux-cpu";
      flake = false;
    };

    catppuccin-tmux = {
      url = "github:catppuccin/tmux";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      workstation = {
        user = "tleach";
        homeDirectory = "/home/tleach";
        host = "tleach-workstation";
        system = "x86_64-linux";

        # Keep false until the existing agent config/state has been backed up and
        # reviewed. Home Manager must never own entire mutable agent directories.
        manageAgentConfig = false;
      };

      inherit (workstation) system;
      homeTarget = "${workstation.user}@${workstation.host}";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      homeConfiguration = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs workstation;
          liveConfigRoot = "${workstation.homeDirectory}/.dev_environment";
        };
        modules = [ ./home.nix ];
      };

      mkScript =
        name: script:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = with pkgs; [
            bash
            coreutils
            findutils
            gawk
            git
            gnugrep
            gnused
          ];
          text = ''
            export DEV_ENV_SOURCE=${self}
            export DEV_ENV_COMMON=${./scripts/common.sh}
            export DEV_ENV_HOME_TARGET=${homeTarget}
            exec ${pkgs.bash}/bin/bash ${script} "$@"
          '';
        };

      scripts = {
        apply = mkScript "dev-env-apply" ./scripts/apply.sh;
        doctor = mkScript "dev-env-doctor" ./scripts/doctor.sh;
        brew-update = mkScript "dev-env-brew-update" ./scripts/brew-update.sh;
        host-ubuntu = mkScript "dev-env-host-ubuntu" ./scripts/host-ubuntu.sh;
        restore = mkScript "dev-env-restore" ./scripts/restore.sh;
      };
    in
    {
      homeConfigurations.${homeTarget} = homeConfiguration;

      packages.${system} = {
        default = homeConfiguration.activationPackage;
        home-manager = home-manager.packages.${system}.home-manager;
      };

      apps.${system} = {
        apply = {
          type = "app";
          program = "${scripts.apply}/bin/dev-env-apply";
        };
        doctor = {
          type = "app";
          program = "${scripts.doctor}/bin/dev-env-doctor";
        };
        brew-update = {
          type = "app";
          program = "${scripts.brew-update}/bin/dev-env-brew-update";
        };
        host-ubuntu = {
          type = "app";
          program = "${scripts.host-ubuntu}/bin/dev-env-host-ubuntu";
        };
        restore = {
          type = "app";
          program = "${scripts.restore}/bin/dev-env-restore";
        };
      };

      checks.${system} = {
        home = homeConfiguration.activationPackage;

        shell =
          pkgs.runCommand "dev-environment-shell-check"
            {
              nativeBuildInputs = [ pkgs.shellcheck ];
            }
            ''
              shellcheck -x --source-path=${./.} \
                ${./bootstrap-linux.sh} \
                ${./rebuild.sh} \
                ${./scripts/common.sh} \
                ${./scripts/apply.sh} \
                ${./scripts/doctor.sh} \
                ${./scripts/brew-update.sh} \
                ${./scripts/host-ubuntu.sh} \
                ${./scripts/restore.sh} \
                ${./tests/smoke.sh}
              touch "$out"
            '';

        brewfile =
          pkgs.runCommand "dev-environment-brewfile-check"
            {
              nativeBuildInputs = [ pkgs.ruby ];
            }
            ''
              ruby -c ${./brew/Brewfile}
              touch "$out"
            '';
      };

      formatter.${system} = pkgs.nixfmt;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          deadnix
          nixd
          nixfmt
          shellcheck
          shfmt
          statix
          stylua
        ];
      };
    };
}
