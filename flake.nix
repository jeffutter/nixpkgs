{
  description = "jeffutter's NixOS and home-manager configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    expert = {
      url = "github:elixir-lang/expert";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zenbook-specific flakes
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    iio-ambient-brightness = {
      url = "github:jeffutter/iio_ambient_brightness/v0.2.16";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fabric = {
      url = "github:danielmiessler/Fabric";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-options-search = {
      url = "github:madsbv/nix-options-search";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    beads = {
      url = "github:steveyegge/beads/v0.49.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tinted-theming-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };

    # Vale prose linting styles
    vale-proselint = {
      url = "github:errata-ai/proselint/v0.3.4";
      flake = false;
    };
    vale-write-good = {
      url = "github:errata-ai/write-good/v0.4.1";
      flake = false;
    };
    vale-alex = {
      url = "github:errata-ai/alex/v0.2.3";
      flake = false;
    };

    stop-slop = {
      url = "github:hardikpandya/stop-slop";
      flake = false;
    };

    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };

    # Fish plugins
    fish-plugin-fenv = {
      url = "github:oh-my-fish/plugin-foreign-env/b3dd471bcc885b597c3922e4de836e06415e52dd";
      flake = false;
    };

    fish-plugin-autopair = {
      url = "github:jorgebucaran/autopair.fish/1.0.4";
      flake = false;
    };

    happy = {
      url = "github:slopus/happy";
      flake = false;
    };

    the-elements-of-style = {
      url = "github:obra/the-elements-of-style";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      nixos-hardware,
      nixvim,
      expert,
      ...
    }@inputs:
    let
      # Overlay to patch opencode version
      opencodeOverlay = final: prev: {
        opencode = prev.opencode.overrideAttrs (oldAttrs: {
          version = "1.1.43";
          src = prev.fetchFromGitHub {
            owner = "anomalyco";
            repo = "opencode";
            rev = "v1.1.43";
            hash = "sha256-+CBqfdK3mw5qnl4sViFEcTSslW0sOE53AtryD2MdhTI=";
          };
          node_modules = oldAttrs.node_modules.overrideAttrs (nodeAttrs: {
            outputHash = "sha256-zkinMkPR1hCBbB5BIuqozQZDpjX4eiFXjM6lpwUx1fM=";
          });
        });
      };

      mkHome =
        {
          system,
          username,
          homeDirectory,
          extraModules ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            config.input-fonts.acceptLicense = true;
            config.permittedInsecurePackages = [ "p7zip-16.02" ];
            overlays = [ opencodeOverlay ];
          };
          extraSpecialArgs = { inherit inputs; };
          modules = [
            inputs.stylix.homeModules.stylix
            ./modules/home/common.nix
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        zenbook =
          let
            system = "x86_64-linux";
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                input-fonts.acceptLicense = true;
                permittedInsecurePackages = [ "p7zip-16.02" ];
              };
              overlays = [ opencodeOverlay ];
            };
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [
              { nixpkgs.pkgs = pkgs; }
              ./hosts/zenbook/default.nix
              nixos-hardware.nixosModules.common-pc-laptop
              nixos-hardware.nixosModules.common-cpu-intel
              nixos-hardware.nixosModules.common-gpu-intel
              inputs.stylix.nixosModules.stylix
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.sharedModules = [ inputs.stylix.homeModules.stylix ];
                home-manager.users.jeffutter = {
                  imports = [
                    ./modules/home/common.nix
                    ./modules/home/linux.nix
                    ./hosts/zenbook/home.nix
                  ];
                };
              }
            ];
          };

        workstation =
          let
            system = "x86_64-linux";
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                input-fonts.acceptLicense = true;
                permittedInsecurePackages = [ "p7zip-16.02" ];
              };
              overlays = [ opencodeOverlay ];
            };
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [
              { nixpkgs.pkgs = pkgs; }
              ./hosts/workstation/default.nix
              inputs.stylix.nixosModules.stylix
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.sharedModules = [ inputs.stylix.homeModules.stylix ];
                home-manager.users.jeffutter = {
                  imports = [
                    ./modules/home/common.nix
                    ./modules/home/linux.nix
                    ./hosts/workstation/home.nix
                  ];
                };
              }
            ];
          };
      };

      darwinConfigurations = {
        work =
          let
            system = "aarch64-darwin";
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                input-fonts.acceptLicense = true;
                permittedInsecurePackages = [ "p7zip-16.02" ];
              };
              overlays = [ opencodeOverlay ];
            };
          in
          nix-darwin.lib.darwinSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [
              { nixpkgs.pkgs = pkgs; }
              ./hosts/work/default.nix
              inputs.stylix.darwinModules.stylix
              home-manager.darwinModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = false; # Keep packages in ~/.nix-profile/bin/
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.sharedModules = [ inputs.stylix.homeModules.stylix ];
                home-manager.users."jeffery.utter" = {
                  imports = [
                    ./modules/home/common.nix
                    ./modules/home/darwin.nix
                    ./hosts/work/home.nix
                  ];
                };
              }
            ];
          };

        personal =
          let
            system = "aarch64-darwin";
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                input-fonts.acceptLicense = true;
                permittedInsecurePackages = [ "p7zip-16.02" ];
              };
              overlays = [ opencodeOverlay ];
            };
          in
          nix-darwin.lib.darwinSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [
              { nixpkgs.pkgs = pkgs; }
              ./hosts/personal/default.nix
              inputs.stylix.darwinModules.stylix
              home-manager.darwinModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = false; # Keep packages in ~/.nix-profile/bin/
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.sharedModules = [ inputs.stylix.homeModules.stylix ];
                home-manager.users.jeffutter = {
                  imports = [
                    ./modules/home/common.nix
                    ./modules/home/darwin.nix
                    ./hosts/personal/home.nix
                  ];
                };
              }
            ];
          };
      };

      homeConfigurations = {
        "jeffutter@personal" = mkHome {
          system = "aarch64-darwin";
          username = "jeffutter";
          homeDirectory = "/Users/jeffutter";
          extraModules = [
            ./modules/home/darwin.nix
            ./hosts/personal/home.nix
          ];
        };

        "jeffery.utter@work" = mkHome {
          system = "aarch64-darwin";
          username = "jeffery.utter";
          homeDirectory = "/Users/Jeffery.Utter";
          extraModules = [
            ./modules/home/darwin.nix
            ./hosts/work/home.nix
          ];
        };
      };
    };
}
