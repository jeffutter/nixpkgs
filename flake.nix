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
      url = "github:jeffutter/iio_ambient_brightness/v0.2.17";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-tail = {
      url = "github:jeffutter/claude-tail/v0.2.4";
    };

    peon-ping = {
      url = "github:PeonPing/peon-ping";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Intentionally NOT following nixpkgs: numtide builds and caches these
    # packages (agent-browser, pi, rtk) against their own pinned nixpkgs.
    # Making them follow our nixpkgs changes the derivation hashes, so they
    # miss numtide's binary cache and rebuild locally -- agent-browser's
    # pnpm-deps step in particular gets OOM-killed. Using numtide's pin makes
    # these pure cache downloads.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
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
      url = "github:vale-cli/proselint/v0.3.4";
      flake = false;
    };
    vale-write-good = {
      url = "github:vale-cli/write-good/v0.4.1";
      flake = false;
    };
    vale-alex = {
      url = "github:vale-cli/alex/v0.2.3";
      flake = false;
    };

    stop-slop = {
      url = "github:hardikpandya/stop-slop";
      flake = false;
    };

    humanizer = {
      url = "github:blader/humanizer";
      flake = false;
    };

    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    apollo_skills = {
      url = "github:apollographql/skills";
      flake = false;
    };

    ast-grep-skill = {
      url = "github:ast-grep/agent-skill";
      flake = false;
    };

    grill-me-skill = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    # Fish plugins
    fish-plugin-fenv = {
      url = "github:oh-my-fish/plugin-foreign-env/7f0cf099ae1e1e4ab38f46350ed6757d54471de7";
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

    backlog-md = {
      url = "github:MrLesk/Backlog.md";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    todoist-cli-src = {
      url = "github:Doist/todoist-cli/v1.69.3";
      flake = false;
    };

    kami = {
      url = "github:tw93/kami";
      flake = false;
    };

    screenpipe-src = {
      url = "github:screenpipe/screenpipe";
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
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    let
      nixpkgsConfig = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
        permittedInsecurePackages = [ "p7zip-16.02" ];
      };

      claudeCodeOverlay =
        final: prev:
        let
          claudeCodeVersion = "2.1.195";
          claudeCodeBaseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
          # Run `nix-prefetch-url <url>` for your platform to get the correct hash
          # URL format: ${claudeCodeBaseUrl}/${claudeCodeVersion}/<platform>/claude
          # Platforms: darwin-arm64, darwin-x64, linux-arm64, linux-x64
          claudeCodeChecksums = {
            "darwin-arm64" = "sha256-i0WtrZPzNquV8z5xRJSxn9M3eklOsFwSLIZ3vIlYdq0=";
            "darwin-x64" = "sha256-frhxbm1uaieNExWHk1KTNikIN/ykV/rP7GVvGxoofGA=";
            "linux-arm64" = "sha256-sCJ5mZBY3ICg4cXTlGPRVFoXhhVJL4QTmqyNYSFKfpo=";
            "linux-x64" = "sha256-gyPnASUGMUekR4uVd0XYNah+XnL/0luDjqmoQcA+ajc=";
          };
          platformKey = "${final.stdenv.hostPlatform.parsed.kernel.name}-${
            if final.stdenv.hostPlatform.isAarch64 then "arm64" else "x64"
          }";
        in
        {
          claude-code = prev.claude-code.overrideAttrs (oldAttrs: {
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
            config = nixpkgsConfig;
            overlays = [
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
              config = nixpkgsConfig;
              overlays = [
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
              config = nixpkgsConfig;
              overlays = [
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
              config = nixpkgsConfig;
              overlays = [
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
              config = nixpkgsConfig;
              overlays = [
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

      packages = forAllSystems (system: {
        actual-cli = (pkgsFor system).callPackage ./pkgs/actual-cli { };
        todoist-cli = (pkgsFor system).callPackage ./pkgs/todoist-cli { src = inputs.todoist-cli-src; };
        screenpipe = (pkgsFor system).callPackage ./pkgs/screenpipe { src = inputs.screenpipe-src; };
        colgrep = (pkgsFor system).callPackage ./pkgs/colgrep { };
      });

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
