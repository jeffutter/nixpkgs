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

    claude-tail = {
      url = "github:jeffutter/claude-tail/v0.2.0";
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

    superpowers = {
      url = "github:obra/superpowers";
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

    the-elements-of-style = {
      url = "github:obra/the-elements-of-style";
      flake = false;
    };

    ticket = {
      url = "github:jeffutter/ticket";
      flake = false;
    };

    opencode-src = {
      url = "github:anomalyco/opencode/v1.2.2";
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
      opencode-src,
      ...
    }@inputs:
    let
      # Overlay to patch opencode version
      # Parse version from packages/opencode/package.json in the source
      opencodePackageJson = builtins.fromJSON (
        builtins.readFile "${opencode-src}/packages/opencode/package.json"
      );
      opencodeVersion = opencodePackageJson.version;

      opencodeOverlay = final: prev: {
        opencode = prev.opencode.overrideAttrs (oldAttrs: {
          version = opencodeVersion;
          src = opencode-src;
          node_modules = oldAttrs.node_modules.overrideAttrs (nodeAttrs: {
            outputHash = "sha256-V+a9EkD/wrVLnd3LpPlgT6HSLkzavPpF+RjMrDib1Nc=";
          });
        });
      };

      claudeCodeOverlay =
        final: prev:
        let
          claudeCodeVersion = "2.1.42";
          claudeCodeBaseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
          # Run `nix-prefetch-url <url>` for your platform to get the correct hash
          # URL format: ${claudeCodeBaseUrl}/${claudeCodeVersion}/<platform>/claude
          # Platforms: darwin-arm64, darwin-x64, linux-arm64, linux-x64
          claudeCodeChecksums = {
            "darwin-arm64" = "sha256-aQgVK/GkursT3oZkDzeVNJAFBptUHUuKOZaAK4Y6Av0=";
            "darwin-x64" = "sha256-Gk4dL5m22bKUYHveQCtnRhNP+pE7InZ+5F+/gg38wbQ=";
            "linux-arm64" = "sha256-WnXQcTKHtjZjagbOkQP/VPV4gXDy6TEvx1WRIfZJ028=";
            "linux-x64" = "sha256-UXhb0m0oljloGYMrwjoYpsDKObe3YRk/p7bpkKF/J9g=";
          };
          platformKey = "${final.stdenv.hostPlatform.parsed.kernel.name}-${
            if final.stdenv.hostPlatform.isAarch64 then "arm64" else "x64"
          }";
        in
        {
          claude-code-bin = prev.claude-code-bin.overrideAttrs (oldAttrs: {
            version = claudeCodeVersion;
            src = final.fetchurl {
              url = "${claudeCodeBaseUrl}/${claudeCodeVersion}/${platformKey}/claude";
              hash = claudeCodeChecksums.${platformKey};
            };
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
            overlays = [
              opencodeOverlay
              claudeCodeOverlay
            ];
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
              overlays = [
                opencodeOverlay
                claudeCodeOverlay
              ];
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
              overlays = [
                opencodeOverlay
                claudeCodeOverlay
              ];
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
              overlays = [
                opencodeOverlay
                claudeCodeOverlay
              ];
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
              overlays = [
                opencodeOverlay
                claudeCodeOverlay
              ];
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
